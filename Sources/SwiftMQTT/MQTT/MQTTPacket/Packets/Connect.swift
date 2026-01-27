import Foundation

struct ConnConnectFlags: Equatable {
    let username: Bool
    let password: Bool
    let willRetain: Bool
    let qos: QoS
    let willFlag: Bool
    let cleanSession: Bool

    init(
        auth: Auth? = nil,
        cleanSession: Bool = true,
        lwt: LWT? = nil
    ) {
        self.cleanSession = cleanSession
        if let lwt = lwt {
            self.willFlag = true
            self.willRetain = lwt.retain
            self.qos = lwt.qos
        } else {
            self.willFlag = false
            self.willRetain = false
            self.qos = .AtMostOnce
        }
        if let auth = auth {
            self.username = true
            self.password = auth.password != nil ? true : false
        } else {
            self.username = false
            self.password = false
        }
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

struct ConnVariableHeader: Equatable {
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

    func encode() -> ByteBuffer {
        var data: ByteBuffer = []

        data.append(contentsOf: encodeUInt16(UInt16(self.protocolName.count)))
        data.append(contentsOf: self.protocolName.utf8)
        data.append(self.protocolLevel)
        data.append(self.connectFlags.encode())
        data.append(contentsOf: encodeUInt16(self.keepAlive))

        return data
    }
}

struct ConnPayload: Equatable {
    var clientId: String
    var willTopic: String?
    var willMessage: Data?
    var username: String?
    var password: Data?

    init(clientId: String, lwt: LWT? = nil, auth: Auth? = nil) {
        self.clientId = clientId
        if let lwt = lwt {
            self.willTopic = lwt.topic
            self.willMessage = lwt.message
        }
        if let auth = auth {
            self.username = auth.username
            self.password = auth.password
        }
    }

    func encode() -> ByteBuffer {
        var data: ByteBuffer = []

        data.append(contentsOf: encodeUInt16(UInt16(self.clientId.count)))
        data.append(contentsOf: self.clientId.utf8)

        if let willTopic = self.willTopic {
            data.append(contentsOf: encodeUInt16(UInt16(willTopic.count)))
            data.append(contentsOf: willTopic.utf8)
        }

        if let willMessage = self.willMessage {
            data.append(contentsOf: encodeUInt16(UInt16(willMessage.count)))
            data.append(contentsOf: willMessage)
        }

        if let username = self.username {
            data.append(contentsOf: encodeUInt16(UInt16(username.count)))
            data.append(contentsOf: username.utf8)
        }

        if let password = self.password {
            data.append(contentsOf: encodeUInt16(UInt16(password.count)))
            data.append(contentsOf: password)
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
        keepAlive: UInt16,
        lwt: LWT? = nil,
        auth: Auth? = nil,
        cleanSession: Bool = true
    ) {
        self.varHeader = ConnVariableHeader(
            protocolName: "MQTT",
            protocolLevel: 4,
            connectFlags: ConnConnectFlags(
                auth: auth,
                cleanSession: cleanSession,
                lwt: lwt
            ),
            keepAlive: 60
        )

        self.payload = ConnPayload(clientId: clientId, lwt: lwt, auth: auth)
        self.fixedHeader = FixedHeader(
            type: .CONNECT,
            flags: 0,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> ByteBuffer {
        var data: ByteBuffer = []
        data.append(contentsOf: self.fixedHeader.encode())
        data.append(contentsOf: self.varHeader.encode())
        data.append(contentsOf: self.payload.encode())
        return data
    }

    func toString() -> String {
        return self.fixedHeader.toString()
    }
}
