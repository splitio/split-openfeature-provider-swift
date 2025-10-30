//  Created for SplitProvider integration testing
//  Real HTTP server using Swifter for mocking Split API

import Foundation
import Swifter

/// A real HTTP server using Swifter for integration testing
class SwifterMockServer {
    
    private let server = HttpServer()
    private var recordedRequests: [HttpRequest] = []
    private let queue = DispatchQueue(label: "com.split.mockserver", attributes: .concurrent)
    
    var port: UInt16 = 0
    
    /// Start the server on an available port
    func start(handler: @escaping (HttpRequest) -> HttpResponse) throws {
        // Clear recorded requests
        recordedRequests.removeAll()
        
        // Set up catch-all route
        server.notFoundHandler = { [weak self] request in
            self?.recordRequest(request)
            return handler(request)
        }
        
        // Try to start on a random available port
        try server.start(0, forceIPv4: true, priority: .default)
        port = UInt16(try server.port())
        print("Mock server started on port \(port)")
    }
    
    /// Stop the server
    func stop() {
        server.stop()
        print("Mock server stopped")
    }
    
    /// Get all recorded requests
    func getRecordedRequests() -> [HttpRequest] {
        queue.sync {
            return recordedRequests
        }
    }
    
    /// Clear recorded requests
    func clearRecordedRequests() {
        queue.async(flags: .barrier) {
            self.recordedRequests.removeAll()
        }
    }
    
    private func recordRequest(_ request: HttpRequest) {
        queue.async(flags: .barrier) {
            self.recordedRequests.append(request)
        }
    }
}

/// Request dispatcher for routing different API endpoints
class SplitAPIDispatcher {
    
    private var splitChangesData: Data?
    
    init(splitChangesData: Data?) {
        self.splitChangesData = splitChangesData
    }
    
    /// Dispatch a request to the appropriate handler
    func dispatch(_ request: HttpRequest) -> HttpResponse {
        let path = request.path
        print("Request: \(request.method) \(path)")
        
        switch path {
        case _ where path.contains("/memberships"):
            return handleMemberships()
        case _ where path.contains("/splitChanges"):
            return handleSplitChanges(request)
        case _ where path.contains("/events"):
            return handleEvents()
        case _ where path.contains("/testImpressions"):
            return handleImpressions()
        case _ where path.contains("/keys/cs"):
            return handleKeys()
        case _ where path.contains("/v2/auth"):
            return handleAuth()
        case _ where path.contains("/metrics"):
            return handleMetrics()
        default:
            print("Unhandled path: \(path)")
            return .ok(.text("{}"))
        }
    }
    
    private func handleMemberships() -> HttpResponse {
        let response = """
        {"ms":{"k":[],"cn":null},"ls":{"k":[],"cn":1702507130121}}
        """
        return .ok(.text(response))
    }
    
    private func handleSplitChanges(_ request: HttpRequest) -> HttpResponse {
        // Extract 'since' query parameter
        let queryParams = request.queryParams
        let since = queryParams.first(where: { $0.0 == "since" })?.1 ?? "-1"
        
        if since == "-1", let data = splitChangesData, let jsonString = String(data: data, encoding: .utf8) {
            // Return initial split changes
            return .ok(.text(jsonString))
        } else {
            // No new changes
            let response = """
            {"ff":{"d":[],"s":10,"t":10},"rbs":{"d":[],"s":10,"t":10}}
            """
            return .ok(.text(response))
        }
    }
    
    private func handleEvents() -> HttpResponse {
        return .ok(.text("{}"))
    }
    
    private func handleImpressions() -> HttpResponse {
        return .ok(.text("{}"))
    }
    
    private func handleKeys() -> HttpResponse {
        return .ok(.text("{}"))
    }
    
    private func handleAuth() -> HttpResponse {
        let response = """
        {"pushEnabled":false}
        """
        return .ok(.text(response))
    }
    
    private func handleMetrics() -> HttpResponse {
        return .ok(.text("{}"))
    }
}
