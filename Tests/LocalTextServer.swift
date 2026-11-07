import Foundation
import Network

/// A real loopback HTTP fixture, started by each test. No Internet/account dependency.
final class LocalTextServer: @unchecked Sendable {
    let listener: NWListener
    private let queue = DispatchQueue(label: "MusiquePapa.fixture.http")
    init(data: Data, ready: @escaping @Sendable () -> Void) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { state in if case .ready = state { ready() } }
        listener.newConnectionHandler = { connection in
            connection.start(queue: DispatchQueue(label: "MusiquePapa.fixture.connection"))
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { request, _, _, _ in
                let found = String(data: request ?? Data(), encoding: .utf8)?.hasPrefix("GET /Internet_original.chordpro ") == true
                let body = found ? data : Data("Introuvable".utf8)
                let header = "HTTP/1.1 \(found ? "200 OK" : "404 Not Found")\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        listener.start(queue: queue)
    }
    func stop() { listener.cancel() }
}
