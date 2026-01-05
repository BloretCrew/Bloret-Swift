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

// MARK: - AI 聊天模型

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    var isError: Bool = false
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - API 请求结构
struct AIRequest: Codable {
    let pause: Bool
    let model: String
    let OauthApp: OauthAppInfo
    let user: AIUserInfo
    let context: [AIContextItem]
}

struct OauthAppInfo: Codable {
    let app_id: String
    let app_secret: String
}

struct AIUserInfo: Codable {
    let name: String
    let token: String
}

struct AIContextItem: Codable {
    let role: String
    let content: String
}

// MARK: - API 响应结构
struct AIResponse: Codable {
    let status: Bool
    let pause: Bool?
    let content: String?
    let connectionId: String?
    let message: String?
    let error: String?
}
