import Foundation

actor MQTTSession {
    private let config: Config
    private let eventBus: MQTTEventBus<MQTTEvent>

    let commandBus: MQTTEventBus<MQTTInternalCommand>

    private var inflightSubscriptions: [UInt16: ([TopicFilter], SubscribeProperties?)] = [:]
    // topic string, qos, properties
    private var subscriptions: [String: (QoS, SubscribeProperties?)] = [:]
    private var inflightUnsubs: [UInt16: [String]] = [:]

    private var keepAliveTask: Task<Void, Never>?
    private var keepAliveCont: CheckedContinuation<Void, Never>?

    // special timeout tasks for ping and conn since they have no packetId
    private var connackTask: TimeoutTask?
    private var pingrespTask: TimeoutTask?

    // publish and subscribe tasks started by the client
    private var activeTasks: [UInt16: InflightTask] = .init()
    // tasks started by the server
    private var passiveTasks: Set<UInt16> = .init()

    init(
        config: Config, eventBus: MQTTEventBus<MQTTEvent>,
        commandBus: MQTTEventBus<MQTTInternalCommand>
    ) {
        self.config = config
        self.eventBus = eventBus
        self.commandBus = commandBus
    }

    func getSubscriptions() -> [SubscribeProperties?: [TopicFilter]] {
        var subs: [SubscribeProperties?: [TopicFilter]] = [:]
        for (key, value) in subscriptions {
            let subProps = value.1
            let topicFilter = TopicFilter(topic: key, qos: value.0)
            if subs[subProps] == nil {
                subs[subProps] = [topicFilter]
            } else {
                subs[subProps]?.append(topicFilter)
            }
        }

        return subs
    }

    func handle(_ event: MQTTInternalEvent) {
        switch event {
        case .send(let packet):
            self.handleSend(packet: packet)
        case .packet(let packet):
            self.handlePacket(packet: packet)
        case .connectionError(let error):
            self.eventBus.emit(.error(error))
        case .connectionInactive:
            self.eventBus.emit(.error(MQTTError.connectionError(.disconnected)))
        case .connectionActive:
            self.eventBus.emit(.info("Connection active"))
        }
    }

    private func handlePacket(packet: MQTTPacket) {
        // self.eventBus.emit(.received(packet))
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
        case .pingresp(let pingresp):
            self.handlePingresp(pingresp)
        case .unsuback(let unsuback):
            self.handleUnsuback(unsuback)
        default:
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(
                        .unexpectedPacket(packet: packet.inner().fixedHeader.type)),
                    reasonCode: .protocolError))
            return
        }
    }

    private func handleSend(packet: any MQTTControlPacket) {
        self.resetKeepAlive()
        self.eventBus.emit(.send(packet))

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
        case .PINGREQ:
            guard let pingreq = packet as? Pingreq else { return }
            self.handleSendPingreq(pingreq)
        case .UNSUBSCRIBE:
            guard let unsubscribe = packet as? Unsubscribe else { return }
            self.handleSendUnsubscribe(unsubscribe)
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
            guard let packetId = publish.variableHeader.packetId else {
                self.commandBus.emit(
                    .disconnect(
                        MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId)),
                        reasonCode: .malformedPacket))
                return
            }
            let timeoutTask = TimeoutTask(
                timeout: self.config.publishTimeout,
                kind: .publish(packetId: packetId, qos: .ExactlyOnce))
            timeoutTask.start()
            self.activeTasks[packetId] = InflightTask(
                state: .publishQoS2(.publishSent), timeout: timeoutTask)
        case .AtLeastOnce:
            guard let packetId = publish.variableHeader.packetId else {
                self.commandBus.emit(
                    .disconnect(
                        MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId)),
                        reasonCode: .malformedPacket))
                return
            }

            let timeoutTask = TimeoutTask(
                timeout: self.config.publishTimeout,
                kind: .publish(packetId: packetId, qos: .AtLeastOnce))
            timeoutTask.start()
            self.activeTasks[packetId] = InflightTask(
                state: .publishQoS1(.publishSent), timeout: timeoutTask)
        case .AtMostOnce:
            break
        }
    }

    private func handleSendPubrel(_ pubrel: Pubrel) {
        let packetId = pubrel.varHeader.packetId
        let timeoutTask = TimeoutTask(
            timeout: self.config.publishTimeout,
            kind: .publish(packetId: packetId, qos: .ExactlyOnce))
        timeoutTask.start()
        self.activeTasks[packetId] = InflightTask(
            state: .publishQoS2(.pubRelSent), timeout: timeoutTask)
    }

    private func handleSendPuback(_ puback: Puback) {
        guard self.passiveTasks.remove(puback.varHeader.packetId) != nil else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(
                        .unknownPacketId(packetId: puback.varHeader.packetId)),
                    reasonCode: .malformedPacket))
            return
        }
    }

    private func handleSendPubrec(_ pubrec: Pubrec) {
        let packetId = pubrec.varHeader.packetId
        guard self.passiveTasks.contains(packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unknownPacketId(packetId: packetId)),
                    reasonCode: .malformedPacket))
            return
        }
    }

    private func handleSendPubcomp(_ pubcomp: Pubcomp) {
        guard self.passiveTasks.remove(pubcomp.varHeader.packetId) != nil else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(
                        .unknownPacketId(packetId: pubcomp.varHeader.packetId)),
                    reasonCode: .malformedPacket))
            return
        }
    }

    private func handleSendSubscribe(_ subscribe: Subscribe) {
        let packetId = subscribe.varHeader.packetId
        let topicFilters = subscribe.payload.topics
        let properties = subscribe.varHeader.properties
        self.inflightSubscriptions[packetId] = (topicFilters, properties)
        // register subscriptions before suback received, delete if suback times out or rejects sub
        for filter in topicFilters {
            self.subscriptions[filter.topic] = (filter.qos, properties)
        }

        let timeoutTask = TimeoutTask(
            timeout: self.config.subscribeTimeout, kind: .subscribe(packetId: packetId))
        timeoutTask.start()
        self.activeTasks[packetId] = InflightTask(
            state: .subscribe(.SubscribeSent), timeout: timeoutTask)
    }

    private func handleSendConnect(_ connect: Connect) {
        let timer = TimeoutTask(timeout: self.config.connTimeout, kind: .connect)
        timer.start()
        self.connackTask = timer
    }

    private func handleSendPingreq(_ pingreq: Pingreq) {
        let timeoutTask = TimeoutTask(timeout: self.config.pingTimeout, kind: .ping)
        timeoutTask.start()
        self.pingrespTask = timeoutTask
    }

    private func handleSendUnsubscribe(_ unsub: Unsubscribe) {
        let packetId = unsub.varHeader.packetId
        let timeoutTask = TimeoutTask(
            timeout: self.config.subscribeTimeout, kind: .unsub(packetId: packetId))
        timeoutTask.start()
        self.activeTasks[packetId] = InflightTask(
            state: .unsubscribe(.unsubSent), timeout: timeoutTask)

        // track inflight unsub so we can handle return codes
        self.inflightUnsubs[packetId] = unsub.payload.topics
    }
}

// MARK: receive handlers
extension MQTTSession {
    private func handleConnack(_ connack: Connack) {
        self.eventBus.emit(.received(MQTTPacket.connack(connack)))
        // v3
        if let returnCode = connack.varHeader.connectReturnCode {
            if case .ConnectionAccepted = returnCode {
                guard let connackTask = self.connackTask else {
                    self.commandBus.emit(
                        .disconnect(
                            MQTTError.unexpectedError("Connack timeoutTask should not be nil"),
                            reasonCode: .unspecifiedError))
                    return
                }

                connackTask.stop()
                self.connackTask = nil
            } else {
                self.commandBus.emit(
                    .disconnect(
                        MQTTError.connectionError(.rejected(reason: .returnCode(returnCode)))))
            }
            // v5
        } else if let reasonCode = connack.varHeader.connectReasonCode {
            if case .success = reasonCode {
                guard let connackTask = self.connackTask else {
                    self.commandBus.emit(
                        .disconnect(
                            MQTTError.unexpectedError("Connack timeoutTask should not be nil"),
                            reasonCode: .unspecifiedError))
                    return
                }

                connackTask.stop()
                self.connackTask = nil
            } else {
                self.commandBus.emit(
                    .disconnect(
                        MQTTError.connectionError(.rejected(reason: .reasonCode(reasonCode)))))
            }
        }
    }

    private func handlePingresp(_ pingresp: Pingresp) {
        self.eventBus.emit(.received(MQTTPacket.pingresp(pingresp)))
        guard let pingrespTask = self.pingrespTask else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.unexpectedError("Pingresp task should not be nil"),
                    reasonCode: .unspecifiedError))
            return
        }

        pingrespTask.stop()
        self.pingrespTask = nil
    }

    private func handleSuback(_ suback: Suback) {
        let packetId = suback.varHeader.packetId
        guard let subackTask = self.activeTasks.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unexpectedPacket(packet: .SUBACK)),
                    reasonCode: .protocolError))
            return
        }

        self.eventBus.emit(.received(MQTTPacket.suback(suback)))

        // if a sub was rejected, notify user
        var index = 0

        guard let inflightSub = self.inflightSubscriptions.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.unexpectedError("infligt sub should exist for packetId: \(packetId)"))
            )
            return
        }
        let topics = inflightSub.0

        for returnCode in suback.payload.returnCodes {
            if case .Rejected = returnCode {
                let topic = topics[index]
                self.subscriptions.removeValue(forKey: topic.topic)  // remove topic from active subscriptions
                self.eventBus.emit(.error(MQTTError.subscriptionRejected(topic)))
            }
            index += 1
        }

        subackTask.timeout?.stop()
    }

    private func handlePublish(_ publish: Publish) {
        // check that topic is actually subscribed to
        let topic = publish.variableHeader.topicName
        guard self.subscriptions[topic] != nil else {
            self.commandBus.emit(
                .disconnect(MQTTError.protocolViolation(.unexpectedPublish(topic: topic))))
            return
        }
        self.eventBus.emit(.received(MQTTPacket.publish(publish)))

        switch publish.qos {
        case .ExactlyOnce:
            guard let packetId = publish.variableHeader.packetId else {
                self.commandBus.emit(
                    .disconnect(
                        MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId)),
                        reasonCode: .malformedPacket))
                return
            }
            self.commandBus.emit(.send(Pubrec(packetId: packetId)))
            self.passiveTasks.insert(packetId)
        case .AtLeastOnce:
            guard let packetId = publish.variableHeader.packetId else {
                self.commandBus.emit(
                    .disconnect(
                        MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId)),
                        reasonCode: .malformedPacket))
                return
            }
            self.commandBus.emit(.send(Puback(packetId: packetId)))
            self.passiveTasks.insert(packetId)
        case .AtMostOnce:
            break
        }
    }

    private func handlePuback(_ puback: Puback) {
        var result: Result<Void, Error> = .success(())
        if let reasonCode = puback.varHeader.reasonCode {
            if case .success = reasonCode {
                result = .success(())
            } else if case .noMatchingSubscribers = reasonCode {
                result = .success(())
                self.eventBus.emit(.info("no matching subscribers"))
            } else {
                let error = MQTTError.protocolViolation(
                    .operationRejected(reasonCode: reasonCode.rawValue, operation: .PUBACK))
                result = .failure(error)
                self.eventBus.emit(.error(error))
            }
        }
        let packetId = puback.varHeader.packetId
        guard let inflightTask = self.activeTasks.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unexpectedPacket(packet: .PUBACK)),
                    reasonCode: .protocolError))
            return
        }

        self.eventBus.emit(.received(MQTTPacket.puback(puback)))

        inflightTask.timeout?.stop(with: result)
    }

    private func handlePubrec(_ pubrec: Pubrec) {
        let packetId = pubrec.varHeader.packetId
        guard let inflightTask = self.activeTasks.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unexpectedPacket(packet: .PUBREC)),
                    reasonCode: .protocolError))
            return
        }

        self.eventBus.emit(.received(MQTTPacket.pubrec(pubrec)))

        inflightTask.timeout?.stop()
    }

    private func handlePubrel(_ pubrel: Pubrel) {
        let packetId = pubrel.varHeader.packetId
        guard self.passiveTasks.contains(packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unexpectedPacket(packet: .PUBREL)),
                    reasonCode: .protocolError))
            return
        }

        self.eventBus.emit(.received(MQTTPacket.pubrel(pubrel)))

        self.commandBus.emit(.send(Pubcomp(packetId: packetId)))
    }

    private func handlePubcomp(_ pubcomp: Pubcomp) {
        let packetId = pubcomp.varHeader.packetId
        guard let inflighTask = self.activeTasks.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unexpectedPacket(packet: .PUBCOMP)),
                    reasonCode: .protocolError))
            return
        }

        self.eventBus.emit(.received(MQTTPacket.pubcomp(pubcomp)))

        inflighTask.timeout?.stop()
    }

    private func handleUnsuback(_ unsuback: Unsuback) {
        // v5
        let packetId = unsuback.varHeader.packetId
        guard let inflightTask = self.activeTasks.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.protocolViolation(.unexpectedPacket(packet: .UNSUBACK)),
                    reasonCode: .protocolError))
            return
        }

        var result: Result<Void, Error> = .success(())
        guard let topics = self.inflightUnsubs.removeValue(forKey: packetId) else {
            self.commandBus.emit(
                .disconnect(
                    MQTTError.unexpectedError(
                        "inflight unsubs should contain packetId: \(packetId)")
                ))
            return
        }
        if let reasonCodes = unsuback.payload?.reasonCodes {
            // v5
            var index = 0
            for reasonCode in reasonCodes {
                if case .success = reasonCode {
                    result = .success(())

                    // remove topic from active subscriptions
                    let topic = topics[index]
                    let _ = self.subscriptions.removeValue(forKey: topic)
                } else {
                    let error =
                        MQTTError.protocolViolation(
                            .operationRejected(
                                reasonCode: reasonCode.rawValue, operation: .UNSUBACK))

                    result = .failure(error)
                    self.eventBus.emit(.error(error))
                }
                index += 1
            }
        } else {
            // v3
            for topic in topics {
                let _ = self.subscriptions.removeValue(forKey: topic)
            }
        }

        self.eventBus.emit(.received(MQTTPacket.unsuback(unsuback)))

        inflightTask.timeout?.stop(with: result)
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
            throw MQTTError.unexpectedError("Pingresp task should not be nil")
        }

        try await pingrespTask.wait()
    }

    func awaitConack() async throws {
        guard let connackTask = self.connackTask else {
            throw MQTTError.unexpectedError("Connack task should not be nil")
        }

        try await connackTask.wait()
    }

    func awaitSuback(packetId: UInt16) async throws {
        guard let subackTask = self.activeTasks[packetId] else {
            throw MQTTError.unexpectedError(
                "Suback task for packetId \(packetId) should not be nil")
        }

        switch subackTask.state {
        case .subscribe(.SubscribeSent):
            try await subackTask.timeout?.wait()
        default:
            // TODO: perhaps change string to inflightstate
            throw MQTTError.protocolViolation(
                .invalidState(
                    expected: "\(InflightState.subscribe(.SubscribeSent))",
                    acutal: "\(subackTask.state)")
            )
        }
    }

    func awaitUnsuback(packetId: UInt16) async throws {
        guard let unsubackTask = self.activeTasks[packetId] else {
            throw MQTTError.unexpectedError(
                "Unsuback task for packetId \(packetId) should not be nil")
        }

        switch unsubackTask.state {
        case .unsubscribe(.unsubSent):
            try await unsubackTask.timeout?.wait()
        default:
            // TODO: perhaps change string to inflightstate
            throw MQTTError.protocolViolation(
                .invalidState(
                    expected: "\(InflightState.unsubscribe(.unsubSent))",
                    acutal: "\(unsubackTask.state)")
            )
        }
    }

    func awaitPuback(packetId: UInt16) async throws {
        guard let pubackTask = self.activeTasks[packetId] else {
            throw MQTTError.unexpectedError(
                "Puback task for packetId \(packetId) should not be nil")
        }

        switch pubackTask.state {
        case .publishQoS1(.publishSent):
            try await pubackTask.timeout?.wait()
        default:
            throw MQTTError.protocolViolation(
                .invalidState(
                    expected: "\(InflightState.publishQoS1(.publishSent))",
                    acutal: "\(pubackTask.state)")
            )
        }
    }

    func awaitPubrec(packetId: UInt16) async throws {
        guard let pubrecTask = self.activeTasks[packetId] else {
            throw MQTTError.unexpectedError(
                "Pubrec task for packetId \(packetId) should not be nil")
        }

        switch pubrecTask.state {
        case .publishQoS2(.publishSent):
            try await pubrecTask.timeout?.wait()
        default:
            throw MQTTError.protocolViolation(
                .invalidState(
                    expected: "\(InflightState.publishQoS2(.publishSent))",
                    acutal: "\(pubrecTask.state)")
            )
        }
    }

    func awaitPubComp(packetId: UInt16) async throws {
        guard let pubcompTask = self.activeTasks[packetId] else {
            throw MQTTError.unexpectedError(
                "Pubcomp task for packetId \(packetId) should not be nil")
        }

        switch pubcompTask.state {
        case .publishQoS2(.pubRelSent):
            try await pubcompTask.timeout?.wait()
        default:
            throw MQTTError.protocolViolation(
                .invalidState(
                    expected: "\(InflightState.publishQoS2(.pubRelSent))",
                    acutal: "\(pubcompTask.state)")
            )
        }
    }
}

// MARK: Keepalive
extension MQTTSession {
    private func startKeepAlive(cont: CheckedContinuation<Void, Never>) {
        self.keepAliveTask = Task {
            do {
                try await Task.sleep(for: .seconds(Double(self.config.keepAlive) * 0.5))
                cont.resume()
                self.keepAliveCont = nil
            } catch {
            }
        }
    }

    private func resetKeepAlive() {
        self.keepAliveTask?.cancel()
        self.keepAliveTask = nil
        guard let cont = self.keepAliveCont else { return }
        startKeepAlive(cont: cont)
    }
}

// MARK: helpers
extension MQTTSession {
    private func registerSubscriptions(
        topicFilters: [TopicFilter], properties: SubscribeProperties?
    ) {
        for topicFilter in topicFilters {
            self.subscriptions[topicFilter.topic] = (topicFilter.qos, properties)
        }
    }
}
