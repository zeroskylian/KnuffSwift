import XCTest
@testable import KnuffSwift

final class KnuffSwiftTests: XCTestCase {
    func testDocumentRoundTrip() throws {
        var document = KnuffDocument()
        document.topic = "com.example.app"
        document.pushType = .background

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(KnuffDocument.self, from: data)

        XCTAssertEqual(decoded.topic, "com.example.app")
        XCTAssertEqual(decoded.pushType, .background)
    }

    func testAllPushTypesHaveHeaderValues() {
        XCTAssertEqual(APNSPushType.allCases.map(\.rawValue), [
            "alert", "background", "voip", "complication", "fileprovider", "mdm", "liveactivity", "location", "pushtotalk"
        ])
    }
}
