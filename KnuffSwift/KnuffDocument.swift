import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let knuffDocument = UTType(exportedAs: "com.knuffapp.document", conformingTo: .json)
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
    static var readableContentTypes: [UTType] { [.knuffDocument, .json] }
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
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(self))
    }
}
