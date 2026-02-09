public protocol MQTTControlPacket: Sendable, Equatable {
    var fixedHeader: FixedHeader { get set }
    func encode() -> Bytes
    func toString() -> String
}
