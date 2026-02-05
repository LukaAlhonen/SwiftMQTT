import NIOCore
import NIOTransportServices

actor MQTTConnection {
    private var channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?
    private let eventLoopGroup: NIOTSEventLoopGroup

    private let host: String
    private let port: Int

    private let eventBus: MQTTEventBus<MQTTInternalEvent>

    init(host: String, port: Int, eventBus: MQTTEventBus<MQTTInternalEvent>) {
        if port <= 0 { fatalError("Invalid port number: \(port)")}

        self.host = host
        self.port = port

        self.eventLoopGroup = .init()

        self.eventBus = eventBus
    }

    func connect() async throws {
        let handler = MQTTConnectionHandler()

        // init handlers
        handler.handleChannelActive = {
            self.eventBus.emit(.connectionActive)
        }

        handler.handleChannelInactive = {
            self.eventBus.emit(.connectionInactive)
        }

        handler.handleError = { error in
            self.eventBus.emit(.connectionError(error))
        }

        handler.handleReceive = { packet in
            self.eventBus.emit(.packet(packet))
        }

        handler.handleSend = { packet in
            self.eventBus.emit(.send(packet))
        }

    let bootstrap = NIOTSConnectionBootstrap(group: self.eventLoopGroup)
        .channelInitializer { channel in
            channel.pipeline.addHandler(handler)
        }

    let channel = try await bootstrap
        .connect(host: self.host, port: self.port) { channel in
            channel.eventLoop.makeCompletedFuture {
                return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }

        self.channel = channel
    }

    func send(packet: any MQTTControlPacket) async throws {
        guard let channel = self.channel else { return }
        let bytes = packet.encode()
        var buffer = channel.channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)

        try await channel.channel.writeAndFlush(buffer)
    }

    func close() async throws {
        try await self.channel?.channel.close()
    }
}
