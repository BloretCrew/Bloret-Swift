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
    
    // API 地址
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

// MARK: - 3. 视图 (View)
struct BloretWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    let maxPlayers: Double = 40.0
    
    var body: some View {
        switch family {
        
        // 1. 圆形 (Circular)
        case .accessoryCircular:
            Gauge(value: Double(entry.playersOnline), in: 0...maxPlayers) {
                if entry.isOnline {
                    Image("BloretServer")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } currentValueLabel: {
                // 底部文字
                Text("\(entry.playersOnline)")
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() } // ✅ 已添加
            
        // 2. 矩形 (Rectangular)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Rectangle()
                    .fill(entry.isOnline ? Color.purple : Color.red)
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bloret Server")
                        .font(.headline)
                        .widgetAccentable()
                    
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
            .containerBackground(for: .widget) { AccessoryWidgetBackground() } // ✅ 已添加
            
        // 3. 行内 (Inline) - 即使是纯文字也需要这个修饰符
        case .accessoryInline:
            Group {
                if entry.isOnline {
                    Text("Bloret: \(entry.playersOnline) Players")
                } else {
                    Text("Bloret: Offline")
                }
            }
            .containerBackground(for: .widget) { Color.clear } // ✅ 修复: Inline 使用透明背景
            
        // 4. 角标 (Corner)
        case .accessoryCorner:
            Group {
                if entry.isOnline {
                    Image("BloretServer")
                        .resizable()
                        .scaledToFit()
                        .widgetLabel {
                            Text("\(entry.playersOnline)")
                        }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .widgetLabel {
                            Text("Offline")
                        }
                }
            }
            .containerBackground(for: .widget) { AccessoryWidgetBackground() } // ✅ 修复: Corner 必须添加
            
        // 其他
        default:
            Text("\(entry.playersOnline)")
                .containerBackground(for: .widget) { AccessoryWidgetBackground() } // ✅ 已添加
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
        BloretWidgetEntryView(entry: ServerStatusEntry(date: Date(), playersOnline: 12, isOnline: true))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
        
        BloretWidgetEntryView(entry: ServerStatusEntry(date: Date(), playersOnline: 12, isOnline: true))
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
            .previewDisplayName("Corner")
    }
}
