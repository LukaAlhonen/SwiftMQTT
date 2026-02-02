import Foundation

final actor PacketBuffer<T: Sendable> {
    private var queue: [T?]
    private let size: Int
    private var tail: Int = 0
    private var head: Int = 0
    private var count = 0

    private var conts: [CheckedContinuation<T, Never>] = []

    init(size: Int) {
        if size <= 0 { fatalError("buffer size cannot be less than 1") }

        self.size = size
        self.queue = [T?](repeating: nil, count: size)
    }

    func push(_ packet: T) {
        // if someone is waiting for a packet then give it to them
        if !self.conts.isEmpty {
            let cont = self.conts.removeFirst()
            DispatchQueue.global().async {
                cont.resume(returning: packet)
            }

            return
        }

        queue[self.tail] = packet
        self.tail = (self.tail + 1) % self.size

        if self.count < self.size {
            self.count += 1
        } else {
            self.head = (self.head + 1) % self.size
        }
    }

    func next() async -> T? {
        if self.count > 0 {
            let packet = self.queue[head]
            self.queue[head] = nil
            self.head = (self.head + 1) % self.size

            self.count -= 1

            return packet
        } else {
            return await withCheckedContinuation {
                (cont: CheckedContinuation<T, Never>) in
                self.conts.append(cont)
            }
        }
    }
}
