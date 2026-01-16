protocol MQTTControlPacket: Sendable {
    var fixedHeader: FixedHeader { get set }
    func encode() -> ByteBuffer
    func toString() -> String
}
