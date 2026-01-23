class PacketIdAllocator {
    private var free: UInt16
    private var allocated: Set<UInt16>

    init() {
        self.free = 1
        self.allocated = []
    }

    private func increment() {
        self.free &+= 1
        if (self.free == 0) { self.free = 1 }
    }

    func next() -> UInt16 {
        while self.allocated.contains(self.free) {
            self.increment()
        }

        let id = self.free
        self.allocated.insert(id)

        self.increment()

        return id
    }

    func release(id: UInt16) {
        self.allocated.remove(id)
    }
}
