import Testing
@testable import SwiftMQTT

@Test("Create/Decode Connack Packet") func createConnackPacket() {
    let rawConnack: ByteBuffer = [0x20, 0x02, 0x00, 0x00]
    let connackPacket = try! MQTTConnackPacket(data: rawConnack)
    #expect(connackPacket.fixedHeader == FixedHeader(type: .CONNACK, flags: 0, remainingLength: 2))
    #expect(connackPacket.varHeader == ConnackVariableHeader(sessionPresent: 0, connectReturnCode: .ConnectionAccepted))
}

@Test("Encode Connack Packet") func encodeConnackPacket() {
    let rawConnack: ByteBuffer = [0x20, 0x02, 0x00, 0x00]
    let connackPacket = try! MQTTConnackPacket(data: rawConnack)

    #expect(connackPacket.fixedHeader.encode() == [0x20, 0x02])
    #expect(connackPacket.varHeader.encode() == [0x00, 0x00])
    #expect(connackPacket.encode() == rawConnack)
}
