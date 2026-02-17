enum MQTTError: Error, Equatable {
    case connectionError(ConnectionError)
    case protocolViolation(ProtocolError)
    case timeout(TimeoutKind)
    case unexpectedError(String)
}

enum ConnectionError: Error, Equatable {
    case rejected(reason: ConnectionRejectedReason)
    case disconnected
    case ioFailure
}

enum ConnectionRejectedReason: Error, Equatable {
    case returnCode(ConnectReturnCode)
    case reasonCode(ConnectReasonCode)
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
    case invalidType(expected: MQTTControlPacketType, actual: Byte)
    case incorrectType(expected: MQTTControlPacketType, actual: MQTTControlPacketType)
    case invalidFlags(expected: Byte, actual: Byte)
    case invalidReturnCode
    case reservedBitModified
    case incorrectdProperty(inPacket: MQTTControlPacketType)
    case duplicateProperty
    case malformedVariableByteInteger
    case decodeError(String)
    case invalidPropertyIdentifier
    case malformedUTF8String
}

enum TimeoutKind: Error, Equatable {
    case connect
    case subscribe(packetId: UInt16)
    case unsub(packetId: UInt16)
    case publish(packetId: UInt16, qos: QoS)
    case ping
}
