import Foundation
import SwiftUI

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
    // Add other fields as needed
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
    @Published var serverInfo: MinecraftServerInfo?
    @Published var isLoading = false
    @Published var error: String?

    func fetchServerInfo() {
        guard let url = URL(string: "https://api.mcsrvstat.us/3/bloret.net") else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = true
                self.error = nil
            }
            URLSession.shared.dataTask(with: url) { data, response, err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = err.localizedDescription
                    }
                    return
                }
                guard let data = data else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = "No data"
                    }
                    return
                }
                do {
                    let info = try JSONDecoder().decode(MinecraftServerInfo.self, from: data)
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.serverInfo = info
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = error.localizedDescription
                    }
                }
            }.resume()
        }
    }
}
