import Testing
@testable import SwiftMQTT

@Test("Connect to broker and check that keepalive works") func connectClient() async {
    let config = Config(keepAlive: 2)
    let client = MQTTClient(clientId: "test-client", host: "localhost", port: 1883, config: config)

    let _ = try! await withTimeout(seconds: 1) {
        try await client.connect()
    }

    let task = Task {
        var packets: [any MQTTControlPacket] = []
        for await event in await client.eventStream {
            switch event {
                case .received(let packet):
                    packets.append(packet.inner())
                case .send(let packet):
                    packets.append(packet)
                default:
                    break
            }
            if packets.count >= 6 { return packets }
        }

        throw TestError.emptyPacketStream
    }

    let packets = try! await withTimeout(seconds: 10) {
        try await task.value
    }

    #expect(packets[0] as? Connect == Connect(clientId: "test-client", keepAlive: config.keepAlive))
    #expect(packets[1] as? Connack == Connack(returnCode: .ConnectionAccepted, sessionPresent: false))
    #expect(packets[2] as? Pingreq == Pingreq())
    #expect(packets[3] as? Pingresp == Pingresp())
    #expect(packets[4] as? Pingreq == Pingreq())
    #expect(packets[5] as? Pingresp == Pingresp())
}

@Test("QoS 0 publish and subscribe") func qos0PubSub() async {
    let subscriber: MQTTClient = .init(clientId: "test-sub", host: "localhost", port: 1883, config: .init())
    let publisher: MQTTClient = .init(clientId: "test-pub", host: "localhost", port: 1883, config: .init())

    let _ = try! await withTimeout(seconds: 1) {
        try await publisher.connect()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.connect()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.subscribe(to: [.init(topic: "test/topic", qos: .AtMostOnce)])
    }

    let packetTask = Task {
        for await event in await subscriber.eventStream {
            switch event {
                case .received(let packet):
                    switch packet {
                        case .publish(let publish):
                            return publish
                        default:
                            break
                    }
                default:
                    break
            }
        }

        throw TestError.emptyPacketStream
    }

    let pubPacket = Publish(topicName: "test/topic", message: "hello", qos: .AtMostOnce)

    try! await publisher.publish(message: "hello", qos: .AtMostOnce, topic: "test/topic")

    let packet = try! await withTimeout(seconds: 5) {
        try await packetTask.value
    }

    await publisher.stop()
    await subscriber.stop()

    #expect(packet == pubPacket)
}

@Test("QoS 1 publish and subscribe") func qos1PubSub() async throws {
    let subscriber: MQTTClient = .init(clientId: "test-sub1", host: "localhost", port: 1883, config: .init())
    let publisher: MQTTClient = .init(clientId: "test-pub1", host: "localhost", port: 1883, config: .init())

    let _ = try! await withTimeout(seconds: 1) {
        try await publisher.connect()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.connect()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.subscribe(to: [.init(topic: "test/topic1", qos: .AtLeastOnce)])
    }

    let packetTask = Task {
        var packets: [any MQTTControlPacket] = []
        for await event in await subscriber.eventStream {
            switch event {
                case .received(let packet):
                    switch packet {
                        case .publish(let publish):
                            packets.append(publish)
                        default:
                            break
                    }
                case .send(let packet):
                    if packet.fixedHeader.type == .PUBACK {
                        packets.append(packet)
                        return packets
                    }
                default:
                    break
            }
        }

        throw TestError.emptyPacketStream
    }

    let publish = try! await publisher.publish(message: "hello", qos: .AtLeastOnce, topic: "test/topic1")
    guard let packetId = publish.varHeader.packetId else {
        throw MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId))
    }

    let packets = try! await withTimeout(seconds: 5) {
        try await packetTask.value
    }

    await publisher.stop()
    await subscriber.stop()

    #expect(packets[0] as? Publish == Publish(topicName: "test/topic1", message: "hello", packetId: packetId, qos: .AtLeastOnce))
    #expect(packets[1] as? Puback == Puback(packetId: packetId))
}

@Test("QoS 2 publish and subscribe") func qos2PubSub() async throws {
    let subscriber: MQTTClient = .init(clientId: "test-sub2", host: "localhost", port: 1883, config: .init())
    let publisher: MQTTClient = .init(clientId: "test-pub2", host: "localhost", port: 1883, config: .init())

    let _ = try! await withTimeout(seconds: 1) {
        try await publisher.connect()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.connect()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.subscribe(to: [.init(topic: "test/topic2", qos: .ExactlyOnce)])
    }

    let packetTask = Task {
        var packets: [any MQTTControlPacket] = []
        for await event in await subscriber.eventStream {
            switch event {
                case .received(let packet):
                    switch packet {
                        case .publish(let publish):
                            packets.append(publish)
                        case .pubrel(let pubrel):
                            packets.append(pubrel)
                        default:
                            break
                    }
                case .send(let packet):
                    switch packet.fixedHeader.type {
                        case .PUBREC:
                            packets.append(packet)
                        case .PUBCOMP:
                            packets.append(packet)
                            return packets
                        default:
                            break
                    }
                default:
                    break
            }
        }

        throw TestError.emptyPacketStream
    }

    let publish = try! await publisher.publish(message: "hello", qos: .ExactlyOnce, topic: "test/topic2")
    guard let packetId = publish.varHeader.packetId else {
        throw MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId))
    }

    let packets = try! await withTimeout(seconds: 5) {
        try await packetTask.value
    }

    await publisher.stop()
    await subscriber.stop()

    // Cast and compare each packet in order
    #expect(packets[0] as? Publish == Publish(topicName: "test/topic2", message: "hello", packetId: packetId, qos: .ExactlyOnce))
    #expect(packets[1] as? Pubrec == Pubrec(packetId: packetId))
    #expect(packets[2] as? Pubrel == Pubrel(packetId: packetId))
    #expect(packets[3] as? Pubcomp == Pubcomp(packetId: packetId))
}
