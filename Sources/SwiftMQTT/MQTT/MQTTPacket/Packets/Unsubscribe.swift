struct Unsubscribe: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: Bytes
    var payload: Bytes
    func encode() -> Bytes {
        return [0x00]
    }


    func toString() -> String {
        return ""
    }
}
