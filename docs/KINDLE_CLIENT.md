# Kindle Client

## Status

V0.5 is implemented and locally simulated, but final acceptance requires the physical KT3. The current network scan did not find an open Kindle SSH service.

Target device:

- Kindle 8th Generation (`KT3`)
- firmware `5.13.7`
- WatchThis jailbreak and hotfix
- 600 x 800 portrait display

## Behavior

The KUAL extension provides three actions:

- **Start hourly dashboard**: keeps Wi-Fi available, stops the Amazon framework, downloads immediately, then refreshes every 3600 seconds;
- **Refresh now**: performs one download and display attempt;
- **Stop and restore Kindle**: stops the loop, restores the framework, and re-enables the normal screensaver behavior.

Each refresh downloads to a temporary file, verifies the PNG signature, atomically replaces the saved image, clears the screen, and displays it with Kindle's built-in `eips`. A failed or invalid download leaves the current screen unchanged.

The client uses `curl` when available and otherwise uses `wget`. It stores only the latest PNG, PID, and a local log under its extension directory.

## Installation option A: SSH

Enable SSH over Wi-Fi through USBNetwork or the installed jailbreak tooling, find the Kindle IP, then run:

```bash
./Scripts/install-kindle-client.sh KINDLE_IP
```

The installer verifies `eips`, `wget`/`curl`, and KUAL's `/mnt/us/extensions` directory before replacing anything. It copies the extension, writes the current Mac dashboard URL, and starts dashboard mode. SSH credentials are never stored in the repository.

Use a non-default SSH port with:

```bash
KINDLE_SSH_PORT=2222 ./Scripts/install-kindle-client.sh KINDLE_IP
```

Uninstall and restore the normal Kindle interface:

```bash
./Scripts/uninstall-kindle-client.sh KINDLE_IP
```

## Installation option B: USB

Connect the Kindle by USB and confirm its volume contains an `extensions` directory, then run:

```bash
./Scripts/install-kindle-client-usb.sh /Volumes/Kindle
```

Safely eject the Kindle, open KUAL, and choose:

```text
Smart Dashboard > Start hourly dashboard
```

The USB route does not require SSH, but it does require KUAL to be installed and one manual menu tap after copying.

## Configuration

The installers create `config.local.sh` without changing the packaged defaults:

```sh
DASHBOARD_URL='http://192.168.110.35:8080/dashboard.png'
```

The Mac address may change after reconnecting to Wi-Fi. A DHCP reservation for the Mac is recommended before treating the dashboard as a permanent appliance.

## Local verification

```bash
./Tests/KindleClientTests/test-refresh.sh
```

The simulation downloads the live 600 x 800 PNG from the installed Mac service, verifies its PNG signature, records fake `eips` calls, then requests an invalid URL and confirms the valid image remains unchanged.

## Implementation references

- [FBInk documentation](https://github.com/KindleModding/FBInk) documents Kindle image support and notes the built-in availability of `eips` on Kindle.
- [KUAL extension example](https://gist.github.com/rvagg/5095506) demonstrates the `/mnt/us/extensions/<name>` layout and `menu.json` action format.
