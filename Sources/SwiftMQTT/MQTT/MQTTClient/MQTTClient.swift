// TODO:
// - Implement disconnect x
// - Implement publish
//      - QoS 0 x
//      - QoS 1
//      - QoS 2
// - Implement unsub

import Foundation
import Network
import OSLog
import Dispatch
import Logging

struct InFlightPacket {
    var type: MQTTControlPacketType
    var cont: CheckedContinuation<Void, Error>
    var timeout: Task<Void, Never>?
}

class PacketIdAllocator {
    private var free: UInt16
    private var allocated: Set<UInt16>

    init() {
        self.free = 1
        self.allocated = []
    }

    private func increment() {
        self.free &+= 1
        if (self.free == 0) { self.free = 1 }
    }

    func next() -> UInt16 {
        while self.allocated.contains(self.free) {
            self.increment()
        }

        let id = self.free
        self.allocated.insert(id)

        self.increment()

        return id
    }

    func release(id: UInt16) {
        self.allocated.remove(id)
    }
}

actor MQTTClient {
    // MQTT client vars
    private let clientId: String
    private let config: Config
    private let lwt: LWT?
    private let auth: Auth?

    private var isConnecting: Bool = false

    private var topics: Set<TopicFilter> = .init()

    private let tcpClient: TCPClient
    private var tcpState: NWConnection.State = .setup
    private var mqttState: MQTTState = .disconnected

    // keepalive
    private var pingTask: Task<Result<Void, MQTTError>, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var lastMessage = Date()

    private var connTask: Task<Result<Void, MQTTError>, Never>?

    private var connGeneration: UInt = 0

    private var inFlight: Dictionary<UInt16, InFlightPacket> = .init()
    private var idAllocator: PacketIdAllocator = .init()

    private let internalPacketStream: AsyncThrowingStream<MQTTControlPacket, Error>
    private let packetContinuation: AsyncThrowingStream<MQTTControlPacket, Error>.Continuation
    nonisolated var packetStream: AsyncThrowingStream<MQTTControlPacket, Error> {
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

        let (stream, continuation) = AsyncThrowingStream<MQTTControlPacket, Error>.makeStream()
        self.internalPacketStream = stream
        self.packetContinuation = continuation

        // set loglevel
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = config.logLevel
            return handler
        }

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
        try await connect()

        // subscribe to all defined topics
        if !self.topics.isEmpty {
            try await self.subscribe(to: Array(self.topics))
        }
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
        self.connTask?.cancel()

        // return if already connected
        if case .connected = self.mqttState { return }

        self.mqttState = .connecting
        // Wait for tcp client to be ready
        try await self.tcpClient.start()

        var retries = 0
        var success = false

        while retries <= self.config.maxRetries {
            let result = await self.sendConnect()
            if case .success = result {
                success = true
                break
            } else {
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
        self.pingTask?.cancel()
        self.pingTask = nil
        self.connTask?.cancel()
        self.connTask = nil

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

    private func sendConnect() async -> Result<Void, MQTTError> {
        do {
            let connectPacket = MQTTConnectPacket(clientId: self.clientId, keepAlive: self.config.keepAlive, lwt: self.lwt, auth: self.auth, cleanSession: self.config.cleanSession)
            try await self.send(packet: connectPacket)
        } catch {
            return .failure(.Disconnected)
        }

        let task = Task { () -> Result<Void, MQTTError> in
            do {
                try await Task.sleep(nanoseconds: UInt64(self.config.connTimeout) * 1_000_000_000)
                return .failure(.Timeout(reason: "connect timed out"))
            } catch {
                return .success(())
            }
        }

        self.connTask = task
        let result = await task.value

        self.connTask = nil
        return result
    }

    func subscribe(to topics: [TopicFilter]) async throws {
        if case .connected = self.mqttState {
            // send sub packet
            let id = self.idAllocator.next()
            let subscribePacket = MQTTSubscribePacket(packetId: id, topics: topics)

            // send sub packet
            try await self.send(packet: subscribePacket)

            try await withCheckedThrowingContinuation { cont in
                inFlight[id] = .init(type: .SUBSCRIBE, cont: cont)

                // timeout task
                let task = Task {
                    do {
                        // TODO: update to use dedicated suback timeout instead of connack
                        try await Task.sleep(nanoseconds: UInt64(self.config.connTimeout) * 1_000_000_000)

                        // timer ran out, release id and throw error
                        if let timedOut = self.inFlight.removeValue(forKey: id) {
                            self.idAllocator.release(id: id)
                            timedOut.cont.resume(throwing: MQTTError.Timeout(reason: "subscribe timed out"))
                        }
                    } catch {
                        // timeout cancelled
                    }
                }

                if var packet = self.inFlight[id] {
                    packet.timeout = task
                    self.inFlight[id] = packet
                }
            }
        } else {
            // place in topics array
            for topic in topics {
                self.topics.insert(topic)
            }
        }
    }

    private func send(packet: MQTTControlPacket) async throws {

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
                            self.connTask?.cancel()
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
                    guard let inflightPacket = self.inFlight.removeValue(forKey: packetId) else {
                        self.logWarning(message: "Received SUBACK for unknown packetId: \(packetId)")
                        break
                    }

                    // cancel timeout
                    inflightPacket.timeout?.cancel()

                    // release id
                    self.idAllocator.release(id: packetId)

                    // resume cont for inflight packet
                    inflightPacket.cont.resume()

                case .PUBLISH:
                    self.packetContinuation.yield(packet)
                case .PINGRESP:
                    self.pingTask?.cancel()
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
        }
    }
}

// MARK: Loggers
extension MQTTClient {
    private func logReceived(packet: MQTTControlPacket) {
        Log.mqtt.debug("Received: \(packet.toString())")
    }

    private func logSent(packet: MQTTControlPacket) {
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
                    let pingResult = await self.ping()
                    if case .failure(.Timeout) = pingResult {
                        // TODO: figure out better way to handle error
                        self.handlePingTimeout()
                        break
                    }
                    if case .failure(.Disconnected) = pingResult {
                        // handle disconnect for now just break the loop
                        break
                    }
                }
            }
        }
    }

    private func resetKeepalive() {
        self.lastMessage = Date()
    }

    private func ping() async -> Result<Void, MQTTError> {
        // Cancel pingtask if active
        self.pingTask?.cancel()

         do {
            try await self.send(packet: MQTTPingreqPacket())
         } catch {
             self.mqttState = .error(error)
             return .failure(.Disconnected)
         }

         let task = Task { () -> Result<Void, MQTTError> in
            do {
                try await Task.sleep(nanoseconds: UInt64(self.config.pingTimeout) * 1_000_000_000)
                return .failure(.Timeout(reason: "ping timed out"))
            } catch {
                return .success(())
            }
         }

         self.pingTask = task
         let result = await task.value

         self.pingTask = nil
         return result
    }

    private func handlePingTimeout() {
        self.logError(error: MQTTError.Timeout(reason: "ping timed out"))

        // TODO: Add option to try reconnect if ping times out
        // if config.retry
        self.disconnect()
    }
}
