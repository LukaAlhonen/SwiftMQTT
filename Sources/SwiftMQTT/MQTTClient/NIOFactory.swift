import NIOCore
import NIOPosix

#if canImport(Network)
    import NIOTransportServices
#endif

func makeBootstrap(group: EventLoopGroup) -> NIOClientTCPBootstrapProtocol {
    #if canImport(Network)
        return NIOTSConnectionBootstrap(group: group)
    #else
        return ClientBootstrap(group: group)
    #endif
}

func makeEventLoop() -> EventLoopGroup {
    #if canImport(Network)
        return NIOTSEventLoopGroup()
    #else
        return MultiThreadedEventLoopGroup(numberOfThreads: 1)
    #endif
}
