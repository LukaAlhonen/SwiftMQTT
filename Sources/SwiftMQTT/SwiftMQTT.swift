@main
struct SwiftMQTT {
    static func main() async {
        let host = "127.0.0.1"
        let port: UInt16 = 1883
        // let subscriber = MQTTClient(
        //     qos: .AtMostOnce,
        //     brokerAddress: host,
        //     brokerPort: port,
        //     clientId: "sub-1",
        //     keepAlive: 60,
        //     maxRetries: 5
        // )
        let subscriber = MQTTClient(
            brokerAddress: host,
            brokerPort: port,
            clientId: "sub-1",
            config: .init(keepAlive: 10, connTimeout: 5, maxRetries: 0))


        do {
            try await subscriber.subscribe(to: [.init(topic: "test/topic", qos: .AtMostOnce)])
        } catch {
            fatalError("\(error)")
        }

        do {
            try await subscriber.start()
        } catch {
            fatalError("\(error)")
        }
    }
}
