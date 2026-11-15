import Foundation
import SwiftSoup

/// Talks to www.vipsite.nl exactly like a browser would, with the member's own session cookie.
/// The password is sent only to vipsite.nl and never stored; the site's "stay logged in" cookie keeps the session.
/// All requests are read-only GETs, except the login itself. Anything that changes data
/// (event sign-up, profile edits) happens on the real website inside `SiteWebView`.
enum VIPError: LocalizedError {
    case notLoggedIn, loginFailed, badResponse(Int), parse(String)
    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "Your session has expired. Log in again."
        case .loginFailed: return "Login failed. Check your student number and password."
        case .badResponse(let c): return "vipsite.nl answered with error \(c). Try again later."
        case .parse(let what): return "Could not read \(what) from vipsite.nl. The website layout may have changed."
        }
    }
}

final class VIPClient: @unchecked Sendable {
    static let shared = VIPClient()
    static let base = URL(string: "https://www.vipsite.nl")!

    let session: URLSession
    let cookies = HTTPCookieStorage.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func url(_ path: String) -> URL {
        if path.hasPrefix("http") { return URL(string: path)! }
        return URL(string: path, relativeTo: Self.base)!.absoluteURL
    }

    /// GET a page and return the parsed document plus the final URL after redirects.
    func page(_ path: String, requireLogin: Bool = false) async throws -> (Document, URL) {
        var req = URLRequest(url: url(path))
        req.setValue("VIP-prototype-iOS/0.1", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VIPError.badResponse(-1) }
        guard (200..<400).contains(http.statusCode) else { throw VIPError.badResponse(http.statusCode) }
        let final = http.url ?? url(path)
        if requireLogin && final.path.hasPrefix("/login") { throw VIPError.notLoggedIn }
        let html = String(decoding: data, as: UTF8.self)
        return (try SwiftSoup.parse(html, final.absoluteString), final)
    }

    // MARK: Session

    func isLoggedIn() async -> Bool {
        guard let (_, final) = try? await page("/my-vip/profile") else { return false }
        return !final.path.hasPrefix("/login")
    }

    func login(username: String, password: String) async throws {
        let (doc, _) = try await page("/login")
        guard let csrf = try doc.select("input[name=csrf_token]").first()?.attr("value") else {
            throw VIPError.parse("the login form")
        }
        var req = URLRequest(url: url("/login"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("VIP-prototype-iOS/0.1", forHTTPHeaderField: "User-Agent")
        req.setValue(url("/login").absoluteString, forHTTPHeaderField: "Referer")
        req.httpBody = Self.formBody([
            "csrf_token": csrf, "username": username, "password": password, "remember_me": "y",
        ])
        let (_, resp) = try await session.data(for: req)
        let final = (resp as? HTTPURLResponse)?.url
        if final?.path.hasPrefix("/login") == true { throw VIPError.loginFailed }
        let ok = await isLoggedIn()
        if !ok { throw VIPError.loginFailed }
    }

    func logout() async {
        _ = try? await page("/logout")
        for c in cookies.cookies(for: Self.base) ?? [] { cookies.deleteCookie(c) }
    }

    static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        return fields.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").data(using: .utf8)!
    }
}
