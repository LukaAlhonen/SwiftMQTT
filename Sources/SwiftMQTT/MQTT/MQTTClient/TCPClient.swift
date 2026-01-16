import Foundation
import Network

// TODO: Should probably expand the erorr types
enum TCPError: Error {
    case notConnected
}

final class TCPClient: @unchecked Sendable {
    private var connection: NWConnection?
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port

    private var isStopped: Bool = false

    // connect retry
    private var retryConnTask: Task<Void, Never>?
    private var retryConnInterval: UInt16 = 1

    private var stateContinuation: AsyncStream<NWConnection.State>.Continuation?
    private lazy var stateStream: AsyncStream<NWConnection.State> = {
        AsyncStream { cont in
            self.stateContinuation = cont
        }
    }()

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
                self?.connection?.cancel()
                self?.connection = nil
                self?.retryConnect()
                return
            }

            if isComplete {
                Log.tcp.debug("Connection closed by peer")
                self?.connection?.cancel()
                self?.connection = nil
                self?.retryConnect()
                // self?.stop()
                return
            }

            self?.receive(on: conn)
        }
    }

    func send(data: ByteBuffer) async throws{
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
        guard self.connection == nil else { return }

        let conn = NWConnection(host: self.host, port: self.port, using: .tcp)

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            self.onStateChange?(state)
            self.stateContinuation?.yield(state)

            switch state {
                case .ready:
                    Log.tcp.debug("tcp client connected")
                    self.retryConnTask?.cancel()
                    self.retryConnTask = nil
                    self.receive(on: conn)
                case .failed, .cancelled:
                    self.connection?.cancel()
                    self.connection = nil
                    self.retryConnect()
                case .waiting(let error):
                    Log.tcp.error("TCP error: \(error)")
                    self.connection?.cancel()
                    self.connection = nil
                    self.retryConnect()
                default:
                    break
            }
        }

        self.connection = conn
        self.connection?.start(queue: .global())
    }

    private func retryConnect() {
        guard self.retryConnTask == nil else { return }

        self.retryConnTask = Task {
            defer { retryConnTask = nil }

            while !Task.isCancelled && !self.isStopped {
                makeConnection()

                try? await Task.sleep(for: .seconds(self.retryConnInterval))

                if connection != nil {
                    return
                }
            }
        }
    }

    private func handleDisconnect() {
        guard !isStopped else { return }
        self.connection?.cancel()
        self.connection = nil
    }

    func start() async throws {
        self.isStopped = false

        _ = self.stateStream

        self.makeConnection()

        for await state in self.stateStream {
            switch state {
                case .ready:
                    return
                default:
                    continue
            }
        }

        throw TCPError.notConnected
    }

    func stop() {
        self.isStopped = true
        self.connection?.cancel()
        self.connection = nil
        self.stateContinuation?.finish()
        self.stateContinuation = nil
    }
}
