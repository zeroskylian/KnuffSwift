import AppKit
import SwiftUI

struct ContentView: View {
    @Binding var document: KnuffDocument
    @StateObject private var deviceBrowser = DeviceBrowser()
    @State private var identities: [APNSIdentity] = []
    @State private var selectedIdentity: APNSIdentity?
    @State private var isChoosingIdentity = false
    @State private var isShowingDevices = false
    @State private var isSending = false
    @State private var alert: AlertContent?

    private var payloadValidation: PayloadValidation {
        guard let data = document.payload.data(using: .utf8) else { return .invalid("The payload is not UTF-8 text.") }
        do {
            let value = try JSONSerialization.jsonObject(with: data)
            guard value is [String: Any] else { return .invalid("The top-level JSON value must be an object.") }
            if data.count > 4096 { return .invalid("The payload is \(data.count) bytes; APNs accepts at most 4096 bytes for regular notifications.") }
            return .valid(bytes: data.count)
        } catch {
            return .invalid(error.localizedDescription)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            identitySection
            Divider()
            payloadSection
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { refreshIdentities() }
        .sheet(isPresented: $isChoosingIdentity) { identityPicker }
        .popover(isPresented: $isShowingDevices) { devicePicker }
        .alert(item: $alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("APNs Certificate", systemImage: "person.badge.key.fill")
                    .font(.headline)
                Spacer()
                Button {
                    refreshIdentities()
                    isChoosingIdentity = true
                } label: {
                    Text(selectedIdentity?.name ?? "Choose Certificate…")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 320, alignment: .center)
                }
                .help("Choose an Apple Push Services identity from your login keychain")
            }

            if let selectedIdentity {
                HStack(spacing: 16) {
                    LabeledContent("Environment") {
                        Picker("Environment", selection: $document.environment) {
                            ForEach(availableEnvironments(for: selectedIdentity), id: \.self) { environment in
                                Text(environment.title).tag(environment)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }
                    Spacer()
                    Button("Export PEM…") { exportIdentity(selectedIdentity) }
                }
            }
        }
        .padding(18)
    }

    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Device Token")
                    .frame(width: 92, alignment: .trailing)
                TextField("64-character hexadecimal token", text: $document.token)
                    .font(.system(.body, design: .monospaced))
                if !deviceBrowser.devices.isEmpty {
                    Button {
                        isShowingDevices = true
                    } label: {
                        Label("Devices", systemImage: "iphone.gen3")
                    }
                }
            }

            HStack(spacing: 10) {
                Text("Topic")
                    .frame(width: 92, alignment: .trailing)
                if let identity = selectedIdentity, !identity.topics.isEmpty {
                    Picker("Topic", selection: $document.topic) {
                        ForEach(identity.topics, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                } else {
                    TextField("App bundle identifier (for example com.example.App)", text: $document.topic)
                }
            }

            HStack(spacing: 10) {
                Text("Collapse ID")
                    .frame(width: 92, alignment: .trailing)
                TextField("Optional", text: $document.collapseID)
                Text("Push Type")
                Picker("Push Type", selection: $document.pushType) {
                    ForEach(APNSPushType.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 145)
                Text("Priority")
                Picker("Priority", selection: $document.priority) {
                    ForEach(APNSPriority.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 145)
            }

            HStack(alignment: .firstTextBaseline) {
                Label("Payload", systemImage: "curlybraces")
                    .font(.headline)
                Spacer()
                switch payloadValidation {
                case .valid(let bytes):
                    Label("Valid JSON · \(bytes) / 4096 bytes", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .invalid(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .lineLimit(1)
                        .foregroundStyle(.red)
                        .help(message)
                }
            }

            JSONEditor(text: $document.payload)
                .frame(minHeight: 280)
                .clipped()

            HStack {
                Button("Format JSON") { formatPayload() }
                    .disabled(!payloadValidation.isValid)
                Spacer()
                Button {
                    sendPush()
                } label: {
                    if isSending {
                        ProgressView().controlSize(.small).frame(width: 70)
                    } else {
                        Label("Send Push", systemImage: "paperplane.fill").frame(width: 90)
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(isSending || selectedIdentity == nil || document.token.isEmpty || !payloadValidation.isValid)
            }
        }
        .padding(18)
    }

    private var identityPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose an APNs Certificate").font(.title2.bold())
            if identities.isEmpty {
                ContentUnavailableView(
                    "No APNs Certificates",
                    systemImage: "person.badge.key",
                    description: Text("Import an Apple Push Services certificate and its private key into Keychain Access, then refresh.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            } else {
                List(identities, selection: Binding(
                    get: { selectedIdentity?.id },
                    set: { id in selectedIdentity = identities.first { $0.id == id } }
                )) { identity in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(identity.name)
                        Text(certificateDescription(identity))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(identity.id)
                }
            }
            HStack {
                Button("Refresh") { refreshIdentities() }
                Spacer()
                Button("Cancel") { isChoosingIdentity = false }
                Button("Choose") {
                    applyIdentityDefaults()
                    isChoosingIdentity = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedIdentity == nil)
            }
        }
        .padding(20)
        .frame(width: 560, height: 360)
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nearby Devices").font(.headline).padding([.top, .horizontal])
            List(deviceBrowser.devices) { device in
                Button {
                    document.token = device.token
                    isShowingDevices = false
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                        Text(device.token).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Copy Token") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(device.token, forType: .string)
                    }
                }
            }
        }
        .frame(width: 430, height: 260)
    }

    private func refreshIdentities() {
        identities = CertificateStore.identities()
        if let id = selectedIdentity?.id { selectedIdentity = identities.first { $0.id == id } }
    }

    private func applyIdentityDefaults() {
        guard let identity = selectedIdentity else { return }
        if let firstTopic = identity.topics.first, document.topic.isEmpty { document.topic = firstTopic }
        switch identity.kind {
        case .development: document.environment = .development
        case .production: document.environment = .production
        case .universal, .invalid: break
        }
    }

    private func availableEnvironments(for identity: APNSIdentity) -> [APNSEnvironment] {
        switch identity.kind {
        case .development: [.development]
        case .production: [.production]
        case .universal, .invalid: APNSEnvironment.allCases
        }
    }

    private func certificateDescription(_ identity: APNSIdentity) -> String {
        let kind: String = switch identity.kind {
        case .development: "Development"
        case .production: "Production"
        case .universal: "Universal"
        case .invalid: "Invalid"
        }
        return identity.topics.isEmpty ? kind : "\(kind) · \(identity.topics.joined(separator: ", "))"
    }

    private func formatPayload() {
        guard let data = document.payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: formatted, encoding: .utf8) else { return }
        document.payload = string
    }

    private func exportIdentity(_ identity: APNSIdentity) {
        Task {
            do { try await CertificateStore.exportPEM(identity) }
            catch { alert = AlertContent(title: "Export Failed", message: error.localizedDescription) }
        }
    }

    private func sendPush() {
        guard let selectedIdentity else { return }
        isSending = true
        let client = APNSClient(identity: selectedIdentity.identity)
        Task {
            defer { isSending = false }
            do {
                let response = try await client.send(
                    payload: document.payload,
                    token: document.token,
                    topic: document.topic,
                    priority: document.priority,
                    collapseID: document.collapseID,
                    pushType: document.pushType,
                    environment: document.environment
                )
                if response.isSuccess {
                    alert = AlertContent(title: "Notification Sent", message: response.apnsID.map { "APNs ID: \($0)" } ?? "APNs accepted the notification.")
                } else {
                    alert = AlertContent(title: "Delivery Failed", message: "HTTP \(response.statusCode): \(response.reason ?? "Unknown APNs error")")
                }
            } catch {
                alert = AlertContent(title: "Delivery Failed", message: error.localizedDescription)
            }
        }
    }
}

private enum PayloadValidation {
    case valid(bytes: Int)
    case invalid(String)
    var isValid: Bool { if case .valid = self { true } else { false } }
}

private struct AlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
