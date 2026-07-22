import SwiftUI

struct ChurchResourcesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var resourceService = ChurchResourceService()
    @State private var searchText = ""
    @State private var selectedCategory: ChurchResourceCategory = .all

    private var categories: [ChurchResourceCategory] {
        [.all] + ChurchResourceCategory.libraryCategories
    }

    private var filteredResources: [ChurchResource] {
        resourceService.filteredResources(
            searchText: searchText,
            selectedCategory: selectedCategory,
            language: appState.selectedLanguage
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ResourcesLibraryHeader(language: appState.selectedLanguage)

                        ResourceServiceStatusCard(
                            source: resourceService.source,
                            isLoading: resourceService.isLoading,
                            hasResources: !resourceService.resources.isEmpty,
                            language: appState.selectedLanguage
                        )

                        ResourceQuickActions(language: appState.selectedLanguage)

                        ResourceSearchField(
                            searchText: $searchText,
                            placeholder: LocalizedText.Resources.searchPlaceholder.text(for: appState.selectedLanguage),
                            language: appState.selectedLanguage
                        )

                        ResourceCategoryFilter(
                            categories: categories,
                            selectedCategory: $selectedCategory,
                            language: appState.selectedLanguage
                        )

                        if let featuredResource = resourceService.resources.first {
                            FeaturedResourceCard(
                                resource: featuredResource,
                                language: appState.selectedLanguage
                            )
                        }

                        if filteredResources.isEmpty {
                            ResourceLibraryEmptyCard(
                                isSearchResult: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory != .all,
                                language: appState.selectedLanguage
                            )
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(filteredResources) { resource in
                                    NavigationLink {
                                        ChurchResourceDetailView(resource: resource, language: appState.selectedLanguage)
                                    } label: {
                                        ChurchResourceGridCard(resource: resource, language: appState.selectedLanguage)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            resourceService.loadResources()
        }
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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(DesignSystem.Colors.accent)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedText.Common.resourcesTab.text(for: language))
                    .font(DesignSystem.Typography.smart(24, weight: .bold, language: language, preferLanguageFont: false))
                    .foregroundColor(DesignSystem.Colors.accentDark)

                Text(LocalizedText.Resources.headerSubtitle.text(for: language))
                    .font(DesignSystem.Typography.smart(12, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            VerseUserButtonView()
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

private struct ResourceCategoryFilter: View {
    let categories: [ChurchResourceCategory]
    @Binding var selectedCategory: ChurchResourceCategory
    let language: CoreModels.VerseLanguage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.title(for: language))
                            .font(DesignSystem.Typography.smart(13, weight: .semibold, language: language))
                            .foregroundColor(selectedCategory == category ? .white : DesignSystem.Colors.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? DesignSystem.Colors.accent : DesignSystem.Colors.surface)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedCategory == category ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FeaturedResourceCard: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage

    var body: some View {
        NavigationLink {
            ChurchResourceDetailView(resource: resource, language: language)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: resource.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accentDark)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.title.text(for: language))
                            .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(resource.subtitle.text(for: language))
                            .font(DesignSystem.Typography.body(13, language: language))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 6) {
                    Text(resource.actionTitle.text(for: language))
                        .font(DesignSystem.Typography.smart(13, weight: .bold, language: language))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                        .fill(DesignSystem.Colors.accent)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ChurchResourceGridCard: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: resource.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accentDark)
                .frame(width: 32, height: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(resource.title.text(for: language))
                    .font(DesignSystem.Typography.smart(16, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)

                Text(resource.subtitle.text(for: language))
                    .font(DesignSystem.Typography.body(12, language: language))
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
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct ChurchResourceDetailView: View {
    let resource: ChurchResource
    let language: CoreModels.VerseLanguage
    @Environment(\.dismiss) private var dismiss

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

                        if let url = resource.primaryURL {
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
    }
}

private struct ResourceActionLabel: View {
    let title: String
    let isExternal: Bool
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(DesignSystem.Typography.smart(15, weight: .bold, language: language))
                .lineLimit(2)

            Spacer()

            Image(systemName: isExternal ? "arrow.up.right" : "checkmark.circle")
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
