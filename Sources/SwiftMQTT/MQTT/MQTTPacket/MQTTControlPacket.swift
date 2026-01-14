protocol MQTTControlPacket {
    var fixedHeader: FixedHeader { get set }
    func encode() -> [UInt8]
    func toString() -> String
}
