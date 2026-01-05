import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = ServerViewModel()
    @StateObject var authManager = AuthManager() // 引入 AuthManager
    
    @State private var showLoginSheet = false
    @State private var showProfileSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("正在连接百络谷...")
                } else if let error = viewModel.errorMessage {
                    // ... (保持原有的错误视图代码) ...
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle) .foregroundColor(.red)
                        Text(error).padding()
                        Button("重试") { viewModel.fetchServerInfo() }
                    }
                } else if let data = viewModel.serverData {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerView(data: data)
                            statusCard(data: data)
                            linksSection(links: data.links)
                            infoCard(title: "📜 公告与提示", content: data.tip)
                            infoCard(title: "🌸 Bloriko 的建议", content: data.bestTime)
                        }
                        .padding()
                    }
                    .refreshable {
                        viewModel.fetchServerInfo()
                    }
                }
            }
            .navigationTitle("Bloret")
            // MARK: - 新增：工具栏登录按钮
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.currentUser != nil {
                            showProfileSheet = true
                        } else {
                            showLoginSheet = true
                        }
                    }) {
                        // 根据登录状态改变图标
                        if let _ = authManager.currentUser {
                            Image(systemName: "person.circle.fill") // 已登录
                                .foregroundColor(.purple)
                                .font(.title3)
                        } else {
                            Image(systemName: "person.circle") // 未登录
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            // MARK: - 弹窗：登录网页
            .sheet(isPresented: $showLoginSheet) {
                if let url = authManager.authURL {
                    NavigationView {
                        OAuthLoginView(
                            url: url,
                            redirectUri: authManager.redirectUri,
                            onCodeReceived: { code in
                                // 收到 code 后调用 API 换 token
                                authManager.exchangeCodeForToken(code: code)
                            },
                            isPresented: $showLoginSheet
                        )
                        .navigationTitle("Bloret PassPort")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { showLoginSheet = false }
                            }
                        }
                    }
                }
            }
            // MARK: - 弹窗：用户资料
            .sheet(isPresented: $showProfileSheet) {
                UserProfileView(authManager: authManager, isPresented: $showProfileSheet)
            }
        }
        .onAppear {
            if viewModel.serverData == nil {
                viewModel.fetchServerInfo()
            }
        }
    }
    
    // ... (保留你原有的 headerView, statusCard 等 ViewBuilder 代码不变) ...
    // 为了节省篇幅，这里省略重复的 ViewBuilder 代码，请直接复制你原来写好的即可
    
    @ViewBuilder
    func headerView(data: ServerResponse) -> some View {
        VStack {
            Text(data.title)
                .font(.system(size: 34, weight: .bold))
            Text(data.text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }
    
    @ViewBuilder
    func statusCard(data: ServerResponse) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Circle()
                    .fill(data.realTimeStatus?.online == true ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(data.realTimeStatus?.online == true ? "服务器在线" : "服务器离线")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if let status = data.realTimeStatus {
                    Text("\(status.playersOnline) / \(status.playersMax) 在线")
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            Divider()
            Button(action: { UIPasteboard.general.string = data.url }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("服务器地址").font(.caption).foregroundColor(.secondary)
                        Text(data.url).font(.title3).fontWeight(.semibold).foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "doc.on.doc").foregroundColor(.blue)
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            if let motd = data.realTimeStatus?.motdClean {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(motd, id: \.self) { line in
                        Text(line.trimmingCharacters(in: .whitespaces))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            HStack {
                Text(data.realTimeStatus?.version ?? "Unknown").font(.caption).padding(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth: 1))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(data.type, id: \.self) { type in
                            Text(type).font(.caption2).padding(5)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(5).foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    @ViewBuilder
    func linksSection(links: [String: LinkItem]?) -> some View {
        if let links = links {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(links.keys.sorted(), id: \.self) { key in
                        if let item = links[key], let url = URL(string: item.link) {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text(key).fontWeight(.medium)
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
        }
    }
    
    @ViewBuilder
    func infoCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Divider()
            Text(.init(content)).font(.callout).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 子视图：用户资料展示
struct UserProfileView: View {
    @ObservedObject var authManager: AuthManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if let user = authManager.currentUser {
                    VStack(spacing: 15) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.purple)
                        
                        Text(user.username)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let email = user.email {
                            Text(email)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    List {
                        Section("应用数据") {
                            HStack {
                                Text("Token 状态")
                                Spacer()
                                Text("已获取")
                                    .foregroundColor(.green)
                            }
                            // 可以在这里展示 AppToken 的前几位
                            HStack {
                                Text("App Token")
                                Spacer()
                                Text(String(user.apptoken.prefix(8)) + "...")
                                    .foregroundColor(.gray)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    
                    Button(action: {
                        authManager.logout()
                        isPresented = false
                    }) {
                        Text("退出登录")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Text("加载中或未登录...")
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isPresented = false }
                }
            }
        }
    }
}
