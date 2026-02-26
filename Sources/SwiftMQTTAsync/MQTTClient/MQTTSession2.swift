import NIOCore

final class MQTTSession2 {
    private var inflightSubscriptions: [UInt16: EventLoopPromise<Suback>] = [:]

    public func sendSubscribe(_ packet: Subscribe, context: ChannelHandler) async throws -> Suback {

    }
}
