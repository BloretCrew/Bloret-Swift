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
    
    override init() {
        super.init()
        loadUser()
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
    }
    
    // 持久化存储
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
