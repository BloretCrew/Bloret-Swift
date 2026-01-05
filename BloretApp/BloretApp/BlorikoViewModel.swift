import SwiftUI
import Combine

class BlorikoViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 引用 AuthManager (或者直接读取 UserDefaults) 来获取用户信息
    @Published var currentUser: BloretUser?
    
    private let apiUrl = "http://pcfs.eno.ink:20000/api/ai"
    
    // 应用配置 (必须与登录时一致)
    private let appId = "BloretApp"
    private let appSecret = "caFzuv-havqe3-hipcug"
    
    init() {
        // 初始化时加载一句欢迎语
        messages.append(ChatMessage(role: .assistant, content: "你好呀！我是络可 (Bloriko)，百络谷的小画家。有关 Minecraft 或者服务器的问题都可以问我哦～ 🌸"))
        loadUser()
    }
    
    func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "BloretUserSaved"),
           let user = try? JSONDecoder().decode(BloretUser.self, from: data) {
            self.currentUser = user
        }
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let user = currentUser else {
            errorMessage = "请先在首页登录账号"
            return
        }
        
        // 1. UI 显示用户消息
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        // 2. 构建 API 请求上下文 (Context)
        // 将本地 ChatMessage 转换为 API 需要的格式
        let contextItems = messages.map { msg in
            AIContextItem(role: msg.role.rawValue, content: msg.content)
        }
        
        // 3. 构建请求体
        let requestBody = AIRequest(
            pause: false, // 暂时使用同步模式
            model: "Bloriko",
            OauthApp: OauthAppInfo(app_id: appId, app_secret: appSecret),
            user: AIUserInfo(name: user.username, token: user.apptoken),
            context: contextItems
        )
        
        // 4. 发送请求
        guard let url = URL(string: apiUrl) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            self.isLoading = false
            self.errorMessage = "编码错误"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.appendError("网络请求失败: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else { return }
                
                // 调试：打印服务器返回
                if let str = String(data: data, encoding: .utf8) {
                    print("AI Raw Response: \(str)")
                }
                
                do {
                    let apiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
                    
                    if apiResponse.status {
                        // 成功响应
                        if let content = apiResponse.content {
                            self?.messages.append(ChatMessage(role: .assistant, content: content))
                        } else if apiResponse.pause == true {
                            // 处理异步工具调用情况 (简单处理: 显示提示)
                            let msg = apiResponse.message ?? "正在查询资料中..."
                            self?.messages.append(ChatMessage(role: .assistant, content: "⏳ \(msg)"))
                        }
                    } else {
                        // API 返回业务错误
                        self?.appendError(apiResponse.error ?? "未知错误")
                    }
                } catch {
                    self?.appendError("解析响应失败")
                    print("AI Decode Error: \(error)")
                }
            }
        }.resume()
    }
    
    private func appendError(_ text: String) {
        messages.append(ChatMessage(role: .assistant, content: "❌ \(text)", isError: true))
    }
}
