import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            
            BlorikoView()
                .tabItem {
                    Label("Bloriko", systemImage: "sparkles")
                }
        }
        .accentColor(.purple) // 设置主题色
    }
}

// 你的 App 入口文件 (通常是 BloretApp.swift)
@main
struct BloretApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// OauthApp Secret: caFzuv-havqe3-hipcug
