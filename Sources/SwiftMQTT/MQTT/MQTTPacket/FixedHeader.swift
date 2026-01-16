struct FixedHeader: Equatable {
    var type: MQTTControlPacketType
    var flags: UInt8
    var remainingLength: UInt

    func encode() -> ByteBuffer {
        var data: ByteBuffer = []

        data.append((self.type.rawValue << 4) | self.flags)
        data.append(contentsOf: encodeUInt(self.remainingLength))

        return data
    }

    func toString() -> String {
        return self.type.toString()
    }
}
