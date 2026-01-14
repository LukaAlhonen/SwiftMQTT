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

@MainActor
final class MQTTClient {
    // MQTT client vars
    private let clientId: String
    private let config: Config
    private let lwt: LWT?
    private let auth: Auth?

    // private var topics: Dictionary<String, QoS> = .init()
    private var topics: Set<TopicFilter> = .init()

    private let tcpClient: TCPClient
    private var tcpState: NWConnection.State = .setup
    private var mqttState: MQTTState = .disconnected

    private var mqttContinuation: CheckedContinuation<Void, Error>?
    private var tcpContinuation: CheckedContinuation<Void, Error>?
    private var subscribeContinuation: CheckedContinuation<Void, Error>?
    private var lifetimeContinuation: CheckedContinuation<Void, Never>?

    private var pingPong: PingPong

    private var pingTask: Task<Result<Void, MQTTError>, Never>?
    private var connTask: Task<Result<Void, MQTTError>, Never>?

    private var inFlight: Dictionary<UInt16, InFlightPacket> = .init()
    private var idAllocator: PacketIdAllocator = .init()

    var onPublish: ((MQTTControlPacket) -> Void)?

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
        self.pingPong = .init(keepAlive: Double(config.keepAlive))

        self.tcpClient.onReceive = handleReceive
        self.tcpClient.onStateChange = handleTCPState

        self.pingPong.onPing = handlePing
        self.pingPong.onPingTimeout = handlePingTimeout
    }

    func start() async throws {
        if case .connected = self.mqttState { return }
        try await connect()

        // subscribe to all defined topics
        try await self.subscribe(to: Array(self.topics))

        await withCheckedContinuation { cont in
            self.lifetimeContinuation = cont
        }
    }
}

extension MQTTClient {
    private func connect() async throws {
        self.connTask?.cancel()

        // return if already connected
        if case .connected = self.mqttState { return }
        if case .ready = self.tcpState { return }

        self.mqttState = .connecting
        // Wait for tcp client to be ready
        self.tcpClient.start()
        try await waitUntilTCPConnected()

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
            self.pingPong.start()
        } else {
            throw MQTTError.Timeout(reason: "connect timed out")
        }
    }

    private func sendConnect() async -> Result<Void, MQTTError> {
        do {
            // let connectPacket = MQTTConnectPacket(clientId: self.clientId, lwt: self.lwt, auth: self.auth, keepAlive: self.config.keepAlive)
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
                let task = Task { [weak self] in
                    guard let self else { return }
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
        self.logSent(packet: packet)

        let bytes = packet.encode()

        try await self.tcpClient.send(data: bytes)
    }
}

// MARK: TCP client handlers
extension MQTTClient {
    private func handleReceive(_ data: Data) {
        let bytes = [UInt8](data)
        let parser = MQTTPacketParser()
        do {
            guard let packet = try parser.parsePacket(data: bytes) else {
                return
            }

            // reset pingpong timer
            self.pingPong.reset()

            logReceived(packet: packet)

            switch packet.fixedHeader.type {
                case .CONNACK:
                    guard let connackPacket = packet as? MQTTConnackPacket else {
                        fatalError("Parser returned wrong packet type: expected Connack, received \(packet.toString())")
                    }
                    switch connackPacket.varHeader.connectReturnCode {
                        case .ConnectionAccepted:
                            self.mqttState = .connected
                            self.mqttContinuation?.resume()
                            self.mqttContinuation = nil
                            self.connTask?.cancel()
                        default:
                            // Could create handler or something for mqtt state updates
                            let err: Error = MQTTError.ConnectError(returnCode: connackPacket.varHeader.connectReturnCode)
                            self.mqttState = .error(err)
                            logError(error: err)
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
                    onPublish?(packet)
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

    private func handleTCPState(_ state: NWConnection.State) {
        self.tcpState = state
        switch state {
            case .ready:
                self.tcpContinuation?.resume()
                self.tcpContinuation = nil
            case .failed(let error):
                self.mqttState = .error(error)
            default:
                break
        }
    }
}

extension MQTTClient {
    private func waitUntilTCPConnected() async throws {
        if self.tcpState == .ready { return }
        try await withCheckedThrowingContinuation { cont in
            self.tcpContinuation = cont
        }
    }
}

// MARK: Loggers
extension MQTTClient {
    private func logReceived(packet: MQTTControlPacket) {
        Log.mqtt.info("Received: \(packet.toString())")
    }

    private func logSent(packet: MQTTControlPacket) {
        Log.mqtt.info("Sent: \(packet.toString())")
    }

    private func logError(error: Error) {
        Log.mqtt.error("Error: \(error)")
    }

    private func logWarning(message: String) {
        Log.mqtt.warning(Logger.Message(stringLiteral: message))
    }
}

// MARK: Keepalive handlers
extension MQTTClient {
    private func handlePing() async -> Result<Void, MQTTError> {
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

        // should enter connect retry loop here, for now just disconnecting
        self.mqttState = .disconnected
        self.lifetimeContinuation?.resume()
        self.lifetimeContinuation = nil
    }
}
