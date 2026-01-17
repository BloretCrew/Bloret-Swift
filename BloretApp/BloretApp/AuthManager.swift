import SwiftUI
import Combine // ✅ 修复: 必须引入这个框架才能使用 ObservableObject
import AuthenticationServices

// MARK: - 用户模型
struct BloretUser: Codable {
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
    
    // ⚠️ 确保你在 Info.plist -> URL Types 里配置了 bloretapp
    let redirectScheme = "bloretapp"
    let redirectUri = "bloretapp://auth"
    
    private var authSession: ASWebAuthenticationSession?
    
    // 2FA 相关状态
    @Published var pendingRequest: TwoFARequestInfo? // 当前待处理的请求
    private var pollingTimer: Timer?
    private var processedRequestIds: Set<String> = [] // 记录已处理的 ID，防止重复弹窗
    
    override init() {
        super.init()
        loadUser()
    }
    
    // MARK: - 2FA 轮询逻辑
    
    private func startPolling() {
        stopPolling() // 防止重复开启
        guard currentUser != nil else { return }
        
        // 每 5 秒轮询一次
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkPending2FARequests()
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // 检查是否有待处理请求
    private func checkPending2FARequests() {
        guard let user = currentUser else { return }
        
        // 文档 API: http://pcfs.eno.ink:20000/api/2fa/app/pending
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
                        // 如果存在请求，且未处理过，且当前没有正在显示的弹窗
                        if !self.processedRequestIds.contains(request.requestId) && self.pendingRequest == nil {
                            self.pendingRequest = request
                        }
                    }
                }
            } catch {
                print("2FA Polling Error: \(error)")
            }
        }.resume()
    }
    
    // 响应请求 (允许或拒绝)
    func respondToRequest(request: TwoFARequestInfo, action: String) {
        guard let user = currentUser else { return }
        
        // 1. 标记为已处理并关闭弹窗
        processedRequestIds.insert(request.requestId)
        self.pendingRequest = nil
        self.isLoading = true
        
        // 2. 构建请求
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
        
        // 3. 发送
        URLSession.shared.dataTask(with: requestObj) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "操作失败: \(error.localizedDescription)"
                    // 如果网络失败，从已处理集合中移除，以便下次重试（可选）
                    self?.processedRequestIds.remove(request.requestId) 
                    return
                }
                
                // 解析结果
                if let data = data {
                    do {
                        let res = try JSONDecoder().decode(TwoFAActionResponse.self, from: data)
                        if !res.success {
                            self?.errorMessage = res.error ?? "服务器返回错误"
                        }
                    } catch {
                        self?.errorMessage = "解析响应失败"
                    }
                }
            }
        }.resume()
    }

    // MARK: - 启动官方登录流程
    func startSignIn() {
        var components = URLComponents(string: "http://pcfs.eno.ink:20000/app/oauth")
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "redirect_uri", value: redirectUri)
        ]
        
        guard let authURL = components?.url else { return }
        
        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
            if let error = error {
                print("Auth Error: \(error.localizedDescription)")
                return
            }
            guard let callbackURL = callbackURL else { return }
            
            if let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems,
               let code = queryItems.first(where: { $0.name == "code" })?.value {
                self?.exchangeCodeForToken(code: code)
            }
        }
        
        authSession?.presentationContextProvider = self
        authSession?.start()
    }
    
    // Step 2: 使用 Code 换取 Token
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
                
                if let error = error {
                    self?.errorMessage = "登录失败: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else { return }
                
                if let jsonString = String(data: data, encoding: .utf8), jsonString.contains("error") {
                    self?.errorMessage = "验证失败: \(jsonString)"
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(BloretUser.self, from: data)
                    self?.saveUser(user)
                } catch {
                    self?.errorMessage = "解析用户信息失败"
                }
            }
        }.resume()
    }
    
    // 登出
    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "BloretUserSaved")
        stopPolling() // 停止轮询
    }
    
    // 持久化存储
    private func saveUser(_ user: BloretUser) {
        self.currentUser = user
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "BloretUserSaved")
        }
        startPolling() // 登录成功后开始轮询
    }
    
    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "BloretUserSaved"),
           let user = try? JSONDecoder().decode(BloretUser.self, from: data) {
            self.currentUser = user
            startPolling() // App 启动加载用户后开始轮询
        }
    }
}

// MARK: - 扩展：告诉系统在哪里弹窗 (修复 iOS 15+ 警告)
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // ✅ 修复: 使用 UIWindowScene 获取当前窗口
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
