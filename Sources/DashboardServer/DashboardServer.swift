import AppKit
import Foundation
import Network

public struct HTTPResponse: Equatable {
    public let statusCode: Int
    public let reason: String
    public let contentType: String
    public let body: Data

    public init(statusCode: Int, reason: String, contentType: String, body: Data) {
        self.statusCode = statusCode
        self.reason = reason
        self.contentType = contentType
        self.body = body
    }

    public var encoded: Data {
        let header = [
            "HTTP/1.1 \(statusCode) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-cache",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        var result = Data(header.utf8)
        result.append(body)
        return result
    }
}

public struct DashboardRouter {
    public let imageURL: URL

    public init(imageURL: URL) {
        self.imageURL = imageURL
    }

    public func response(method: String, path: String) -> HTTPResponse {
        guard method == "GET" else {
            return textResponse(405, "Method Not Allowed", "仅支持 GET 请求。\n")
        }

        let components = URLComponents(string: "http://localhost\(path)")
        let requestPath = components?.path ?? path

        switch requestPath {
        case "/health":
            return textResponse(200, "OK", "ok\n")
        case "/dashboard.png":
            do {
                let data = try Data(contentsOf: imageURL)
                let batteryLevel = components?.queryItems?
                    .first(where: { $0.name == "battery" })?
                    .value
                    .flatMap(Int.init)
                    .flatMap { (0...100).contains($0) ? $0 : nil }
                let body = DashboardOverlay.render(batteryLevel: batteryLevel, onto: data) ?? data
                return HTTPResponse(statusCode: 200, reason: "OK", contentType: "image/png", body: body)
            } catch {
                return textResponse(404, "Not Found", "仪表盘图片尚未生成。请先运行 render 命令。\n")
            }
        default:
            return textResponse(404, "Not Found", "未找到该路径。\n")
        }
    }

    private func textResponse(_ code: Int, _ reason: String, _ text: String) -> HTTPResponse {
        HTTPResponse(
            statusCode: code,
            reason: reason,
            contentType: "text/plain; charset=utf-8",
            body: Data(text.utf8)
        )
    }
}

enum DashboardOverlay {
    static func render(batteryLevel: Int?, onto pngData: Data) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: pngData),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        let height = CGFloat(bitmap.pixelsHigh)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSColor.white.setFill()
        if let level = batteryLevel {
            NSRect(x: 478, y: height - 32, width: 82, height: 24).fill()

            let batteryFrame = NSRect(x: 484, y: height - 24, width: 20, height: 11)
            let outline = NSBezierPath(roundedRect: batteryFrame, xRadius: 2, yRadius: 2)
            outline.lineWidth = 1.5
            NSColor.black.setStroke()
            outline.stroke()
            NSRect(x: 504, y: height - 21, width: 2, height: 5).fill()

            let fillWidth = max(0, 16 * CGFloat(level) / 100)
            NSRect(x: 486, y: height - 22, width: fillWidth, height: 7).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph
            ]
            ("\(level)%" as NSString).draw(
                in: NSRect(x: 508, y: height - 29, width: 52, height: 20),
                withAttributes: attributes
            )
        }

        drawTouchControls(height: height)

        context.flushGraphics()
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func drawTouchControls(height: CGFloat) {
        let labels = ["撤销", "清空", "阅读"]
        let positions: [CGFloat] = [0, 200, 400]
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor(deviceWhite: 0.42, alpha: 1),
            .paragraphStyle: paragraph
        ]

        for (label, x) in zip(labels, positions) {
            (label as NSString).draw(
                in: NSRect(x: x, y: height - 739, width: 200, height: 22),
                withAttributes: attributes
            )
        }
    }
}

public final class DashboardHTTPServer {
    private let router: DashboardRouter
    private let listener: NWListener
    private let queue = DispatchQueue(label: "KindleSmartDashboard.HTTPServer")

    public init(host: String, port: UInt16, imageURL: URL) throws {
        guard let networkPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPort(port)
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(host), port: networkPort)
        self.listener = try NWListener(using: parameters)
        self.router = DashboardRouter(imageURL: imageURL)
    }

    public func start() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            if case let .failed(error) = state {
                fputs("服务器错误：\(error)\n", stderr)
            }
        }
        listener.start(queue: queue)
    }

    public func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            guard let self else { return }
            let requestLine = data.flatMap { String(data: $0, encoding: .utf8) }?
                .split(separator: "\r\n", maxSplits: 1)
                .first?
                .split(separator: " ")
            let method = requestLine.flatMap { $0.indices.contains(0) ? String($0[0]) : nil } ?? ""
            let path = requestLine.flatMap { $0.indices.contains(1) ? String($0[1]) : nil } ?? ""
            let response = self.router.response(method: method, path: path)
            connection.send(content: response.encoded, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

public enum ServerError: Error, LocalizedError {
    case invalidPort(UInt16)

    public var errorDescription: String? {
        switch self {
        case let .invalidPort(port):
            return "无效端口：\(port)"
        }
    }
}
