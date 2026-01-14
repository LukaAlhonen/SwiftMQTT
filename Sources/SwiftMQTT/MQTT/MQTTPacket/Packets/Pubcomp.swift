struct MQTTPubcompPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: [UInt8]
    var payload: [UInt8]
    func encode() -> [UInt8] {
        return [0x00]
    }

    func toString() -> String {
        return ""
    }
}
