import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = ServerViewModel()
    @StateObject var authManager = AuthManager()
    
    // 注意：不再需要 showLoginSheet，因为系统会自动处理弹窗
    @State private var showProfileSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("正在连接百络谷...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error).multilineTextAlignment(.center).padding()
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
                            Color.clear.frame(height: 20)
                        }
                        .padding()
                    }
                    .refreshable { viewModel.fetchServerInfo() }
                }
            }
            .navigationTitle("Bloret")
            
            // MARK: - 工具栏
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.currentUser != nil {
                            showProfileSheet = true
                        } else {
                            // ✅ 关键点：直接调用 AuthManager 的方法唤起系统登录
                            authManager.startSignIn()
                        }
                    }) {
                        if let _ = authManager.currentUser {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.purple).font(.title3)
                        } else {
                            Image(systemName: "person.circle")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            // MARK: - 只保留用户资料弹窗
            .sheet(isPresented: $showProfileSheet) {
                UserProfileView(authManager: authManager, isPresented: $showProfileSheet)
            }
        }
        .onAppear {
            if viewModel.serverData == nil { viewModel.fetchServerInfo() }
        }
        // 监听 2FA 请求弹窗
        .alert(item: $authManager.pendingRequest) { request in
            Alert(
                title: Text("尝试登录请求"),
                message: Text("检测到网页端登录请求\nIP: \(request.ip)\n设备: \(request.device)"),
                primaryButton: .default(Text("允许登录"), action: {
                    // ✅ 修改: 先进行 Face ID 验证，成功后再发送 approve
                    authManager.authenticateUser { success in
                        if success {
                            authManager.respondToRequest(request: request, action: "approve")
                        } else {
                            // 验证失败（用户取消或 FaceID 错误），不做任何操作或提示错误
                            // 由于 Alert 此时已关闭，如果需要，可以在这里设置一个错误状态弹窗
                        }
                    }
                }),
                secondaryButton: .destructive(Text("拒绝"), action: {
                    // 拒绝通常不需要生物识别验证
                    authManager.respondToRequest(request: request, action: "reject")
                })
            )
        }
    }
    
    // MARK: - 下面是你的 UI 组件 (保持不变)
    
    @ViewBuilder
    func headerView(data: ServerResponse) -> some View {
        VStack {
            Text(data.title).font(.system(size: 34, weight: .bold))
            Text(data.text).font(.subheadline).foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }
    
    @ViewBuilder
    func statusCard(data: ServerResponse) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Circle().fill(data.realTimeStatus?.online == true ? Color.green : Color.red).frame(width: 10, height: 10)
                Text(data.realTimeStatus?.online == true ? "服务器在线" : "服务器离线").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                Spacer()
                if let status = data.realTimeStatus {
                    Text("\(status.playersOnline) / \(status.playersMax) 在线").font(.caption).padding(6).background(Color.blue.opacity(0.1)).cornerRadius(8)
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
                .padding(10).background(Color(UIColor.secondarySystemBackground)).cornerRadius(10)
            }
            if let motd = data.realTimeStatus?.motdClean {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(motd, id: \.self) { line in
                        Text(line.trimmingCharacters(in: .whitespaces)).font(.system(.footnote, design: .monospaced)).foregroundColor(.secondary)
                    }
                }
            }
            HStack {
                Text(data.realTimeStatus?.version ?? "Unknown").font(.caption).padding(5).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth: 1))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(data.type, id: \.self) { type in
                            Text(type).font(.caption2).padding(5).background(Color.orange.opacity(0.2)).cornerRadius(5).foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding().background(Color(UIColor.systemBackground)).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
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
                                .padding().background(Color(UIColor.systemBackground)).cornerRadius(12).shadow(radius: 2)
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
            Text(.init(content)).font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding().background(Color(UIColor.systemBackground)).cornerRadius(15).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 用户资料弹窗 (保持不变)
struct UserProfileView: View {
    @ObservedObject var authManager: AuthManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if let user = authManager.currentUser {
                    VStack(spacing: 15) {
                        Image(systemName: "person.crop.circle.fill").resizable().frame(width: 80, height: 80).foregroundColor(.purple)
                        Text(user.username).font(.title).fontWeight(.bold)
                        if let email = user.email { Text(email).foregroundColor(.secondary) }
                    }
                    .padding()
                    List {
                        Section("应用数据") {
                            HStack { Text("Token 状态"); Spacer(); Text("已获取").foregroundColor(.green) }
                            HStack { Text("App Token"); Spacer(); Text(String(user.apptoken.prefix(8)) + "...").foregroundColor(.gray).font(.system(.caption, design: .monospaced)) }
                        }
                    }
                    Button(action: { authManager.logout(); isPresented = false }) {
                        Text("退出登录").fontWeight(.bold).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).foregroundColor(.red).cornerRadius(10)
                    }
                    .padding()
                } else {
                    Text("加载中或未登录...")
                }
            }
            .navigationTitle("个人中心").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { isPresented = false } }
            }
        }
    }
}
