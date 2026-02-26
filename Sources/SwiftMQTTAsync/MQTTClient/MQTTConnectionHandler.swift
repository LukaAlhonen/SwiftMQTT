import NIOCore

final class MQTTConnectionHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundIn = any MQTTControlPacket
    typealias OutboundOut = ByteBuffer

    private var parser: PacketParser
    private(set) var context: ChannelHandlerContext!

    var handleReceive: ((MQTTPacket) -> Void)?
    var handleSend: ((any MQTTControlPacket) -> Void)?
    var handleError: ((any Error) -> Void)?
    var handleChannelActive: (() -> Void)?
    var handleChannelInactive: (() -> Void)?

    init(version: Version) {
        self.parser = PacketParser(version: version)
    }

    func handlerAdded(context: ChannelHandlerContext) {

    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = Self.unwrapInboundIn(data)
        let packets = parser.feed(buffer: buffer)

        for packet in packets {
            handleReceive?(packet)
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let packet = unwrapOutboundIn(data)

        handleSend?(packet)

        let bytes = packet.encode()
        var buffer = context.channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)

        context.write(NIOAny(buffer), promise: promise)
    }

    func channelActive(context: ChannelHandlerContext) {
        handleChannelActive?()
    }

    func channelInactive(context: ChannelHandlerContext) {
        handleChannelInactive?()
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        handleError?(error)
    }
}
