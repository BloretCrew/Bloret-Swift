import Foundation
import Combine

class ServerViewModel: ObservableObject {
    @Published var serverData: ServerResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // API 地址
    private let urlString = "http://pcfs.eno.ink:20901/api/getserver?name=Bloret"
    
    func fetchServerInfo() {
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "请求失败: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let decoder = JSONDecoder()
                    let decodedData = try decoder.decode(ServerResponse.self, from: data)
                    self?.serverData = decodedData
                } catch {
                    self?.errorMessage = "解析错误: \(error.localizedDescription)"
                    print("Decode Error: \(error)")
                }
            }
        }.resume()
    }
}
