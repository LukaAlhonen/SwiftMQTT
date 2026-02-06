final class MQTTEventBus<T: Sendable>: Sendable {
    private let continuation: AsyncStream<T>.Continuation

    init(continuation: AsyncStream<T>.Continuation) {
        self.continuation = continuation
    }

    func emit(_ event: T) {
        continuation.yield(event)
    }

    func finnish() {
        continuation.finish()
    }
}
