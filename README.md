![Static Badge](https://img.shields.io/badge/Swift-6.2-orange?logo=swift) ![Static Badge](https://img.shields.io/badge/Platforms-macOS%20%7C%20linux-blue?logo=swift)

# SwiftMQTT

SwiftMQTT is an async, cross-platform MQTT client library that uses swift-nio under the hood. This package is currenlty in ealry-ish developement and currently only supports MQTTv3.1.1.
New features are constantly being added and are usually listed under the repo issues.

## Installation

Add this to `package.swift` under `dependencies`
```swift
.package(url: "https://github.com/LukaAlhonen/SwiftMQTT.git", from: "<version>"),
```

## Basic usage

Sample subscriber
```swift
let client = MQTTClient(host: "localhost", port: 1883, config: Config(keepAlive: 30, maxRetries: 5))
try! await client.connect()
try! await client.subscribe(to: [TopicFilter(topic: "test/topic", qos: .AtMostOnce)

for try await event in await packet.eventStream {
  switch event {
    case .received(let packet):
      print("Received: \(packet.inner().toString())")
    case .send(let packet):
      print("Sent: \(packet.toString())")
    default:
      break
  }
}
```

Sample publisher
```swift
let client = MQTTClient(host: "localhost", port: 1883, config: Config())
try! await clent.connect()
try! await client.publish(message: "hello", qos: .AtMostOnce, topic: "test/topic")
```
