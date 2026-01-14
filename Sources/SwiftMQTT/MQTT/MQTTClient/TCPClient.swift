import Foundation
import Network

enum TCPError: Error {
    case notConnected
}

final class TCPClient: @unchecked Sendable {
    private var connection: NWConnection?
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port

    private var isStopped: Bool = false

    var onReceive: ((Data) -> Void)?
    var onStateChange: ((NWConnection.State) -> Void)?

    init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    private func receive(on conn: NWConnection) {
        conn.receive(
            minimumIncompleteLength: 1,
            maximumLength: 4096
        ) { [weak self] data, _, isComplete, error in

            if let data, !data.isEmpty {
                self?.onReceive?(data)
            }

            if let error {
                Log.tcp.error("Receive error: \(error)")
                return
            }

            if isComplete {
                Log.tcp.info("Connection closed by peer")
                return
            }

            self?.receive(on: conn)
        }
    }

    func send(data: [UInt8]) async throws{
        guard let connection else {
            throw TCPError.notConnected
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        Log.tcp.error("Error sending \(error)")
                        cont.resume(throwing: error)
                    } else {
                        cont.resume()
                    }
                }
            )
        }
    }

    private func makeConnection() {
        let conn = NWConnection(host: self.host, port: self.port, using: .tcp)

        conn.stateUpdateHandler = { [weak self] state in
            self?.onStateChange?(state)

            switch state {
                case .ready:
                    Log.tcp.info("tcp client connected")
                    self?.receive(on: conn)
                case .failed, .cancelled:
                    self?.handleDisconnect()
                default:
                    break
            }
        }

        self.connection = conn
        self.connection?.start(queue: .global())
    }

    private func handleDisconnect() {
        guard !isStopped else { return }
        Log.tcp.error("Disconnected, retrying in 2s")
        self.connection?.cancel()
        self.connection = nil

        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            self.makeConnection()
        }
    }

    func start() {
        self.isStopped = false
        self.makeConnection()
    }

    func stop() {
        self.isStopped = true
        self.connection?.cancel()
        self.connection = nil
    }
}
