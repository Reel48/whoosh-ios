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

    func usernameAvailable(_ handle: String) async throws -> UsernameAvailability {
        let q = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await get("/api/v1/account/username-available?handle=\(q)")
    }

    func setUsername(_ username: String) async throws -> ProfileResult {
        try await post("/api/v1/account/profile", body: SetUsernameBody(username: username))
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
