import SwiftUI
import Combine
import AuthenticationServices
import LocalAuthentication
import WatchConnectivity // ✅ 新增: 引入 WatchConnectivity

// MARK: - 用户模型
// ✅ 修复: 添加 Equatable 协议，以便 SwiftUI 的 onChange 可以比较用户变化
struct BloretUser: Codable, Equatable {
    let username: String
    let email: String?
    let apptoken: String
}

// MARK: - 认证管理器
class AuthManager: NSObject, ObservableObject {
    @Published var currentUser: BloretUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 配置信息
    private let appId = "BloretApp"
    private let appSecret = "caFzuv-havqe3-hipcug"
    
    #if os(iOS)
    let redirectScheme = "bloretapp"
    let redirectUri = "bloretapp://auth"
    private var authSession: ASWebAuthenticationSession?
    #endif
    
    // 2FA 相关状态
    @Published var pendingRequest: TwoFARequestInfo?
    private var pollingTimer: Timer?
    private var processedRequestIds: Set<String> = []
    
    override init() {
        super.init()
        // 1. 激活 WCSession
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        // 2. 加载用户并开启轮询
        loadUser()
    }
    
    // MARK: - 2FA 轮询逻辑
    private func startPolling() {
        stopPolling()
        guard currentUser != nil else { return }
        
        // 5秒轮询
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkPending2FARequests()
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func checkPending2FARequests() {
        guard let user = currentUser else { return }
        
        var components = URLComponents(string: "http://pcfs.eno.ink:20000/api/2fa/app/pending")
        components?.queryItems = [
            URLQueryItem(name: "username", value: user.username),
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "token", value: user.apptoken)
        ]
        
        guard let url = components?.url else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            do {
                let response = try JSONDecoder().decode(TwoFAPendingResponse.self, from: data)
                if response.success, let request = response.requests.first {
                    DispatchQueue.main.async {
                        if !self.processedRequestIds.contains(request.requestId) && self.pendingRequest == nil {
                            // WatchOS 上可以通过 WKInterfaceDevice.current().play(.notification) 震动
                            #if os(watchOS)
                            WKInterfaceDevice.current().play(.notification)
                            #endif
                            self.pendingRequest = request
                        }
                    }
                }
            } catch {
                print("2FA Polling Error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - 生物识别验证 (支持 iOS FaceID 和 Watch Passcode)
    func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        #if os(iOS)
        // iOS: 优先 Face ID
        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
        #else
        // WatchOS: 使用密码/解锁状态 (.deviceOwnerAuthentication)
        // Watch 没有 FaceID 硬件 API
        let policy: LAPolicy = .deviceOwnerAuthentication
        #endif
        
        if context.canEvaluatePolicy(policy, error: &error) {
            let reason = "验证身份以批准登录"
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        // iOS 失败回退逻辑
                        #if os(iOS)
                        self.authenticateWithPasscode(context: context, completion: completion)
                        #else
                        completion(false)
                        #endif
                    }
                }
            }
        } else {
            #if os(iOS)
            authenticateWithPasscode(context: context, completion: completion)
            #else
            // Watch 如果没有设置密码，默认允许
            DispatchQueue.main.async { completion(true) }
            #endif
        }
    }
    
    #if os(iOS)
    private func authenticateWithPasscode(context: LAContext, completion: @escaping (Bool) -> Void) {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "无法识别 Face ID，请输入密码") { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        } else {
            DispatchQueue.main.async { completion(true) }
        }
    }
    #endif

    // MARK: - 响应请求
    func respondToRequest(request: TwoFARequestInfo, action: String) {
        guard let user = currentUser else { return }
        
        processedRequestIds.insert(request.requestId)
        self.pendingRequest = nil
        self.isLoading = true
        
        let url = URL(string: "http://pcfs.eno.ink:20000/api/2fa/app/approve")!
        var requestObj = URLRequest(url: url)
        requestObj.httpMethod = "POST"
        requestObj.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "username": user.username,
            "app_id": appId,
            "token": user.apptoken,
            "requestId": request.requestId,
            "action": action
        ]
        
        requestObj.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: requestObj) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "操作失败: \(error.localizedDescription)"
                    self?.processedRequestIds.remove(request.requestId)
                    return
                }
                if let data = data {
                    do {
                        let res = try JSONDecoder().decode(TwoFAActionResponse.self, from: data)
                        if !res.success {
                            self?.errorMessage = res.error ?? "错误"
                        }
                    } catch { self?.errorMessage = "解析失败" }
                }
            }
        }.resume()
    }

    // MARK: - 登录 (仅 iOS)
    #if os(iOS)
    func startSignIn() {
        var components = URLComponents(string: "http://pcfs.eno.ink:20000/app/oauth")
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "redirect_uri", value: redirectUri)
        ]
        
        guard let authURL = components?.url else { return }
        
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
            if let error = error { print("Auth Error: \(error.localizedDescription)"); return }
            guard let callbackURL = callbackURL else { return }
            
            if let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems,
               let code = queryItems.first(where: { $0.name == "code" })?.value {
                self?.exchangeCodeForToken(code: code)
            }
        }
        
        authSession?.presentationContextProvider = self
        authSession?.start()
    }
    
    func exchangeCodeForToken(code: String) {
        guard let url = URL(string: "http://pcfs.eno.ink:20000/app/verify") else { return }
        DispatchQueue.main.async { self.isLoading = true }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "app_secret", value: appSecret),
            URLQueryItem(name: "code", value: code)
        ]
        
        guard let requestUrl = components?.url else { return }
        
        URLSession.shared.dataTask(with: requestUrl) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let _ = error { self?.errorMessage = "登录失败"; return }
                guard let data = data else { return }
                
                if let jsonString = String(data: data, encoding: .utf8), jsonString.contains("error") {
                    self?.errorMessage = "验证失败: \(jsonString)"
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(BloretUser.self, from: data)
                    self?.saveUser(user)
                } catch { self?.errorMessage = "解析失败" }
            }
        }.resume()
    }
    #endif
    
    // MARK: - 登出 & 存储
    
    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "BloretUserSaved")
        stopPolling()
        // 同步登出状态到 Watch
        syncUserToWatch(nil)
    }
    
    // 公开给 iOS 端调用
    func saveUser(_ user: BloretUser) {
        _saveUserInternal(user)
        // 同步登录状态到 Watch
        syncUserToWatch(user)
    }
    
    // 内部存储逻辑
    private func _saveUserInternal(_ user: BloretUser) {
        self.currentUser = user
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "BloretUserSaved")
        }
        startPolling()
    }
    
    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "BloretUserSaved"),
           let user = try? JSONDecoder().decode(BloretUser.self, from: data) {
            self.currentUser = user
            startPolling()
            // ✅ 修复: App 启动加载完用户后，尝试同步到 Watch
            // 注意：此时 Session 可能还没 activated，所以会在下面的 delegate 中再次尝试
            syncUserToWatch(user)
        }
    }
    
    // MARK: - Watch Connectivity Sync
    
    private func syncUserToWatch(_ user: BloretUser?) {
        #if os(iOS)
        // 检查 Session 是否激活
        guard WCSession.default.activationState == .activated else {
            print("Sync failed: Session not activated")
            return
        }
        
        var context: [String: Any] = [:]
        if let user = user, let data = try? JSONEncoder().encode(user) {
            context["user"] = data
        } else {
            context["user"] = nil // 删除
        }
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("Sync sent to Watch: \(user?.username ?? "Logout")")
        } catch {
            print("Sync Error: \(error)")
        }
        #endif
    }
}

// MARK: - Watch Connectivity Delegate
extension AuthManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // ✅ 修复: Session 激活成功后，如果当前已登录，立即把用户信息发给 Watch
        // 这解决了“iPhone 已登录但 Watch 没数据”的问题
        DispatchQueue.main.async {
            #if os(iOS)
            if activationState == .activated, let user = self.currentUser {
                self.syncUserToWatch(user)
            }
            #endif
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate() // 重新激活
    }
    #endif
    
    // 接收 Application Context (Watch 接收 iOS 的数据)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            if let userData = applicationContext["user"] as? Data {
                // 收到用户数据 -> 登录
                if let user = try? JSONDecoder().decode(BloretUser.self, from: userData) {
                    self._saveUserInternal(user)
                }
            } else {
                // 没有用户数据 -> 登出
                self.currentUser = nil
                UserDefaults.standard.removeObject(forKey: "BloretUserSaved")
                self.stopPolling()
            }
        }
    }
}

// MARK: - 扩展：告诉系统在哪里弹窗 (iOS only)
#if os(iOS)
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
#endif