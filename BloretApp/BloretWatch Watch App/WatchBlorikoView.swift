import SwiftUI

struct WatchBlorikoView: View {
    @ObservedObject var authManager: AuthManager
    @StateObject private var viewModel = BlorikoViewModel() // 需确保 BlorikoViewModel 属于 Watch Target
    
    var body: some View {
        VStack {
            if authManager.currentUser != nil {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { msg in
                            Text(msg.content)
                                .font(.caption)
                                .padding(8)
                                .background(msg.role == .user ? Color.purple : Color.gray.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(msg.role == .user ? .white : .primary)
                        }
                        if viewModel.isLoading {
                            ProgressView()
                        }
                    }
                }
                
                // Watch 输入方式
                TextField("发送消息...", text: $viewModel.inputText)
                    .onSubmit {
                        viewModel.sendMessage()
                    }
            } else {
                Text("需登录使用")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            // 同步 ViewModel 的用户状态
            viewModel.currentUser = authManager.currentUser
        }
        .onChange(of: authManager.currentUser) { newUser in
            viewModel.currentUser = newUser
        }
    }
}