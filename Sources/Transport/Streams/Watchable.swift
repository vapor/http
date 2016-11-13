import Foundation
import Dispatch

/**
    Start watching the stream for available data and execute the `handler`
    on the specified queue if data is ready to be received.
*/
public protocol Watchable {
    /**
        Start watching for available data and execute the `handler`
        on the specified queue if data is ready to be received.
    */
    func startWatching(on queue:DispatchQueue, handler:@escaping ()->()) throws
    
    /**
        Stops watching for available data.
    */
    func stopWatching() throws
}
