import Foundation

struct StoredCredentials: Codable {
    let accessToken:  String
    let refreshToken: String?
    let expiresAt:    Date?

    func needsRefresh(leeway: TimeInterval = 300) -> Bool {
        guard let exp = expiresAt else { return false }
        return Date().addingTimeInterval(leeway) >= exp
    }
    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }
}

final class TokenStore {
    static let shared = TokenStore()

    private let dir: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/claudebar", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Secure permissions
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: base.path)
        return base
    }()

    private var credFile: URL { dir.appending(path: "credentials.json") }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func load() -> StoredCredentials? {
        guard let data = try? Data(contentsOf: credFile) else { return nil }
        return try? decoder.decode(StoredCredentials.self, from: data)
    }

    func save(_ creds: StoredCredentials) {
        guard let data = try? encoder.encode(creds) else { return }
        try? data.write(to: credFile, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credFile.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: credFile)
    }
}
