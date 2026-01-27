import Foundation
import Dispatch
import Logging

@main
struct SwiftMQTT {
    static func main() async {
        // set loglevel
        // TODO: update client to take logger as input
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }

        let host = "127.0.0.1"
        let port: UInt16 = 1883
        let subscriber = MQTTClient(
            brokerAddress: host,
            brokerPort: port,
            clientId: "sub-1",
            config: .init(keepAlive: 5)
        )

        do {
            try await subscriber.start()
        } catch {
            Log.mqtt.error("Error connecting: \(error)")
        }

        do {
            try await subscriber.subscribe(to:
                [
                    .init(topic: "test/topic0", qos: .AtMostOnce),
                    .init(topic: "test/topic1", qos: .AtLeastOnce),
                    .init(topic: "test/topic2", qos: .ExactlyOnce)
                ]
            )
        } catch {
            Log.mqtt.error("Error subscribing: \(error)")
        }

        do {
            for try await packet in subscriber.packetStream {
                Log.mqtt.info("Got sum: \(packet.toString())")
            }
        } catch {
            Log.mqtt.error("Error: \(error)")
        }
    }
}
