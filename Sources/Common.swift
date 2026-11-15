import SwiftUI
import WebKit

/// Loads data with a spinner, an error state with retry, and pull-to-refresh.
struct Loader<T, Content: View>: View {
    let load: () async throws -> T
    @ViewBuilder let content: (T) -> Content
    @State private var value: T?
    @State private var error: String?
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if let value {
                content(value)
            } else if let error {
                ContentUnavailableView {
                    Label("Couldn't load", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: {
                    Button("Try again") { Task { await run() } }.buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { if value == nil { await run() } }
        .refreshable { await run() }
    }

    func run() async {
        do { value = try await load(); error = nil }
        catch VIPError.notLoggedIn { await state.check() }
        catch { self.error = error.localizedDescription }
    }
}

/// Text whose links, web addresses, email addresses and phone numbers can be tapped.
/// vipsite.nl links open inside the app (logged in); everything else opens in Safari, Mail or Phone.
struct LinkedText: View {
    let attributed: AttributedString

    init(_ string: String, links: [String: URL] = [:]) {
        var a = AttributedString(string)
        for (label, url) in links {
            var search = a.startIndex..<a.endIndex
            while let r = a[search].range(of: label) {
                a[r].link = url
                search = r.upperBound..<a.endIndex
            }
        }
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let ns = string as NSString
            for m in detector.matches(in: string, range: NSRange(location: 0, length: ns.length)) {
                guard let r = Range(m.range, in: string),
                      let lower = AttributedString.Index(r.lowerBound, within: a),
                      let upper = AttributedString.Index(r.upperBound, within: a),
                      a[lower..<upper].link == nil else { continue }
                if let u = m.url { a[lower..<upper].link = u }
                else if let phone = m.phoneNumber,
                        let u = URL(string: "tel:" + phone.filter { "+0123456789".contains($0) }) { a[lower..<upper].link = u }
            }
        }
        attributed = a
    }

    var body: some View { Text(attributed).textSelection(.enabled) }
}

/// Renders scraped page content: headings, paragraphs and images.
struct BlocksView: View {
    let blocks: [ContentBlock]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                switch b {
                case .heading(let t): Text(t).font(.headline).padding(.top, 6)
                case .text(let t, let links): LinkedText(t, links: links).font(.body)
                case .image(let u):
                    AsyncImage(url: u) { $0.resizable().scaledToFit() } placeholder: { Color.secondary.opacity(0.1).frame(height: 160) }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContentPageView: View {
    let title: String
    let path: String
    var requireLogin = false
    var body: some View {
        Loader(load: { try await Scraper.contentPage(path, requireLogin: requireLogin) }) { blocks in
            ScrollView { BlocksView(blocks: blocks).padding() }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Logged-in website view

/// Shows a vipsite.nl page with the app's session cookies, for actions the app leaves to the
/// real website: event sign-up and payment, editing your profile, privacy and notification settings.
struct SiteWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let store = web.configuration.websiteDataStore.httpCookieStore
        let cookies = HTTPCookieStorage.shared.cookies(for: VIPClient.base) ?? []
        Task { @MainActor in
            for c in cookies { await store.setCookie(c) }
            web.load(URLRequest(url: url))
        }
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct SiteSheet: View {
    let title: String
    let path: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SiteWebView(url: VIPClient.shared.url(path))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
