import SwiftUI
import VisionKit

struct MoreView: View {
    @EnvironmentObject var state: AppState
    @State private var showSignUp = false

    var body: some View {
        List {
            Section("New at VIP") {
                NavigationLink { FirstYearGuideView() } label: { Label("First-year student guide", systemImage: "graduationcap") }
            }
            Section("Rewards") {
                NavigationLink { LoyaltyView() } label: { Label("Loyalty points", systemImage: "star.circle") }
            }
            Section("Need help?") {
                NavigationLink { ContentPageView(title: "Trust persons", path: "/contact/trustpersons") } label: {
                    Label("Trust persons", systemImage: "hand.raised")
                }
                NavigationLink { ContentPageView(title: "Complaints", path: "/contact/complaints-structure") } label: {
                    Label("Complaints procedure", systemImage: "exclamationmark.bubble")
                }
                NavigationLink { ContentPageView(title: "Contact", path: "/contact/contact-us") } label: {
                    Label("Contact VIP", systemImage: "envelope")
                }
            }
            if state.status == .loggedOut {
                Section { Button("Become a member") { showSignUp = true } }
            }
            Section {
                NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
            }
            Section {
                Text("Unofficial prototype. Data comes live from vipsite.nl using your own login; nothing is stored outside this phone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("More")
        .sheet(isPresented: $showSignUp) { SiteSheet(title: "Become a member", path: "/my-vip/sign-up") }
    }
}

// MARK: Loyalty points: info from the website plus a QR scanner for the board's code at events.

struct LoyaltyView: View {
    @EnvironmentObject var state: AppState
    @State private var showScanner = false
    @State private var scanned: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button { showScanner = true } label: {
                    Label("Scan event QR code", systemImage: "qrcode.viewfinder")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.status != .loggedIn)

                if state.status == .loggedIn {
                    Loader(load: { try await Scraper.contentPage("/my-vip/loyalty-points", requireLogin: true) }) {
                        BlocksView(blocks: $0)
                    }.frame(minHeight: 200)
                } else {
                    Text("Log in on the Me tab to collect points.").foregroundStyle(.secondary)
                }
            }.padding()
        }
        .navigationTitle("Loyalty points")
        .sheet(isPresented: $showScanner) {
            QRScanner { url in showScanner = false; scanned = url }
        }
        .sheet(item: Binding(get: { scanned.map { IdentifiedPath(path: $0.absoluteString) } }, set: { scanned = $0.flatMap { URL(string: $0.path) } })) { item in
            SiteSheet(title: "Check in", path: item.path)
        }
    }
}

struct QRScanner: View {
    let onURL: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerRepresentable(onURL: onURL).ignoresSafeArea()
                } else {
                    ContentUnavailableView("Camera not available", systemImage: "camera",
                                           description: Text("QR scanning needs a real iPhone camera."))
                }
            }
            .navigationTitle("Scan QR code").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct ScannerRepresentable: UIViewControllerRepresentable {
    let onURL: (URL) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onURL: onURL) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onURL: (URL) -> Void
        var done = false
        init(onURL: @escaping (URL) -> Void) { self.onURL = onURL }
        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for case .barcode(let code) in items {
                // Only follow codes that point to vipsite.nl, so a random QR code can't open an arbitrary site.
                if let s = code.payloadStringValue, let url = URL(string: s), url.host?.hasSuffix("vipsite.nl") == true {
                    done = true; scanner.stopScanning(); onURL(url); return
                }
            }
        }
    }
}
