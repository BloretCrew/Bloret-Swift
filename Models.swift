import Foundation

// MARK: - ServerResponse
struct ServerResponse: Codable {
    let title: String
    let text: String
    let url: String
    let otherip: [String: String]?
    let onlineCheck: Bool
    let type: [String]
    let tip: String
    let links: [String: LinkItem]?
    let author: String
    let time: Int64
    let bestTime: String
    let realTimeStatus: RealTimeStatus?
    
    enum CodingKeys: String, CodingKey {
        case title, text, url, otherip
        case onlineCheck = "OnlineCheck"
        case type, tip, links, author, time
        case bestTime = "BestTime"
        case realTimeStatus
    }
}

// MARK: - LinkItem
struct LinkItem: Codable, Identifiable {
    var id: String { link } // 使用链接作为唯一标识
    let link: String
    let icon: String
    let darkicon: String
}

// MARK: - RealTimeStatus
struct RealTimeStatus: Codable {
    let online: Bool
    let ip: String
    let port: Int
    let version: String
    let protocolName: String
    let playersOnline: Int
    let playersMax: Int
    let motdClean: [String]?
}
