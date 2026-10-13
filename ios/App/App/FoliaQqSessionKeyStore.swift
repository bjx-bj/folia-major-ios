import Foundation
import Security

// ios/App/App/FoliaQqSessionKeyStore.swift — 兼容侧载签名的设备私有 QQ 会话密钥。
enum FoliaQqSessionKeyStore {
    private static func keyFile() throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true).appendingPathComponent("FoliaQQ", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var file = directory.appendingPathComponent("session-key")
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        if FileManager.default.fileExists(atPath: file.path) { try file.setResourceValues(values) }
        return file
    }
    private static func validSecret(_ data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8), let decoded = Data(base64Encoded: text), decoded.count == 32 else { return nil }
        return text
    }
    private static func generatedSecret() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw failure("Cannot create QQ session key", status) }
        return Data(bytes).base64EncodedString()
    }
    private static func failure(_ message: String, _ status: OSStatus) -> NSError {
        NSError(domain: "FoliaQQ.SessionKey", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "\(message) (OSStatus \(status))"])
    }
    // 保持已经选定的文件密钥，避免重新签名后 Keychain 恢复可用时让已有登录态失效。
    static func secret() throws -> String {
        var file = try keyFile()
        if FileManager.default.fileExists(atPath: file.path) {
            guard let existing = validSecret(try Data(contentsOf: file)) else { throw failure("Invalid stored QQ session key", -1) }
            return existing
        }
        let service = (Bundle.main.bundleIdentifier ?? "top.izuna.foliamajor") + ".qq"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "session-secret"]
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data, let existing = validSecret(data) else { throw failure("Invalid Keychain QQ session key", -1) }
            return existing
        }
        let missingEntitlement: OSStatus = -34018
        guard [errSecItemNotFound, missingEntitlement, errSecNotAvailable].contains(status) else {
            throw failure("Cannot read QQ session key", status)
        }
        let secret = try generatedSecret()
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(secret.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let saved = SecItemAdd(item as CFDictionary, nil)
            if saved == errSecSuccess { return secret }
            guard [missingEntitlement, errSecNotAvailable].contains(saved) else { throw failure("Cannot persist QQ session key", saved) }
        }
        // 仅在 Keychain 不可用时降级；文件不暴露到 JS 存储、分享目录或备份。
        try Data(secret.utf8).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try file.setResourceValues(values)
        return secret
    }
}
