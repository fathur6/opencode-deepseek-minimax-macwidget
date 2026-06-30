import XCTest

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (data: Data?, error: Error?, statusCode: Int)] = [:]
    nonisolated(unsafe) static var defaultData: Data?
    nonisolated(unsafe) static var defaultError: Error?
    nonisolated(unsafe) static var defaultStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let urlStr = request.url?.absoluteString ?? ""
        let response: (data: Data?, error: Error?, statusCode: Int)
        if let match = Self.responses[urlStr] {
            response = match
        } else {
            response = (Self.defaultData, Self.defaultError, Self.defaultStatusCode)
        }

        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let httpResponse = HTTPURLResponse(url: request.url!, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        if let data = response.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
