/**
* Tests for all packets used in the publish process, qos 0, 1 and 2
**/

import Testing
@testable import SwiftMQTT

@Test("Decode Publish Packet") func deocdePublishPacket() {
    let rawPublish: ByteBuffer = [0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68, 0x65, 0x6c, 0x6c, 0x6f]
    let publishPacket = try! MQTTPublishPacket(bytes: rawPublish)

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
    let publish = MQTTPublishPacket(topicName: "test/topic", message: "hello", qos: .AtMostOnce)
    let rawPublish: ByteBuffer = [0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68, 0x65, 0x6c, 0x6c, 0x6f]

    #expect(publish.encode() == rawPublish)
}

@Test("Create Publish Packet with string message") func createPublishByteMessage() {
    let publish = MQTTPublishPacket(topicName: "test/topic", message: ByteBuffer("hello".utf8), qos: .AtMostOnce)
    let rawPublish: ByteBuffer = [0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69, 0x63, 0x68, 0x65, 0x6c, 0x6c, 0x6f]

    #expect(publish.encode() == rawPublish)
}

// Puback
// Pubrec
// Pubrel
// Pubcomp
