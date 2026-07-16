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

        switch path {
        case "/health":
            return textResponse(200, "OK", "ok\n")
        case "/dashboard.png":
            do {
                let data = try Data(contentsOf: imageURL)
                return HTTPResponse(statusCode: 200, reason: "OK", contentType: "image/png", body: data)
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
