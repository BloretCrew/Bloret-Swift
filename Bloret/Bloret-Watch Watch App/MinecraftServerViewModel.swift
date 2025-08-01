import Foundation
import SwiftUI
import Combine

struct MinecraftServerInfo: Codable {
    let online: Bool
    let ip: String?
    let port: Int?
    let hostname: String?
    let version: String?
    let icon: String?
    let motd: Motd?
    let players: Players?
    let map: MapInfo?
    let software: String?
    let plugins: [Plugin]?
    let mods: [Mod]?
    let info: Motd?
}

struct Motd: Codable {
    let raw: [String]?
    let clean: [String]?
    let html: [String]?
}

struct Players: Codable {
    let online: Int?
    let max: Int?
    let list: [Player]?
}

struct Player: Codable {
    let name: String?
    let uuid: String?
}

struct Plugin: Codable {
    let name: String?
    let version: String?
}

struct Mod: Codable {
    let name: String?
    let version: String?
}

struct MapInfo: Codable {
    let raw: String?
    let clean: String?
    let html: String?
}

class MinecraftServerViewModel: ObservableObject {
    @Published var serverInfo: MinecraftServerInfo? = nil
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    func fetchServerInfo() {
        guard let url = URL(string: "https://api.mcsrvstat.us/3/bloret.net") else { return }
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        URLSession.shared.dataTask(with: url) { data, response, err in
            DispatchQueue.main.async {
                if let err = err {
                    self.isLoading = false
                    self.error = err.localizedDescription
                    return
                }
                guard let data = data else {
                    self.isLoading = false
                    self.error = "No data"
                    return
                }
                do {
                    let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)
                    self.serverInfo = info
                    self.isLoading = false
                } catch {
                    self.isLoading = false
                    self.error = error.localizedDescription
                }
            }
        }.resume()
    }
}
