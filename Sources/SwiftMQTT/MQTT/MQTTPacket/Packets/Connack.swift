enum DecodeConnackError: Error {
    case InvalidPacketType
    case InvalidRemainingLength
    case InvalidFlags
    case InvalidReturnCode
}

enum ConnectReturnCode: UInt8 {
    case ConnectionAccepted = 0
    case UnnacceptableProtocolVersion = 1
    case IdentifierRejected = 2
    case ServerUnavailable = 3
    case BadAuth = 4
    case Unauthorized = 5
    case Reserved
}

struct ConnackVariableHeader: Equatable {
    var sessionPresent: UInt8
    var connectReturnCode: ConnectReturnCode

    init(sessionPresent: UInt8, connectReturnCode: ConnectReturnCode) {
        self.sessionPresent = sessionPresent
        self.connectReturnCode = connectReturnCode
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []

        data.append(self.sessionPresent)
        data.append(self.connectReturnCode.rawValue)

        return data
    }
}

struct MQTTConnackPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: ConnackVariableHeader
    var payload: [UInt8] = []

    init(data: [UInt8]) throws {
        let type: UInt8 = data[0] >> 4
        if (type != 2) {
            throw DecodeConnackError.InvalidPacketType
        }

        if (data[1] != 2) {
            throw DecodeConnackError.InvalidRemainingLength
        }

        self.fixedHeader = FixedHeader(type: .CONNACK, flags: 0, remainingLength: 2)

        if (data[2] != 0 && data[2] != 1) {
            throw DecodeConnackError.InvalidFlags
        }

        guard let connectionReturnCode = ConnectReturnCode(rawValue: data[3]) else {
            throw DecodeConnackError.InvalidReturnCode
        }

        self.varHeader = ConnackVariableHeader(sessionPresent: data[2], connectReturnCode: connectionReturnCode)
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []

        data.append(contentsOf: self.fixedHeader.encode())
        data.append(contentsOf: self.varHeader.encode())
        data.append(contentsOf: self.payload)

        return data
    }
}
