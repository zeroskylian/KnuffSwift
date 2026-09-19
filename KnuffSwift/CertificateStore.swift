import AppKit
import Foundation
import Security

enum APNSCertificateKind: Equatable {
    case development, production, universal, invalid
}

final class APNSIdentity: Identifiable, Hashable {
    let id: String
    let name: String
    let identity: SecIdentity
    let kind: APNSCertificateKind
    let topics: [String]

    init(identity: SecIdentity) {
        self.identity = identity

        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)
        if let certificate {
            name = (SecCertificateCopySubjectSummary(certificate) as String?) ?? "Unnamed certificate"
            id = (SecCertificateCopySerialNumberData(certificate, nil) as Data?)?.base64EncodedString() ?? UUID().uuidString
            let metadata = CertificateStore.metadata(for: certificate)
            kind = metadata.kind
            topics = metadata.topics
        } else {
            name = "Unnamed identity"
            id = UUID().uuidString
            kind = .invalid
            topics = []
        }
    }

    static func == (lhs: APNSIdentity, rhs: APNSIdentity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum CertificateStore {
    private static let developmentOID = "1.2.840.113635.100.6.3.1"
    private static let productionOID = "1.2.840.113635.100.6.3.2"
    private static let universalOID = "1.2.840.113635.100.6.3.6"

    static func identities() -> [APNSIdentity] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnRef: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let identities = result as? [SecIdentity] else { return [] }

        return identities
            .map(APNSIdentity.init)
            .filter { $0.kind != .invalid }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    fileprivate static func metadata(for certificate: SecCertificate) -> (kind: APNSCertificateKind, topics: [String]) {
        let keys = [developmentOID, productionOID, universalOID] as CFArray
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [String: Any] else {
            return (.invalid, [])
        }
        let hasDevelopment = values[developmentOID] != nil
        let hasProduction = values[productionOID] != nil
        let kind: APNSCertificateKind = hasDevelopment && hasProduction ? .universal : (hasDevelopment ? .development : (hasProduction ? .production : .invalid))

        guard let universal = values[universalOID] as? [String: Any],
              let entries = universal[kSecPropertyKeyValue as String] as? [[String: Any]] else {
            return (kind, [])
        }
        let topics = entries.compactMap { entry -> String? in
            guard (entry[kSecPropertyKeyLabel as String] as? String) == "Data" else { return nil }
            return entry[kSecPropertyKeyValue as String] as? String
        }
        return (kind, topics)
    }

    @MainActor
    static func exportPEM(_ selected: APNSIdentity) async throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "cert.pem"
        panel.prompt = "Export"
        guard await panel.begin() == .OK, let destination = panel.url else { return }

        let password = UUID().uuidString
        var parameters = SecItemImportExportKeyParameters()
        parameters.version = UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION)
        parameters.passphrase = Unmanaged.passUnretained(password as CFString)
        var exported: CFData?
        let status = SecItemExport(selected.identity, .formatPKCS12, [], &parameters, &exported)
        guard status == errSecSuccess, let data = exported as Data? else {
            throw CertificateError.exportFailed(status)
        }

        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("p12")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["pkcs12", "-in", temporaryURL.path, "-out", destination.path, "-nodes", "-passin", "pass:\(password)"]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown OpenSSL error"
            throw CertificateError.conversionFailed(details)
        }
    }
}

enum CertificateError: LocalizedError {
    case exportFailed(OSStatus)
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let status): "Could not export the identity (Security error \(status))."
        case .conversionFailed(let details): "Could not convert the identity to PEM. \(details)"
        }
    }
}
