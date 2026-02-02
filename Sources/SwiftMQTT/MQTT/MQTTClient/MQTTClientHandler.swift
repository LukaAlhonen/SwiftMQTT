import NIOCore
import NIOPosix
import Foundation
import NIOTransportServices

final class MQTTClientHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    weak var client: MQTTClient?
    private var parser = PacketParser()

    init(client: MQTTClient) {
        self.client = client
    }

    func channelActive(context: ChannelHandlerContext) {
        // call onChannelActive or connect or something
        client?.onChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        // call onChannelInactive or disconnect idc
        // print("dead")
        // client?.stop()
        // Log.tcp.error("Disconnected")
        client?.onChannelInactive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = Self.unwrapInboundIn(data)
        let packets = parser.feed(buffer: buffer)

        for packet in packets {
            self.client?.onReceive(packet)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
    //     print("Error: \(error)")

    //     context.close(promise: nil)
        client?.onChannelError(error)
    }
}
