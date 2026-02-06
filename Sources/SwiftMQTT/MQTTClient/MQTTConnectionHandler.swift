import NIOCore

final class MQTTConnectionHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var parser = PacketParser()

    var handleReceive: ((MQTTPacket) -> Void)?
    var handleSend: ((any MQTTControlPacket) -> Void)?
    var handleError: ((any Error) -> Void)?
    var handleChannelActive: (() -> Void)?
    var handleChannelInactive: (() -> Void)?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = Self.unwrapInboundIn(data)
        let packets = parser.feed(buffer: buffer)

        for packet in packets {
            handleReceive?(packet)
        }
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
