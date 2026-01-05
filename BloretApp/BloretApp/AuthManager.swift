import SwiftUI
import Combine

// MARK: - 用户模型
struct BloretUser: Codable {
    let username: String
    let email: String?
    let apptoken: String
    // 根据 API 文档，可能还有 admin 等字段，这里按需取用
}

// MARK: - 认证管理器
class AuthManager: ObservableObject {
    @Published var currentUser: BloretUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 配置信息 (来自你的提供)
    private let appId = "BloretApp"
    private let appSecret = "caFzuv-havqe3-hipcug"
    // 注意：在 WebView 中拦截此 URL
    let redirectUri = "http://localhost:17248/login/BloretPassPort"
    
    init() {
        loadUser()
    }
    
    // 生成授权 URL
    var authURL: URL? {
        var components = URLComponents(string: "http://pcfs.eno.ink:20000/app/oauth")
        components?.queryItems = [
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "redirect_uri", value: redirectUri)
        ]
        return components?.url
    }
    
    // Step 2: 使用 Code 换取 Token
    func exchangeCodeForToken(code: String) {
        guard let url = URL(string: "http://pcfs.eno.ink:20000/app/verify") else { return }
        
        isLoading = true
        errorMessage = nil
        
        // 构建查询参数
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
                
                // 检查是否是 API 错误响应
                if let jsonString = String(data: data, encoding: .utf8), jsonString.contains("error") {
                    self?.errorMessage = "验证失败: \(jsonString)"
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(BloretUser.self, from: data)
                    self?.saveUser(user)
                } catch {
                    self?.errorMessage = "解析用户信息失败"
                    print("Auth Decode Error: \(error)")
                }
            }
        }.resume()
    }
    
    // 登出
    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "BloretUserSaved")
    }
    
    // MARK: - 持久化存储 (简单版使用 UserDefaults)
    private func saveUser(_ user: BloretUser) {
        self.currentUser = user
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "BloretUserSaved")
        }
    }
    
    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "BloretUserSaved"),
           let user = try? JSONDecoder().decode(BloretUser.self, from: data) {
            self.currentUser = user
        }
    }
}
