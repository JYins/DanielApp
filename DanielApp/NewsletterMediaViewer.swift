import SwiftUI
import UIKit

struct NewsletterMediaViewer: View {
    let imageURLs: [URL]
    let initialIndex: Int
    let language: CoreModels.VerseLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int
    @State private var showingGestureHint = true
    @State private var isCurrentPageZoomed = false

    init(imageURLs: [URL], initialIndex: Int = 0, language: CoreModels.VerseLanguage) {
        self.imageURLs = imageURLs
        self.initialIndex = min(max(initialIndex, 0), max(imageURLs.count - 1, 0))
        self.language = language
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), max(imageURLs.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if imageURLs.isEmpty {
                ContentUnavailableView(
                    unavailableTitle,
                    systemImage: "photo",
                    description: Text(unavailableMessage)
                )
                .foregroundStyle(.white)
            } else {
                ZoomableRemoteNewsletterImage(
                    url: imageURLs[selectedIndex],
                    language: language,
                    onZoomChange: { isCurrentPageZoomed = $0 }
                )
                .id(selectedIndex)
                .accessibilityLabel(imageAccessibilityLabel(for: selectedIndex))
                .ignoresSafeArea()
                .simultaneousGesture(navigationGesture)
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .accessibilityLabel(closeTitle)

                    Spacer()

                    if imageURLs.count > 1 {
                        Text("\(selectedIndex + 1) / \(imageURLs.count)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .accessibilityLabel(pageAccessibilityLabel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if showingGestureHint {
                    Text(gestureHint)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 18)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
        }
        .statusBarHidden()
        .task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.25)) { showingGestureHint = false }
        }
    }

    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard !isCurrentPageZoomed else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height

                if abs(horizontal) > abs(vertical), abs(horizontal) > 80 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isCurrentPageZoomed = false
                        selectedIndex = min(max(selectedIndex + (horizontal < 0 ? 1 : -1), 0), imageURLs.count - 1)
                    }
                } else if abs(horizontal) < 70, vertical > 120 {
                    dismiss()
                }
            }
    }

    private var closeTitle: String {
        switch language {
        case .chinese: return "关闭图片"
        case .english: return "Close image"
        case .korean: return "이미지 닫기"
        }
    }

    private var gestureHint: String {
        switch language {
        case .chinese: return "双指或双击放大 · 下滑关闭"
        case .english: return "Pinch or double-tap to zoom · Swipe down to close"
        case .korean: return "두 손가락 또는 두 번 탭하여 확대 · 아래로 밀어 닫기"
        }
    }

    private var unavailableTitle: String {
        switch language {
        case .chinese: return "图片不可用"
        case .english: return "Image unavailable"
        case .korean: return "이미지를 사용할 수 없습니다"
        }
    }

    private var unavailableMessage: String {
        switch language {
        case .chinese: return "这份 Newsletter 暂时没有可以查看的图片。"
        case .english: return "This newsletter does not currently have a viewable image."
        case .korean: return "이 뉴스레터에는 현재 볼 수 있는 이미지가 없습니다."
        }
    }

    private var pageAccessibilityLabel: String {
        imageAccessibilityLabel(for: selectedIndex)
    }

    private func imageAccessibilityLabel(for index: Int) -> String {
        switch language {
        case .chinese: return "第 \(index + 1) 张，共 \(imageURLs.count) 张"
        case .english: return "Image \(index + 1) of \(imageURLs.count)"
        case .korean: return "\(imageURLs.count)장 중 \(index + 1)번째 이미지"
        }
    }
}

struct NewsletterMediaThumbnail: View {
    let url: URL
    let height: CGFloat?
    let cornerRadius: CGFloat
    let imageCount: Int
    let language: CoreModels.VerseLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback(systemImage: "exclamationmark.triangle")
                    default:
                        Rectangle()
                            .fill(DesignSystem.Colors.cardBackground)
                            .overlay(ProgressView().tint(DesignSystem.Colors.accent))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: height == nil ? .infinity : nil)
                .frame(height: height)
                .clipped()

                HStack(spacing: 6) {
                    if imageCount > 1 {
                        Image(systemName: "square.stack")
                        Text("\(imageCount)")
                    }
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.black.opacity(0.58), in: Capsule())
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(openTitle)
        .accessibilityHint(openHint)
    }

    private func fallback(systemImage: String) -> some View {
        Rectangle()
            .fill(DesignSystem.Colors.cardBackground)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            )
    }

    private var openTitle: String {
        switch language {
        case .chinese: return imageCount > 1 ? "打开 Newsletter 图片，共 \(imageCount) 张" : "打开 Newsletter 图片"
        case .english: return imageCount > 1 ? "Open \(imageCount) newsletter images" : "Open newsletter image"
        case .korean: return imageCount > 1 ? "뉴스레터 이미지 \(imageCount)장 열기" : "뉴스레터 이미지 열기"
        }
    }

    private var openHint: String {
        switch language {
        case .chinese: return "全屏查看并缩放"
        case .english: return "View full screen and zoom"
        case .korean: return "전체 화면으로 보고 확대합니다"
        }
    }
}

private struct ZoomableRemoteNewsletterImage: View {
    let url: URL
    let language: CoreModels.VerseLanguage
    let onZoomChange: (Bool) -> Void
    @State private var image: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let image {
                ZoomableNewsletterImage(image: image, onZoomChange: onZoomChange)
            } else if let errorMessage {
                ContentUnavailableView(
                    failedTitle,
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            }
        }
        .task(id: url) { await loadImage() }
    }

    @MainActor
    private func loadImage() async {
        image = nil
        errorMessage = nil
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let response = response as? HTTPURLResponse,
               !(200...299).contains(response.statusCode) {
                throw URLError(.badServerResponse)
            }
            guard let decoded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            image = decoded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var failedTitle: String {
        switch language {
        case .chinese: return "无法加载图片"
        case .english: return "Couldn't load image"
        case .korean: return "이미지를 불러올 수 없습니다"
        }
    }
}

private struct ZoomableNewsletterImage: UIViewRepresentable {
    let image: UIImage
    let onZoomChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onZoomChange: onZoomChange) }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2

        let imageView = context.coordinator.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onZoomChange = onZoomChange
        context.coordinator.imageView.image = image
        context.coordinator.layoutImage(in: scrollView)
        DispatchQueue.main.async { [weak scrollView, weak coordinator = context.coordinator] in
            guard let scrollView else { return }
            coordinator?.layoutImage(in: scrollView)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        weak var scrollView: UIScrollView?
        var onZoomChange: (Bool) -> Void

        init(onZoomChange: @escaping (Bool) -> Void) {
            self.onZoomChange = onZoomChange
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let isZoomed = scrollView.zoomScale > 1.01
            scrollView.panGestureRecognizer.minimumNumberOfTouches = isZoomed ? 1 : 2
            onZoomChange(isZoomed)
            centerImage(in: scrollView)
        }

        func layoutImage(in scrollView: UIScrollView) {
            guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
            imageView.frame = scrollView.bounds
            scrollView.contentSize = scrollView.bounds.size
            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            let horizontal = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
            let vertical = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        }

        @objc func didDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let targetScale = min(2.5, scrollView.maximumZoomScale)
            let point = recognizer.location(in: imageView)
            let width = scrollView.bounds.width / targetScale
            let height = scrollView.bounds.height / targetScale
            scrollView.zoom(to: CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height), animated: true)
        }
    }
}
