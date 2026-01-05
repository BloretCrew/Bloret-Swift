import SwiftUI

struct BlorikoView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // MARK: - 图标部分 (兼容性处理)
                if #available(iOS 17.0, *) {
                    // iOS 17+ 用户可以看到动画
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.pink)
                        .symbolEffect(.bounce, options: .repeating)
                } else {
                    // iOS 16 及以下用户只看到静态图标，防止崩溃
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.pink)
                }
                
                Text("Bloriko AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("我是络可 (Bloriko)！\nAI 聊天功能正在开发中，\n敬请期待...")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Bloriko")
        }
    }
}
