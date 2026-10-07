import SwiftUI
import WebKit

// MARK: - 加载状态
final class WebState: ObservableObject {
    @Published var progress: Double = 0
    @Published var isLoading: Bool = true
    @Published var canGoBack: Bool = false
    @Published var reloadToken: Int = 0
    weak var webView: WKWebView?

    func reload() { webView?.reload() }
    func goBack() { webView?.goBack() }
}

// MARK: - WebView 封装
struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var state: WebState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = true
        state.webView = webView
        context.coordinator.observe(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        _ = state.reloadToken
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let state: WebState
        private var progressObs: NSKeyValueObservation?
        private var backObs: NSKeyValueObservation?

        init(state: WebState) { self.state = state }

        func observe(_ webView: WKWebView) {
            progressObs = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.state.progress = wv.estimatedProgress
                    self?.state.isLoading = wv.isLoading
                }
            }
            backObs = webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.state.canGoBack = wv.canGoBack }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = false
                self.state.progress = 1.0
                self.state.canGoBack = webView.canGoBack
            }
        }
    }
}

// MARK: - Liquid Glass 自适应（iOS 26+ 用真玻璃，低版本用毛玻璃）
extension View {
    @ViewBuilder
    func adaptiveGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
        }
    }
}

// MARK: - 启动画面
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.995, green: 0.95, blue: 0.965),
                    Color(red: 0.94, green: 0.955, blue: 1.0)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Group {
                    if let icon = UIImage(named: "AppIcon") {
                        Image(uiImage: icon).resizable()
                    } else {
                        Image(systemName: "heart.fill")
                            .resizable()
                            .foregroundStyle(Color(red: 0.91, green: 0.33, blue: 0.42))
                            .padding(24)
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                .shadow(color: Color(red: 0.91, green: 0.33, blue: 0.42).opacity(0.25), radius: 18, y: 8)

                Text("YuriのBlog")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.72, green: 0.31, blue: 0.40))

                Text("Somewhere between reality and 2D.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.72, green: 0.31, blue: 0.40).opacity(0.55))
            }
            .scaleEffect(appear ? 1 : 0.88)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) { appear = true }
        }
    }
}

// MARK: - 主界面
struct ContentView: View {
    @StateObject private var state = WebState()
    @State private var showSplash = true

    private let brand = Color(red: 0.91, green: 0.33, blue: 0.42)
    private let homeURL = URL(string: "https://www.132778.xyz/")!

    var body: some View {
        ZStack {
            Color(red: 0.995, green: 0.95, blue: 0.965).ignoresSafeArea()

            WebView(url: homeURL, state: state)
                .ignoresSafeArea(edges: .bottom)

            // 顶部加载进度条
            VStack(spacing: 0) {
                if state.isLoading && state.progress < 1.0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Color.clear
                            Rectangle()
                                .fill(
                                    LinearGradient(colors: [brand.opacity(0.7), brand],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(2, geo.size.width * CGFloat(state.progress)))
                                .animation(.easeOut(duration: 0.25), value: state.progress)
                        }
                    }
                    .frame(height: 2.5)
                    .transition(.opacity)
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // 底部 Liquid Glass 工具栏
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    toolbarButton(icon: "chevron.left", enabled: state.canGoBack) { state.goBack() }
                    divider
                    toolbarButton(icon: "house.fill") {
                        state.webView?.load(URLRequest(url: homeURL))
                    }
                    divider
                    toolbarButton(icon: "arrow.clockwise") { state.reload() }
                }
                .padding(5)
                .adaptiveGlass(cornerRadius: 26)
                .padding(.bottom, 20)
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.55)) { showSplash = false }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(brand.opacity(0.15))
            .frame(width: 0.5, height: 22)
    }

    @ViewBuilder
    private func toolbarButton(icon: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? brand : brand.opacity(0.28))
                .frame(width: 48, height: 40)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}
