#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/**
    A Swift wrapper around pthread_mutex from
    Swift's Foundation project.
*/
public class Lock {

    let mutex = UnsafeMutablePointer<pthread_mutex_t>(allocatingCapacity: 1)

    public init() {
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deinitialize()
        mutex.deallocateCapacity(1)
    }

    public func lock() {
        pthread_mutex_lock(mutex)
    }

    public func unlock() {
        pthread_mutex_unlock(mutex)
    }

    public func locked(closure: @noescape () throws -> Void) rethrows {
        lock()
        try closure()
        unlock()
    }
}
