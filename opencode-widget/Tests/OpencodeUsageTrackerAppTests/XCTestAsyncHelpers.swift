func XCTAssertThrowsError<T>(_ expression: @autoclosure () async throws -> T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but got success", file: file, line: line)
    } catch {
        // Expected
    }
}
