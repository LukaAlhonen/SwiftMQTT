enum MQTTEvent {
    case received(MQTTPacket)
    case error(any Error)
    case warning(String)
}
