import WidgetKit
import SwiftUI

// MARK: - 1. 数据条目 (Entry)
struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let playersOnline: Int
    let isOnline: Bool
}

// MARK: - 2. 时间线提供者 (Provider)
struct Provider: TimelineProvider {
    
    let apiUrl = URL(string: "http://pcfs.eno.ink:20901/api/getserver?name=Bloret")!
    
    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(date: Date(), playersOnline: 15, isOnline: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> ()) {
        let entry = ServerStatusEntry(date: Date(), playersOnline: 12, isOnline: true)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> ()) {
        let task = URLSession.shared.dataTask(with: apiUrl) { data, response, error in
            var playerCount = 0
            var online = false
            
            if let data = data, let decoded = try? JSONDecoder().decode(ServerResponse.self, from: data) {
                playerCount = decoded.realTimeStatus?.playersOnline ?? 0
                online = decoded.realTimeStatus?.online ?? false
            }
            
            let entry = ServerStatusEntry(date: Date(), playersOnline: playerCount, isOnline: online)
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            
            completion(timeline)
        }
        task.resume()
    }
}

// MARK: - 3. 视图 (View) - 支持多种尺寸
struct BloretWidgetEntryView : View {
    var entry: Provider.Entry
    
    // 获取当前组件的类型（圆形、矩形、角标等）
    @Environment(\.widgetFamily) var family
    
    let maxPlayers: Double = 40.0
    
    var body: some View {
        switch family {
        
        // 1. 圆形组件 (保持之前的圆环设计)
        case .accessoryCircular:
            Gauge(value: Double(entry.playersOnline), in: 0...maxPlayers) {
                if entry.isOnline {
                    Image("BloretServer") // ⚠️ 确保图片已缩小至 100x100
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
            
        // 2. 矩形组件 (显示更详细的信息)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                // 左侧竖线装饰
                Rectangle()
                    .fill(entry.isOnline ? Color.purple : Color.red)
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bloret Server")
                        .font(.headline)
                        .widgetAccentable() // 允许被表盘染色
                    
                    if entry.isOnline {
                        Text("\(entry.playersOnline) / 40 Online")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Server Offline")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
            
        // 3. 行内组件 (顶部文字，适合 Modular 表盘)
        case .accessoryInline:
            if entry.isOnline {
                Text("Bloret: \(entry.playersOnline) Players")
            } else {
                Text("Bloret: Offline")
            }
            
        // 4. 角标组件 (适合圆形表盘的四个角)
        case .accessoryCorner:
            if entry.isOnline {
                Image("BloretServer")
                    .resizable()
                    .scaledToFit()
                    .widgetLabel {
                        Text("\(entry.playersOnline)/40")
                    }
            } else {
                Image(systemName: "xmark.circle.fill")
                    .widgetLabel {
                        Text("Offline")
                    }
            }
            
        // 其他未知类型
        default:
            Text("\(entry.playersOnline)")
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
    }
}

// MARK: - 4. Widget 配置
@main
struct BloretWidget: Widget {
    let kind: String = "BloretWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BloretWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("服务器状态")
        .description("查看 Bloret 在线人数")
        // ✅ 注册支持的所有类型
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - 5. 预览
struct BloretWidget_Previews: PreviewProvider {
    static var previews: some View {
        // 预览圆形
        BloretWidgetEntryView(entry: ServerStatusEntry(date: Date(), playersOnline: 12, isOnline: true))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
        
        // 预览矩形
        BloretWidgetEntryView(entry: ServerStatusEntry(date: Date(), playersOnline: 35, isOnline: true))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
    }
}
