![Static Badge](https://img.shields.io/badge/Swift-6.2-orange?logo=swift) ![Static Badge](https://img.shields.io/badge/Platforms-macOS%20%7C%20linux-blue?logo=swift)

# SwiftMQTTAsync

SwiftMQTTAsync, as the name suggests, is an async MQTT client library for swift. The library works on macOS and linux and uses swift-nio under the hood. This package is currenlty in ealry-ish developement and supports both v3.1.1 (release 0.2.0) and v5 (release 1.0.0-beta).
New features are constantly being added and are usually listed under the repo issues.

## Installation

Add this to `package.swift` under `dependencies`

```swift
.package(url: "https://github.com/LukaAlhonen/SwiftMQTTAsync.git", from: "<version>"),
```

## Example usage

### v1.0.0b (MQTTv5 + v3)

Sample v5 subscriber

```swift
let client = MQTTClientV5(
    clientId: "test-sub", host: "localhost", port: 1883, config: Config())

try! await client.connect()

try! await client.subscribe(to: [TopicFilter(topic: "test/topic", qos: .AtMostOnce)])

for await event in client.eventStream {
    switch event {
    case .received(let packet):
        switch packet {
        case .publish(let publish):
            let topic = publish.variableHeader.topicName
            let qos = publish.qos
            let rawPayload = publish.payload.content
            let message = String(bytes: rawPayload, encoding: .utf8)
            print("Received message: \(message ?? "") on topic: \(topic), with qos: \(qos)")
        default:
            print("Received: \(packet.inner().toString())")
        }
    case .send(let packet):
        print("Sent: \(packet.toString())")
    case .error(let error):
        print("Error: \(error)")
    case .info(let message):
        print("Info: \(message)")
    case .warning(let warning):
        print("Warning: \(warning)")
    }
}

await client.stop()
```

Sample v5 publisher

```swift
let client = MQTTClientV5(
    clientId: "test-pub", host: "localhost", port: 1883, config: Config())

try! await client.connect()

try! await client.publish(message: "hello", qos: .AtMostOnce, topic: "test/topic")

await client.stop()
```

### v0.2.0 (MQTTv3 only)

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
