import Foundation

/// A minimal hand-rolled Supabase Realtime client (Phoenix v1 protocol over a
/// `URLSessionWebSocketTask`) — no SDK. It subscribes to Postgres changes for a
/// single chat channel at a time (matching the open ChannelView) and emits the
/// raw changed rows; the view enriches authors and merges them in.
///
/// Auth: the socket carries the user's access token in the join payload, so the
/// `chat_message`/`chat_reaction` SELECT RLS policies gate exactly which rows we
/// receive. Heartbeats keep it alive; drops trigger an exponential-backoff
/// reconnect that re-joins the current channel.
actor RealtimeClient {
    enum Event {
        case messageInsert(ChatMessageRecord)
        case messageUpdate(ChatMessageRecord)
        case reactionChange(channelId: Int)
    }

    private let socketURL: URL
    private let anonKey: String
    private let token: @Sendable () async -> String?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var channelId: Int?
    private var handler: (@Sendable (Event) -> Void)?
    private var ref = 0
    private var heartbeat: Task<Void, Never>?
    private var running = false
    private var backoff: UInt64 = 1

    init(token: @escaping @Sendable () async -> String?,
         supabaseURL: URL = Config.supabaseURL,
         anonKey: String = Config.supabaseAnonKey) {
        self.token = token
        self.anonKey = anonKey
        var comps = URLComponents(url: supabaseURL.appendingPathComponent("realtime/v1/websocket"),
                                  resolvingAgainstBaseURL: false)!
        comps.scheme = "wss"
        comps.queryItems = [URLQueryItem(name: "apikey", value: anonKey), URLQueryItem(name: "vsn", value: "1.0.0")]
        self.socketURL = comps.url!
    }

    /// Subscribe to a channel's live message/reaction changes. Replaces any
    /// previous subscription.
    func subscribe(channelId: Int, onEvent: @escaping @Sendable (Event) -> Void) async {
        self.channelId = channelId
        self.handler = onEvent
        running = true
        await connect()
    }

    func unsubscribe() {
        running = false
        heartbeat?.cancel(); heartbeat = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        channelId = nil
        handler = nil
    }

    // MARK: Connection

    private func connect() async {
        guard running, let channelId else { return }
        let session = URLSession(configuration: .default)
        self.session = session
        let task = session.webSocketTask(with: socketURL)
        self.task = task
        task.resume()

        let accessToken = await token()
        ref += 1
        let topic = "realtime:chat:\(channelId)"
        let join: [String: Any] = [
            "topic": topic,
            "event": "phx_join",
            "ref": "\(ref)",
            "payload": [
                "access_token": accessToken ?? "",
                "config": [
                    "postgres_changes": [
                        ["event": "INSERT", "schema": "public", "table": "chat_message", "filter": "channel_id=eq.\(channelId)"],
                        ["event": "UPDATE", "schema": "public", "table": "chat_message", "filter": "channel_id=eq.\(channelId)"],
                        ["event": "*", "schema": "public", "table": "chat_reaction", "filter": "channel_id=eq.\(channelId)"],
                    ],
                ],
            ],
        ]
        await send(join)
        startHeartbeat()
        await receiveLoop()
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard let self else { return }
                await self.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() async {
        ref += 1
        await send(["topic": "phoenix", "event": "heartbeat", "payload": [:], "ref": "\(ref)"])
    }

    private func send(_ object: [String: Any]) async {
        guard let task, let data = try? JSONSerialization.data(withJSONObject: object),
              let str = String(data: data, encoding: .utf8) else { return }
        try? await task.send(.string(str))
    }

    private func receiveLoop() async {
        guard let task else { return }
        do {
            while running {
                let message = try await task.receive()
                if case let .string(text) = message { handleIncoming(text) }
                else if case let .data(d) = message, let text = String(data: d, encoding: .utf8) { handleIncoming(text) }
            }
        } catch {
            await reconnect()
        }
    }

    private func reconnect() async {
        guard running else { return }
        heartbeat?.cancel()
        task = nil
        let delay = min(backoff, 16)
        backoff = min(backoff * 2, 16)
        try? await Task.sleep(for: .seconds(Double(delay)))
        if running { await connect() }
    }

    // MARK: Decoding

    private func handleIncoming(_ text: String) {
        backoff = 1
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = obj["event"] as? String else { return }
        guard event == "postgres_changes",
              let payload = obj["payload"] as? [String: Any],
              let change = payload["data"] as? [String: Any],
              let type = change["type"] as? String,
              let table = change["table"] as? String else { return }

        if table == "chat_reaction" {
            let rec = (change["record"] as? [String: Any]) ?? (change["old_record"] as? [String: Any])
            if let cid = rec?["channel_id"] as? Int { emit(.reactionChange(channelId: cid)) }
            return
        }
        guard table == "chat_message", let record = change["record"] as? [String: Any],
              let row = ChatMessageRecord(record) else { return }
        switch type {
        case "INSERT": emit(.messageInsert(row))
        case "UPDATE": emit(.messageUpdate(row))
        default: break
        }
    }

    private func emit(_ event: Event) { handler?(event) }
}

/// A raw `chat_message` row as it arrives over Realtime (snake_case columns).
struct ChatMessageRecord: Sendable {
    let id: Int
    let channelId: Int
    let userId: String
    let body: String
    let imageUrl: String?
    let replyToId: Int?
    let starCount: Int
    let createdAt: String
    let editedAt: String?
    let deletedAt: String?

    init?(_ r: [String: Any]) {
        guard let id = r["id"] as? Int,
              let channelId = r["channel_id"] as? Int,
              let userId = r["user_id"] as? String else { return nil }
        self.id = id
        self.channelId = channelId
        self.userId = userId
        self.body = (r["body"] as? String) ?? ""
        self.imageUrl = r["image_url"] as? String
        self.replyToId = r["reply_to_id"] as? Int
        self.starCount = (r["star_count"] as? Int) ?? 0
        self.createdAt = (r["created_at"] as? String) ?? ""
        self.editedAt = r["edited_at"] as? String
        self.deletedAt = r["deleted_at"] as? String
    }
}
