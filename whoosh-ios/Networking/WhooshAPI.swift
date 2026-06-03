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

    // News
    /// `sport` nil → Whoosh community feed; `view == "mine"` → the user's keeps;
    /// `sport` set → that sport's swipeable article feed.
    func newsFeed(sport: String? = nil, mine: Bool = false) async throws -> NewsFeed {
        var path = "/api/v1/news/feed"
        if let sport { path += "?sport=\(sport)" }
        else if mine { path += "?view=mine" }
        return try await get(path)
    }
    @discardableResult
    func swipe(sport: String, direction: String, article: Article) async throws -> Int {
        struct R: Decodable { let points: Int }
        let body = SwipeBody(action: "swipe", sport: sport, direction: direction, guid: nil,
                             article: .init(guid: article.guid, title: article.title,
                                            description: article.description, link: article.link,
                                            author: article.author, image: article.imageUrl,
                                            pubDate: article.pubDate))
        let r: R = try await post("/api/v1/news/swipe", body: body)
        return r.points
    }
    @discardableResult
    func undoSwipe(guid: String) async throws -> Int {
        struct R: Decodable { let points: Int }
        let body = SwipeBody(action: "undo", sport: nil, direction: nil, guid: guid, article: nil)
        let r: R = try await post("/api/v1/news/swipe", body: body)
        return r.points
    }
    /// Live ESPN scores across the major leagues (public; no bearer needed).
    func scores() async throws -> [Game] {
        struct R: Decodable { let games: [Game] }
        let r: R = try await get("/api/v1/news/scores")
        return r.games
    }

    // Chat
    func chatOverview() async throws -> ChatOverview { try await get("/api/v1/chat/overview") }
    func chatMessages(channelId: Int, before: Int? = nil) async throws -> [ChatMessage] {
        struct R: Decodable { let messages: [ChatMessage] }
        var path = "/api/v1/chat/channels/\(channelId)/messages"
        if let before { path += "?before=\(before)" }
        let r: R = try await get(path)
        return r.messages
    }
    @discardableResult
    func sendChatMessage(channelId: Int, body: String?, imageUrl: String? = nil, replyTo: Int? = nil) async throws -> SendChatMessageResult {
        try await post("/api/v1/chat/channels/\(channelId)/messages",
                       body: SendChatMessageBody(body: body, imageUrl: imageUrl, replyTo: replyTo))
    }
    @discardableResult
    func reactChat(messageId: Int, emoji: String, on: Bool) async throws -> Int {
        struct R: Decodable { let count: Int }
        let r: R = try await post("/api/v1/chat/messages/\(messageId)/react", body: ChatReactBody(emoji: emoji, on: on))
        return r.count
    }
    func editChat(messageId: Int, body: String) async throws {
        struct R: Decodable { let ok: Bool }
        let _: R = try await patch("/api/v1/chat/messages/\(messageId)", body: ChatEditBody(body: body))
    }
    func deleteChat(messageId: Int) async throws {
        struct R: Decodable { let ok: Bool }
        let _: R = try await delete("/api/v1/chat/messages/\(messageId)")
    }
    func chatLeaderboard() async throws -> [ChatLeaderboardRow] {
        struct R: Decodable { let rows: [ChatLeaderboardRow] }
        let r: R = try await get("/api/v1/chat/leaderboard"); return r.rows
    }
    func chatStarboard() async throws -> [ChatMessage] {
        struct R: Decodable { let messages: [ChatMessage] }
        let r: R = try await get("/api/v1/chat/starboard"); return r.messages
    }
    func chatUsers(ids: [String]) async throws -> [ChatAuthor] {
        struct R: Decodable { let users: [ChatAuthor] }
        let q = ids.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let r: R = try await get("/api/v1/chat/users?ids=\(q)"); return r.users
    }
    func chatMembers(query: String) async throws -> [ChatMember] {
        struct R: Decodable { let members: [ChatMember] }
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let r: R = try await get("/api/v1/chat/members?q=\(q)"); return r.members
    }
    func chatRoles() async throws -> [ChatRole] {
        struct R: Decodable { let roles: [ChatRole] }
        let r: R = try await get("/api/v1/chat/admin/roles"); return r.roles
    }
    @discardableResult
    func createChatRole(key: String, name: String, color: String, priority: Int) async throws -> ChatRole {
        struct B: Encodable { let key: String; let name: String; let color: String; let priority: Int }
        struct R: Decodable { let role: ChatRole }
        let r: R = try await post("/api/v1/chat/admin/roles", body: B(key: key, name: name, color: color, priority: priority))
        return r.role
    }
    func assignChatRole(userId: String, roleId: Int, on: Bool) async throws {
        struct R: Decodable { let ok: Bool }
        let _: R = try await post("/api/v1/chat/admin/roles/assign", body: ChatRoleAssignBody(userId: userId, roleId: roleId, on: on))
    }
    /// Upload a chat image (multipart) → public URL.
    func uploadChatImage(imageData: Data, fileName: String = "image.jpg", mimeType: String = "image/jpeg") async throws -> URL {
        struct R: Decodable { let url: String }
        var req = await request("POST", "/api/v1/chat/upload")
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        let r: R = try await send(req)
        guard let u = URL(string: r.url) else { throw APIError.unknown }
        return u
    }

    // Fantasy
    func fantasyOverview() async throws -> FantasyOverview { try await get("/api/v1/fantasy/overview") }
    func fantasyRankings() async throws -> CrossLeagueScoreboard { try await get("/api/v1/fantasy/rankings") }
    func fantasyMatchups() async throws -> MatchupsResponse { try await get("/api/v1/fantasy/matchups") }
    func fantasyLeague(_ id: String) async throws -> LeagueDetailResponse {
        try await get("/api/v1/fantasy/leagues/\(id)")
    }
    func fantasyPools() async throws -> [PoolSummary] {
        struct R: Decodable { let pools: [PoolSummary] }
        let r: R = try await get("/api/v1/fantasy/pools")
        return r.pools
    }
    func fantasyPool(_ id: String) async throws -> PoolDetail { try await get("/api/v1/fantasy/pools/\(id)") }
    /// Hosted Stripe Checkout URL for a pool/league group's entry fee (web link-out).
    func fantasyCheckout(groupKey: String) async throws -> URL {
        let r: CheckoutURL = try await post("/api/v1/fantasy/checkout",
                                            body: FantasyCheckoutBody(groupKey: groupKey))
        guard let u = URL(string: r.url) else { throw APIError.unknown }
        return u
    }
    @discardableResult
    func linkSleeper(username: String) async throws -> FantasyLink? {
        struct R: Decodable { let link: FantasyLink? }
        let r: R = try await post("/api/v1/fantasy/link", body: LinkSleeperBody(username: username, action: nil))
        return r.link
    }
    func unlinkSleeper() async throws {
        struct R: Decodable { let link: FantasyLink? }
        let _: R = try await post("/api/v1/fantasy/link", body: LinkSleeperBody(username: nil, action: "unlink"))
    }

    /// Start a Premium subscription — returns a hosted Stripe Checkout URL the
    /// app opens in the browser (web link-out; the Stripe webhook grants premium).
    func subscribe(interval: String) async throws -> URL {
        let r: CheckoutURL = try await post("/api/v1/checkout", body: SubscribeBody(interval: interval))
        guard let u = URL(string: r.url) else { throw APIError.unknown }
        return u
    }
    /// Stripe Billing Portal URL to manage/cancel an existing subscription.
    func manageSubscription() async throws -> URL {
        let r: CheckoutURL = try await postNoBody("/api/v1/portal")
        guard let u = URL(string: r.url) else { throw APIError.unknown }
        return u
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

    private func patch<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        var req = await request("PATCH", path)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        try await send(await request("DELETE", path))
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
