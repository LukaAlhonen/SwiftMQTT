struct ConnConnectFlags {
    var username: Bool
    var password: Bool
    var willRetain: Bool
    var qos: QoS
    var willFlag: Bool
    var cleanSession: Bool

    init(
        username: Bool = false,
        password: Bool = false,
        willRetain: Bool = false,
        qos: QoS,
        willFlag: Bool = false,
        cleanSession: Bool = true
    ) {
        self.username = username
        self.password = password
        self.willRetain = willRetain
        self.qos = qos
        self.willFlag = willFlag
        self.cleanSession = cleanSession
    }

    func encode() -> UInt8 {
        var flags: UInt8 = 0

        if self.username {
            flags |= 1 << 7
        }

        if self.password {
            flags |= 1 << 6
        }

        if self.willRetain {
            flags |= 1 << 5
        }

        flags |= (qos.rawValue & 0b11) << 3

        if self.willFlag {
            flags |= 1 << 2
        }

        if self.cleanSession {
            flags |= 1 << 1
        }

        return flags
    }
}

struct ConnVariableHeader {
    var protocolName: String
    var protocolLevel: UInt8
    var connectFlags: ConnConnectFlags
    var keepAlive: UInt16

    init(protocolName: String = "MQTT", protocolLevel: UInt8, connectFlags: ConnConnectFlags, keepAlive: UInt16) {
        self.protocolName = protocolName
        self.protocolLevel = protocolLevel
        self.connectFlags = connectFlags
        self.keepAlive = keepAlive
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []

        data.append(contentsOf: encodeUInt16(UInt16(self.protocolName.count)))
        data.append(contentsOf: self.protocolName.utf8)
        data.append(self.protocolLevel)
        data.append(self.connectFlags.encode())
        data.append(contentsOf: encodeUInt16(self.keepAlive))

        return data
    }
}

struct ConnPayload {
    var clientId: String
    var willTopic: String?
    var willMessage: String?
    var username: String?
    var password: String?

    func encode() -> [UInt8] {
        var data: [UInt8] = []

        data.append(contentsOf: encodeUInt16(UInt16(self.clientId.count)))
        data.append(contentsOf: self.clientId.utf8)

        if let willTopic = self.willTopic {
            data.append(contentsOf: encodeUInt16(UInt16(willTopic.count)))
            data.append(contentsOf: willTopic.utf8)
        }

        if let willMessage = self.willMessage {
            data.append(contentsOf: encodeUInt16(UInt16(willMessage.count)))
            data.append(contentsOf: willMessage.utf8)
        }

        if let username = self.username {
            data.append(contentsOf: encodeUInt16(UInt16(username.count)))
            data.append(contentsOf: username.utf8)
        }

        if let password = self.password {
            data.append(contentsOf: encodeUInt16(UInt16(password.count)))
            data.append(contentsOf: password.utf8)
        }

        return data
    }
}

struct MQTTConnectPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: ConnVariableHeader
    var payload: ConnPayload

    init(
        clientId: String,
        qos: QoS,
        keepAlive: UInt16,
        username: String? = nil,
        password: String? = nil,
        willTopic: String? = nil,
        willMessage: String? = nil,
        willRetain: Bool = false,
        cleanSession: Bool = true
    ) {
        self.varHeader = ConnVariableHeader(
            protocolName: "MQTT",
            protocolLevel: 4,
            connectFlags: ConnConnectFlags(
                username: username != nil ? true : false,
                password: username != nil ? true : false,
                willRetain: willRetain,
                qos: qos,
                willFlag: willTopic != nil && willMessage != nil,
                cleanSession: cleanSession
            ),
            keepAlive: 60
        )

        self.payload = ConnPayload(clientId: clientId, willTopic: willTopic, willMessage: willMessage)
        self.fixedHeader = FixedHeader(
            type: .CONNECT,
            flags: 0,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []
        data.append(contentsOf: self.fixedHeader.encode())
        data.append(contentsOf: self.varHeader.encode())
        data.append(contentsOf: self.payload.encode())
        return data
    }
}
