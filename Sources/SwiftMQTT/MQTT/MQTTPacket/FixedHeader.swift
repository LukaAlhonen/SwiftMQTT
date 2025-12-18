struct FixedHeader: Equatable {
    var type: MQTTControlPacketType
    var flags: UInt8
    var remainingLength: UInt

    func encode() -> [UInt8] {
        var data: [UInt8] = []

        data.append((self.type.rawValue << 4) | self.flags)
        data.append(contentsOf: encodeUInt(self.remainingLength))

        return data
    }
}
