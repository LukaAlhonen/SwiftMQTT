import Testing

@testable import SwiftMQTT

@Test("Create/Decode Connack Packet") func createConnackPacket() {
    let rawConnack: Bytes = [0x20, 0x02, 0x00, 0x00]
    let connackPacket = try! Connack(bytes: rawConnack)
    #expect(connackPacket.fixedHeader == FixedHeader(type: .CONNACK, flags: 0, remainingLength: 2))
    #expect(
        connackPacket.varHeader
            == ConnackVariableHeader(sessionPresent: 0, connectReturnCode: .ConnectionAccepted))
}

@Test("Encode Connack Packet") func encodeConnackPacket() {
    let rawConnack: Bytes = [0x20, 0x02, 0x00, 0x00]
    let connackPacket = try! Connack(bytes: rawConnack)

    #expect(connackPacket.fixedHeader.encode() == [0x20, 0x02])
    #expect(connackPacket.varHeader.encode() == [0x00, 0x00])
    #expect(connackPacket.encode() == rawConnack)
}

@Test("Create Connect Packet") func createConnectPacket() {
    let connectPacket = Connect(clientId: "swift-1", keepAlive: 60)
    #expect(connectPacket.fixedHeader == FixedHeader(type: .CONNECT, flags: 0, remainingLength: 19))
    #expect(
        connectPacket.varHeader.encode() == [
            0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3c,
        ])
    #expect(
        connectPacket.payload.encode() == [0x00, 0x07, 0x73, 0x77, 0x69, 0x66, 0x74, 0x2D, 0x31])
}

@Test("Encode Connect Packet") func encodeConnectPacket() {
    let connectPacket = Connect(clientId: "swift-1", keepAlive: 60)
    #expect(
        connectPacket.encode() == [
            0x10, 0x13, 0x00, 0x04, 0x4D, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3C, 0x00, 0x07,
            0x73, 0x77, 0x69, 0x66, 0x74, 0x2D, 0x31,
        ])
}

@Test("Decode Publish Packet") func deocdePublishPacket() {
    let rawPublish: Bytes = [
        0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68,
        0x65, 0x6c, 0x6c, 0x6f,
    ]
    let publishPacket = try! Publish(bytes: rawPublish)

    #expect(publishPacket.fixedHeader == FixedHeader(type: .PUBLISH, flags: 0, remainingLength: 17))
    #expect(publishPacket.varHeader.packetId == nil)
    #expect(publishPacket.varHeader.topicName == "test/topic")
    #expect(publishPacket.payload.content == [0x68, 0x65, 0x6c, 0x6c, 0x6f])
    #expect(publishPacket.payload.toString() == "hello")
    #expect(publishPacket.qos == .AtMostOnce)
    #expect(publishPacket.dup == false)
    #expect(publishPacket.retain == false)
}

@Test("Create Publish Packet with string message") func createPublishStringMessage() {
    let publish = Publish(topicName: "test/topic", message: "hello", qos: .AtMostOnce)
    let rawPublish: Bytes = [
        0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68,
        0x65, 0x6c, 0x6c, 0x6f,
    ]

    #expect(publish.encode() == rawPublish)
}

@Test("Create Publish Packet with string message") func createPublishByteMessage() {
    let publish = Publish(
        topicName: "test/topic", message: Bytes("hello".utf8), qos: .AtMostOnce)
    let rawPublish: Bytes = [
        0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68,
        0x65, 0x6c, 0x6c, 0x6f,
    ]

    #expect(publish.encode() == rawPublish)
}

@Test("Create Subscribe Packet") func createSubscribePacket() {
    let subscribePacket = Subscribe(topics: [.init(topic: "test/topic", qos: .AtMostOnce)]
    )
    #expect(
        subscribePacket.fixedHeader == FixedHeader(type: .SUBSCRIBE, flags: 2, remainingLength: 15))
    #expect(subscribePacket.varHeader.encode() == [0x00, 0x01])
    #expect(
        subscribePacket.payload.encode() == [
            0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x74, 0x6F, 0x70, 0x69, 0x63, 0x00,
        ])
}

@Test("Encode Subscribe Packet") func encodeSubscribePacket() {
    let subscribePacket = Subscribe(topics: [.init(topic: "test/topic", qos: .AtMostOnce)]
    )
    #expect(
        subscribePacket.encode() == [
            0x82, 0x0f, 0x00, 0x01, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x74, 0x6F, 0x70,
            0x69, 0x63, 0x00,
        ])
}
