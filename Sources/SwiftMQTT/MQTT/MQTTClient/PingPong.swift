import Dispatch
import Foundation

class PingPong: @unchecked Sendable {
    var onPing: (() async -> Result<Void, MQTTError>)?
    var onPingTimeout: (() -> Void)?
    private let keepAlive: TimeInterval
    private var task: Task<Void, Never>?
    private var lastMessage: Date

    init(keepAlive: TimeInterval) {
        self.lastMessage = Date()
        self.keepAlive = keepAlive
    }

    func start() {
        guard self.task == nil else { return }
        self.lastMessage = Date()

        task = Task { [weak self] in
            await self?.loop()
        }
    }

    func stop() {
        self.task?.cancel()
        self.task = nil
    }

    func reset() {
        self.lastMessage = Date()
    }

    private func loop() async {
        while !Task.isCancelled {
            let reference = lastMessage
            let elapsed = Date().timeIntervalSince(reference)
            let sleepTime = (self.keepAlive - elapsed) * 0.5 // only sleeping half of keepalive, can be adjusted

            if sleepTime > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                } catch {
                    break // task cancelled
                }
            }

            // If time between now and last message is smaller than keepalive interval -> restart loop
            guard reference == self.lastMessage else { continue }

            if let onPing = self.onPing {
                let result = await onPing()
                if case .failure(.Timeout) = result {
                    self.onPingTimeout?()
                    break
                }
            }

            // self.lastMessage = Date()
        }
    }
}
