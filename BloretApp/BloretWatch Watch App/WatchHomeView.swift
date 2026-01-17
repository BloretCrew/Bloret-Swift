import SwiftUI

struct WatchHomeView: View {
    @ObservedObject var authManager: AuthManager
    @StateObject var serverVM = ServerViewModel() // 确保这个文件已勾选 Watch Target
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // MARK: - 1. 用户状态区
                if let user = authManager.currentUser {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title3)
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .font(.headline)
                            Text("已登录")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "iphone.gen2")
                            .font(.title2)
                        Text("请在 iPhone 上登录")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Divider()
                
                // MARK: - 2. 服务器状态区
                if serverVM.isLoading {
                    ProgressView()
                        .padding()
                } else if let error = serverVM.errorMessage {
                    // 错误提示
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text("无法连接服务器")
                            .font(.caption2)
                        Text(error) // 方便调试，发布时可隐藏
                            .font(.system(size: 8))
                            .lineLimit(2)
                            .foregroundColor(.gray)
                    }
                    .onTapGesture {
                        serverVM.fetchServerInfo()
                    }
                } else if let data = serverVM.serverData {
                    // 正常显示数据
                    VStack(alignment: .leading, spacing: 8) {
                        // 在线状态
                        HStack {
                            Circle()
                                .fill(data.realTimeStatus?.online == true ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(data.realTimeStatus?.online == true ? "服务器在线" : "离线")
                                .font(.caption)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if let status = data.realTimeStatus {
                                Text("\(status.playersOnline) / \(status.playersMax)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .padding(4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // 地址
                        Text(data.url)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Divider()
                        
                        // 公告 (Tip)
                        if !data.tip.isEmpty {
                            Text(data.tip)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
                
                // 刷新按钮
                Button(action: {
                    serverVM.fetchServerInfo()
                }) {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .padding(.top, 5)
            }
            .padding(.horizontal)
        }
        .onAppear {
            // 页面显示时自动拉取
            if serverVM.serverData == nil {
                serverVM.fetchServerInfo()
            }
        }
        // MARK: - 2FA 弹窗支持
        .alert(item: $authManager.pendingRequest) { request in
            Alert(
                title: Text("登录请求"),
                message: Text("IP: \(request.ip)\n设备: \(request.device)"),
                primaryButton: .default(Text("允许"), action: {
                    authManager.authenticateUser { success in
                        if success {
                            authManager.respondToRequest(request: request, action: "approve")
                        }
                    }
                }),
                secondaryButton: .destructive(Text("拒绝"), action: {
                    authManager.respondToRequest(request: request, action: "reject")
                })
            )
        }
    }
}
