//import Dispatch
//import Foundation
//
//let asyncQueue = DispatchQueue(label: "codes.vapor.asynchronousOperationsQueue", attributes: .concurrent)
//
//extension Sequence where Element : FutureType {
//    public typealias Expectation = Element.Expectation
//    public typealias Result = FutureResult<Expectation>
//
//    public func await(for interval: DispatchTimeInterval) throws -> [Expectation] {
//        let time = DispatchTime.now() + interval
//
//        return try self.await(until: time)
//    }
//
//    public func await(until time: DispatchTime) throws -> [Expectation] {
//        return try self.map {
//            try $0.await(until: time)
//        }
//    }
//
//    public func await(until date: Date) throws -> [Expectation] {
//        return try self.map {
//            try $0.await(until: DispatchTime.now() + date.timeIntervalSinceNow)
//        }
//    }
//
//    public func then(_ handler: @escaping ((([Result]) -> ()))) {
//        var all = Array(self)
//        var heap = [Result]()
//
//        guard all.count > 0 else {
//            handler([])
//            return
//        }
//
//        var promise = all.removeFirst()
//
//        while all.count > 0 {
//            let newPromise = all.removeFirst()
//
//            promise.onComplete { result in
//                heap.append(result)
//            }
//
//            promise = newPromise
//        }
//
//        promise.onComplete { result in
//            heap.append(result)
//            handler(heap)
//        }
//    }
//}
//
//extension Sequence where Element : FutureResultType {
//    public func assertSuccess() throws -> [Expectation] {
//        return try self.map {
//            try $0.assertSuccess()
//        }
//    }
//}
//
//extension Sequence where Element : FutureResultType, Element.Expectation == Void {
//    public func assertSuccess() throws {
//        for result in self {
//            try result.assertSuccess()
//        }
//    }
//}
//
//public protocol FutureType {
//    associatedtype Expectation
//
//    func onComplete(_ handler: @escaping ResultHandler)
//    func await(until time: DispatchTime) throws -> Expectation
//}
//
//public protocol FutureResultType {
//    associatedtype Expectation
//
//    func assertSuccess() throws -> Expectation
//}
//
//extension FutureType {
//    public typealias ResultHandler = ((FutureResult<Expectation>) -> ())
//}
//
///// A result, be it an error or successful result
//public indirect enum FutureResult<T> : FutureResultType {
//    public typealias Expectation = T
//
//    case success(T)
//    case error(Swift.Error)
//
//    public func assertSuccess() throws -> T {
//        switch self {
//        case .success(let data):
//            return data
//        case .error(let error):
//            throw error
//        }
//    }
//}
//
//public final class Future<T> : FutureType {
//    public typealias Expectation = T
//
//    var result: Result?
//    var handlers = [ResultHandler]()
//    let start = DispatchTime.now()
//    let lock = NSRecursiveLock()
//
//    public typealias Result = FutureResult<Expectation>
//
//    /// Awaits for a `Result`
//    ///
//    /// The result can be an error or successful data. May not throw.
//    ///
//    /// Usage:
//    ///
//    /// ```swift
//    /// let future = Future<User>
//    ///
//    /// future.then { result in
//    ///     switch {
//    ///     case .success(let user):
//    ///         user.doStuff()
//    ///     case .error(let error):
//    ///         print(error)
//    ///     }
//    /// }
//    /// ```
//    public func onComplete(_ handler: @escaping ResultHandler) {
//        lock.lock()
//        defer { lock.unlock() }
//
//        if let result = result {
//            handler(result)
//        } else {
//            handlers.append(handler)
//        }
//    }
//
//    /// Gets called only when a result has been successfully captured
//    ///
//    /// ```swift
//    /// future.onSuccess { data in
//    ///     process(data)
//    /// }
//    /// ```
//    public func then(_ handler: @escaping ((T) -> ())) {
//        self.onComplete { result in
//            if case .success(let value) = result {
//                handler(value)
//            }
//        }
//    }
//
//    public func await(until time: DispatchTime) throws -> T {
//        let semaphore = DispatchSemaphore(value: 0)
//        var awaitedResult: Result?
//
//        self.onComplete { result in
//            awaitedResult = result
//            semaphore.signal()
//        }
//
//        guard semaphore.wait(timeout: time) == .success else {
//            throw FutureError.timeout(at: time)
//        }
//
//        if let awaitedResult = awaitedResult {
//            return try awaitedResult.assertSuccess()
//        }
//
//        throw FutureError.inconsistency
//    }
//
//    public func await(for interval: DispatchTimeInterval) throws -> T {
//        return try self.await(until: DispatchTime.now() + interval)
//    }
//
//    /// Gets called only when an error occurred due to throwing
//    ///
//    /// ```swift
//    /// future.onError { error in
//    ///     print(error)
//    /// }
//    /// ```
//    public func `catch`(_ handler: @escaping ((Swift.Error) -> ())) {
//        self.onComplete { result in
//            if case .error(let error) = result {
//                handler(error)
//            }
//        }
//    }
//
//    /// Completes the future, calling all awaiting handlers
//    ///
//    /// If the completion throws an error, this will be passed to the handlers
//    public func complete(_ closure: @escaping () throws -> T) throws {
//        lock.lock()
//        defer { lock.unlock() }
//
//        guard result == nil else {
//            throw FutureError.alreadyCompleted
//        }
//
//        self._complete(closure)
//    }
//
//    internal func _complete(_ closure: @escaping () throws -> T) {
//        asyncQueue.async {
//            do {
//                let result = Result.success(try closure())
//
//                self.lock.lock()
//                defer { self.lock.unlock() }
//
//                for handler in self.handlers {
//                    handler(result)
//                }
//
//                self.result = result
//            } catch {
//                self.lock.lock()
//
//                defer { self.lock.unlock() }
//                let error = Result.error(error)
//
//                for handler in self.handlers {
//                    handler(error)
//                }
//
//                self.result = error
//            }
//        }
//    }
//
//    public var isCompleted: Bool {
//        lock.lock()
//        defer { lock.unlock() }
//
//        return self.result != nil
//    }
//
//    public init() {}
//
//    public init(_ closure: @escaping () throws -> T) {
//        self._complete(closure)
//    }
//
//    /// Creates a new future, combining `futures` into a single future that completes once all contained futures complete
//    public convenience init<FT, S>(_ futures: S) where S : Sequence, S.Element == FT, FT : FutureType, FT.Expectation == Void, T == Void {
//        self.init {
//            _ = try futures.await(until: DispatchTime.distantFuture)
//        }
//    }
//
//    /// Creates a new future, combining `futures` into a single future that completes once all contained futures complete
//    public convenience init<FT, S>(_ futures: S) where S : Sequence, S.Element == FT, FT : FutureType, T == [FT.Expectation] {
//        self.init {
//            return try futures.await(until: DispatchTime.distantFuture)
//        }
//    }
//
//    internal init<Base, FT : FutureType>(transform: @escaping ((Base) throws -> (Future<T>)), from: FT) throws where FT.Expectation == Base {
//        func processResult(_ result: Future<Base>.Result) throws {
//            switch result {
//            case .success(let data):
//                let promise = try transform(data)
//                if let result = promise.result {
//                    self._complete {
//                        try result.assertSuccess()
//                    }
//                } else {
//                    promise.onComplete { result in
//                        self._complete { try result.assertSuccess() }
//                    }
//                }
//            case .error(let error):
//                self._complete { throw error }
//            }
//        }
//
//        from.onComplete { result in
//            do {
//                try processResult(result)
//            } catch {
//                self._complete { throw error }
//            }
//        }
//    }
//
//    internal init<Base, FT : FutureType>(transform: @escaping ((Base) throws -> (T)), from: FT) where FT.Expectation == Base {
//        from.onComplete { result in
//            switch result {
//            case .success(let data):
//                self._complete { try transform(data) }
//            case .error(let error):
//                self._complete { throw error }
//            }
//        }
//    }
//}
//
//public enum FutureError : Error {
//    case alreadyCompleted
//    case timeout(at: DispatchTime)
//    case inconsistency
//}
//
//extension FutureType {
//    public func map<B>(_ closure: @escaping ((Expectation) throws -> (B))) -> Future<B> {
//        return Future<B>(transform: closure, from: self)
//    }
//
//    public func replace<B>(_ closure: @escaping ((Expectation) throws -> (Future<B>))) throws -> Future<B> {
//        return try Future<B>(transform: closure, from: self)
//    }
//}

