import Testing

@testable import SwiftMQTT

// MARK: Connack
@Test("Create Connack Packet") func createConnackPacket() {
    let connack = Connack(returnCode: .ConnectionAccepted, sessionPresent: false)
    #expect(connack.fixedHeader == FixedHeader(type: .CONNACK, flags: 0, remainingLength: 2))
    #expect(connack.varHeader == ConnackVariableHeader(sessionPresent: 0, connectReturnCode: .ConnectionAccepted))
}

@Test("Decode Connack Packet") func decodeConnackPacket() {
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

// MARK: Connect
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

// MARK: Publish
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

@Test("Create Publish Packet with byte message") func createPublishByteMessage() {
    let publish = Publish(
        topicName: "test/topic", message: Bytes("hello".utf8), qos: .AtMostOnce)
    let rawPublish: Bytes = [
        0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68,
        0x65, 0x6c, 0x6c, 0x6f,
    ]

    #expect(publish.encode() == rawPublish)
}

// MARK: Puback
@Test("Create Puback") func createPuback() {
    let puback = Puback(packetId: 1)
    #expect(puback.fixedHeader == FixedHeader(type: .PUBACK, flags: 0, remainingLength: 2))
    #expect(puback.varHeader == PubackVarableHeader(packetId: 1))
}

@Test("Decode Puback") func decodePuback() {
    let bytes: Bytes = [0x40, 0x02, 0x00, 0x01]
    let puback = try! Puback(bytes: bytes)
    #expect(puback == Puback(packetId: 1))
}

@Test("Encode Puback") func encodePuback() {
    let puback = Puback(packetId: 1)
    let bytes: Bytes = [0x40, 0x02, 0x00, 0x01]
    #expect(puback.encode() == bytes)
}

// MARK: Pubrec
@Test("Create pubrec") func createPubrec() {
    let pubrec = Pubrec(packetId: 1)
    #expect(pubrec.fixedHeader == FixedHeader(type: .PUBREC, flags: 0, remainingLength: 2))
    #expect(pubrec.varHeader == PubrecVariableHeader(packetId: 1))
}

@Test("Decode pubrec") func decodePubrec() {
    let bytes: Bytes = [0x50, 0x02, 0x00, 0x01]
    let pubrec = try! Pubrec(bytes: bytes)
    #expect(pubrec == Pubrec(packetId: 1))
}

@Test("Encode pubrec") func encodePubrec() {
    let pubrec = Pubrec(packetId: 1)
    let bytes: Bytes = [0x50, 0x02, 0x00, 0x01]
    #expect(pubrec.encode() == bytes)
}

// MARK: Pubrel
@Test("Create pubrel") func createPubrel() {
    let pubrel = Pubrel(packetId: 1)
    #expect(pubrel.fixedHeader == FixedHeader(type: .PUBREL, flags: 2, remainingLength: 2))
    #expect(pubrel.varHeader == PubrelVariableHeader(packetId: 1))
}

@Test("Decode pubrel") func decodePubrel() {
    let bytes: Bytes = [0x62, 0x02, 0x00, 0x01]
    let pubrel = try! Pubrel(bytes: bytes)
    #expect(pubrel == Pubrel(packetId: 1))
}

@Test("Encode pubrel") func encodePubrel() {
    let pubrel = Pubrel(packetId: 1)
    let bytes: Bytes = [0x62, 0x02, 0x00, 0x01]
    #expect(pubrel.encode() == bytes)
}

// Mark: Pubcomp
@Test("Create pubcomp") func createPubcomp() {
    let pubcomp = Pubcomp(packetId: 1)
    #expect(pubcomp.fixedHeader == FixedHeader(type: .PUBCOMP, flags: 0, remainingLength: 2))
    #expect(pubcomp.varHeader == PubcompVariableHeader(packetId: 1))
}

@Test("Decode pubcomp") func decodePubcomp() {
    let bytes: Bytes = [0x70, 0x02, 0x00, 0x01]
    let pubcomp = try! Pubcomp(bytes: bytes)
    #expect(pubcomp == Pubcomp(packetId: 1))
}

@Test("Encode pubcomp") func encodePubcomp() {
    let pubcomp = Pubcomp(packetId: 1)
    let bytes: Bytes = [0x70, 0x02, 0x00, 0x01]
    #expect(pubcomp.encode() == bytes)
}

// MARK: Subscribe
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

// MARK: Suback
@Test("Create suback") func createSuback() {
    let suback = Suback(packetId: 1, returnCodes: [.QoS0, .QoS1, .QoS2])
    #expect(suback.fixedHeader == FixedHeader(type: .SUBACK, flags: 0, remainingLength: 5))
    #expect(suback.varHeader == SubackVariableHeader(packetId: 1))
    #expect(suback.payload == SubackPayload(returnCodes: [.QoS0, .QoS1, .QoS2]))
}

@Test("Decode suback") func decodeSuback() {
    let bytes: Bytes = [0x90, 0x05, 0x00, 0x01, 0x00, 0x01, 0x02]
    let suback = try! Suback(bytes: bytes)
    #expect(suback == Suback(packetId: 1, returnCodes: [.QoS0, .QoS1, .QoS2]))
}

@Test("Encode suback") func encodeSuback() {
    let bytes: Bytes = [0x90, 0x05, 0x00, 0x01, 0x00, 0x01, 0x02]
    let suback = Suback(packetId: 1, returnCodes: [.QoS0, .QoS1, .QoS2])
    #expect(suback.encode() == bytes)
}

// MARK: Unsub
// MARK: Unsuback

// MARK: Pingreq
@Test("Create pingreq") func createPingreq() {
    let pingreq = Pingreq()
    #expect(pingreq.fixedHeader == FixedHeader(type: .PINGREQ, flags: 0, remainingLength: 0))
}

@Test("Encode pingreq") func encodePingreq() {
    let pingreq = Pingreq()
    let bytes: Bytes = [0xc0, 0x00]
    #expect(pingreq.encode() == bytes)
}

// MARK: Pingresp
@Test("Create pingresp") func createPingresp() {
    let pingresp = Pingresp()
    #expect(pingresp.fixedHeader == FixedHeader(type: .PINGRESP, flags: 0, remainingLength: 0))
}

@Test("Decode pingresp") func decodePingresp() {
    let bytes: Bytes = [0xd0, 0x00]
    let pingresp = try! Pingresp(bytes: bytes)
    #expect(pingresp == Pingresp())
}

@Test("Encode pingresp") func encodePingresp() {
    let pingresp = Pingresp()
    let bytes: Bytes = [0xd0, 0x00]
    #expect(pingresp.encode() == bytes)
}

// MARK: Disconnect
@Test("Create disconnect") func createDisconnect() {
    let disconnect = Disconnect()
    #expect(disconnect.fixedHeader == FixedHeader(type: .DISCONNECT, flags: 0, remainingLength: 0))
}

@Test("Encode disconnect") func encodeDisconnect() {
    let disconnect = Disconnect()
    let bytes: Bytes = [0xe0, 0x00]
    #expect(disconnect.encode() == bytes)
}
