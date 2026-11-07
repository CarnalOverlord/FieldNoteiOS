import Foundation

final class APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "https://fn.drkflm.co.za/api/v1")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = true, retryAuth: Bool = true) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = KeychainStore.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "The server response was unavailable.") }
        if http.statusCode == 401, authenticated, retryAuth {
            do {
                _ = try await refresh()
            } catch {
                KeychainStore.clear()
                throw APIError(message: "Your session expired. Please sign in again.")
            }
            return try await self.request(path, method: method, body: body, authenticated: true, retryAuth: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? decoder.decode(Problem.self, from: data)
            throw APIError(message: problem?.detail ?? problem?.title ?? "Request failed (\(http.statusCode)).")
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError(message: "The server returned data the app could not read.") }
    }

    func requestVoid(_ path: String, method: String = "POST", body: Data? = nil, retryAuth: Bool = true) async throws {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token = KeychainStore.read() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "The server response was unavailable.") }
        if http.statusCode == 401, retryAuth {
            do { _ = try await refresh() }
            catch { KeychainStore.clear(); throw APIError(message: "Your session expired. Please sign in again.") }
            try await requestVoid(path, method: method, body: body, retryAuth: false)
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? decoder.decode(Problem.self, from: data)
            throw APIError(message: problem?.detail ?? problem?.title ?? "Request failed (\(http.statusCode)).")
        }
    }

    func authenticate(email: String, password: String, register: Bool) async throws -> TokenResponse {
        let payload = Credentials(email: email, password: password)
        let body = try encoder.encode(payload)
        return try await request(register ? "auth/register" : "auth/login", method: "POST", body: body, authenticated: false)
    }

    func dashboard() async throws -> Dashboard { try await request("dashboard") }
    func entries() async throws -> EntryList { try await request("entries?limit=100") }
    func saveEntry(date: String, payload: EntryPayload) async throws -> Entry {
        try await request("entries/by-date/\(date)", method: "PUT", body: payload.encodedWithNulls())
    }
    func generateInsight() async throws -> InsightResult { try await request("insights", method: "POST") }
    func generateEntryInsight(id: String) async throws -> InsightResult { try await request("entries/\(id)/insight", method: "POST") }
    func deleteEntry(id: String) async throws { try await requestVoid("entries/\(id)", method: "DELETE") }
    func uploadPhoto(jpegData: Data, retryAuth: Bool = true) async throws -> PhotoUpload {
        let boundary = "FieldNote-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"progress.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpegData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: makeURL("photos"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = KeychainStore.read() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "The server response was unavailable.") }
        if http.statusCode == 401, retryAuth {
            do { _ = try await refresh() }
            catch { KeychainStore.clear(); throw APIError(message: "Your session expired. Please sign in again.") }
            return try await uploadPhoto(jpegData: jpegData, retryAuth: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? decoder.decode(Problem.self, from: data)
            throw APIError(message: problem?.detail ?? problem?.title ?? "Photo upload failed (\(http.statusCode)).")
        }
        return try decoder.decode(PhotoUpload.self, from: data)
    }

    func photoData(path: String, retryAuth: Bool = true) async throws -> Data {
        let encodedPath = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? String($0) }.joined(separator: "/")
        var request = URLRequest(url: makeURL("photos/\(encodedPath)"))
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        if let token = KeychainStore.read() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "The photo response was unavailable.") }
        if http.statusCode == 401, retryAuth {
            do { _ = try await refresh() }
            catch { KeychainStore.clear(); throw APIError(message: "Your session expired. Please sign in again.") }
            return try await photoData(path: path, retryAuth: false)
        }
        guard (200..<300).contains(http.statusCode) else { throw APIError(message: "This progress photo could not be loaded.") }
        return data
    }
    func updateProfile(_ payload: ProfilePayload) async throws -> Profile {
        let values: [String: Any] = [
            "display_name": payload.display_name as Any? ?? NSNull(),
            "sex": payload.sex,
            "height_cm": payload.height_cm as Any? ?? NSNull(),
            "goal_weight_kg": payload.goal_weight_kg as Any? ?? NSNull()
        ]
        let body = try JSONSerialization.data(withJSONObject: values)
        return try await request("profile", method: "PATCH", body: body)
    }
    func logout() async {
        try? await requestVoid("auth/logout")
        KeychainStore.clear()
    }

    private func refresh() async throws -> String {
        let rotated: TokenResponse = try await request("auth/refresh", method: "POST", authenticated: true, retryAuth: false)
        try KeychainStore.save(rotated.access_token)
        return rotated.access_token
    }

    private func makeURL(_ route: String) -> URL {
        let pieces = route.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path += "/" + String(pieces[0])
        if pieces.count == 2 { components.percentEncodedQuery = String(pieces[1]) }
        return components.url!
    }
}

private struct Credentials: Encodable { let email: String; let password: String }

private extension EntryPayload {
    func encodedWithNulls() throws -> Data {
        let values: [String: Any] = [
            "weight_kg": weight_kg as Any? ?? NSNull(),
            "neck_cm": neck_cm as Any? ?? NSNull(),
            "waist_cm": waist_cm as Any? ?? NSNull(),
            "hip_cm": hip_cm as Any? ?? NSNull(),
            "chest_cm": chest_cm as Any? ?? NSNull(),
            "arm_cm": arm_cm as Any? ?? NSNull(),
            "thigh_cm": thigh_cm as Any? ?? NSNull(),
            "body_fat_pct": body_fat_pct as Any? ?? NSNull(),
            "photo_path": photo_path as Any? ?? NSNull(),
            "notes": notes as Any? ?? NSNull()
        ]
        return try JSONSerialization.data(withJSONObject: values)
    }
}
