enum MQTTEvent {
    case received(MQTTPacket)
    case errorr(MQTTError)
}
