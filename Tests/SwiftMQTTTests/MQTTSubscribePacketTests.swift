import Testing
@testable import SwiftMQTT

@Test("Create Subscribe Packet") func createSubscribePacket() {
    let subscribePacket = MQTTSubscribePacket(topic: "test/topic", qos: .AtMostOnce)
    #expect(subscribePacket.fixedHeader == FixedHeader(type: .SUBSCRIBE, flags: 2, remainingLength: 15))
    #expect(subscribePacket.varHeader.encode() == [0x00, 0x01])
    #expect(subscribePacket.payload.encode() == [0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x74, 0x6F, 0x70, 0x69, 0x63, 0x00])
}

@Test("Encode Subscribe Packet") func encodeSubscribePacket() {
    let subscribePacket = MQTTSubscribePacket(topic: "test/topic", qos: .AtMostOnce)
    #expect(subscribePacket.encode() == [0x82, 0x0f, 0x00, 0x01, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2F, 0x74, 0x6F, 0x70, 0x69, 0x63, 0x00])
}
