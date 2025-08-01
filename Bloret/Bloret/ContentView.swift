//
//  ContentView.swift
//  Bloret
//
//  Created by mac on 2025/7/25.
//

import SwiftUI
import UIKit

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var viewModel = MinecraftServerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.trailing, 16)
            ZStack {
                // 毛玻璃和半透明背景，保证卡片可见
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 8)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.3))
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading server info...")
                            .padding()
                    } else if let error = viewModel.error {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else if let info = viewModel.serverInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                if let iconData = info.icon,
                                   let data = Data(base64Encoded: iconData.replacingOccurrences(of: "data:image/png;base64,", with: "")),
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .cornerRadius(8)
                                } else {
                                    Image(systemName: info.online ? "checkmark.seal.fill" : "xmark.seal")
                                        .foregroundColor(info.online ? .green : .red)
                                        .imageScale(.large)
                                }
                                VStack(alignment: .leading) {
                                    Text("Bloret")
                                        .font(.headline)
                                    Text("Java 1.21.7-1.21.8 · bloret.net")
                                        .font(.subheadline)
                                }
                                Spacer()
                            }
                            Text("Version: \(info.version ?? "Unknown")")
                                .font(.subheadline)
                            // 修复 MOTD HTML 渲染
                            if let motdHtml = info.motd?.html {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(motdHtml, id: \ .self) { htmlLine in
                                        AttributedText(html: htmlLine)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            if let players = info.players {
                                Text("Players: \(players.online ?? 0) /\(players.max ?? 0)")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .padding(.horizontal)
            .padding(.top, 16)
            Spacer()
        }
        .onAppear {
            viewModel.fetchServerInfo()
        }
    }
}

// 修复 AttributedText 组件，确保 HTML 正确渲染
struct AttributedText: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = htmlToAttributedString(html)
        label.backgroundColor = .clear
        return label
    }
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = htmlToAttributedString(html)
    }
    private func htmlToAttributedString(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        return try? NSAttributedString(data: data, options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ], documentAttributes: nil)
    }
}

#Preview {
    ContentView()
}
