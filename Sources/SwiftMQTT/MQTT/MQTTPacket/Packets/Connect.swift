struct MQTTConnectPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: [UInt8]
    var payload: [UInt8]

    init(clientId: String) {
        let mqtt: [UInt8] = Array("MQTT".utf8)
        self.varHeader = [0x00, 0x04] // protocol name len
        self.varHeader.append(contentsOf: mqtt) // protocol name
        self.varHeader.append(0x04) // MQTT Version, 4 = 3.1.1
        self.varHeader.append(0x02) // Connect flags, clean session + QoS 0
        self.varHeader.append(contentsOf: [0x00, 0x3c]) // Keepalive 60s
        let encodedClientId: [UInt8] = Array(clientId.utf8)
        self.payload = encodeUInt16(UInt16(encodedClientId.count))
        self.payload.append(contentsOf: encodedClientId)
        self.fixedHeader = FixedHeader(type: .CONNECT, flags: 0, remainingLength: UInt(self.varHeader.count + self.payload.count))
    }

    // decode received packet into ControlPacket
    // init(data: [UInt8]) {}

    func encode() -> [UInt8] {
        var data: [UInt8] = []
        data.append(contentsOf: self.fixedHeader.encode())
        data.append(contentsOf: self.varHeader)
        data.append(contentsOf: self.payload)
        return data
    }
}
