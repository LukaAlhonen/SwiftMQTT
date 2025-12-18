import Testing
@testable import SwiftMQTT

@Test("Create Connect Packet") func createConnectPacket() {
    let connectPacket = MQTTConnectPacket(clientId: "swift-1")
    #expect(connectPacket.fixedHeader == FixedHeader(type: .CONNECT, flags: 0, remainingLength: 19))
    #expect(connectPacket.varHeader == [0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3c])
    #expect(connectPacket.payload == [0x00, 0x07, 0x73, 0x77, 0x69, 0x66, 0x74, 0x2D, 0x31])
}

@Test("Encode Connect Packet") func encodeConnectPacket() {
    let connectPacket = MQTTConnectPacket(clientId: "swift-1")
    #expect(connectPacket.encode() == [0x10, 0x13, 0x00, 0x04, 0x4D, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3C, 0x00, 0x07, 0x73, 0x77, 0x69, 0x66, 0x74, 0x2D, 0x31])
}


@Test("Create Subscribe Packet") func createSubscribePacket() {
    let subscribePacket = MQTTSubscribePacket(messageId: 1, topic: "test/topic")
    #expect(subscribePacket.fixedHeader == FixedHeader(type: .SUBSCRIBE, flags: 2, remainingLength: 15))
    #expect(subscribePacket.varHeader == [0x00, 0x01])
    #expect(subscribePacket.payload == [0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x74, 0x6F, 0x70, 0x69, 0x63, 0x00])
}

@Test("Encode Subscribe Packet") func encodeSubscribePacket() {
    let subscribePacket = MQTTSubscribePacket(messageId: 1, topic: "test/topic")
    #expect(subscribePacket.encode() == [0x82, 0x0f, 0x00, 0x01, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x74, 0x6F, 0x70, 0x69, 0x63, 0x00])
}
