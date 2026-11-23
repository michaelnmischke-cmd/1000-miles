import MessageUI
import SwiftUI
import UIKit

/// Where feedback goes. Change `address` to send feedback somewhere else.
/// When the app gets a backend (stage 3), this is the one place to swap
/// email for a server endpoint.
enum FeedbackConfig {
    static let address = "feedback@example.com" // TODO: set the real support address
}

/// Settings > Send feedback. The user picks a topic and writes a note; tapping
/// Send opens a pre-filled email (Apple Mail sheet, or their default mail app).
struct FeedbackScreen: View {
    enum Topic: String, CaseIterable, Identifiable {
        case idea = "Idea"
        case bug = "Something's broken"
        case love = "Something I love"
        case other = "Other"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var topic: Topic = .idea
    @State private var message = ""
    @State private var includeDeviceInfo = true
    @State private var showingMail = false
    @State private var showNoMailAlert = false
    @State private var mailWasSent = false
    @State private var sentThanks = false

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Topic") {
                Picker("Topic", selection: $topic) {
                    ForEach(Topic.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }

            Section {
                TextField("Tell us what's on your mind…", text: $message, axis: .vertical)
                    .lineLimit(6...12)
            } header: {
                Text("Your feedback")
            }

            Section {
                Toggle("Include app and iOS version", isOn: $includeDeviceInfo)
            } footer: {
                Text("This helps us track down bugs. No Health data is ever sent.")
            }

            Section {
                Button {
                    send()
                } label: {
                    Text("Send feedback")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(trimmed.isEmpty)
                .tint(Theme.trail)
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                Theme.paper
                TopoBackground()
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMail, onDismiss: {
            if mailWasSent { sentThanks = true }
        }) {
            MailComposer(
                recipient: FeedbackConfig.address,
                subject: subject,
                body: fullBody
            ) { result in
                mailWasSent = (result == .sent)
                showingMail = false
            }
            .ignoresSafeArea()
        }
        .alert("Thanks for the feedback!", isPresented: $sentThanks) {
            Button("Done") { dismiss() }
        }
        .alert("No mail app set up", isPresented: $showNoMailAlert) {
            Button("Copy feedback") {
                UIPasteboard.general.string = "To: \(FeedbackConfig.address)\n\n\(fullBody)"
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Copy your feedback and email it to \(FeedbackConfig.address).")
        }
    }

    private var subject: String { "1000 Miles feedback: \(topic.rawValue)" }

    private var fullBody: String {
        guard includeDeviceInfo else { return trimmed }
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        return """
        \(trimmed)

        ---
        App \(version) (\(build)) · \(device.systemName) \(device.systemVersion) · \(device.model)
        """
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() {
            showingMail = true
            return
        }
        // No Apple Mail account: hand off to whatever mail app is the default.
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FeedbackConfig.address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: fullBody),
        ]
        guard let url = components.url else {
            showNoMailAlert = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showNoMailAlert = true }
        }
    }
}

/// Wraps Apple's mail compose sheet for SwiftUI.
private struct MailComposer: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish(result)
        }
    }
}

#Preview {
    NavigationStack { FeedbackScreen() }
}
