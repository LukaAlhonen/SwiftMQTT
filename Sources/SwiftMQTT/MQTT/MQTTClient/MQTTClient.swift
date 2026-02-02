// TODO:
// - Implement unsub
// - Implement auth

import Dispatch
import Foundation
import Logging
import Network
import OSLog
import NIOCore
import NIOPosix
import NIOTransportServices

enum PublishQoS1State {
    case publishSent
    case pubAckReceived
}

enum PublishQoS2State {
    case publishSent
    case pubRecReceived
    case pubRelSent
    case pubCompReceived
}

enum SubscribeState {
    case SubscribeSent
    case Done
}

final class MQTTClient: @unchecked Sendable {
    // MQTT client vars
    private let clientId: String
    private let config: Config
    private let lwt: LWT?
    private let auth: Auth?

    private var isConnecting: Bool = false

    private var topics: [String: TopicFilter] = .init()

    private var mqttState: MQTTState = .disconnected

    // keepalive
    private var pingTask: TimeoutTask?
    private var keepAliveTask: Task<Void, Never>?
    private var lastMessage = Date()

    private var connectTask: TimeoutTask?

    private var connGeneration: UInt = 0

    private var activeTasks: [UInt16: InflightTask] = .init()
    private var passiveTasks: Set<UInt16> = .init()
    private var idAllocator: PacketIdAllocator = .init()

    private let internalEventStream: AsyncThrowingStream<MQTTEvent, Error>
    private let eventContinuation: AsyncThrowingStream<MQTTEvent, Error>.Continuation
    nonisolated var eventStream: AsyncThrowingStream<MQTTEvent, Error> {
        internalEventStream
    }


    private var channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?
    private let eventLoopGroup: NIOTSEventLoopGroup

    private let host: String
    private let port: Int

    private var disconnectContinuation: CheckedContinuation<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    enum MQTTState {
        case connected
        case connecting
        case disconnected
        case error(Error)
    }

    init(
        host: String, port: Int, clientId: String, config: Config,
        lwt: LWT? = nil, auth: Auth? = nil, bufferSize: Int = 100
    ) {
        self.host = host
        self.port = port
        self.clientId = clientId
        self.config = config
        self.lwt = lwt
        self.auth = auth

        self.eventLoopGroup = .init()

        var cont: AsyncThrowingStream<MQTTEvent, Error>.Continuation!
        self.internalEventStream = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(10)) {
            continuation in
            cont = continuation
        }
        self.eventContinuation = cont
    }

    func start() async throws {
        if case .connected = self.mqttState { return }

        // try await self.tryConnect()
        self.connectionTask = Task {
            await connectionLoop()
        }
    }

    func stop() {
        self.disconnect()

        self.eventContinuation.finish()
        self.connectionTask?.cancel()
        self.connectionTask = nil
    }
}

extension MQTTClient {
    private func bootstrapChannel() async throws {
        let bootstrap = NIOTSConnectionBootstrap(group: self.eventLoopGroup).channelInitializer { channel in
            channel.eventLoop.makeCompletedFuture {
                try channel.pipeline.syncOperations.addHandler(MQTTClientHandler(client: self))
            }
        }

        let clientChannel = try await bootstrap
            .connect(host: self.host, port: self.port) { channel in
                channel.eventLoop.makeCompletedFuture {
                    return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                }
            }

        self.channel = clientChannel
    }
}

// MARK: Connect
extension MQTTClient {
    private func connect() async throws {
        self.connGeneration += 1
        let generation = self.connGeneration

        // return if already connected
        if case .connected = self.mqttState { return }
        self.connectTask?.stop()

        self.mqttState = .connecting
        // Wait for tcp client to be ready

        var retries = 0
        var success = false

        while retries <= self.config.maxRetries {

            do {
                try await self.sendConnect()
                success = true
                break
            } catch {
                retries += 1
            }
        }

        if success {
            self.mqttState = .connected
            self.startKeepAlive(generation: generation)
        } else {
            throw MQTTError.Timeout(reason: "connect timed out")
        }
    }

    private func tryConnect() async throws {
        guard !isConnecting else { return }
        self.isConnecting = true

        defer { self.isConnecting = false }
        do {
            try await self.connect()
            try await self.subscribeToTopics()
        } catch {
            self.yieldError(error)
            throw error
        }
    }

    private func connectionLoop() async  {
        while !Task.isCancelled {
            do {
                try await self.bootstrapChannel()
                try await self.tryConnect()
                await waitForDisconnect()
            } catch {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func waitForDisconnect() async {
        await withCheckedContinuation { cont in
            self.disconnectContinuation = cont
        }
    }

    private func disconnect() {
        // cancel all tasks
        self.keepAliveTask?.cancel()
        self.keepAliveTask = nil
        self.pingTask?.stop()
        self.pingTask = nil
        self.connectTask?.stop()
        self.connectTask = nil

        if case .connected = self.mqttState {
            Task {
                try? await self.send(packet: Disconnect())
            }
        }
        self.mqttState = .disconnected
        Task { [weak self] in
            guard let self else { return }
            try? await self.channel?.executeThenClose { inbound, outbound in
                try? await self.send(packet: Disconnect())
            }
        }
    }

    private func sendConnect() async throws {
        let connectPacket = Connect(
            clientId: self.clientId, keepAlive: self.config.keepAlive, lwt: self.lwt,
            auth: self.auth, cleanSession: self.config.cleanSession)
        try await self.send(packet: connectPacket)

        let task = TimeoutTask(timeout: self.config.connTimeout)
        task.start()
        self.connectTask = task

        try await self.connectTask?.wait()
    }
}

// MARK: Send
extension MQTTClient {
    private func send(packet: any MQTTControlPacket) async throws {

        guard let channel = self.channel else {
            return
        }

        let bytes = packet.encode()
        let buffer = channel.channel.allocator.buffer(bytes: bytes)

        try await channel.channel.writeAndFlush(buffer)

        // reset ping timer
        self.resetKeepalive()
    }
}

// MARK: Subscribe
extension MQTTClient {
    func subscribe(to topics: [TopicFilter]) async throws {
        if case .connected = self.mqttState {
            // send sub packet
            let id = self.idAllocator.next()
            let subscribePacket = Subscribe(packetId: id, topics: topics)

            // send sub packet
            try await self.send(packet: subscribePacket)

            // TODO: update to use dedicated suback timeout instead of connack
            let timeout = TimeoutTask(timeout: self.config.connTimeout)
            timeout.start()
            self.activeTasks[id] = InflightTask(state: .subscribe(.SubscribeSent), timeout: timeout)
            try await timeout.wait()

        } else {
            // place in topics array
            for topic in topics {
                self.topics[topic.topic] = topic
            }
        }
    }

    private func subscribeToTopics() async throws {
        if self.topics.isEmpty { return }

        try await self.subscribe(to: Array(self.topics.values))
    }
}

// MARK: Publish related methods
// TODO: remove packetID allocation on qos 1
extension MQTTClient {
    func publish(data: Bytes, qos: QoS, topic: String) async throws {
        let packetId = self.idAllocator.next()
        let publishPacket = Publish(
            topicName: topic, message: data, packetId: packetId, qos: qos)

        try await self.sendPublish(packet: publishPacket)
    }

    func publish(message: String, qos: QoS, topic: String) async throws {
        let packetId = self.idAllocator.next()
        let publishPacket = Publish(
            topicName: topic, message: Bytes(message.utf8), packetId: packetId, qos: qos)

        try await self.sendPublish(packet: publishPacket)
    }

    func publish(packet: Publish) async throws {
        try await self.sendPublish(packet: packet)
    }

    private func sendPublish(packet: Publish) async throws {
        let packetId = packet.varHeader.packetId ?? self.idAllocator.next()
        let qos = packet.qos

        if qos == .AtMostOnce {
            try await self.send(packet: packet)
        }

        // wait for puback
        if qos == .AtLeastOnce {
            // should create separate timeout for publish
            let timeout = TimeoutTask(timeout: self.config.connTimeout)
            timeout.start()
            self.activeTasks[packetId] = InflightTask(
                state: .publishQoS1(.publishSent), timeout: timeout)
            try await self.send(packet: packet)
            try await timeout.wait()
        }

        if qos == .ExactlyOnce {
            // Send publish and wait for pubrec
            let pubTimeout = TimeoutTask(timeout: self.config.connTimeout)
            pubTimeout.start()
            self.activeTasks[packetId] = InflightTask(
                state: .publishQoS2(.publishSent), timeout: pubTimeout)
            try await self.send(packet: packet)
            try await pubTimeout.wait()

            // Send pubrel and wait for pubcomp
            let pubrelTimeout = TimeoutTask(timeout: self.config.connTimeout)
            pubrelTimeout.start()
            self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubRelSent))
            try await self.send(packet: Pubrel(packetId: packetId))
            try await pubrelTimeout.wait()
        }
    }
}

// MARK: TCP client handlers
// TODO: Get rid of all tasks
extension MQTTClient {
    func onChannelInactive() {
        self.mqttState = .disconnected

        self.disconnectContinuation?.resume()
        self.disconnectContinuation = nil
    }

    func onChannelError(_ error: any Error) {
        self.mqttState = .error(error)

        self.disconnectContinuation?.resume()
        self.disconnectContinuation = nil
    }

    func onReceive(_ packet: MQTTPacket) {
        self.yieldPacket(packet)

        switch packet {
            case .connack(let connackPacket):
                switch connackPacket.varHeader.connectReturnCode {
                case .ConnectionAccepted:
                    self.mqttState = .connected
                    self.connectTask?.stop()
                default:
                    let err: MQTTError = MQTTError.ConnectError(
                        returnCode: connackPacket.varHeader.connectReturnCode)
                    self.mqttState = .error(err)
                    self.yieldError(err)
                }
            case .suback(let subackPacket):
                // TODO: Change this to resume the continuation for the specific sub
                let packetId = subackPacket.varHeader.packetId
                guard let timeoutTask = self.activeTasks.removeValue(forKey: packetId) else {
                    self.yieldWarning("Received SUBACK for unknown packetId: \(packetId)")
                    break
                }

                // release id
                self.idAllocator.release(id: packetId)
                timeoutTask.timeout?.stop()

            case .publish(let publishPacket):
                // Inspect qos of packet and act accrodingly
                let topic = publishPacket.varHeader.topicName
                guard self.topics[topic] != nil else {
                    self.yieldWarning("Recieved PUBLISH for unknown topic")
                    return
                }

                let qos = publishPacket.qos

                // qos 1 => send puback
                if qos == .AtLeastOnce {
                    guard let packetId = publishPacket.varHeader.packetId else {
                        self.yieldWarning("Received QoS 1 PUBLISH packet without packet ID")
                        return
                    }
                    Task {
                        do {
                            try await self.send(packet: Puback(packetId: packetId))
                        } catch {
                            self.yieldError(error)
                        }
                    }
                }

                if qos == .ExactlyOnce {
                    guard let packetId = publishPacket.varHeader.packetId else {
                        self.yieldWarning("Received QoS 2 PUBLISH packet without packet ID")
                        return
                    }
                    if publishPacket.dup {
                        self.yieldWarning("Received QoS 2 PUBLISH packet with dup flag set")
                    }

                    // store packetId, send pubrec and init onward delivery of message
                    self.passiveTasks.insert(packetId)

                    Task {
                        do {
                            try await self.send(packet: Pubrec(packetId: packetId))
                        } catch {
                            self.yieldError(error)
                        }
                    }
                }
            case .pubrel(let pubrelPacket):
                let packetId = pubrelPacket.varHeader.packetId

                if !self.passiveTasks.contains(packetId) {
                    self.yieldWarning("Received PUBREL with unknown packetID: \(packetId)")
                    return
                }

                self.passiveTasks.remove(packetId)

                Task {
                    do {
                        try await self.send(packet: Pubcomp(packetId: packetId))
                    } catch {
                        self.yieldError(error)
                    }
                }
            case .puback(let pubackPacket):
                let packetId = pubackPacket.varHeader.packetId

                guard var task = self.activeTasks.removeValue(forKey: packetId) else {
                    self.yieldWarning("Recieved PUBACK with unknown packetId")
                    return
                }
                task.timeout?.stop()
                task.state = .publishQoS1(.pubAckReceived)
                self.idAllocator.release(id: packetId)
            case .pubrec(let pubrecPacket):
                let packetId = pubrecPacket.varHeader.packetId
                guard let task = self.activeTasks.removeValue(forKey: packetId) else {
                    self.yieldWarning("Received PUBREC with unknown packetId")
                    return
                }
                task.timeout?.stop()
                self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubRecReceived))
            case .pubcomp(let pubcompPacket):
                let packetId = pubcompPacket.varHeader.packetId
                guard let task = self.activeTasks.removeValue(forKey: packetId) else {
                    self.yieldWarning("Received PUBCOMP with unknown packetId")
                    return
                }
                task.timeout?.stop()
                self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubCompReceived))
            case .pingresp:
                self.pingTask?.stop()
                self.pingTask = nil
            default:
                return
        }
    }
}

// MARK: Ping keepalive
extension MQTTClient {
    private func startKeepAlive(generation: UInt) {
        self.keepAliveTask = Task {
            while !Task.isCancelled {
                guard generation == self.connGeneration else { return }

                let elapsed = Date().timeIntervalSince(self.lastMessage)
                let sleepTime = (Double(self.config.keepAlive) - elapsed) * 0.5  // only sleeping half of keepalive, can be adjusted

                if sleepTime > 0 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                    } catch {
                        break  // task cancelled
                    }
                }

                guard generation == self.connGeneration else { return }

                if Date().timeIntervalSince(self.lastMessage) >= TimeInterval(self.config.keepAlive)
                {
                    do {
                        try await self.ping()
                    } catch MQTTError.Timeout {
                        self.handlePingTimeout()
                        break
                    } catch {
                        break
                    }
                }
            }
        }
    }

    private func resetKeepalive() {
        self.lastMessage = Date()
    }

    private func ping() async throws {
        // Cancel pingtask if active
        self.pingTask?.stop()

        try await self.send(packet: Pingreq())

        let task = TimeoutTask(timeout: self.config.pingTimeout)

        self.pingTask = task
        try await self.pingTask?.wait()
    }

    private func handlePingTimeout() {
        self.yieldError(MQTTError.Timeout(reason: "ping timed out"))

        // TODO: Add option to try reconnect if ping times out
        // if config.retry
        self.disconnect()
    }
}

// MARK: eventContinuation yield helpers
extension MQTTClient {
    private func yieldPacket(_ packet: MQTTPacket) {
        self.eventContinuation.yield(.received(packet))
    }

    private func yieldError(_ error: any Error) {
        self.eventContinuation.yield(.error(error))
    }

    private func yieldWarning(_ warning: String) {
        self.eventContinuation.yield(.warning(warning))
    }
}
