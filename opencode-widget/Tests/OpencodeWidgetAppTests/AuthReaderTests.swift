import XCTest
@testable import OpencodeWidgetApp

final class AuthReaderTests: XCTestCase {
    let tempDir = FileManager.default.temporaryDirectory
    var tempAuthPath: String!

    override func setUp() {
        super.setUp()
        tempAuthPath = tempDir.appendingPathComponent("test-auth-\(UUID().uuidString).json").path
    }

    override func tearDown() {
        if let path = tempAuthPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempAuthPath = nil
        super.tearDown()
    }

    func testReadsValidCredentials() throws {
        let json = """
        {
            "deepseek": { "key": "ds-key-123" },
            "minimax": { "key": "mm-key-456" }
        }
        """
        try json.write(toFile: tempAuthPath, atomically: true, encoding: .utf8)

        let creds = AuthReader.readCredentials(authPath: tempAuthPath)

        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.deepseekKey, "ds-key-123")
        XCTAssertEqual(creds?.minimaxKey, "mm-key-456")
    }

    func testReturnsNilWhenFileMissing() {
        let creds = AuthReader.readCredentials(authPath: tempAuthPath)
        XCTAssertNil(creds)
    }

    func testReturnsNilWhenFileIsInvalidJSON() throws {
        try "not-json".write(toFile: tempAuthPath, atomically: true, encoding: .utf8)
        let creds = AuthReader.readCredentials(authPath: tempAuthPath)
        XCTAssertNil(creds)
    }

    func testReturnsNilWhenMissingProviderKeys() throws {
        let json = """
        {
            "deepseek": { "key": "ds-key" }
        }
        """
        try json.write(toFile: tempAuthPath, atomically: true, encoding: .utf8)
        let creds = AuthReader.readCredentials(authPath: tempAuthPath)
        XCTAssertNil(creds)
    }

    func testReturnsNilWhenKeyFieldsMissing() throws {
        let json = """
        {
            "deepseek": { "foo": "bar" },
            "minimax": { "key": "mm-key" }
        }
        """
        try json.write(toFile: tempAuthPath, atomically: true, encoding: .utf8)
        let creds = AuthReader.readCredentials(authPath: tempAuthPath)
        XCTAssertNil(creds)
    }

    func testReturnsNilWhenAuthIsNotADictionary() throws {
        let json = """
        ["just", "an", "array"]
        """
        try json.write(toFile: tempAuthPath, atomically: true, encoding: .utf8)
        let creds = AuthReader.readCredentials(authPath: tempAuthPath)
        XCTAssertNil(creds)
    }
}
