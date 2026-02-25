protocol Properties: Equatable, Sendable {
    var properties: [Property?] { get }
    init(from properties: [Property]) throws
    func toString() -> String
    func encode() -> Bytes
    func setProperty(_ field: inout Property?, _ value: Property) throws
}

extension Properties {
    func setProperty(_ field: inout Property?, _ value: Property) throws {
        if field != nil {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .duplicateProperty))
        }
        field = value
    }
}

extension Properties {
    func encode() -> Bytes {
        var pBytes: Bytes = []
        var bytes: Bytes = []
        for property in properties {
            pBytes.append(contentsOf: property?.encode() ?? [])
        }
        bytes.append(contentsOf: encodeUInt(UInt(pBytes.count)))
        bytes.append(contentsOf: pBytes)

        return bytes
    }
}

extension Properties {
    func toString() -> String {
        properties
            .compactMap {$0}
            .map {"\($0)"}
            .joined(separator: ", ")
    }
}
