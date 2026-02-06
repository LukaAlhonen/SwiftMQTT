enum MQTTError: Error, Equatable {
    case connectionError(ConnectionError)
    case protocolViolation(ProtocolError)
    case timeout(TimeoutKind)
    case unexpectedError(String)
}

enum ConnectionError: Error, Equatable {
    case rejected(returnCode: ConnectReturnCode)
    case disconnected
    case ioFailure
}

enum ProtocolError: Error, Equatable {
    case malformedPacket(reason: MalformedPacketReason)
    case unexpectedPacket(packet: MQTTControlPacketType)
    case unknownPacketId(packetId: UInt16)
    case invalidState(expected: String, acutal: String)
}

enum MalformedPacketReason: Error, Equatable {
    case missingPacketId
    case invalidQoS
    case invalidRemainingLenght
    case invalidType(expected: MQTTControlPacketType, actual: UInt8)
    case incorrectType(expected: MQTTControlPacketType, actual: MQTTControlPacketType)
    case invalidFlags(expected: UInt8, actual: UInt8)
    case invalidReturnCode
    case reservedBitModified
}

enum TimeoutKind: Error, Equatable {
    case connect
    case subscribe(packetId: UInt16)
    case unsub(packetId: UInt16)
    case publish(packetId: UInt16, qos: QoS)
    case ping
}
