// TODO:
// - Implement disconnect x
// - Implement publish x
//      - receive: x
//          - QoS 0 x
//          - QoS 1 x
//          - QoS 2 x
//      - send:
//          - QoS 0 x
//          - QoS 1 x
//          - QoS 2 x
// - Implement unsub
// - Implement auth

import Foundation
import Network
import OSLog
import Dispatch
import Logging

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

enum InflightState {
    case publishQoS1(PublishQoS1State)
    case publishQoS2(PublishQoS2State)
    case subscribe(SubscribeState)
}

struct InflightTask {
    var state: InflightState
    var timeout: TimeoutTask?
}

final class TimeoutTask: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private var cont: CheckedContinuation<Void, Error>?
    private var timeout: Duration
    private var completedResult: Result<Void, Error>?

    init(timeout: UInt16) {
        self.timeout = .seconds(Double(timeout))
    }

    func start() {
        guard task == nil else {
            return
        }

        self.task = Task {
            do {
                try await Task.sleep(for: self.timeout)
                self.finish(result: .failure(MQTTError.Timeout(reason: "Task timed out")))
            } catch {
                // timer cancelled
            }
        }
    }

    private func finish(result: Result<Void, Error>) {
        if let cont = self.cont {
            self.cont = nil
            self.task?.cancel()
            self.task = nil


            switch result {
                case .success:
                    cont.resume()
                case .failure(let error):
                    cont.resume(throwing: error)
            }
        } else {
            self.completedResult = result
            self.task?.cancel()
            self.task = nil
        }
    }

    func stop() {
        self.finish(result: .success(()))
    }

    func wait() async throws {
        try await withCheckedThrowingContinuation { cont in
            if let result = self.completedResult {
                self.resume(cont: cont, result: result)
            } else {
                self.cont = cont
            }
        }
    }

    private func resume(cont: CheckedContinuation<Void, Error>, result: Result<Void, Error>) {
        switch result {
            case .success:
                cont.resume()
            case .failure(let error):
                cont.resume(throwing: error)
        }
    }
}

actor MQTTClient {
    // MQTT client vars
    private let clientId: String
    private let config: Config
    private let lwt: LWT?
    private let auth: Auth?

    private var isConnecting: Bool = false

    private var topics: Dictionary<String, TopicFilter> = .init()

    private let tcpClient: TCPClient
    private var tcpState: NWConnection.State = .setup
    private var mqttState: MQTTState = .disconnected

    // keepalive
    private var pingTask: TimeoutTask?
    private var keepAliveTask: Task<Void, Never>?
    private var lastMessage = Date()

    private var connectTask: TimeoutTask?

    private var connGeneration: UInt = 0

    // TODO: rename
    // private var activeTasks: Dictionary<UInt16, TimeoutTask> = .init()
    private var activeTasks: Dictionary<UInt16, InflightTask> = .init()
    private var passiveTasks: Set<UInt16> = .init()
    private var idAllocator: PacketIdAllocator = .init()

    private let internalPacketStream: AsyncThrowingStream<any MQTTControlPacket, Error>
    private let packetContinuation: AsyncThrowingStream<any MQTTControlPacket, Error>.Continuation
    nonisolated var packetStream: AsyncThrowingStream<any MQTTControlPacket, Error> {
        internalPacketStream
    }

    enum MQTTState {
        case connected
        case connecting
        case disconnected
        case error(Error)
    }

    init(brokerAddress: String, brokerPort: UInt16, clientId: String, config: Config, lwt: LWT? = nil, auth: Auth? = nil) {
        self.tcpClient = TCPClient(host: brokerAddress, port: brokerPort)
        self.clientId = clientId
        self.config = config
        self.lwt = lwt
        self.auth = auth

        // let (stream, continuation) = AsyncThrowingStream<any MQTTControlPacket, Error>.makeStream()
        // self.internalPacketStream = stream
        // self.packetContinuation = continuation
        var cont: AsyncThrowingStream<any MQTTControlPacket, Error>.Continuation!
        self.internalPacketStream = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(10)) { continuation in
            cont = continuation}
        self.packetContinuation = cont

        self.tcpClient.onReceive = { [weak self] data in
            guard let self else { return }
            Task {
                await self.handleReceive(data)
            }
        }

        self.tcpClient.onStateChange = { [weak self] state in
            guard let self else { return }
            Task {
                await self.handleTCPState(state)
            }
        }
    }

    func start() async throws {
        if case .connected = self.mqttState { return }

        try await self.tcpClient.start()
    }

    func stop() {
        self.disconnect()

        self.packetContinuation.finish()

        self.tcpClient.stop()
    }
}

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
                self.logError(error: error)
                retries += 1
            }
        }

        if success {
            self.mqttState = .connected
            self.startKeepAlive(generation: generation)
            self.logInfo(message: "MQTT Client Connected")
        } else {
            throw MQTTError.Timeout(reason: "connect timed out")
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
                do {
                    try await self.send(packet: MQTTDisconnectPacket())
                } catch {
                    self.logError(error: error)
                }
            }
        }
        self.mqttState = .disconnected
    }

    private func sendConnect() async throws {
        let connectPacket = MQTTConnectPacket(clientId: self.clientId, keepAlive: self.config.keepAlive, lwt: self.lwt, auth: self.auth, cleanSession: self.config.cleanSession)
        try await self.send(packet: connectPacket)

        let task = TimeoutTask(timeout: self.config.connTimeout)
        task.start()
        self.connectTask = task

        try await self.connectTask?.wait()
    }

    func subscribe(to topics: [TopicFilter]) async throws {
        if case .connected = self.mqttState {
            // send sub packet
            let id = self.idAllocator.next()
            let subscribePacket = MQTTSubscribePacket(packetId: id, topics: topics)

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

    private func send(packet: any MQTTControlPacket) async throws {

        let bytes = packet.encode()

        do {
            try await self.tcpClient.send(data: bytes)
        } catch {
            throw error
        }
        self.logSent(packet: packet)

        // reset ping timer
        self.resetKeepalive()
    }
}

// MARK: Publish related methods
// TODO: remove packetID allocation on qos 1
extension MQTTClient {
    func publish(data: ByteBuffer, qos: QoS, topic: String) async throws {
        let packetId = self.idAllocator.next()
        let publishPacket = MQTTPublishPacket(topicName: topic, message: data, packetId: packetId, qos: qos)

        try await self.sendPublish(packet: publishPacket)
    }

    func publish(message: String, qos: QoS, topic: String) async throws {
        let packetId = self.idAllocator.next()
        let publishPacket = MQTTPublishPacket(topicName: topic, message: ByteBuffer(message.utf8), packetId: packetId, qos: qos)

        try await self.sendPublish(packet: publishPacket)
    }

    func publish(packet: MQTTPublishPacket) async throws {
        try await self.sendPublish(packet: packet)
    }

    private func sendPublish(packet: MQTTPublishPacket) async throws {
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
            self.activeTasks[packetId] = InflightTask(state: .publishQoS1(.publishSent), timeout: timeout)
            try await self.send(packet: packet)
            try await timeout.wait()
        }

        if qos == .ExactlyOnce {
            // Send publish and wait for pubrec
            let pubTimeout = TimeoutTask(timeout: self.config.connTimeout)
            pubTimeout.start()
            self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.publishSent), timeout: pubTimeout)
            try await self.send(packet: packet)
            try await pubTimeout.wait()

            // Send pubrel and wait for pubcomp
            let pubrelTimeout = TimeoutTask(timeout: self.config.connTimeout)
            pubrelTimeout.start()
            self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubRelSent))
            try await self.send(packet: MQTTPubrelPacket(packetId: packetId))
            try await pubrelTimeout.wait()
        }
    }
}

// MARK: TCP client handlers
extension MQTTClient {
    private func handleReceive(_ data: Data) {
        let bytes = ByteBuffer(data)
        let parser = MQTTPacketParser()
        do {
            guard let packet = try parser.parsePacket(data: bytes) else {
                return
            }

            self.logReceived(packet: packet)


            switch packet.fixedHeader.type {
                case .CONNACK:
                    guard let connackPacket = packet as? MQTTConnackPacket else {
                        fatalError("Parser returned wrong packet type: expected Connack, received \(packet.toString())")
                    }
                    switch connackPacket.varHeader.connectReturnCode {
                        case .ConnectionAccepted:
                            self.mqttState = .connected
                            self.connectTask?.stop()
                        default:
                            // Could create handler or something for mqtt state updates
                            let err: Error = MQTTError.ConnectError(returnCode: connackPacket.varHeader.connectReturnCode)
                            self.mqttState = .error(err)
                            self.logError(error: err)
                    }
                case .SUBACK:
                    // Change this to resume the continuation for the specific sub
                    guard let subackPacket = packet as? MQTTSubackPacket else {
                        fatalError("Parser returned wrong packet type: expected Suback, received \(packet.toString())")
                    }
                    let packetId = subackPacket.varHeader.packetId
                    guard let timeoutTask = self.activeTasks.removeValue(forKey: packetId) else {
                        self.logWarning(message: "Received SUBACK for unknown packetId: \(packetId)")
                        break
                    }

                    // release id
                    self.idAllocator.release(id: packetId)
                    timeoutTask.timeout?.stop()

                case .PUBLISH:
                    // Inspect qos of packet and act accrodingly
                    guard let publishPacket = packet as? MQTTPublishPacket else {
                        fatalError("Parser returned wrong packet type: expected PUBLISH, received \(packet.fixedHeader.type.toString())")
                    }

                    let topic = publishPacket.varHeader.topicName
                    guard let _ = self.topics[topic] else {
                        self.logWarning(message: "Recieved PUBLISH for unknown topic")
                        return
                    }

                    let qos = publishPacket.qos

                    // qos 1 => send puback
                    if qos == .AtLeastOnce {
                        guard let packetId = publishPacket.varHeader.packetId else {
                            self.logWarning(message: "Received QoS 1 PUBLISH packet without packet ID")
                            return
                        }
                        Task {
                            do {
                                try await self.send(packet: MQTTPubackPacket(packetId: packetId))
                            } catch {
                                self.logError(error: error)
                            }
                        }
                    }

                    if qos == .ExactlyOnce {
                        guard let packetId = publishPacket.varHeader.packetId else {
                            self.logWarning(message: "Received QoS 2 PUBLISH packet without packet ID")
                            return
                        }
                        if publishPacket.dup {
                            self.logWarning(message: "Received QoS 2 PUBLISH packet with dup flag set")
                        }

                        // store packetId, send pubrec and init onward delivery of message
                        self.passiveTasks.insert(packetId)

                        Task {
                            do {
                                try await self.send(packet: MQTTPubrecPacket(packetId: packetId))
                            } catch {
                                self.logError(error: error)
                            }
                        }
                    }

                    self.packetContinuation.yield(packet)
                case .PUBREL:
                    guard let pubrelPacket = packet as? MQTTPubrelPacket else {
                        fatalError("Parser returned wrong packet type: expected PUBREL, received \(packet.fixedHeader.type.toString())")
                    }

                    let packetId = pubrelPacket.varHeader.packetId

                    if !self.passiveTasks.contains(packetId) {
                        self.logWarning(message: "Received PUBREL with unknown packetID: \(packetId)")
                        return
                    }

                    self.passiveTasks.remove(packetId)

                    Task {
                        do {
                            try await self.send(packet: MQTTPubcompPacket(packetId: packetId))
                        } catch {
                            self.logError(error: error)
                        }
                    }
                case .PUBACK:
                    guard let pubackPacket = packet as? MQTTPubackPacket else {
                        fatalError("Parser returned wrong packet type: expected PUBACK, received \(packet.fixedHeader.type.toString())")
                    }

                    let packetId = pubackPacket.varHeader.packetId

                    guard var task = self.activeTasks.removeValue(forKey: packetId) else {
                        self.logWarning(message: "Recieved PUBACK with unknown packetId")
                        return
                    }
                    task.timeout?.stop()
                    task.state = .publishQoS1(.pubAckReceived)
                    self.idAllocator.release(id: packetId)
                case .PUBREC:
                    guard let pubrecPacket = packet as? MQTTPubrecPacket else {
                        fatalError("Parser returned wrong packet type: expected PUBREC, received \(packet.fixedHeader.type.toString())")
                    }
                    let packetId = pubrecPacket.varHeader.packetId
                    guard let task = self.activeTasks.removeValue(forKey: packetId) else {
                        self.logWarning(message: "Received PUBREC with unknown packetId")
                        return
                    }
                    task.timeout?.stop()
                    self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubRecReceived))
                case .PUBCOMP:
                    guard let pubcompPacket = packet as? MQTTPubcompPacket else {
                        fatalError("Parser returned wrong packet type: expected PUBCOMP, received \(packet.fixedHeader.type.toString())")
                    }
                    let packetId = pubcompPacket.varHeader.packetId
                    guard let task = self.activeTasks.removeValue(forKey: packetId) else {
                        self.logWarning(message: "Received PUBCOMP with unknown packetId")
                        return
                    }
                    task.timeout?.stop()
                    self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubCompReceived))
                case .PINGRESP:
                    self.pingTask?.stop()
                    self.pingTask = nil
                default:
                    return
            }
        } catch {
            return
        }
    }

    private func handleTCPState(_ state: NWConnection.State) async {
        self.tcpState = state
        switch state {
            case .ready:
                await tryConnect()
            case .failed(let error):
                self.mqttState = .error(error)
            case .cancelled:
                self.mqttState = .disconnected
            default:
                break
        }
    }

    private func tryConnect() async {
        guard !isConnecting else { return }
        self.isConnecting = true

        Task {
            defer { self.isConnecting = false }
            try? await self.connect()
            await self.subscribeToTopics()
        }
    }

    private func subscribeToTopics() async {
        if self.topics.isEmpty { return }

        do {
            try await self.subscribe(to: Array(self.topics.values))
        } catch {
            self.logError(error: error)
        }
    }
}

// MARK: Loggers
extension MQTTClient {
    private func logReceived(packet: any MQTTControlPacket) {
        Log.mqtt.debug("Received: \(packet.toString())")
    }

    private func logSent(packet: any MQTTControlPacket) {
        Log.mqtt.debug("Sent: \(packet.toString())")
    }

    private func logError(error: Error) {
        Log.mqtt.error("Error: \(error)")
    }

    private func logWarning(message: String) {
        Log.mqtt.warning(Logger.Message(stringLiteral: message))
    }

    private func logInfo(message: String) {
        Log.mqtt.info(Logger.Message(stringLiteral: message))
    }
}

// MARK: Ping keepalive
extension MQTTClient {
    private func startKeepAlive(generation: UInt) {
        self.keepAliveTask = Task {
            while !Task.isCancelled {
                guard generation == self.connGeneration else { return }

                let elapsed = Date().timeIntervalSince(self.lastMessage)
                let sleepTime = (Double(self.config.keepAlive) - elapsed) * 0.5 // only sleeping half of keepalive, can be adjusted

                if sleepTime > 0 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                    } catch {
                        break // task cancelled
                    }
                }

                guard generation == self.connGeneration else { return }

                if Date().timeIntervalSince(self.lastMessage) >= TimeInterval(self.config.keepAlive) {
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

        try await self.send(packet: MQTTPingreqPacket())

         let task = TimeoutTask(timeout: self.config.pingTimeout)


         self.pingTask = task
         try await self.pingTask?.wait()
    }

    private func handlePingTimeout() {
        self.logError(error: MQTTError.Timeout(reason: "ping timed out"))

        // TODO: Add option to try reconnect if ping times out
        // if config.retry
        self.disconnect()
    }
}
