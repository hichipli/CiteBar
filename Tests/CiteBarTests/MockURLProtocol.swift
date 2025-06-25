
import Foundation
import XCTest

// A thread-safe container for our mock responses.
// By marking this class as @unchecked Sendable, we are telling the compiler that
// we are taking responsibility for its thread safety, which we do using an NSLock.
private final class MockStorage: @unchecked Sendable {
    static let shared = MockStorage()
    private let lock = NSLock()

    private var _mockResponses = [URL: Result<Data, Error>]()

    private init() {}

    func setResponse(for url: URL, result: Result<Data, Error>) {
        lock.withLock {
            _mockResponses[url] = result
        }
    }

    func response(for url: URL) -> Result<Data, Error>? {
        lock.withLock {
            _mockResponses[url]
        }
    }

    func clearAllMocks() {
        lock.withLock {
            _mockResponses.removeAll()
        }
    }
}


class MockURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return MockStorage.shared.response(for: url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else {
            let error = NSError(domain: "MockURLProtocol", code: 0, userInfo: [NSLocalizedDescriptionKey: "Request URL is nil."])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let mock = MockStorage.shared.response(for: url) else {
            let error = NSError(domain: "MockURLProtocol", code: 1, userInfo: [NSLocalizedDescriptionKey: "No mock response for \(url.absoluteString)"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        switch mock {
        case .success(let data):
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    // Test setup helpers
    static func setMockResponse(for url: URL, result: Result<Data, Error>) {
        MockStorage.shared.setResponse(for: url, result: result)
    }

    static func clearMocks() {
        MockStorage.shared.clearAllMocks()
    }

    static func loadSampleData(from fileName: String, fileExtension: String) -> Data? {
        guard let url = Bundle.module.url(forResource: fileName, withExtension: fileExtension) else {
            fatalError("Failed to locate \(fileName).\(fileExtension) in test bundle resources. Check that it is included in the test target's resources.")
        }
        return try? Data(contentsOf: url)
    }
}

extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
