enum MQTTError: Error, Equatable{
    case ConnectError(returnCode: ConnectReturnCode)
    case DecodePacketError(message: String?)
    case Timeout(reason: String)
    case Disconnected
}
