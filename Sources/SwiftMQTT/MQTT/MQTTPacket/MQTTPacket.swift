enum MQTTPacket: Equatable {
    case connack(Connack)
    case connect(Connect)
    case disconnect(Disconnect)
    case pingreq(Pingreq)
    case pingresp(Pingresp)
    case puback(Puback)
    case pubcomp(Pubcomp)
    case publish(Publish)
    case pubrec(Pubrec)
    case pubrel(Pubrel)
    case suback(Suback)
    case subscribe(Subscribe)
    case unsuback(Unsuback)
    case unsubscribe(Unsubscribe)

    func inner() -> any MQTTControlPacket {
        switch self {
            case .connack(let connack):
                return connack
            case .connect(let connect):
                return connect
            case .disconnect(let disconnect):
                return disconnect
            case .pingreq(let pingreq):
                return pingreq
            case .pingresp(let pingresp):
                return pingresp
            case .puback(let puback):
                return puback
            case .pubcomp(let pubcomp):
                return pubcomp
            case .publish(let publish):
                return publish
            case .pubrec(let pubrec):
                return pubrec
            case .pubrel(let pubrel):
                return pubrel
            case .suback(let suback):
                return suback
            case .subscribe(let subscribe):
                return subscribe
            case .unsuback(let unsuback):
                return unsuback
            case .unsubscribe(let unsubscribe):
                return unsubscribe
        }
    }
}
