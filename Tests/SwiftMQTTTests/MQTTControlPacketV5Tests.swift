import Testing

@testable import SwiftMQTTAsync

// MARK: Connect
@Test("Create v5 Connect Packet") func createV5ConnectPacket() {
    let connectPacket = Connect(
        version: .v5,
        clientId: "test-sub1",
        keepAlive: 60,
        lwt: nil,
        auth: nil,
        properties: ConnectProperties(
            sessionExpiryInterval: 10,
            receiveMaximum: 1000,
            maximumPacketSize: 1000,
            topicAliasMaximum: 10,
            requestResponseInformation: 0,
            requestProblemInformation: 0
        )
    )

    #expect(connectPacket.fixedHeader == FixedHeader(type: .CONNECT, flags: 0, remainingLength: 42))

    #expect(connectPacket.varHeader == ConnVariableHeader(
            protocolName: "MQTT",
            protocolLevel: .v5,
            connectFlags: ConnConnectFlags(
                auth: nil,
                cleanSession: true,
                lwt: nil
            ),
            keepAlive: 60,
            properties: ConnectProperties(
                sessionExpiryInterval: 10,
                receiveMaximum: 1000,
                maximumPacketSize: 1000,
                topicAliasMaximum: 10,
                requestResponseInformation: 0,
                requestProblemInformation: 0,
            )
        )
    )

    #expect(connectPacket.payload == ConnPayload(clientId: "test-sub1"))
}

@Test("Encode v5 Connect Packet") func encodeV5Connect() {
    let raw: Bytes = [0x10, 0x2a, 0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x05, 0x02, 0x00, 0x3c, 0x14, 0x11, 0x00, 0x00, 0x00, 0x0a, 0x21, 0x03, 0xe8, 0x27, 0x00, 0x00, 0x03, 0xe8, 0x22, 0x00, 0x0a, 0x19, 0x00, 0x17, 0x00, 0x00, 0x09, 0x74, 0x65, 0x73, 0x74, 0x2d, 0x73, 0x75, 0x62, 0x31]
    let connectPacket = Connect(
        version: .v5,
        clientId: "test-sub1",
        keepAlive: 60,
        lwt: nil,
        auth: nil,
        properties: ConnectProperties(
            sessionExpiryInterval: 10,
            receiveMaximum: 1000,
            maximumPacketSize: 1000,
            topicAliasMaximum: 10,
            requestResponseInformation: 0,
            requestProblemInformation: 0
        )
    )

    #expect(connectPacket.encode() == raw)
}

// MARK: Connack

// MARK: Disconnect

// MARK: Pingreq

// MARK: Pingresp

// MARK: Puback

// MARK: Pubcomp

// MARK: Publish

// MARK: Pubrec

// MARK: Pubrel

// MARK: Suback

// MARK: Subscribe

// MARK: Unsuback

// MARK: Unsubscribe
