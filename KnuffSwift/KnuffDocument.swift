import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let knuffDocument = UTType(exportedAs: "com.knuffapp.document", conformingTo: .data)
    static let legacyKnuffDocument = UTType(importedAs: "com.madebybowtie.Knuff-OSX.document", conformingTo: .data)
}

enum APNSPriority: Int, Codable, CaseIterable, Identifiable {
    case conservePower = 5
    case immediately = 10

    var id: Int { rawValue }
    var title: String { self == .immediately ? "Immediately" : "Conserve Power" }
}

enum APNSPushType: String, Codable, CaseIterable, Identifiable {
    case alert, background, voip, complication, fileprovider, mdm, liveactivity, location, pushtotalk

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fileprovider: "File Provider"
        case .liveactivity: "Live Activity"
        case .pushtotalk: "Push to Talk"
        default: rawValue.capitalized
        }
    }
}

enum APNSEnvironment: String, Codable, CaseIterable, Identifiable {
    case development, production
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct KnuffDocument: FileDocument, Codable {
    static var readableContentTypes: [UTType] { [.knuffDocument, .legacyKnuffDocument, .json] }
    static var writableContentTypes: [UTType] { [.knuffDocument] }

    var token = ""
    var topic = ""
    var collapseID = ""
    var payload = """
    {
      "aps": {
        "alert": "Test",
        "sound": "default",
        "badge": 1
      }
    }
    """
    var priority = APNSPriority.immediately
    var pushType = APNSPushType.alert
    var environment = APNSEnvironment.development

    init() {}

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data)
    }

    init(data: Data) throws {
        do {
            self = try JSONDecoder().decode(Self.self, from: data)
        } catch let jsonError {
            guard let legacyDocument = try? Self.decodeLegacyArchive(from: data) else {
                throw jsonError
            }
            self = legacyDocument
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(self))
    }

    private static func decodeLegacyArchive(from data: Data) throws -> Self {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.setClass(LegacyAPNSItem.self, forClassName: "APNSItem")
        defer { unarchiver.finishDecoding() }

        guard let item = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyAPNSItem,
              unarchiver.error == nil else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var document = Self()
        document.token = item.token
        document.collapseID = item.collapseID
        document.payload = item.payload
        document.priority = APNSPriority(rawValue: item.priority) ?? .immediately
        document.pushType = APNSPushType.legacyValue(item.pushType)
        document.environment = item.sandbox ? .development : .production
        return document
    }
}

private extension APNSPushType {
    static func legacyValue(_ rawValue: Int) -> Self {
        let legacyValues: [Self] = [.alert, .background, .voip, .complication, .fileprovider, .mdm]
        return legacyValues.indices.contains(rawValue) ? legacyValues[rawValue] : .alert
    }
}

/// Decodes the keyed fields written by Mantle's old `APNSItem` model without
/// requiring the obsolete Objective-C class or the Mantle framework at runtime.
@objc(KnuffLegacyAPNSItem)
private final class LegacyAPNSItem: NSObject, NSCoding {
    let token: String
    let collapseID: String
    let payload: String
    let priority: Int
    let pushType: Int
    let sandbox: Bool

    required init?(coder: NSCoder) {
        token = coder.decodeObject(of: NSString.self, forKey: "token") as String? ?? ""
        collapseID = coder.decodeObject(of: NSString.self, forKey: "collapseID") as String? ?? ""
        payload = coder.decodeObject(of: NSString.self, forKey: "payload") as String? ?? ""
        priority = coder.decodeObject(of: NSNumber.self, forKey: "priority")?.intValue ?? APNSPriority.immediately.rawValue
        pushType = coder.decodeObject(of: NSNumber.self, forKey: "pushType")?.intValue ?? 0
        sandbox = coder.decodeObject(of: NSNumber.self, forKey: "sandbox")?.boolValue ?? false
        super.init()
    }

    func encode(with coder: NSCoder) {
        // KnuffSwift only reads this compatibility type; it always writes JSON.
    }
}
