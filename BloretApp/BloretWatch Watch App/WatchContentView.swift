import SwiftUI

struct WatchContentView: View {
    @StateObject var authManager = AuthManager() // 共享的管理器，自动同步手机登录态
    
    var body: some View {
        TabView {
            WatchHomeView(authManager: authManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
            
            // 复用 BlorikoViewModel 的逻辑，但需要适配 Watch 的 UI
            WatchBlorikoView(authManager: authManager)
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("AI")
                }
        }
    }
}