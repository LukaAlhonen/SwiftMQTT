public enum QoS: UInt8, Sendable {
    case AtMostOnce = 0
    case AtLeastOnce = 1
    case ExactlyOnce = 2
}
