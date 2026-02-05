enum MQTTEvent: Sendable {
    case received(MQTTPacket)
    case error(any Error)
    case warning(String)
    case info(String)
    case send(any MQTTControlPacket)
}

enum MQTTInternalEvent: Sendable {
    case packet(MQTTPacket)
    case send(any MQTTControlPacket)
    case connectionActive
    case connectionInactive
    case connectionError(any Error)
}

enum MQTTInternalCommand: Sendable {
    case send(any MQTTControlPacket)
    case disconnect(Error?)
}
