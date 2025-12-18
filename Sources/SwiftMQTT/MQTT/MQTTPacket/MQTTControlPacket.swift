protocol MQTTControlPacket {
    var fixedHeader: FixedHeader { get set }
    var varHeader: [UInt8] { get set }
    var payload: [UInt8] { get set }
    func encode() -> [UInt8]
}
