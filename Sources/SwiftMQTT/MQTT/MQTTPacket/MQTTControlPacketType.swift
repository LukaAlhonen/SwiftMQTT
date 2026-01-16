enum MQTTControlPacketType: UInt8 {
    case CONNECT = 1
    case CONNACK = 2
    case PUBLISH = 3
    case PUBACK = 4
    case PUBREC = 5
    case PUBREL = 6
    case PUBCOMP = 7
    case SUBSCRIBE = 8
    case SUBACK = 9
    case UNSUBSCRIBE = 10
    case UNSUBACK = 11
    case PINGREQ = 12
    case PINGRESP = 13
    case DISCONNECT = 14

    func toString() -> String {
        switch self {
            case .CONNECT:
                return "CONNECT"
            case .CONNACK:
                return "CONNACK"
            case .PUBLISH:
                return "PUBLISH"
            case .PUBACK:
                return "PUBACK"
            case .PUBREC:
                return "PUBREC"
            case .PUBREL:
                return "PUBREL"
            case .PUBCOMP:
                return "PUBCOMP"
            case .SUBSCRIBE:
                return "SUBSCRIBE"
            case .SUBACK:
                return "SUBACK"
            case .UNSUBSCRIBE:
                return "UNSUBSCRIBE"
            case .UNSUBACK:
                return "UNSUBACK"
            case .PINGREQ:
                return "PINGREQ"
            case .PINGRESP:
                return "PINGRESP"
            case .DISCONNECT:
                return "DISCONNECT"
        }
    }
}
