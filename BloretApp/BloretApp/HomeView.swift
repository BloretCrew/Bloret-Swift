import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = ServerViewModel()
    
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
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("重试") {
                            viewModel.fetchServerInfo()
                        }
                    }
                } else if let data = viewModel.serverData {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 头部标题
                            headerView(data: data)
                            
                            // 主状态卡片
                            statusCard(data: data)
                            
                            // 链接部分
                            linksSection(links: data.links)
                            
                            // 提示信息 (Markdown)
                            infoCard(title: "📜 公告与提示", content: data.tip)
                            
                            // 最佳时间 (来自 Bloriko)
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
        }
        .onAppear {
            if viewModel.serverData == nil {
                viewModel.fetchServerInfo()
            }
        }
    }
    
    // MARK: - 子视图组件
    
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
            // 在线状态指示
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
            
            // IP 地址 (点击复制)
            Button(action: {
                UIPasteboard.general.string = data.url
            }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("服务器地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(data.url)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            
            // MOTD 显示
            if let motd = data.realTimeStatus?.motdClean {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(motd, id: \.self) { line in
                        Text(line.trimmingCharacters(in: .whitespaces))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 版本和类型
            HStack {
                Text(data.realTimeStatus?.version ?? "Unknown Version")
                    .font(.caption)
                    .padding(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth: 1))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(data.type, id: \.self) { type in
                            Text(type)
                                .font(.caption2)
                                .padding(5)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(5)
                                .foregroundColor(.orange)
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
                    // 需要对字典键进行排序以保证显示顺序一致
                    ForEach(links.keys.sorted(), id: \.self) { key in
                        if let item = links[key], let url = URL(string: item.link) {
                            Link(destination: url) {
                                HStack {
                                    // 这里简单使用系统图标代替网络图标，
                                    // 实际开发中可以使用 AsyncImage 加载 item.icon
                                    Image(systemName: "link")
                                    Text(key)
                                        .fontWeight(.medium)
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
            Text(title)
                .font(.headline)
            
            Divider()
            
            // SwiftUI Text 支持基础 Markdown 解析
            Text(.init(content))
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
