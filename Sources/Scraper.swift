import Foundation
import SwiftSoup

// MARK: Models

struct EventSummary: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let title: String
    let day: String
    let month: String
    let when: String        // "26 Nov 2026 20:30 - 22:30"
    let category: String
    let teaser: String
    let imageURL: URL?
    let date: Date?         // start date, parsed from `when`; used by the calendar view
}

struct EventDetail {
    let title: String
    let facts: [(label: String, value: String)]
    let participation: String?   // e.g. "approved"
    let signUpPath: String?
    let imageURL: URL?
    let body: [ContentBlock]
}

struct MyEvent: Identifiable, Hashable {
    var id: String { path + section }
    let section: String   // "Upcoming events" / "Past events"
    let path: String
    let title: String
    let start: String
    let status: String
}

struct ProfileField: Identifiable, Hashable { var id: String { group + label }; let group: String; let label: String; let value: String }
struct ProfileTab: Identifiable, Hashable { var id: String { key }; let key: String; let title: String; let fields: [ProfileField] }
struct Profile {
    let displayName: String
    let tabs: [ProfileTab]
    func value(_ label: String) -> String? { tabs.flatMap(\.fields).first { $0.label == label }?.value }
}

struct AlmanacEntry: Identifiable, Hashable { let id: String; let name: String; let details: [String]; let photoURL: URL? }
struct MemberDetail { let name: String; let photoURL: URL?; let fields: [ProfileField] }

struct PhotoFolder: Identifiable, Hashable { var id: String { path }; let title: String; let path: String }
struct Album: Identifiable, Hashable { var id: String { path }; let title: String; let path: String; let date: String; let count: String; let coverURL: URL? }
struct AlbumDetail { let title: String; let date: String; let count: String; let photos: [URL] }

struct TableRow: Identifiable, Hashable { let id = UUID(); let cells: [String]; let link: URL?; let badge: String? }
struct PageTable { let headers: [String]; let rows: [TableRow]; let message: String? }

enum ContentBlock: Hashable {
    /// `links` maps link text in the paragraph to its target, so the text can be tapped.
    case heading(String), text(String, links: [String: URL]), image(URL)
}

// MARK: Parsing

enum Scraper {
    static let client = VIPClient.shared

    static func text(_ e: Element?) -> String { ((try? e?.text()) ?? "")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }

    /// The main content column used on every Congressus page.
    static func mainColumn(_ doc: Document) throws -> Element {
        if let col = try doc.select("section.col-lg-9").first() { return col }
        if let main = try doc.select("main").first() { return main }
        throw VIPError.parse("the page")
    }

    // Events

    static func events() async throws -> [EventSummary] {
        let (doc, _) = try await client.page("/events")
        return try mainColumn(doc).select("article").compactMap { art in
            guard let name = try art.select("a.name").first() else { return nil }
            let meta = text(try art.select("span.meta").first())
            // meta: "26 Nov 2026 20:30 - 22:30 Social" -> category is the last word(s) after the time
            let parts = meta.components(separatedBy: " ")
            let category = parts.last ?? ""
            let when = parts.dropLast().joined(separator: " ")
            let img = try art.select("img").first().flatMap { URL(string: try $0.attr("abs:src")) }
            return EventSummary(
                path: try name.attr("href"), title: text(name),
                day: text(try art.select("a.date .day").first()),
                month: text(try art.select("a.date .month").first()),
                when: when, category: category,
                teaser: text(try art.select("div.details p").first()), imageURL: img,
                date: startDate(when))
        }
    }

    /// Parses the start date out of "26 Nov 2026 20:30 - 22:30" or "22 - 31 Jan 2027".
    static func startDate(_ when: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM yyyy"
        let ns = when as NSString
        if let m = try? NSRegularExpression(pattern: #"(\d{1,2}) ([A-Za-z]{3}) (\d{4})"#)
            .firstMatch(in: when, range: NSRange(location: 0, length: ns.length)) {
            return f.date(from: ns.substring(with: m.range))
        }
        // Multi-day: "22 - 31 Jan 2027" -> first day, month and year from the end.
        if let m = try? NSRegularExpression(pattern: #"^(\d{1,2})\s*-\s*\d{1,2} ([A-Za-z]{3}) (\d{4})"#)
            .firstMatch(in: when, range: NSRange(location: 0, length: ns.length)) {
            let s = [1, 2, 3].map { ns.substring(with: m.range(at: $0)) }.joined(separator: " ")
            return f.date(from: s)
        }
        return nil
    }

    static func event(_ path: String) async throws -> EventDetail {
        let (doc, _) = try await client.page(path)
        let title = text(try doc.select(".breadcrumb .active").first())
        var facts: [(String, String)] = []
        var participation: String?
        for block in try doc.select("nav.subNav .aside-block") {
            let heading = text(try block.select("h4").first())
            let dts = try block.select("dt").array(), dds = try block.select("dd").array()
            for (dt, dd) in zip(dts, dds) {
                if heading.contains("participation") { participation = text(dd) } else { facts.append((text(dt), text(dd))) }
            }
        }
        let signUp = try doc.select("nav.subNav a[href$=/sign-up]").first()?.attr("href")
        let col = try mainColumn(doc)
        let img = try col.select("figure img").first().flatMap { URL(string: try $0.attr("abs:src")) }
        try col.select("h1.page-title, figure").remove()
        return EventDetail(title: title.isEmpty ? "Event" : title, facts: facts, participation: participation,
                           signUpPath: signUp, imageURL: img, body: try blocks(col))
    }

    static func calendarFeed() async throws -> URL? {
        let (doc, _) = try await client.page("/events/calendar", requireLogin: false)
        let link = try doc.select("a[href^=webcal:]").first()?.attr("href")
        return link.flatMap(URL.init(string:))
    }

    // Profile

    static func profile() async throws -> Profile {
        let (doc, _) = try await client.page("/my-vip/profile", requireLogin: true)
        let col = try mainColumn(doc)
        let name = text(try col.select("h2").first())
        var titles: [String: String] = [:]
        for a in try col.select("nav.nav-tabs a") { titles[String(try a.attr("href").dropFirst())] = text(a) }
        let tabs: [ProfileTab] = try col.select(".tab-pane").map { pane in
            var fields: [ProfileField] = []
            for fs in try pane.select("fieldset") {
                let group = text(try fs.select("legend").first())
                for row in try fs.select(".form-group") {
                    let label = text(try row.select("label").first())
                    let value = text(try row.select(".form-control-plaintext").first())
                    if !label.isEmpty { fields.append(.init(group: group, label: label, value: value.isEmpty ? "–" : value)) }
                }
            }
            return ProfileTab(key: pane.id(), title: titles[pane.id()] ?? pane.id(), fields: fields)
        }
        return Profile(displayName: name, tabs: tabs)
    }

    static func myEvents() async throws -> [MyEvent] {
        let (doc, _) = try await client.page("/my-vip/profile/events", requireLogin: true)
        let col = try mainColumn(doc)
        var out: [MyEvent] = []
        var section = "Upcoming events"
        for el in try col.select("h2, h3, h4, table") {
            if el.tagName() != "table" { section = text(el); continue }
            for tr in try el.select("tbody tr") {
                let tds = try tr.select("td").array()
                guard tds.count >= 3, let a = try tds[0].select("a").first() else { continue }
                out.append(.init(section: section, path: try a.attr("href"), title: text(a), start: text(tds[1]), status: text(tds[2])))
            }
        }
        return out
    }

    // Almanac ("Stalking Guide"): results stay in memory only, nothing is cached or stored.

    static func almanac(_ term: String) async throws -> [AlmanacEntry] {
        var comps = URLComponents(string: "/my-vip/stalking-guide")!
        comps.queryItems = [URLQueryItem(name: "term", value: term)]
        let (doc, _) = try await client.page(comps.string!, requireLogin: true)
        return try doc.select("#search_results li.media").compactMap { li in
            guard let a = try li.select("h4.media-heading a").first() else { return nil }
            var details: [String] = []
            for col in try li.select(".row > div") {
                let html = try col.html().replacingOccurrences(of: "<br>", with: "\n")
                let lines = try SwiftSoup.parse(html).text(trimAndNormaliseWhitespace: false)
                    .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                details += lines.filter { !$0.isEmpty && $0 != "-" }
            }
            return AlmanacEntry(id: try a.attr("href"), name: text(a), details: details,
                                photoURL: try photoURL(in: li.select(".media-object").first()))
        }
    }

    /// A member's page in the Stalking Guide. Shows only what that member chose to share.
    static func member(_ path: String) async throws -> MemberDetail {
        let (doc, _) = try await client.page(path, requireLogin: true)
        let col = try mainColumn(doc)
        var fields: [ProfileField] = []
        for fs in try col.select("fieldset") {
            let group = text(try fs.select("legend").first())
            for row in try fs.select(".form-group") {
                let label = text(try row.select("label").first())
                let value = text(try row.select(".form-control-plaintext").first())
                if !label.isEmpty && !value.isEmpty && value != "-" { fields.append(.init(group: group, label: label, value: value)) }
            }
        }
        let name = fields.first { $0.label == "Name" }?.value ?? ""
        return MemberDetail(name: name, photoURL: try photoURL(in: col.select(".profile-picture").first()), fields: fields)
    }

    /// Profile photos appear either as an <img> or as a CSS background image.
    static func photoURL(in el: Element?) throws -> URL? {
        guard let el else { return nil }
        if let img = try el.select("img").first() {
            return URL(string: try img.attr("abs:src"))
        }
        let styles = try ([el] + el.select("[style]").array()).map { try $0.attr("style") }
        for s in styles {
            if let r = s.range(of: #"url\(['"]?([^'")]+)"#, options: .regularExpression) {
                let raw = s[r].replacingOccurrences(of: #"url\(['"]?"#, with: "", options: .regularExpression)
                return URL(string: raw, relativeTo: VIPClient.base)?.absoluteURL
            }
        }
        return nil
    }

    // Photos

    static let photosRoot = "/my-vip/15297-photos"

    static func photoYears() async throws -> [PhotoFolder] {
        let (doc, _) = try await client.page(photosRoot, requireLogin: true)
        return try doc.select("nav.subNav a.nav-link").compactMap { a in
            let href = try a.attr("href")
            guard href.hasPrefix(photosRoot + "/"), href.split(separator: "/").count == 3 else { return nil }
            return PhotoFolder(title: text(a).replacingOccurrences(of: "Foto's", with: "Photos"), path: href)
        }
    }

    /// Opening a year redirects to its latest month; the side menu then lists all months of that year.
    static func photoMonths(year: String) async throws -> [PhotoFolder] {
        let (doc, _) = try await client.page(year, requireLogin: true)
        return try doc.select("nav.subNav a.nav-link").compactMap { a in
            let href = try a.attr("href")
            guard href.hasPrefix(year + "/"), href.split(separator: "/").count == 4 else { return nil }
            return PhotoFolder(title: text(a), path: href)
        }
    }

    static func albums(_ path: String) async throws -> [Album] {
        let (doc, _) = try await client.page(path, requireLogin: true)
        return try mainColumn(doc).select("a.heading-photo").map { a in
            let lis = try a.select(".heading-photo-overlay li").array().map(text)
            return Album(title: text(try a.select("h4").first()), path: try a.attr("href"),
                         date: lis.first ?? "", count: lis.count > 1 ? lis[1] : "",
                         coverURL: try a.select("img").first().flatMap { URL(string: try $0.attr("abs:src") + "?tr=w-600,h-400,fo-auto") })
        }
    }

    static func album(_ path: String) async throws -> AlbumDetail {
        let (doc, _) = try await client.page(path, requireLogin: true)
        let meta = try doc.select("article.gallery > ul li").array().map(text)
        let photos = try doc.select("a.gallery-popup").compactMap { URL(string: try $0.attr("abs:href")) }
        return AlbumDetail(title: text(try doc.select(".breadcrumb .active").first()),
                           date: meta.first ?? "", count: meta.count > 1 ? meta[1] : "", photos: photos)
    }

    // Account tables: orders, invoices, groups. Generic so an unseen layout (e.g. orders, which we
    // have no sample of yet) still shows its columns instead of failing.

    static func accountTable(_ path: String) async throws -> PageTable {
        let (doc, _) = try await client.page(path, requireLogin: true)
        let col = try mainColumn(doc)
        let headers = try col.select("thead th").array().map(text)
        var rows: [TableRow] = try col.select("tbody tr").map { tr in
            let tds = try tr.select("td").array()
            let badge = text(try tr.select(".badge").first())
            var cells = tds.map { td -> String in
                _ = try? td.select(".badge").remove()
                let parts = ((try? td.select("a, span, div").array()) ?? []).map(text).filter { !$0.isEmpty }
                return parts.isEmpty ? text(td) : parts.joined(separator: " · ")
            }
            if cells.last?.isEmpty == true && !badge.isEmpty { cells.removeLast() }
            let link = try tr.select("a[href]").first()?.attr("abs:href")
            return TableRow(cells: cells, link: link.flatMap(URL.init(string:)), badge: badge.isEmpty ? nil : badge)
        }
        // Pages without a table (e.g. groups) list their items as links.
        if rows.isEmpty {
            rows = try col.select("ul li a[href], .media-heading a[href], .list-group a[href]").map { a in
                TableRow(cells: [text(a)], link: URL(string: try a.attr("abs:href")), badge: nil)
            }
        }
        let message = rows.isEmpty ? (try col.select("p, .alert").array().map(text).first { !$0.isEmpty }
                                      ?? (try? col.text()) ?? "") : nil
        return PageTable(headers: headers, rows: rows, message: message)
    }

    // Generic content pages (loyalty points, yearsticker, trust persons, complaints)

    static func contentPage(_ path: String, requireLogin: Bool = false) async throws -> [ContentBlock] {
        let (doc, _) = try await client.page(path, requireLogin: requireLogin)
        let col = try mainColumn(doc)
        try col.select("h1.page-title").remove()
        return try blocks(col)
    }

    static func blocks(_ root: Element) throws -> [ContentBlock] {
        var out: [ContentBlock] = []
        for el in try root.select("h2, h3, h4, h5, p, li, img") {
            switch el.tagName() {
            case "img":
                if let u = URL(string: try el.attr("abs:src")), u.scheme == "https" { out.append(.image(u)) }
            case "h2", "h3", "h4", "h5":
                let t = text(el); if !t.isEmpty { out.append(.heading(t)) }
            default:
                if el.tagName() == "p", try el.parents().first(where: { $0.tagName() == "li" }) != nil { continue }
                let html = try el.html().replacingOccurrences(of: "<br>", with: "\n")
                let t = try SwiftSoup.parse(html).text(trimAndNormaliseWhitespace: false)
                    .replacingOccurrences(of: "\u{00a0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                var links: [String: URL] = [:]
                for a in try el.select("a[href]") {
                    let label = text(a)
                    if !label.isEmpty, let u = URL(string: try a.attr("abs:href")), u.scheme != nil { links[label] = u }
                }
                if !t.isEmpty { out.append(.text(el.tagName() == "li" ? "• " + t : t, links: links)) }
            }
        }
        return out
    }
}
