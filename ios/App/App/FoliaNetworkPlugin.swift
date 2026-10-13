import Foundation
import Capacitor
import Security

// ios/App/App/FoliaNetworkPlugin.swift — QQ 源码运行时的原生网络与设备密钥。
@objc(FoliaNetworkPlugin)
public class FoliaNetworkPlugin: CAPPlugin, CAPBridgedPlugin, URLSessionTaskDelegate {
    public let identifier = "FoliaNetworkPlugin"
    public let jsName = "FoliaNetwork"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "request", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancel", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sessionSecret", returnType: CAPPluginReturnPromise)
    ]
    private let lock = NSLock()
    private var tasks: [String: URLSessionDataTask] = [:]
    private var redirectPolicy: [String: Bool] = [:]
    private func allowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), ["https", "http"].contains(url.scheme ?? "") else { return false }
        return ["qq.com", "tencentmusic.com", "gtimg.cn", "qpic.cn"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
    @objc func request(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let raw = call.getString("url"), let url = URL(string: raw), allowed(url) else {
            call.reject("Invalid QQ endpoint"); return
        }
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = call.getString("method") ?? "GET"
        request.httpShouldHandleCookies = false
        if let headers = call.getObject("headers") {
            for (name, value) in headers { if let value = value as? String { request.setValue(value, forHTTPHeaderField: name) } }
        }
        if let body = call.getString("body") { request.httpBody = Data(base64Encoded: body) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        lock.lock(); redirectPolicy[id] = call.getBool("followRedirects") ?? false; lock.unlock()
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.lock.lock(); self?.tasks.removeValue(forKey: id); self?.redirectPolicy.removeValue(forKey: id); self?.lock.unlock()
            defer { session.finishTasksAndInvalidate() }
            if let error = error { call.reject(error.localizedDescription); return }
            guard let response = response as? HTTPURLResponse else { call.reject("Missing HTTP response"); return }
            var headers: [String: String] = [:]
            for (name, value) in response.allHeaderFields { headers[String(describing: name)] = String(describing: value) }
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url).map { "\($0.name)=\($0.value)" }
            call.resolve(["status": response.statusCode, "headers": headers, "cookies": cookies, "body": (data ?? Data()).base64EncodedString()])
        }
        task.taskDescription = id
        lock.lock(); tasks[id] = task; lock.unlock()
        task.resume()
    }
    @objc func cancel(_ call: CAPPluginCall) {
        if let id = call.getString("id") {
            lock.lock(); let task = tasks[id]; lock.unlock()
            task?.cancel()
        }
        call.resolve()
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        lock.lock(); let follow = redirectPolicy[task.taskDescription ?? ""] ?? false; lock.unlock()
        completionHandler(follow && request.url.map(allowed) == true ? request : nil)
    }
    // 设备密钥只保存在 Keychain 中；重启应用后可继续打开原源码的加密登录态。
    @objc func sessionSecret(_ call: CAPPluginCall) {
        let service = (Bundle.main.bundleIdentifier ?? "top.izuna.foliamajor") + ".qq"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "session-secret"]
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let secret = String(data: data, encoding: .utf8) {
            call.resolve(["secret": secret]); return
        }
        guard status == errSecItemNotFound else { call.reject("Cannot read QQ session key"); return }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            call.reject("Cannot create QQ session key"); return
        }
        let secret = Data(bytes).base64EncodedString()
        var item = query
        item[kSecValueData as String] = Data(secret.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { call.reject("Cannot persist QQ session key"); return }
        call.resolve(["secret": secret])
    }
}
