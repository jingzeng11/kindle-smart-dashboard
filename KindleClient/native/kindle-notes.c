#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <linux/input.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <time.h>

#define SCREEN_WIDTH 600
#define SCREEN_HEIGHT 800
#define WRITING_TOP 155
#define WRITING_BOTTOM 700
#define TOOLBAR_TOP 700
#define BRUSH_RADIUS 2
#define WAVEFORM_MODE_DU 2
#define UPDATE_MODE_PARTIAL 0
#define TEMP_USE_AMBIENT 0x1000
#define MXCFB_SEND_UPDATE 0x4040462eUL

struct mxcfb_rect {
    uint32_t top;
    uint32_t left;
    uint32_t width;
    uint32_t height;
};

struct mxcfb_alt_buffer_data {
    uint32_t phys_addr;
    uint32_t width;
    uint32_t height;
    struct mxcfb_rect alt_update_region;
};

struct mxcfb_update_data {
    struct mxcfb_rect update_region;
    uint32_t waveform_mode;
    uint32_t update_mode;
    uint32_t update_marker;
    int32_t temp;
    uint32_t flags;
    struct mxcfb_alt_buffer_data alt_buffer_data;
};

struct note_point {
    uint16_t x;
    uint16_t y;
    uint8_t starts_stroke;
    uint8_t reserved;
} __attribute__((packed));

struct framebuffer {
    int fd;
    uint8_t *pixels;
    size_t length;
    struct fb_var_screeninfo var;
    struct fb_fix_screeninfo fix;
};

static int framebuffer_open(struct framebuffer *fb) {
    memset(fb, 0, sizeof(*fb));
    fb->fd = open("/dev/fb0", O_RDWR);
    if (fb->fd < 0) return -1;
    if (ioctl(fb->fd, FBIOGET_VSCREENINFO, &fb->var) < 0 ||
        ioctl(fb->fd, FBIOGET_FSCREENINFO, &fb->fix) < 0) {
        close(fb->fd);
        return -1;
    }
    fb->length = (size_t)fb->fix.line_length * fb->var.yres_virtual;
    fb->pixels = mmap(NULL, fb->length, PROT_READ | PROT_WRITE, MAP_SHARED, fb->fd, 0);
    if (fb->pixels == MAP_FAILED) {
        close(fb->fd);
        return -1;
    }
    return 0;
}

static void framebuffer_close(struct framebuffer *fb) {
    if (fb->pixels && fb->pixels != MAP_FAILED) munmap(fb->pixels, fb->length);
    if (fb->fd >= 0) close(fb->fd);
}

static int screen_x(const struct framebuffer *fb, int x) {
    return x * (int)fb->var.xres / SCREEN_WIDTH;
}

static int screen_y(const struct framebuffer *fb, int y) {
    return y * (int)fb->var.yres / SCREEN_HEIGHT;
}

static void put_black_pixel(struct framebuffer *fb, int logical_x, int logical_y) {
    int x = screen_x(fb, logical_x);
    int y = screen_y(fb, logical_y);
    if (x < 0 || y < 0 || x >= (int)fb->var.xres || y >= (int)fb->var.yres) return;
    size_t offset = (size_t)(y + fb->var.yoffset) * fb->fix.line_length;
    offset += (size_t)(x + fb->var.xoffset) * fb->var.bits_per_pixel / 8;
    if (offset >= fb->length) return;
    if (fb->var.bits_per_pixel == 8) {
        fb->pixels[offset] = 0;
    } else if (fb->var.bits_per_pixel == 16 && offset + 1 < fb->length) {
        fb->pixels[offset] = 0;
        fb->pixels[offset + 1] = 0;
    } else if (fb->var.bits_per_pixel == 32 && offset + 3 < fb->length) {
        memset(fb->pixels + offset, 0, 4);
    }
}

static void draw_brush(struct framebuffer *fb, int x, int y) {
    for (int dy = -BRUSH_RADIUS; dy <= BRUSH_RADIUS; dy++) {
        for (int dx = -BRUSH_RADIUS; dx <= BRUSH_RADIUS; dx++) {
            if (dx * dx + dy * dy <= BRUSH_RADIUS * BRUSH_RADIUS + 1) {
                put_black_pixel(fb, x + dx, y + dy);
            }
        }
    }
}

static void draw_line(struct framebuffer *fb, int x0, int y0, int x1, int y1) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int error = dx + dy;
    for (;;) {
        draw_brush(fb, x0, y0);
        if (x0 == x1 && y0 == y1) break;
        int twice = 2 * error;
        if (twice >= dy) { error += dy; x0 += sx; }
        if (twice <= dx) { error += dx; y0 += sy; }
    }
}

static void refresh_region(struct framebuffer *fb, int left, int top, int width, int height) {
    static uint32_t marker = 1;
    if (left < 0) { width += left; left = 0; }
    if (top < 0) { height += top; top = 0; }
    if (left + width > SCREEN_WIDTH) width = SCREEN_WIDTH - left;
    if (top + height > SCREEN_HEIGHT) height = SCREEN_HEIGHT - top;
    if (width <= 0 || height <= 0) return;
    struct mxcfb_update_data update;
    memset(&update, 0, sizeof(update));
    update.update_region.left = (uint32_t)screen_x(fb, left);
    update.update_region.top = (uint32_t)screen_y(fb, top);
    update.update_region.width = (uint32_t)screen_x(fb, width);
    update.update_region.height = (uint32_t)screen_y(fb, height);
    update.waveform_mode = WAVEFORM_MODE_DU;
    update.update_mode = UPDATE_MODE_PARTIAL;
    update.update_marker = marker++;
    update.temp = TEMP_USE_AMBIENT;
    ioctl(fb->fd, MXCFB_SEND_UPDATE, &update);
}

static int append_point(int fd, int x, int y, int starts_stroke) {
    if (fd < 0) return -1;
    struct note_point point = {
        .x = (uint16_t)x,
        .y = (uint16_t)y,
        .starts_stroke = (uint8_t)(starts_stroke ? 1 : 0),
        .reserved = 0
    };
    ssize_t written = write(fd, &point, sizeof(point));
    return written == (ssize_t)sizeof(point) ? 0 : -1;
}

static int64_t monotonic_milliseconds(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) return 0;
    return (int64_t)value.tv_sec * 1000 + value.tv_nsec / 1000000;
}

static void include_dirty_point(int x, int y, int *left, int *top, int *right, int *bottom) {
    if (x - 8 < *left) *left = x - 8;
    if (y - 8 < *top) *top = y - 8;
    if (x + 8 > *right) *right = x + 8;
    if (y + 8 > *bottom) *bottom = y + 8;
}

static void flush_dirty_region(struct framebuffer *fb, int force, int *left, int *top,
                               int *right, int *bottom, int64_t *last_refresh) {
    if (*right < *left || *bottom < *top) return;
    int64_t now = monotonic_milliseconds();
    if (!force && now - *last_refresh < 180) return;
    refresh_region(fb, *left, *top, *right - *left + 1, *bottom - *top + 1);
    *left = SCREEN_WIDTH;
    *top = SCREEN_HEIGHT;
    *right = -1;
    *bottom = -1;
    *last_refresh = now;
}

static void redraw_strokes(struct framebuffer *fb, const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return;
    struct note_point point;
    int have_previous = 0;
    int previous_x = 0, previous_y = 0;
    while (read(fd, &point, sizeof(point)) == (ssize_t)sizeof(point)) {
        if (!point.starts_stroke && have_previous) {
            draw_line(fb, previous_x, previous_y, point.x, point.y);
        } else {
            draw_brush(fb, point.x, point.y);
        }
        previous_x = point.x;
        previous_y = point.y;
        have_previous = 1;
    }
    close(fd);
    refresh_region(fb, 0, WRITING_TOP, SCREEN_WIDTH, WRITING_BOTTOM - WRITING_TOP);
}

static int show_base_image(const char *image_path) {
    pid_t child = fork();
    if (child < 0) return -1;
    if (child == 0) {
        execl("/usr/sbin/eips", "eips", "-g", image_path, (char *)NULL);
        _exit(127);
    }
    int status = 0;
    return waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -1;
}

static void restore_and_redraw(struct framebuffer *fb, const char *image_path, const char *notes_path) {
    show_base_image(image_path);
    redraw_strokes(fb, notes_path);
}

static void undo_last_stroke(const char *path) {
    int fd = open(path, O_RDWR);
    if (fd < 0) return;
    off_t size = lseek(fd, 0, SEEK_END);
    if (size < (off_t)sizeof(struct note_point)) { close(fd); return; }
    size_t count = (size_t)size / sizeof(struct note_point);
    struct note_point *points = malloc(count * sizeof(*points));
    if (!points) { close(fd); return; }
    lseek(fd, 0, SEEK_SET);
    ssize_t bytes = read(fd, points, count * sizeof(*points));
    if (bytes > 0) {
        size_t valid_count = (size_t)bytes / sizeof(*points);
        size_t truncate_at = valid_count;
        while (truncate_at > 0) {
            truncate_at--;
            if (points[truncate_at].starts_stroke) break;
        }
        ftruncate(fd, (off_t)(truncate_at * sizeof(*points)));
        fsync(fd);
    }
    free(points);
    close(fd);
}

static void clear_strokes(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) close(fd);
}

static int toolbar_action(int x, int y) {
    if (y < TOOLBAR_TOP) return 0;
    if (x < 200) return 1;  /* undo */
    if (x < 400) return 2;  /* clear */
    return 3;               /* read */
}

static int watch_touch(const char *device_path, const char *image_path,
                       const char *notes_path, pid_t dashboard_pid) {
    int input_fd = open(device_path, O_RDONLY);
    if (input_fd < 0) return 2;
    struct framebuffer fb;
    if (framebuffer_open(&fb) < 0) { close(input_fd); return 3; }
    int notes_fd = open(notes_path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (notes_fd < 0) { framebuffer_close(&fb); close(input_fd); return 4; }

    int touching = 0, drawing = 0, stroke_started = 0;
    int x = 0, y = 0, start_x = 0, start_y = 0, previous_x = 0, previous_y = 0;
    int dirty_left = SCREEN_WIDTH, dirty_top = SCREEN_HEIGHT, dirty_right = -1, dirty_bottom = -1;
    int64_t last_refresh = monotonic_milliseconds();
    struct input_event event;

    while (read(input_fd, &event, sizeof(event)) == (ssize_t)sizeof(event)) {
        if (event.type == EV_ABS && event.code == ABS_MT_POSITION_X) x = event.value;
        if (event.type == EV_ABS && event.code == ABS_MT_POSITION_Y) y = event.value;
        if (event.type == EV_ABS && event.code == ABS_MT_TRACKING_ID) {
            if (event.value >= 0) {
                touching = 1;
                drawing = 0;
                stroke_started = 0;
            } else {
                if (drawing) {
                    flush_dirty_region(&fb, 1, &dirty_left, &dirty_top, &dirty_right, &dirty_bottom, &last_refresh);
                    fsync(notes_fd);
                }
                if (touching && !drawing) {
                    int action = toolbar_action(start_x, start_y);
                    if (action == 1) {
                        undo_last_stroke(notes_path);
                        restore_and_redraw(&fb, image_path, notes_path);
                    } else if (action == 2) {
                        clear_strokes(notes_path);
                        restore_and_redraw(&fb, image_path, notes_path);
                    } else if (action == 3) {
                        kill(dashboard_pid, SIGTERM);
                        break;
                    }
                }
                touching = 0;
                drawing = 0;
                stroke_started = 0;
            }
        }
        if (event.type == EV_SYN && event.code == SYN_REPORT && touching) {
            if (!stroke_started) {
                start_x = x;
                start_y = y;
                previous_x = x;
                previous_y = y;
                stroke_started = 1;
            }
            if (start_y >= WRITING_TOP && start_y < WRITING_BOTTOM &&
                y >= WRITING_TOP && y < WRITING_BOTTOM) {
                if (!drawing) {
                    append_point(notes_fd, x, y, 1);
                    draw_brush(&fb, x, y);
                    drawing = 1;
                } else if (x != previous_x || y != previous_y) {
                    append_point(notes_fd, x, y, 0);
                    draw_line(&fb, previous_x, previous_y, x, y);
                }
                include_dirty_point(previous_x, previous_y, &dirty_left, &dirty_top, &dirty_right, &dirty_bottom);
                include_dirty_point(x, y, &dirty_left, &dirty_top, &dirty_right, &dirty_bottom);
                previous_x = x;
                previous_y = y;
                flush_dirty_region(&fb, 0, &dirty_left, &dirty_top, &dirty_right, &dirty_bottom, &last_refresh);
            }
        }
    }

    close(notes_fd);
    framebuffer_close(&fb);
    close(input_fd);
    return 0;
}

static void usage(const char *program) {
    fprintf(stderr, "Usage: %s redraw NOTES_FILE | watch INPUT IMAGE NOTES_FILE DASHBOARD_PID\n", program);
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "redraw") == 0) {
        struct framebuffer fb;
        if (framebuffer_open(&fb) < 0) return 3;
        redraw_strokes(&fb, argv[2]);
        framebuffer_close(&fb);
        return 0;
    }
    if (argc == 6 && strcmp(argv[1], "watch") == 0) {
        return watch_touch(argv[2], argv[3], argv[4], (pid_t)strtol(argv[5], NULL, 10));
    }
    usage(argv[0]);
    return 1;
}
