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
@Test("Create v5 connack packet") func createV5Connack() {
    let connack = Connack(reasonCode: .success, sessionPresent: false, properties: ConnackProperties(
        receiveMaximum: 20,
        maximumPacketSize: 2000000,
        topicAliasMaximum: 10,
        )
    )
    #expect(connack.fixedHeader == FixedHeader(type: .CONNACK, flags: 0, remainingLength: 14))
    #expect(
        connack.varHeader
            == ConnackVariableHeader(sessionPresent: 0, connectReasonCode: .success, connackProperties: ConnackProperties(
                    receiveMaximum: 20,
                    maximumPacketSize: 2000000,
                    topicAliasMaximum: 10,
                )
            )
    )
}

@Test("Decode v5 connack packet") func decodeV5Connack() {
    let rawConnack: Bytes = [0x20, 0x0e, 0x00, 0x00, 0x0b, 0x22, 0x00, 0x0a, 0x27, 0x00, 0x1e, 0x84, 0x80, 0x21, 0x00, 0x14]
    let connack = try! Connack(bytes: rawConnack)
    let varHeader = ConnackVariableHeader(sessionPresent: 0, connectReasonCode: .success, connackProperties: ConnackProperties(
            receiveMaximum: 20,
            maximumPacketSize: 2000000,
            topicAliasMaximum: 10,
        )
    )
    #expect(connack.fixedHeader == FixedHeader(type: .CONNACK, flags: 0, remainingLength: 14))
    #expect(connack.varHeader == varHeader)
}

@Test("Encode v5 connack packet") func encodeV5Connack() {
    let connack = Connack(reasonCode: .success, sessionPresent: false, properties: ConnackProperties(
        receiveMaximum: 20,
        maximumPacketSize: 2000000,
        topicAliasMaximum: 10,
        )
    )
    let rawConnack: Bytes = [0x20, 0x0e, 0x00, 0x00, 0x0b, 0x21, 0x00, 0x14, 0x27, 0x00, 0x1e, 0x84, 0x80, 0x22, 0x00, 0x0a]
    #expect(connack.encode() == rawConnack)
}

// MARK: Disconnect
@Test("Create v5 disconnect packet") func createV5Disconnect() {
    let disconnect = Disconnect(
        reasonCode: .normalDisconnection,
        properties: DisconnectProperties(
            sessionExpiryInterval: 30
        )
    )
    #expect(disconnect.fixedHeader == FixedHeader(type: .DISCONNECT, flags: 0, remainingLength: 7))
    #expect(disconnect.variableHeader == DisconnectVariableHeader(
            disconnectReasonCode: .normalDisconnection, properties: DisconnectProperties(sessionExpiryInterval: 30)
        )
    )
}

@Test("Decode v5 disconnect packet") func decodV5Disconnect() {
    let bytes: Bytes = [0xe0, 0x07, 0x00, 0x05, 0x11, 0x00, 0x00, 0x00, 0x1e]
    let disconnect = try! Disconnect(from: bytes)
    #expect(disconnect.fixedHeader == FixedHeader(type: .DISCONNECT, flags: 0, remainingLength: 7))
    #expect(disconnect.variableHeader == DisconnectVariableHeader(
            disconnectReasonCode: .normalDisconnection, properties: DisconnectProperties(sessionExpiryInterval: 30)
        )
    )
}

@Test("Encode v5 disconnect packet") func encodeV5Disconnect() {
    let bytes: Bytes = [0xe0, 0x07, 0x00, 0x05, 0x11, 0x00, 0x00, 0x00, 0x1e]
    let disconnect = Disconnect(reasonCode: .normalDisconnection, properties: DisconnectProperties(sessionExpiryInterval: 30))
    #expect(disconnect.encode() == bytes)
}

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
