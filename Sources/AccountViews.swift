import SwiftUI

// MARK: My past: past events + orders (first version of idea 1 in IDEAS.md)

struct MyPastView: View {
    struct Past { let events: [MyEvent]; let orders: PageTable }

    var body: some View {
        Loader(load: {
            async let events = Scraper.myEvents()
            async let orders = Scraper.accountTable("/my-vip/profile/orders")
            return Past(events: try await events.filter { !$0.section.lowercased().contains("upcoming") },
                        orders: try await orders)
        }) { past in
            List {
                Section("Events you took part in") {
                    if past.events.isEmpty {
                        Text("No past events yet.").foregroundStyle(.secondary)
                    }
                    ForEach(past.events) { e in
                        NavigationLink { EventDetailView(path: e.path, fallbackTitle: e.title) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.title).font(.headline)
                                HStack { Text(e.start).foregroundStyle(.secondary); Spacer(); StatusPill(status: e.status) }
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                Section("Orders") { TableRowsView(table: past.orders, empty: "No orders yet.") }
            }
        }
        .navigationTitle("My past")
    }
}

// MARK: Invoices

struct InvoicesView: View {
    var body: some View {
        Loader(load: { try await Scraper.accountTable("/my-vip/profile/invoices") }) { table in
            List { TableRowsView(table: table, empty: "No invoices.") }
        }
        .navigationTitle("Invoices")
    }
}

// MARK: Committees (groups)

struct MyCommitteesView: View {
    var body: some View {
        Loader(load: { try await Scraper.accountTable("/my-vip/profile/groups") }) { table in
            List {
                TableRowsView(table: table, empty: "You're not in a committee yet.")
                Section {
                    NavigationLink("How to become active") {
                        ContentPageView(title: "Become active", path: "/association/committees-structures/become-active")
                    }
                }
            }
        }
        .navigationTitle("My committees")
    }
}

/// Shows rows from an account table; tapping a row with a link opens it on the website (e.g. an invoice).
struct TableRowsView: View {
    let table: PageTable
    let empty: String
    @State private var open: URL?

    var body: some View {
        if table.rows.isEmpty {
            Text(table.message?.isEmpty == false ? table.message! : empty).foregroundStyle(.secondary)
        }
        ForEach(table.rows) { row in
            Button { open = row.link } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.cells.first ?? "").font(.headline).foregroundStyle(.primary)
                        ForEach(Array(row.cells.dropFirst().enumerated()), id: \.offset) { i, c in
                            if !c.isEmpty {
                                Text(label(i + 1) + c).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    if let b = row.badge { StatusPill(status: b) }
                }
            }
            .disabled(row.link == nil)
        }
        .sheet(item: Binding(get: { open.map { IdentifiedPath(path: $0.absoluteString) } }, set: { open = $0.flatMap { URL(string: $0.path) } })) {
            SiteSheet(title: table.headers.first ?? "Details", path: $0.path)
        }
    }

    func label(_ i: Int) -> String {
        guard i < table.headers.count, !table.headers[i].isEmpty else { return "" }
        return table.headers[i] + ": "
    }
}

// MARK: Membership: end membership / become alumnus

struct MembershipView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Become an alumnus member") {
                    ContentPageView(title: "Alumni", path: "/my-vip/finished-your-studies/alumni")
                }
                NavigationLink("End your membership") {
                    ContentPageView(title: "End membership", path: "/my-vip/finished-your-studies/sign-out")
                }
            } footer: {
                Text("Membership changes go by email to the board.")
            }
            Section {
                Link(destination: URL(string: "mailto:vip.gmw@rug.nl?subject=Membership")!) {
                    Label("Email the board", systemImage: "envelope")
                }
                LabeledContent("Address", value: "vip.gmw@rug.nl").textSelection(.enabled)
            }
        }
        .navigationTitle("Membership")
    }
}

// MARK: First-year student guide

struct FirstYearGuideView: View {
    let pages: [(String, String, String)] = [
        ("What is a study association?", "questionmark.circle", "/first-year-student/what-is-a-study-association"),
        ("Practical information", "book", "/first-year-student/practical-information-study"),
        ("Introduction period", "party.popper", "/first-year-student/introduction-period"),
        ("The VIP board", "person.3", "/first-year-student/vip-board"),
        ("Living in Groningen", "house", "/first-year-student/living-in-groningen"),
    ]
    var body: some View {
        List(pages, id: \.2) { title, icon, path in
            NavigationLink { ContentPageView(title: title, path: path) } label: { Label(title, systemImage: icon) }
        }
        .navigationTitle("First year")
    }
}
