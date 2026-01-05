import SwiftUI
import WebKit

struct OAuthLoginView: UIViewRepresentable {
    let url: URL
    let redirectUri: String
    var onCodeReceived: (String) -> Void
    @Binding var isPresented: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 只在初次加载时请求
        if uiView.url == nil {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: OAuthLoginView
        
        init(parent: OAuthLoginView) {
            self.parent = parent
        }
        
        // 核心拦截逻辑
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // 检查是否跳转到了回调地址 (http://localhost:17248/login/BloretPassPort)
            // 使用 absoluteString 前缀匹配，防止 query 参数影响判断
            if url.absoluteString.starts(with: parent.redirectUri) {
                
                // 解析 URL 中的 ?code=...
                if let components = URLComponents(string: url.absoluteString),
                   let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                   let code = codeItem.value {
                    
                    // 拿到 Code，传回给 AuthManager
                    parent.onCodeReceived(code)
                    parent.isPresented = false // 关闭 WebView
                    decisionHandler(.cancel)   // 取消这次本地跳转
                    return
                }
            }
            
            decisionHandler(.allow)
        }
    }
}
