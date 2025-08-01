import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MinecraftServerViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.fetchServerInfo()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.large)
                            .padding(8)
                    }
                    .accessibilityLabel("Refresh")
                }
                .padding(.trailing, 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .shadow(radius: 4)
                    Group {
                        if viewModel.isLoading {
                            ProgressView("Loading...")
                                .padding()
                        } else if let error = viewModel.error {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                        } else if let info = viewModel.serverInfo {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: info.online ? "checkmark.seal.fill" : "xmark.seal")
                                        .foregroundColor(info.online ? .green : .red)
                                        .imageScale(.large)
                                    VStack(alignment: .leading) {
                                        Text("Bloret")
                                            .font(.headline)
                                        Text("bloret.net")
                                            .font(.caption2)
                                    }
                                    Spacer()
                                }
                                Text("Version: \(info.version ?? "Unknown")")
                                    .font(.caption2)
                                if let motdHtml = info.motd?.html {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(motdHtml, id: \.self) { htmlLine in
                                            Text(htmlLine)
                                                .font(.caption2)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                if let players = info.players {
                                    Text("Players: \(players.online ?? 0) /\(players.max ?? 0)")
                                        .font(.caption2)
                                }
                            }
                            .padding(6)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .padding(.horizontal)
                Spacer()
            }
            .onAppear {
                viewModel.fetchServerInfo()
            }
        }
    }
}

#Preview {
    ContentView()
}
