import SwiftUI

struct BlorikoView: View {
    @StateObject private var viewModel = BlorikoViewModel()
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // MARK: - 聊天内容区域
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            // 顶部占位，防止导航栏遮挡
                            Color.clear.frame(height: 10)
                            
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("络可正在思考...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 5)
                            }
                            
                            // 底部垫片
                            Color.clear.frame(height: 10)
                                .id("bottom")
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: viewModel.messages) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: isInputFocused) { focused in
                        if focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
                
                // MARK: - 底部输入栏
                VStack(spacing: 0) {
                    Divider()
                    HStack(alignment: .bottom, spacing: 10) {
                        
                        // 输入框
                        if viewModel.currentUser != nil {
                            // MARK: 兼容性处理
                            if #available(iOS 16.0, *) {
                                // iOS 16+ 使用支持多行的输入框
                                TextField("和络可聊聊 Minecraft...", text: $viewModel.inputText, axis: .vertical)
                                    .focused($isInputFocused)
                                    .padding(10)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(20)
                                    .lineLimit(1...5)
                            } else {
                                // iOS 15 及以下使用标准单行输入框
                                TextField("和络可聊聊 Minecraft...", text: $viewModel.inputText)
                                    .focused($isInputFocused)
                                    .padding(10)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(20)
                            }
                            
                            // 发送按钮
                            Button(action: viewModel.sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(viewModel.inputText.isEmpty || viewModel.isLoading ? .gray : .purple)
                            }
                            .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                        } else {
                            // 未登录提示
                            HStack {
                                Image(systemName: "lock.fill")
                                Text("请先在首页登录以使用 AI 聊天")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                }
            }
            .navigationTitle("Bloriko")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadUser() // 每次进入页面刷新用户状态
            }
        }
    }
}

// MARK: - 聊天气泡组件
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .assistant {
                // AI 头像
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(6)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
                    .foregroundColor(.purple)
            } else {
                Spacer()
            }
            
            // 消息内容
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ? Color.purple : Color(UIColor.secondarySystemBackground)
                )
                .foregroundColor(message.role == .user ? .white : .primary)
                // 气泡圆角逻辑
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                // 针对错误消息变红
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.red, lineWidth: message.isError ? 1 : 0)
                )
            
            if message.role == .user {
                // 用户头像 (可选)
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.gray)
            } else {
                Spacer()
            }
        }
    }
}
