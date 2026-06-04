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
        case presence(Set<String>)   // user ids currently online in the channel
        case typing(userId: String, username: String, isTyping: Bool)
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
    private var myUserId: String?
    private var topic: String?
    private var present: Set<String> = []

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
        myUserId = accessToken.flatMap(Self.jwtSub)
        present = []
        ref += 1
        let topic = "realtime:chat:\(channelId)"
        self.topic = topic
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
                    "broadcast": ["self": false],
                    "presence": ["key": myUserId ?? ""],
                ],
            ],
        ]
        await send(join)
        // Announce presence so others see us online.
        if let myUserId {
            ref += 1
            await send(["topic": topic, "event": "presence", "ref": "\(ref)",
                        "payload": ["event": "track", "payload": ["user_id": myUserId]]])
        }
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

        // Presence: initial state + incremental joins/leaves.
        if event == "presence_state", let payload = obj["payload"] as? [String: Any] {
            present = Set(payload.keys)
            emit(.presence(present)); return
        }
        if event == "presence_diff", let payload = obj["payload"] as? [String: Any] {
            if let joins = payload["joins"] as? [String: Any] { present.formUnion(joins.keys) }
            if let leaves = payload["leaves"] as? [String: Any] { present.subtract(leaves.keys) }
            emit(.presence(present)); return
        }
        // Typing (broadcast).
        if event == "broadcast", let payload = obj["payload"] as? [String: Any],
           (payload["event"] as? String) == "typing",
           let p = payload["payload"] as? [String: Any],
           let uid = p["user_id"] as? String, uid != myUserId {
            emit(.typing(userId: uid, username: (p["username"] as? String) ?? "Someone",
                         isTyping: (p["typing"] as? Bool) ?? true))
            return
        }

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

    /// Broadcast a typing start/stop to the other members of the open channel.
    func sendTyping(_ isTyping: Bool, username: String) async {
        guard let topic, let myUserId else { return }
        ref += 1
        await send(["topic": topic, "event": "broadcast", "ref": "\(ref)",
                    "payload": ["type": "broadcast", "event": "typing",
                                "payload": ["user_id": myUserId, "username": username, "typing": isTyping]]])
    }

    /// Decode the `sub` (user id) claim from a Supabase access token (JWT).
    private static func jwtSub(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["sub"] as? String
    }
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
    let kind: String?
    let data: JSONValue?

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
        self.kind = r["kind"] as? String
        // `data` arrives as a parsed JSON object/array (or NSNull) over the WAL.
        if let raw = r["data"], !(raw is NSNull) { self.data = JSONValue(any: raw) } else { self.data = nil }
    }
}
