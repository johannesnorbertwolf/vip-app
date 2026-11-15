import SwiftUI

struct EventsView: View {
    enum Mode: String, CaseIterable { case list = "List", calendar = "Calendar", gallery = "Gallery" }
    @AppStorage("eventsMode") private var mode: Mode = .list
    @EnvironmentObject var state: AppState

    var body: some View {
        Loader(load: Scraper.events) { events in
            Group {
                switch mode {
                case .list:
                    List(events) { e in NavigationLink(value: e) { EventRow(event: e) } }
                        .listStyle(.plain)
                case .calendar:
                    EventCalendarView(events: events)
                case .gallery:
                    EventGalleryView(events: events)
                }
            }
            .overlay { if events.isEmpty { ContentUnavailableView("No upcoming events", systemImage: "calendar") } }
            .safeAreaInset(edge: .top) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.bottom, 6)
                .background(.bar)
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: EventSummary.self) { EventDetailView(path: $0.path, fallbackTitle: $0.title) }
        .toolbar {
            if state.status == .loggedIn {
                ToolbarItem {
                    Button { Task { await subscribe() } } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }
                }
            }
        }
    }

    /// Subscribes the iPhone calendar to the member's personal iCal feed from /events/calendar.
    func subscribe() async {
        if let url = try? await Scraper.calendarFeed() { await UIApplication.shared.open(url) }
    }
}

// MARK: Calendar view: month grid with a dot on days that have events; tap a day to see them.

struct EventCalendarView: View {
    let events: [EventSummary]
    @State private var month: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
    @State private var selected: Date?

    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; return c }   // weeks start on Monday

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                    Spacer()
                    Text(month, format: .dateTime.month(.wide).year()).font(.title3.bold())
                    Spacer()
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
                }
                .padding(.horizontal)

                let symbols = Array(cal.veryShortWeekdaySymbols[(cal.firstWeekday - 1)...] + cal.veryShortWeekdaySymbols[..<(cal.firstWeekday - 1)])
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    ForEach(Array(days().enumerated()), id: \.offset) { _, day in
                        if let day { dayCell(day) } else { Color.clear.frame(height: 40) }
                    }
                }
                .padding(.horizontal, 8)

                let shown = selected.map(eventsOn) ?? eventsIn(month)
                VStack(alignment: .leading, spacing: 0) {
                    Text(selected.map { $0.formatted(.dateTime.weekday(.wide).day().month()) } ?? "This month")
                        .font(.headline).padding(.horizontal).padding(.bottom, 6)
                    if shown.isEmpty {
                        Text("No events").foregroundStyle(.secondary).padding(.horizontal)
                    }
                    ForEach(shown) { e in
                        NavigationLink(value: e) { EventRow(event: e).padding(.horizontal) }
                            .buttonStyle(.plain)
                        Divider().padding(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical)
        }
    }

    func dayCell(_ day: Date) -> some View {
        let has = !eventsOn(day).isEmpty
        let isSel = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isToday = cal.isDateInToday(day)
        return Button { selected = isSel ? nil : day } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.body.monospacedDigit().weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSel ? .white : (isToday ? Color.vip : .primary))
                Circle().fill(has ? (isSel ? .white : Color.vip) : .clear).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSel ? Color.vip : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (has ? ", has events" : ""))
    }

    func days() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    func eventsOn(_ day: Date) -> [EventSummary] { events.filter { $0.date.map { cal.isDate($0, inSameDayAs: day) } ?? false } }
    func eventsIn(_ m: Date) -> [EventSummary] { events.filter { $0.date.map { cal.isDate($0, equalTo: m, toGranularity: .month) } ?? false } }
    func shift(_ n: Int) { month = cal.date(byAdding: .month, value: n, to: month) ?? month; selected = nil }
}

// MARK: Gallery view: event posters in a grid.

struct EventGalleryView: View {
    let events: [EventSummary]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 16) {
                ForEach(events) { e in
                    NavigationLink(value: e) {
                        VStack(alignment: .leading, spacing: 6) {
                            Color.secondary.opacity(0.12)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    AsyncImage(url: e.imageURL) { $0.resizable().scaledToFill() } placeholder: {
                                        Image(systemName: "calendar").font(.largeTitle).foregroundStyle(Color.vip.opacity(0.4))
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    VStack(spacing: 0) {
                                        Text(e.day).font(.headline.monospacedDigit())
                                        Text(e.month.uppercased()).font(.caption2.bold())
                                    }
                                    .foregroundStyle(.white).padding(6)
                                    .background(Color.vip, in: RoundedRectangle(cornerRadius: 8)).padding(8)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(e.title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                            Text(e.category).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct EventRow: View {
    let event: EventSummary
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(event.day).font(.title2.bold()).monospacedDigit()
                Text(event.month.uppercased()).font(.caption2.bold())
            }
            .foregroundStyle(.white)
            .frame(width: 52, height: 56)
            .background(Color.vip, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline)
                Text(event.when).font(.subheadline).foregroundStyle(.secondary)
                if !event.category.isEmpty {
                    Text(event.category).font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.vip.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.vip)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EventDetailView: View {
    let path: String
    let fallbackTitle: String
    @State private var showSignUp = false
    @EnvironmentObject var state: AppState

    var body: some View {
        Loader(load: { try await Scraper.event(path) }) { e in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let img = e.imageURL {
                        AsyncImage(url: img) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.1) }
                            .frame(height: 200).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(e.title).font(.title.bold())

                    if let p = e.participation {
                        Label("You're signed up: \(p)", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(e.facts, id: \.label) { f in
                            HStack(alignment: .top) {
                                Text(f.label).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                                Text(f.value)
                            }.font(.subheadline)
                        }
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                    if e.signUpPath != nil && e.participation == nil {
                        Button { showSignUp = true } label: {
                            Text("Sign up").bold().frame(maxWidth: .infinity).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent)
                    }

                    BlocksView(blocks: e.body)
                }
                .padding()
            }
            .sheet(isPresented: $showSignUp) {
                SiteSheet(title: "Sign up", path: e.signUpPath ?? path)
            }
        }
        .navigationTitle(fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
