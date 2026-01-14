import Testing
@testable import SwiftMQTT

@Test("Create Connect Packet") func createConnectPacket() {
    let connectPacket = MQTTConnectPacket(clientId: "swift-1", keepAlive: 60)
    #expect(connectPacket.fixedHeader == FixedHeader(type: .CONNECT, flags: 0, remainingLength: 19))
    #expect(connectPacket.varHeader.encode() == [0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3c])
    #expect(connectPacket.payload.encode() == [0x00, 0x07, 0x73, 0x77, 0x69, 0x66, 0x74, 0x2D, 0x31])
}

@Test("Encode Connect Packet") func encodeConnectPacket() {
    let connectPacket = MQTTConnectPacket(clientId: "swift-1", keepAlive: 60)
    #expect(connectPacket.encode() == [0x10, 0x13, 0x00, 0x04, 0x4D, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3C, 0x00, 0x07, 0x73, 0x77, 0x69, 0x66, 0x74, 0x2D, 0x31])
}
