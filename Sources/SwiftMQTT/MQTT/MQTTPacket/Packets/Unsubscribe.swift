struct MQTTUnsubscribePacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: ByteBuffer
    var payload: ByteBuffer
    func encode() -> ByteBuffer {
        return [0x00]
    }


    func toString() -> String {
        return ""
    }
}
