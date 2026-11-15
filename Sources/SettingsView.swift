import SwiftUI

/// App settings plus your vipsite.nl preferences (almanac privacy, mailings, notifications).
/// Preferences are read from the website; changing them happens on vipsite.nl in the logged-in web view.
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showEdit = false

    var body: some View {
        List {
            if state.status == .loggedIn {
                Loader(load: Scraper.profile) { p in
                    let prefs = p.tabs.first { $0.key == "preferences" }?.fields ?? []
                    ForEach(Array(Dictionary(grouping: prefs, by: \.group).sorted { $0.key < $1.key }), id: \.key) { group, fields in
                        Section(group.isEmpty ? "Preferences" : group) {
                            ForEach(fields) { f in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.label)
                                    Text(f.value).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Section {
                        Button("Change preferences on vipsite.nl") { showEdit = true }
                    } footer: {
                        Text("Who can see you in the Stalking Guide, and which emails and notifications you get.")
                    }
                }
            }

            Section("Calendar") {
                Button {
                    Task { if let url = try? await Scraper.calendarFeed() { await UIApplication.shared.open(url) } }
                } label: { Label("Add my VIP events to my calendar", systemImage: "calendar.badge.plus") }
                .disabled(state.status != .loggedIn)
            }

            Section("Account") {
                if state.status == .loggedIn {
                    Button("Log out", role: .destructive) { Task { await state.logout() } }
                } else {
                    Text("Not logged in. Log in on the Me tab.").foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                Link("Open vipsite.nl", destination: URL(string: "https://www.vipsite.nl")!)
                Text("Unofficial prototype, not made by the VIP board. Data comes live from vipsite.nl with your own login; your password is not stored.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showEdit) { SiteSheet(title: "Preferences", path: "/my-vip/profile/edit") }
    }
}
