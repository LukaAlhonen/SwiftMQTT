// The Swift Programming Language
// https://docs.swift.org/swift-book

import Testing
import Network

func hexDump(_ data: [UInt8]) {
    let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
    print("Hex: \(hex)")
}

@main
struct SwiftMQTT {
    static func main() {
        print("hello pensi")
    }
}
