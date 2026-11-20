import SwiftUI

struct EventsView: View {
    enum Mode: String, CaseIterable { case list = "List", calendar = "Calendar" }
    @AppStorage("eventsMode") private var mode: Mode = .list
    @AppStorage("showPosters") private var showPosters = false
    @EnvironmentObject var state: AppState

    var body: some View {
        Loader(load: Scraper.events) { events in
            Group {
                switch mode {
                case .list:
                    List(events) { e in
                        NavigationLink(value: e) { EventRow(event: e, showPoster: showPosters) }
                    }
                    .listStyle(.plain)
                case .calendar:
                    EventCalendarView(events: events)
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
            if mode == .list {
                ToolbarItem {
                    Toggle(isOn: $showPosters) {
                        Label("Show posters", systemImage: showPosters ? "photo.fill" : "photo")
                    }
                    .toggleStyle(.button)
                }
            }
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

// MARK: Calendar view: a month grid with the event names inside each day. Tap a day for its details.

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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    ForEach(Array(days().enumerated()), id: \.offset) { _, day in
                        if let day { dayCell(day) } else { Color.clear.frame(minHeight: 66) }
                    }
                }
                .padding(.horizontal, 6)

                if let selected {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(selected.formatted(.dateTime.weekday(.wide).day().month()))
                            .font(.headline).padding(.horizontal).padding(.bottom, 6)
                        let shown = eventsOn(selected)
                        if shown.isEmpty {
                            Text("No events").foregroundStyle(.secondary).padding(.horizontal)
                        }
                        ForEach(shown) { e in
                            NavigationLink(value: e) { EventRow(event: e, showPoster: false).padding(.horizontal) }
                                .buttonStyle(.plain)
                            Divider().padding(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical)
        }
    }

    func dayCell(_ day: Date) -> some View {
        let dayEvents = eventsOn(day)
        let isSel = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isToday = cal.isDateInToday(day)
        return Button { selected = isSel ? nil : day } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: day))")
                    .font(.footnote.monospacedDigit().weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSel ? .white : (isToday ? Color.vip : .primary))
                ForEach(Array(dayEvents.prefix(2).enumerated()), id: \.offset) { _, e in
                    Text(e.title)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(isSel ? .white : Color.vip)
                        .padding(.horizontal, 2).padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSel ? Color.white.opacity(0.25) : Color.vip.opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
                }
                if dayEvents.count > 2 {
                    Text("+\(dayEvents.count - 2)").font(.system(size: 8, weight: .bold)).foregroundStyle(isSel ? .white : .secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .top)
            .background(isSel ? Color.vip : .clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (dayEvents.isEmpty ? "" : ", \(dayEvents.count) events"))
    }

    func days() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    func eventsOn(_ day: Date) -> [EventSummary] { events.filter { $0.date.map { cal.isDate($0, inSameDayAs: day) } ?? false } }
    func shift(_ n: Int) { month = cal.date(byAdding: .month, value: n, to: month) ?? month; selected = nil }
}

struct EventRow: View {
    let event: EventSummary
    var showPoster = false

    var body: some View {
        if showPoster {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: event.imageURL) { $0.resizable().scaledToFill() } placeholder: {
                    Color.secondary.opacity(0.12).overlay(Image(systemName: "calendar").foregroundStyle(Color.vip.opacity(0.4)))
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                info
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Text(event.day).font(.title2.bold()).monospacedDigit()
                    Text(event.month.uppercased()).font(.caption2.bold())
                }
                .foregroundStyle(.white)
                .frame(width: 52, height: 56)
                .background(Color.vip, in: RoundedRectangle(cornerRadius: 10))
                info
            }
            .padding(.vertical, 4)
        }
    }

    var info: some View {
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
