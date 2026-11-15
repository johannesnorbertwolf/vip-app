import SwiftUI

// MARK: Me

struct MeView: View {
    @EnvironmentObject var state: AppState
    @State private var editPath: String?

    var body: some View {
        Loader(load: Scraper.profile) { p in
            List {
                Section {
                    NavigationLink { MembershipCardView(profile: p) } label: {
                        MembershipCardView.Mini(profile: p)
                    }
                }
                Section {
                    NavigationLink { MyEventsView() } label: { Label("My events", systemImage: "ticket") }
                    NavigationLink { MyPastView() } label: { Label("My past", systemImage: "clock.arrow.circlepath") }
                    NavigationLink { MyCommitteesView() } label: { Label("My committees", systemImage: "person.3") }
                    NavigationLink { InvoicesView() } label: { Label("Invoices", systemImage: "doc.text") }
                    NavigationLink { MembershipView() } label: { Label("Membership", systemImage: "graduationcap") }
                }
                // Preferences live in Settings now.
                ForEach(p.tabs.filter { $0.key != "preferences" }) { tab in
                    Section(tab.title) {
                        ForEach(tab.fields) { f in
                            LabeledContent(f.label, value: f.value)
                        }
                        if tab.key != "membership" {
                            Button("Change on vipsite.nl") { editPath = "/my-vip/profile/edit" }
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle(p.displayName.isEmpty ? "Me" : p.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
        .sheet(item: Binding(get: { editPath.map(IdentifiedPath.init) }, set: { editPath = $0?.path })) { item in
            SiteSheet(title: "Edit profile", path: item.path)
        }
    }
}

struct IdentifiedPath: Identifiable { var id: String { path }; let path: String }

struct MyEventsView: View {
    var body: some View {
        // Only upcoming events here; past events are under My past.
        Loader(load: { try await Scraper.myEvents().filter { $0.section.lowercased().contains("upcoming") } }) { events in
            List {
                Section("Upcoming") {
                        ForEach(events) { e in
                            NavigationLink { EventDetailView(path: e.path, fallbackTitle: e.title) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.title).font(.headline)
                                    HStack {
                                        Text(e.start).foregroundStyle(.secondary)
                                        Spacer()
                                        StatusPill(status: e.status)
                                    }.font(.subheadline)
                                }
                            }
                        }
                }
            }
            .overlay { if events.isEmpty { ContentUnavailableView("No upcoming events", systemImage: "ticket") } }
        }
        .navigationTitle("My events")
    }
}

struct StatusPill: View {
    let status: String
    var color: Color { status.lowercased().contains("approved") ? .green : status.lowercased().contains("cancel") ? .red : .orange }
    var body: some View {
        Text(status).font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule()).foregroundStyle(color)
    }
}

// MARK: Digital membership card (replaces "show you're logged in on the website" for yearsticker discounts)

struct MembershipCardView: View {
    let profile: Profile

    struct Mini: View {
        let profile: Profile
        var body: some View {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6).fill(Color.vip).frame(width: 44, height: 30)
                    .overlay(Text("VIP").font(.caption.bold()).foregroundStyle(.white))
                VStack(alignment: .leading) {
                    Text("Membership card").font(.headline)
                    Text("Show this for member discounts").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                card
                Text("Partner discounts").font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
                DiscountsList()
            }.padding()
        }
        .navigationTitle("Membership card")
        .navigationBarTitleDisplayMode(.inline)
    }

    var card: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("VIP").font(.system(size: 34, weight: .heavy, design: .rounded))
                    Spacer()
                    Text("Member").font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                Spacer(minLength: 0)
                Text(profile.displayName).font(.title2.bold())
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let s = profile.value("Student number") { Text(s).font(.subheadline.monospaced()) }
                        if let m = profile.value("Member since") { Text("Member since \(m)").font(.caption) }
                    }
                    Spacer()
                    // Live clock so a screenshot can't pass as the real thing.
                    VStack(alignment: .trailing, spacing: 2) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                            .scaleEffect(Calendar.current.component(.second, from: ctx.date) % 2 == 0 ? 1 : 0.6)
                            .animation(.easeInOut, value: ctx.date)
                        Text(ctx.date, format: .dateTime.hour().minute().second()).font(.caption.monospacedDigit())
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 210)
            .background(
                LinearGradient(colors: [.vip, Color.vip.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.vip.opacity(0.3), radius: 12, y: 6)
        }
    }
}

struct DiscountsList: View {
    var body: some View {
        Loader(load: { try await Scraper.contentPage("/my-vip/yearsticker", requireLogin: true) }) { blocks in
            BlocksView(blocks: blocks)
        }
        .frame(minHeight: 120)
    }
}

// MARK: Member page

struct MemberAvatar: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                    .foregroundStyle(Color.vip.opacity(0.35))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct MemberDetailView: View {
    let entry: AlmanacEntry
    var body: some View {
        Loader(load: { try await Scraper.member(entry.id) }) { m in
            List {
                Section {
                    VStack(spacing: 10) {
                        MemberAvatar(url: m.photoURL ?? entry.photoURL, size: 120)
                        Text(m.name.isEmpty ? entry.name : m.name).font(.title2.bold())
                        if m.photoURL == nil && entry.photoURL == nil {
                            Text("No profile photo").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                ForEach(Array(Dictionary(grouping: m.fields, by: \.group).sorted { $0.key < $1.key }), id: \.key) { group, fields in
                    Section(group) {
                        ForEach(fields) { f in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.label).font(.caption).foregroundStyle(.secondary)
                                LinkedText(f.value)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Almanac ("Stalking Guide")

struct AlmanacView: View {
    @State private var term = ""
    @State private var results: [AlmanacEntry] = []
    @State private var searched = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(results) { r in
                NavigationLink { MemberDetailView(entry: r) } label: {
                    HStack(spacing: 12) {
                        MemberAvatar(url: r.photoURL, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.headline)
                            if let first = r.details.first {
                                Text(first).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }.padding(.vertical, 2)
                }
            }
        }
        .overlay {
            if busy { ProgressView() }
            else if results.isEmpty {
                ContentUnavailableView(searched ? "Nobody found" : "Find a member",
                                       systemImage: "person.2",
                                       description: Text(searched
                                           ? "Try a full first or last name."
                                           : "Search by name. Members choose what they share in their privacy settings."))
            }
        }
        .searchable(text: $term, prompt: "Name")
        .onSubmit(of: .search) { Task { await search() } }
        .navigationTitle("Members")
    }

    func search() async {
        let q = term.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        busy = true; error = nil
        do { results = try await Scraper.almanac(q) } catch { self.error = error.localizedDescription; results = [] }
        searched = true; busy = false
    }
}
