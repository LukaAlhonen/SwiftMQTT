import Testing
@testable import SwiftMQTT

@Test("QoS 1 publish and subscribe") func connectMQTTClient() async {
    let subscriber: MQTTClient = .init(brokerAddress: "localhost", brokerPort: 1883, clientId: "test-sub", config: .init())
    let publisher: MQTTClient = .init(brokerAddress: "localhost", brokerPort: 1883, clientId: "test-pub", config: .init())

    let _ = try! await withTimeout(seconds: 1) {
        try await publisher.start()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.start()
    }

    let _ = try! await withTimeout(seconds: 1) {
        try? await subscriber.subscribe(to: [.init(topic: "test/topic", qos: .AtMostOnce)])
    }

    let packetTask = Task {
        for try await pkt in subscriber.packetStream {
            print("hello")
            return pkt
        }

        throw TestError.emptyPacketStream
    }

    let pubPacket = Publish(topicName: "test/topic", message: "hello", qos: .AtMostOnce)

    try! await publisher.publish(packet: pubPacket)

    let packet = try! await withTimeout(seconds: 5) {
        try await packetTask.value
    }

    #expect(packet as? Publish == pubPacket)
}
