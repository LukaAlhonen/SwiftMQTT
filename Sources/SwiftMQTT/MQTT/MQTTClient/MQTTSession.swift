import Foundation

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

actor MQTTSession {
    private let config: Config
    private let eventBus: MQTTEventBus<MQTTEvent>

    let commandBus: MQTTEventBus<MQTTInternalCommand>

    private var subscriptions: [TopicFilter] = []
    private var keepAliveTask: Task<Void, Never>?
    private var keepAliveCont: CheckedContinuation<Void, Never>?

    // special timeout tasks for ping and conn since they have no packetId
    private var connackTask: TimeoutTask?
    private var pingrespTask: TimeoutTask?

    // publish and subscribe tasks started by the client
    private var activeTasks: Dictionary<UInt16, InflightTask> = .init()
    // tasks started by the server
    private var passiveTasks: Set<UInt16> = .init()

    init(config: Config, eventBus: MQTTEventBus<MQTTEvent>, commandBus: MQTTEventBus<MQTTInternalCommand>) {
        self.config = config
        self.eventBus = eventBus
        self.commandBus = commandBus
    }

    func getSubscriptions() -> [TopicFilter] {
        return self.subscriptions
    }

    func handle(_ event: MQTTInternalEvent) {
        switch event {
            case .send(let packet):
                self.handleSend(packet: packet)
            case .packet(let packet):
                self.eventBus.emit(.received(packet))
                self.handlePacket(packet: packet)
            case .connectionError(let error):
                self.eventBus.emit(.error(error))
            case .connectionInactive:
                // TODO: emit error instead
                self.eventBus.emit(.warning("Connection inactive"))
            case .connectionActive:
                self.eventBus.emit(.info("Connection active"))
        }
    }

    private func handlePacket(packet: MQTTPacket) {
        switch packet {
            case .puback(let puback):
                self.handlePuback(puback)
            case .pubrec(let pubrec):
                self.handlePubrec(pubrec)
            case .pubcomp(let pubcomp):
                self.handlePubcomp(pubcomp)
            case .pubrel(let pubrel):
                self.handlePubrel(pubrel)
            case .publish(let publish):
                self.handlePublish(publish)
            case .connack(let connack):
                self.handleConnack(connack)
            case .suback(let suback):
                self.handleSuback(suback)
            default:
                // TODO: Throw error and close connection
                return
        }
    }

    private func handleSend(packet: any MQTTControlPacket) {
        // reset keepalive
        // emit send event

        // start timer based on packet type and qos
        switch packet.fixedHeader.type {
            case .CONNECT:
                guard let connect = packet as? Connect else { return }
                self.handleSendConnect(connect)
            case .SUBSCRIBE:
                guard let subscribe = packet as? Subscribe else { return }
                self.handleSendSubscribe(subscribe)
            case .PUBLISH:
                guard let publish = packet as? Publish else { return }
                self.handleSendPublish(publish)
            case .PUBACK:
                guard let puback = packet as? Puback else { return }
                self.handleSendPuback(puback)
            case .PUBREC:
                guard let pubrec = packet as? Pubrec else { return }
                self.handleSendPubrec(pubrec)
            case .PUBREL:
                guard let pubrel = packet as? Pubrel else { return }
                self.handleSendPubrel(pubrel)
            case .PUBCOMP:
                guard let pubcomp = packet as? Pubcomp else { return }
                self.handleSendPubcomp(pubcomp)
            default:
                break
        }
    }

}

// MARK: send handlers
extension MQTTSession {
    private func handleSendPublish(_ publish: Publish) {
        switch publish.qos {
            // QoS 2
            case .ExactlyOnce:
                // should define separate timeout for publish in config
                guard let packetId = publish.varHeader.packetId else {
                    // should probably emit error or more realistically crash the client
                    self.eventBus.emit(.warning("Attempt to send QoS 2 publish without packetId"))
                    return
                }
                let timeoutTask = TimeoutTask(timeout: 10)
                timeoutTask.start()
                self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.publishSent), timeout: timeoutTask)
            case .AtLeastOnce:
                guard let packetId = publish.varHeader.packetId else {
                    self.eventBus.emit(.warning("Attempt to send QoS 1 publish without packetId"))
                    return
                }

                let timeoutTask = TimeoutTask(timeout: 10)
                timeoutTask.start()
                self.activeTasks[packetId] = InflightTask(state: .publishQoS1(.publishSent), timeout: timeoutTask)
            case .AtMostOnce:
                break
        }
    }

    private func handleSendPubrel(_ pubrel: Pubrel) {
        let packetId = pubrel.varHeader.packetId
        // TODO: set timout in config
        let timeoutTask = TimeoutTask(timeout: 10)
        timeoutTask.start()
        self.activeTasks[packetId] = InflightTask(state: .publishQoS2(.pubRelSent), timeout: timeoutTask)
    }

    private func handleSendPuback(_ puback: Puback) {
        // let packetId =
        guard self.passiveTasks.remove(puback.varHeader.packetId) != nil else {
            // TODO: Throw error and close connection
            self.eventBus.emit(.warning("Sent puback for unkown packetId"))
            return
        }
    }

    private func handleSendPubrec(_ pubrec: Pubrec) {
        let packetId = pubrec.varHeader.packetId
        guard self.passiveTasks.contains(packetId) else {
            // TODO: Throw error and close connection
            self.eventBus.emit(.warning("Sent pubrec for unknown packetId"))
            return
        }
    }

    private func handleSendPubcomp(_ pubcomp: Pubcomp) {
        guard self.passiveTasks.remove(pubcomp.varHeader.packetId) != nil else {
            // TODO: Throw error and close connection
            self.eventBus.emit(.warning("Sent pubcomp for unknown packetId"))
            return
        }
    }

    private func handleSendSubscribe(_ subscribe: Subscribe) {
        let packetId = subscribe.varHeader.packetId
        let topicFilters = subscribe.payload.topics
        self.subscriptions.append(contentsOf: topicFilters)

        // TODO: Define duration in config
        let timeoutTask = TimeoutTask(timeout: 10)
        timeoutTask.start()
        self.activeTasks[packetId] = InflightTask(state: .subscribe(.SubscribeSent), timeout: timeoutTask)
    }

    private func handleSendConnect(_ connect: Connect) {
        let timer = TimeoutTask(timeout: self.config.connTimeout)
        timer.start()
        self.connackTask = timer
    }

    private func handleSendPingreq(_ pingreq: Pingreq) {
        let timeoutTask = TimeoutTask(timeout: self.config.pingTimeout)
        timeoutTask.start()
        self.pingrespTask = timeoutTask
    }
}

// MARK: receive handlers
extension MQTTSession {
    private func handleConnack(_ connack: Connack) {
        let returnCode = connack.varHeader.connectReturnCode

        if case .ConnectionAccepted = returnCode {
            guard let connackTask = self.connackTask else {
                // TODO: maybe throw error here
                return
            }

            connackTask.stop()
            self.connackTask = nil
        } else {
            // TODO: Throw error and close connection
            self.eventBus.emit(.warning("Connection rejected with error code: \(returnCode)"))
        }
    }

    private func handleSuback(_ suback: Suback) {
        let packetId = suback.varHeader.packetId
        guard let subackTask = self.activeTasks.removeValue(forKey: packetId) else {
            // TODO: throw error and close connection
            self.eventBus.emit(.warning("Received suback for unknown packetId"))
            return
        }
        subackTask.timeout?.stop()
    }

    private func handlePublish(_ publish: Publish) {
        switch publish.qos {
            case .ExactlyOnce:
                guard let packetId = publish.varHeader.packetId else {
                    // TODO: Close connection instead of warning
                    self.eventBus.emit(.warning("Received QoS 2 publish without packetId"))
                    return
                }
                self.commandBus.emit(.send(Pubrec(packetId: packetId)))
                self.passiveTasks.insert(packetId)
                // self.eventBus.emit(.received(.publish(publish)))
            case .AtLeastOnce:
                guard let packetId = publish.varHeader.packetId else {
                    // TODO: Close connection instead of warning
                    self.eventBus.emit(.warning("Received QoS 1 publish without packetId"))
                    return
                }
                self.commandBus.emit(.send(Puback(packetId: packetId)))
                self.passiveTasks.insert(packetId)
                // self.eventBus.emit(.received(.publish(publish)))
            case .AtMostOnce:
                break
                // self.eventBus.emit(.received(.publish(publish)))
        }
    }

    private func handlePuback(_ puback: Puback) {
        let packetId = puback.varHeader.packetId
        guard let inflightTask = self.activeTasks.removeValue(forKey: packetId) else {
            // should close connection here
            self.eventBus.emit(.warning("Received puback for unknown packetId"))
            return
        }

        inflightTask.timeout?.stop()
    }

    private func handlePubrec(_ pubrec: Pubrec) {
        let packetId = pubrec.varHeader.packetId
        guard let inflightTask = self.activeTasks.removeValue(forKey: packetId) else {
            // should close connection here
            self.eventBus.emit(.warning("Received pubrec for unknown packetId"))
            return
        }

        inflightTask.timeout?.stop()
    }

    private func handlePubrel(_ pubrel: Pubrel) {
        let packetId = pubrel.varHeader.packetId
        guard self.passiveTasks.contains(packetId) else {
            // TODO: Throw error and close connection
            self.eventBus.emit(.warning("Received pubrel for unknown packetId"))
            return
        }
        self.commandBus.emit(.send(Pubcomp(packetId: packetId)))
    }

    private func handlePubcomp(_ pubcomp: Pubcomp) {
        let packetId = pubcomp.varHeader.packetId
        guard let inflighTask = self.activeTasks.removeValue(forKey: packetId) else {
            // should close connection here
            self.eventBus.emit(.warning("Received pubcomp for unknown packetId"))
            return
        }

        inflighTask.timeout?.stop()
    }
}

// MARK: Await functions
extension MQTTSession {
    func awaitKeepAlive() async {
        precondition(self.keepAliveCont == nil, "already awaiting keepalive")

        await withCheckedContinuation { cont in
            self.keepAliveCont = cont

            self.startKeepAlive(cont: cont)
        }
    }

    func awaitPingresp() async throws {
        guard let pingrespTask = self.pingrespTask else {
            // TODO: throw error
            return
        }

        try await pingrespTask.wait()
    }

    func awaitConack() async throws {
        guard let connackTask = self.connackTask else {
            // TODO: Throw error
            return
        }

        try await connackTask.wait()
    }

    func awaitSuback(packetId: UInt16) async throws {
        guard let subackTask = self.activeTasks[packetId] else {
            // TODO: throw error
            return
        }

        switch subackTask.state {
            case .subscribe(.SubscribeSent):
                try await subackTask.timeout?.wait()
            default:
                // TODO: throw error
                return
        }

    }

    func awaitPuback(packetId: UInt16) async throws {
        guard let pubackTask = self.activeTasks[packetId] else {
            // TODO: throw error
            return
        }

        switch pubackTask.state {
            case .publishQoS1(.publishSent):
                try await pubackTask.timeout?.wait()
            default:
                // TODO: throw error
                return
        }
    }

    func awaitPubrec(packetId: UInt16) async throws {
        guard let pubrecTask = self.activeTasks[packetId] else {
            // TODO: throw error
            return
        }

        switch pubrecTask.state {
            case .publishQoS2(.publishSent):
                try await pubrecTask.timeout?.wait()
            default:
                // TODO: throw error
                return
        }
    }

    func awaitPubComp(packetId: UInt16) async throws {
        guard let pubcompTask = self.activeTasks[packetId] else {
            // TODO: throw error
            return
        }

        switch pubcompTask.state {
            case .publishQoS2(.pubRelSent):
                try await pubcompTask.timeout?.wait()
            default:
                // TODO: throw error
                return
        }
    }
}

// MARK: Keepalive
extension MQTTSession {
    private func startKeepAlive(cont: CheckedContinuation<Void, Never>) {
        self.keepAliveTask = Task {
            try? await Task.sleep(for: .seconds(Double(self.config.keepAlive) * 0.5))
            cont.resume()
            self.keepAliveCont = nil
        }
    }

    private func resetKeepAlive() {
        self.keepAliveTask?.cancel()
        self.keepAliveTask = nil
        guard let cont = self.keepAliveCont else { return }
        startKeepAlive(cont: cont)
    }
}
