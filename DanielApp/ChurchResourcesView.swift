import SwiftUI
import AVFoundation
import PDFKit

struct ChurchResourcesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var resourceService = ChurchResourceService()
    @State private var searchText = ""

    private var filteredResources: [ChurchResource] {
        resourceService.filteredResources(
            searchText: searchText,
            selectedCategory: .all,
            language: appState.selectedLanguage
        )
    }

    private var featuredHymn: ChurchResource? {
        filteredResources.first { $0.category == .hymnbook }
    }

    private var directoryResources: [ChurchResource] {
        filteredResources.filter { $0.id != featuredHymn?.id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ResourcesLibraryHeader(language: appState.selectedLanguage)

                        ResourceSearchField(
                            searchText: $searchText,
                            placeholder: LocalizedText.Resources.searchPlaceholder.text(for: appState.selectedLanguage),
                            language: appState.selectedLanguage
                        )

                        ResourceServiceStatusCard(
                            source: resourceService.source,
                            isLoading: resourceService.isLoading,
                            hasResources: !resourceService.resources.isEmpty,
                            language: appState.selectedLanguage
                        )

                        if filteredResources.isEmpty {
                            ResourceLibraryEmptyCard(
                                isSearchResult: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                language: appState.selectedLanguage
                            )
                        } else {
                            if let featuredHymn {
                                NavigationLink {
                                    ChurchResourceDetailView(resource: featuredHymn, language: appState.selectedLanguage)
                                } label: {
                                    FeaturedHymnCard(resource: featuredHymn, language: appState.selectedLanguage)
                                }
                                .buttonStyle(.plain)
                            }

                            if !directoryResources.isEmpty {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(directoryResources) { resource in
                                        NavigationLink {
                                            ChurchResourceDetailView(resource: resource, language: appState.selectedLanguage)
                                        } label: {
                                            ChurchResourceGridCard(resource: resource, language: appState.selectedLanguage)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text(personalToolsTitle)
                                    .font(DesignSystem.Typography.smart(13, weight: .bold, language: appState.selectedLanguage))
                                    .foregroundColor(DesignSystem.Colors.mutedText)
                                    .textCase(.uppercase)

                                ResourceQuickActions(language: appState.selectedLanguage)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            resourceService.loadResources()
        }
    }

    private var personalToolsTitle: String {
        switch appState.selectedLanguage {
        case .chinese: return "我的工具"
        case .english: return "My Tools"
        case .korean: return "나의 도구"
        }
    }
}

private struct FeaturedHymnCard: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: resource.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title.text(for: language))
                        .font(DesignSystem.Typography.smart(18, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(resource.subtitle.text(for: language))
                        .font(DesignSystem.Typography.body(12, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                Text(resource.actionTitle.text(for: language))
                    .font(DesignSystem.Typography.smart(13, weight: .bold, language: language))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(DesignSystem.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignSystem.Colors.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct ResourceQuickActions: View {
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                BibleReaderView(language: language)
            } label: {
                ResourceQuickActionCard(
                    icon: "text.book.closed.fill",
                    title: bibleTitle,
                    subtitle: bibleSubtitle,
                    language: language
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FavoritesView(language: language)
            } label: {
                ResourceQuickActionCard(
                    icon: "heart.text.square.fill",
                    title: favoritesTitle,
                    subtitle: favoritesSubtitle,
                    language: language
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var bibleTitle: String {
        switch language {
        case .chinese: return "圣经阅读"
        case .english: return "Bible Reader"
        case .korean: return "성경 읽기"
        }
    }

    private var bibleSubtitle: String {
        switch language {
        case .chinese: return "按书卷章节阅读"
        case .english: return "Read by book and chapter"
        case .korean: return "권과 장별로 읽기"
        }
    }

    private var favoritesTitle: String {
        switch language {
        case .chinese: return "收藏夹"
        case .english: return "Favorites"
        case .korean: return "즐겨찾기"
        }
    }

    private var favoritesSubtitle: String {
        switch language {
        case .chinese: return "经文和笔记"
        case .english: return "Verses and notes"
        case .korean: return "말씀과 노트"
        }
    }
}

private struct ResourceQuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accentDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DesignSystem.Typography.smart(15, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)

                Text(subtitle)
                    .font(DesignSystem.Typography.body(11, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .padding(14)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct ResourcesLibraryHeader: View {
    let language: CoreModels.VerseLanguage
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedText.Common.resourcesTab.text(for: language))
                    .font(DesignSystem.Typography.smart(23, weight: .bold, language: language, preferLanguageFont: false))
                    .foregroundColor(DesignSystem.Colors.accentDark)

                Text(LocalizedText.Resources.headerSubtitle.text(for: language))
                    .font(DesignSystem.Typography.smart(12, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                appState.cycleLanguage()
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageSwitchTitle)

            VerseUserButtonView()
        }
    }

    private var languageSwitchTitle: String {
        switch language {
        case .chinese: return "切换语言"
        case .english: return "Switch Language"
        case .korean: return "언어 변경"
        }
    }
}

private struct ResourceServiceStatusCard: View {
    let source: ChurchResourceSource
    let isLoading: Bool
    let hasResources: Bool
    let language: CoreModels.VerseLanguage

    var body: some View {
        if isLoading {
            statusRow(
                icon: "arrow.triangle.2.circlepath",
                title: LocalizedText.Resources.loadingTitle.text(for: language),
                message: LocalizedText.Resources.loadingMessage.text(for: language)
            )
        } else if case .localFallback = source {
            statusRow(
                icon: "wifi.slash",
                title: LocalizedText.Resources.fallbackTitle.text(for: language),
                message: LocalizedText.Resources.fallbackMessage.text(for: language)
            )
        } else if !hasResources {
            statusRow(
                icon: "tray",
                title: LocalizedText.Resources.emptyLibraryTitle.text(for: language),
                message: LocalizedText.Resources.emptyLibraryMessage.text(for: language)
            )
        }
    }

    private func statusRow(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accentDark)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignSystem.Colors.cardBackground))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DesignSystem.Typography.smart(14, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(message)
                    .font(DesignSystem.Typography.body(12, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct ResourceSearchField: View {
    @Binding var searchText: String
    let placeholder: String
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.mutedText)

            TextField(placeholder, text: $searchText)
                .font(DesignSystem.Typography.body(15, language: language))
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.mutedText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
    }
}

private struct ChurchResourceGridCard: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: resource.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .frame(width: 26, height: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(resource.title.text(for: language))
                    .font(DesignSystem.Typography.smart(15, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)

                Text(resource.subtitle.text(for: language))
                    .font(DesignSystem.Typography.body(11, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text(LocalizedText.Resources.browse.text(for: language))
                    .font(DesignSystem.Typography.smart(12, weight: .semibold, language: language))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(DesignSystem.Colors.accentDark)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(14)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct ChurchResourceDetailView: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var showingHymnReader = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text(LocalizedText.Common.resourcesTab.text(for: language))
                        }
                        .font(DesignSystem.Typography.smart(15, weight: .semibold, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: resource.icon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accentDark)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(resource.title.text(for: language))
                                .font(DesignSystem.Typography.smart(28, weight: .bold, language: language, preferLanguageFont: false))
                                .foregroundColor(DesignSystem.Colors.primaryText)

                            Text(resource.category.title(for: language))
                                .font(DesignSystem.Typography.smart(13, weight: .semibold, language: language))
                                .foregroundColor(DesignSystem.Colors.accentDark)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(DesignSystem.Colors.cardBackground))
                        }

                        Text(resource.description.text(for: language))
                            .font(DesignSystem.Typography.body(16, language: language))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(5)

                        if let content = resource.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(content)
                                .font(DesignSystem.Typography.body(15, language: language))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .lineSpacing(4)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DesignSystem.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if resource.category == .hymnbook {
                            Button {
                                showingHymnReader = true
                            } label: {
                                ResourceActionLabel(
                                    title: hymnActionTitle,
                                    isExternal: false,
                                    language: language,
                                    systemImage: "music.note"
                                )
                            }
                            .buttonStyle(.plain)
                        } else if let url = resource.primaryURL {
                            Link(destination: url) {
                                ResourceActionLabel(
                                    title: resource.actionTitle.text(for: language),
                                    isExternal: true,
                                    language: language
                                )
                            }
                        } else {
                            ResourceActionLabel(
                                title: LocalizedText.Resources.detailOnly.text(for: language),
                                isExternal: false,
                                language: language
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingHymnReader) {
            HymnReaderView(resource: resource, language: language)
        }
    }

    private var hymnActionTitle: String {
        switch language {
        case .chinese: return "打开诗歌本"
        case .english: return "Open Hymnbook"
        case .korean: return "찬송가 열기"
        }
    }
}

private struct ResourceActionLabel: View {
    let title: String
    let isExternal: Bool
    let language: CoreModels.VerseLanguage
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(DesignSystem.Typography.smart(15, weight: .bold, language: language))
                .lineLimit(2)

            Spacer()

            Image(systemName: systemImage ?? (isExternal ? "arrow.up.right" : "checkmark.circle"))
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(isExternal ? .white : DesignSystem.Colors.accentDark)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                .fill(isExternal ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                .stroke(isExternal ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct HymnReaderView: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .frame(width: 40, height: 40)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DesignSystem.Colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(backTitle)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(resource.title.text(for: language))
                            .font(DesignSystem.Typography.smart(21, weight: .bold, language: language))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(1)

                        Text(readerSubtitle)
                            .font(DesignSystem.Typography.body(12, language: language))
                            .foregroundColor(DesignSystem.Colors.mutedText)
                    }

                    Spacer()
                }

                if let audioURL = resource.audioURL {
                    HymnAudioPlayerCard(url: audioURL, language: language)
                }

                if let pdfURL = resource.pdfURL {
                    RemotePDFReader(url: pdfURL, language: language)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignSystem.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                } else {
                    ContentUnavailableView(
                        pdfUnavailableTitle,
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(pdfUnavailableMessage)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
    }

    private var backTitle: String {
        switch language {
        case .chinese: return "返回"
        case .english: return "Back"
        case .korean: return "뒤로"
        }
    }

    private var readerSubtitle: String {
        if resource.audioURL != nil, resource.pdfURL != nil {
            switch language {
            case .chinese: return "播放音频时可以继续阅读和翻页"
            case .english: return "Keep listening while you read and turn pages"
            case .korean: return "오디오를 들으며 계속 읽고 페이지를 넘길 수 있습니다"
            }
        }

        if resource.audioURL != nil {
            switch language {
            case .chinese: return "音频可以独立播放，乐谱上传后会同时显示"
            case .english: return "Audio is ready; sheet music will appear here when added"
            case .korean: return "오디오는 재생할 수 있으며 악보가 추가되면 함께 표시됩니다"
            }
        }

        if resource.pdfURL != nil {
            switch language {
            case .chinese: return "阅读和翻页；音频上传后可同时播放"
            case .english: return "Read and turn pages; audio will play here when added"
            case .korean: return "악보를 읽고 넘기며 오디오가 추가되면 함께 재생할 수 있습니다"
            }
        }

        switch language {
        case .chinese: return "PDF 乐谱与音频会在同一个阅读页面中使用"
        case .english: return "PDF sheet music and audio share one reading screen"
        case .korean: return "PDF 악보와 오디오를 한 읽기 화면에서 함께 사용합니다"
        }
    }

    private var pdfUnavailableTitle: String {
        switch language {
        case .chinese: return "暂未提供乐谱"
        case .english: return "Sheet music unavailable"
        case .korean: return "악보가 아직 없습니다"
        }
    }

    private var pdfUnavailableMessage: String {
        if resource.audioURL == nil {
            switch language {
            case .chinese: return "管理员添加 PDF 乐谱或音频后，会显示在这个阅读页面中。"
            case .english: return "PDF sheet music or audio will appear here after an administrator adds it."
            case .korean: return "관리자가 PDF 악보나 오디오를 추가하면 이 읽기 화면에 표시됩니다."
            }
        }

        switch language {
        case .chinese: return "音频仍然可以播放；管理员上传 PDF 后会显示在这里。"
        case .english: return "Audio remains available. The PDF will appear here after an administrator uploads it."
        case .korean: return "오디오는 계속 재생할 수 있습니다. 관리자가 PDF를 올리면 여기에 표시됩니다."
        }
    }
}

private struct HymnAudioPlayerCard: View {
    @StateObject private var playback: HymnAudioPlayback
    let language: CoreModels.VerseLanguage

    init(url: URL, language: CoreModels.VerseLanguage) {
        _playback = StateObject(wrappedValue: HymnAudioPlayback(url: url))
        self.language = language
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    playback.togglePlayback()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playback.isPlaying ? pauseTitle : playTitle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(nowPlayingTitle)
                        .font(DesignSystem.Typography.smart(15, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(nowPlayingSubtitle)
                        .font(DesignSystem.Typography.body(12, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Text(playback.formatted(playback.currentTime))
                Slider(
                    value: Binding(
                        get: { playback.currentTime },
                        set: { playback.seek(to: $0) }
                    ),
                    in: 0...max(playback.duration, 1)
                )
                .tint(DesignSystem.Colors.accent)
                Text(playback.formatted(playback.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(DesignSystem.Colors.mutedText)

            if let errorMessage = playback.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(DesignSystem.Typography.body(12, language: language))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .onDisappear { playback.pause() }
    }

    private var nowPlayingTitle: String {
        switch language {
        case .chinese: return "诗歌音频"
        case .english: return "Hymn audio"
        case .korean: return "찬송가 오디오"
        }
    }

    private var nowPlayingSubtitle: String {
        switch language {
        case .chinese: return "播放不会影响下方 PDF 阅读"
        case .english: return "Playback continues while you read the PDF below"
        case .korean: return "아래 PDF를 읽는 동안 재생이 계속됩니다"
        }
    }

    private var playTitle: String {
        switch language {
        case .chinese: return "播放"
        case .english: return "Play"
        case .korean: return "재생"
        }
    }

    private var pauseTitle: String {
        switch language {
        case .chinese: return "暂停"
        case .english: return "Pause"
        case .korean: return "일시 정지"
        }
    }
}

private final class HymnAudioPlayback: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?

    private let player: AVPlayer
    private var timeObserver: Any?

    init(url: URL) {
        player = AVPlayer(url: url)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite { currentTime = max(seconds, 0) }
            if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite {
                duration = max(itemDuration, 0)
            }
            if player.currentItem?.status == .failed {
                errorMessage = player.currentItem?.error?.localizedDescription ?? "Audio unavailable"
                isPlaying = false
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            errorMessage = nil
            player.play()
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let target = min(max(seconds, 0), max(duration, 0))
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func formatted(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let value = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct RemotePDFReader: View {
    let url: URL
    let language: CoreModels.VerseLanguage
    @State private var pdfData: Data?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let pdfData {
                PDFKitDocumentView(data: pdfData)
            } else if let errorMessage {
                ContentUnavailableView(
                    loadFailedTitle,
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(DesignSystem.Colors.accent)
                    Text(loadingTitle)
                        .font(DesignSystem.Typography.body(13, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
        .task(id: url) { await loadPDF() }
    }

    @MainActor
    private func loadPDF() async {
        pdfData = nil
        errorMessage = nil
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                throw URLError(.badServerResponse)
            }
            guard PDFDocument(data: data) != nil else { throw URLError(.cannotDecodeContentData) }
            pdfData = data
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var loadingTitle: String {
        switch language {
        case .chinese: return "正在加载乐谱…"
        case .english: return "Loading sheet music…"
        case .korean: return "악보를 불러오는 중…"
        }
    }

    private var loadFailedTitle: String {
        switch language {
        case .chinese: return "无法打开乐谱"
        case .english: return "Couldn't open sheet music"
        case .korean: return "악보를 열 수 없습니다"
        }
    }
}

private struct PDFKitDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .secondarySystemBackground
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard pdfView.document?.dataRepresentation() != data else { return }
        pdfView.document = PDFDocument(data: data)
    }
}

private struct ResourceLibraryEmptyCard: View {
    let isSearchResult: Bool
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: isSearchResult ? "magnifyingglass" : "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accentDark)

            Text(isSearchResult ? LocalizedText.Resources.noResultsTitle.text(for: language) : LocalizedText.Resources.emptyLibraryTitle.text(for: language))
                .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(isSearchResult ? LocalizedText.Resources.noResultsMessage.text(for: language) : LocalizedText.Resources.emptyLibraryMessage.text(for: language))
                .font(DesignSystem.Typography.body(14, language: language))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}
