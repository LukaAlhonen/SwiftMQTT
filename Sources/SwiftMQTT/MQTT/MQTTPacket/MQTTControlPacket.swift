protocol MQTTControlPacket: Sendable, Equatable {
    var fixedHeader: FixedHeader { get set }
    func encode() -> ByteBuffer
    func toString() -> String
}
