import Foundation

/// Thrown when the API returns `{ ok: false, error }`. Switch on `code`
/// (stable) — e.g. `"conflict"` (handle taken), `"unauthorized"` (re-auth).
struct APIError: Error, Sendable {
    let code: String
    let message: String
    static let unknown = APIError(code: "unknown", message: "Something went wrong.")
}

/// Client for the Whoosh `api/v1` surface. Injects the bearer token + `X-Client:
/// ios` on every request and unwraps the `{ ok, data }` envelope.
actor WhooshAPI {
    private let baseURL: URL
    private let token: @Sendable () async -> String?

    init(baseURL: URL = Config.apiBaseURL, token: @escaping @Sendable () async -> String?) {
        self.baseURL = baseURL
        self.token = token
    }

    func account() async throws -> Account { try await get("/api/v1/account") }
    func home() async throws -> Home { try await get("/api/v1/home") }
    func wallet() async throws -> Dashboard { try await get("/api/v1/wb/wallet") }
    func ticker() async throws -> [TickerQuote] {
        struct R: Decodable { let quotes: [TickerQuote] }
        let r: R = try await get("/api/v1/capital/ticker")
        return r.quotes
    }

    func usernameAvailable(_ handle: String) async throws -> UsernameAvailability {
        let q = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await get("/api/v1/account/username-available?handle=\(q)")
    }

    func setUsername(_ username: String) async throws -> ProfileResult {
        try await post("/api/v1/account/profile", body: SetUsernameBody(username: username))
    }

    // Wallet actions
    func buyWB(amount: Double) async throws -> URL {
        let r: CheckoutURL = try await post("/api/v1/wb/buy", body: BuyWBBody(amount: amount))
        guard let u = URL(string: r.url) else { throw APIError.unknown }
        return u
    }
    func transfer(recipient: String, amount: Double, memo: String?) async throws -> TransferResult {
        try await post("/api/v1/wb/transfer", body: TransferBody(recipient: recipient, amount: amount, memo: memo))
    }
    func claimBonus() async throws -> BonusResult { try await postNoBody("/api/v1/wb/bonus") }
    func bonusStatus() async throws -> BonusStatus { try await get("/api/v1/wb/bonus") }
    func activity() async throws -> [LedgerEntry] {
        struct R: Decodable { let entries: [LedgerEntry] }
        let r: R = try await get("/api/v1/wb/activity")
        return r.entries
    }

    // Investing
    func searchSymbols(_ q: String) async throws -> [SearchResult] {
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        struct R: Decodable { let results: [SearchResult] }
        let r: R = try await get("/api/v1/wb/search?q=\(enc)")
        return r.results
    }
    func quote(_ symbol: String) async throws -> Quote {
        let enc = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await get("/api/v1/wb/quote?symbol=\(enc)")
    }
    func symbolDetail(_ symbol: String, range: String) async throws -> SymbolDetail {
        let enc = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await get("/api/v1/wb/symbol?symbol=\(enc)&range=\(range)")
    }
    func orders() async throws -> [Order] {
        struct R: Decodable { let orders: [Order] }
        let r: R = try await get("/api/v1/wb/orders")
        return r.orders
    }
    func placeOrder(symbol: String, side: String, amount: Double?, shares: Double?) async throws -> InvestOrderResult {
        try await post("/api/v1/wb/invest/order",
                       body: InvestOrderBody(symbol: symbol, side: side, amount: amount, shares: shares))
    }
    func watchlist() async throws -> [WatchEntry] {
        struct R: Decodable { let items: [WatchEntry] }
        let r: R = try await get("/api/v1/wb/watchlist")
        return r.items
    }
    func mutateWatchlist(symbol: String, add: Bool) async throws {
        struct R: Decodable { let symbol: String }
        let _: R = try await post("/api/v1/wb/watchlist",
                                  body: WatchlistMutateBody(symbol: symbol, action: add ? "add" : "remove"))
    }

    // House bets / events
    func events() async throws -> [BetEvent] {
        struct R: Decodable { let events: [BetEvent] }
        let r: R = try await get("/api/v1/wb/events")
        return r.events
    }
    func myBets() async throws -> [UserWager] {
        struct R: Decodable { let wagers: [UserWager] }
        let r: R = try await get("/api/v1/wb/bets")
        return r.wagers
    }
    @discardableResult
    func placeWager(eventId: Int, outcomeId: Int, stake: Double) async throws -> Int {
        struct R: Decodable { let wagerId: Int }
        let r: R = try await post("/api/v1/wb/wager",
                                  body: PlaceWagerBody(eventId: eventId, outcomeId: outcomeId, stake: stake))
        return r.wagerId
    }

    func uploadAvatar(imageData: Data, fileName: String = "avatar.jpg",
                      mimeType: String = "image/jpeg") async throws -> AvatarResult {
        var req = await request("POST", "/api/v1/account/avatar")
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        return try await send(req)
    }

    // MARK: Plumbing

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(await request("GET", path))
    }

    private func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        var req = await request("POST", path)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    private func postNoBody<T: Decodable>(_ path: String) async throws -> T {
        try await send(await request("POST", path))
    }

    private func request(_ method: String, _ path: String) async -> URLRequest {
        var req = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        req.httpMethod = method
        req.setValue("ios", forHTTPHeaderField: "X-Client")
        if let t = await token() { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, _) = try await URLSession.shared.data(for: req)
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        if envelope.ok, let value = envelope.data { return value }
        throw envelope.error.map { APIError(code: $0.code, message: $0.message) } ?? .unknown
    }
}

private extension Data {
    mutating func append(_ s: String) { append(Data(s.utf8)) }
}
