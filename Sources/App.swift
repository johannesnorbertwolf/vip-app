import SwiftUI

extension Color {
    /// VIP red, taken from vipsite.nl's --primary.
    static let vip = Color(red: 0xE6 / 255, green: 0x30 / 255, blue: 0x28 / 255)
}

@MainActor
final class AppState: ObservableObject {
    enum Status { case checking, loggedOut, loggedIn }
    @Published var status: Status = .checking
    /// A vipsite.nl page to show in the logged-in web view (set when a link to the site is tapped).
    @Published var sitePage: IdentifiedPath?

    func check() async {
        status = await VIPClient.shared.isLoggedIn() ? .loggedIn : .loggedOut
    }
    func login(_ user: String, _ pass: String) async throws {
        try await VIPClient.shared.login(username: user, password: pass)
        status = .loggedIn
    }
    func logout() async {
        await VIPClient.shared.logout()
        status = .loggedOut
    }
}

@main
struct VIPApp: App {
    @StateObject private var state = AppState()
    @AppStorage("appearance") private var appearance = "system"

    /// nil follows the phone's light/dark setting.
    private var scheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(.vip)
                .preferredColorScheme(scheme)
                .task { await state.check() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        TabView {
            NavigationStack { EventsView() }
                .tabItem { Label("Events", systemImage: "calendar") }
            MembersOnly { NavigationStack { PhotoYearsView() } }
                .tabItem { Label("Photos", systemImage: "photo.on.rectangle") }
            MembersOnly { NavigationStack { AlmanacView() } }
                .tabItem { Label("Members", systemImage: "person.2") }
            MembersOnly { NavigationStack { MeView() } }
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        // Links to vipsite.nl open logged in, inside the app; other links go to Safari/Mail/Phone.
        .environment(\.openURL, OpenURLAction { url in
            if url.host?.hasSuffix("vipsite.nl") == true {
                state.sitePage = IdentifiedPath(path: url.absoluteString)
                return .handled
            }
            return .systemAction
        })
        .sheet(item: $state.sitePage) { SiteSheet(title: "VIP", path: $0.path) }
    }
}

/// Shows the login screen in place of member-only tabs until the member is logged in.
struct MembersOnly<Content: View>: View {
    @EnvironmentObject var state: AppState
    @ViewBuilder var content: Content
    var body: some View {
        switch state.status {
        case .checking: ProgressView("Checking your session…")
        case .loggedOut: LoginView()
        case .loggedIn: content
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var user = ""
    @State private var pass = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showSignUp = false
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIP").font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(Color.vip)
                        Text("Log in with your vipsite.nl account to see photos, members and your profile.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section {
                    TextField("Student number", text: $user)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $pass).textContentType(.password)
                } footer: {
                    Text("Your password goes straight to vipsite.nl and is not stored in the app.")
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button {
                        Task {
                            busy = true; error = nil
                            do { try await state.login(user, pass); pass = "" } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        HStack { Spacer(); if busy { ProgressView() } else { Text("Log in").bold() }; Spacer() }
                    }.disabled(user.isEmpty || pass.isEmpty || busy)
                }
                Section {
                    Button("Forgot your password?") { showReset = true }
                    Button("Not a member yet? Sign up") { showSignUp = true }
                }
            }
            .navigationTitle("Log in")
            .sheet(isPresented: $showSignUp) { SiteSheet(title: "Become a member", path: "/my-vip/sign-up") }
            .sheet(isPresented: $showReset) { SiteSheet(title: "Reset password", path: "/password/forgot") }
        }
    }
}
