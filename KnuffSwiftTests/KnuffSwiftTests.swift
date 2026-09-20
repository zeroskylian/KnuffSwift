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

    func testReadsLegacyKnuffArchive() throws {
        let fixture = LegacyAPNSItemFixture()
        fixture.token = "0123456789abcdef"
        fixture.payload = #"{"aps":{"alert":"Legacy"}}"#
        fixture.collapseID = "message-42"
        fixture.priority = 5
        fixture.pushType = 2
        fixture.sandbox = true

        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.setClassName("APNSItem", for: LegacyAPNSItemFixture.self)
        archiver.encode(fixture, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()

        let document = try KnuffDocument(data: archiver.encodedData)

        XCTAssertEqual(document.token, fixture.token)
        XCTAssertEqual(document.payload, fixture.payload)
        XCTAssertEqual(document.collapseID, fixture.collapseID)
        XCTAssertEqual(document.priority, .conservePower)
        XCTAssertEqual(document.pushType, .voip)
        XCTAssertEqual(document.environment, .development)
    }
}

@objc(KnuffTestsLegacyAPNSItemFixture)
private final class LegacyAPNSItemFixture: NSObject, NSCoding {
    var token = ""
    var payload = ""
    var collapseID = ""
    var priority = 10
    var pushType = 0
    var sandbox = false

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        token = coder.decodeObject(forKey: "token") as? String ?? ""
        payload = coder.decodeObject(forKey: "payload") as? String ?? ""
        collapseID = coder.decodeObject(forKey: "collapseID") as? String ?? ""
        priority = coder.decodeInteger(forKey: "priority")
        pushType = coder.decodeInteger(forKey: "pushType")
        sandbox = coder.decodeBool(forKey: "sandbox")
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(token, forKey: "token")
        coder.encode(payload, forKey: "payload")
        coder.encode(collapseID, forKey: "collapseID")
        coder.encode(NSNumber(value: priority), forKey: "priority")
        coder.encode(NSNumber(value: pushType), forKey: "pushType")
        coder.encode(NSNumber(value: sandbox), forKey: "sandbox")
    }
}
