import SwiftUI

struct FavoritesView: View {
    let language: CoreModels.VerseLanguage
    @StateObject private var favoriteService = FavoriteService.shared
    @Environment(\.dismiss) private var dismiss

    private var groupedFavorites: [(dateKey: String, favorites: [FavoriteRecord])] {
        let grouped = Dictionary(grouping: favoriteService.favorites, by: \.dateKey)
        return grouped
            .map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.0 > $1.0 }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if groupedFavorites.isEmpty {
                        emptyCard
                    } else {
                        ForEach(groupedFavorites, id: \.dateKey) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(sectionTitle(for: group.dateKey))
                                    .font(DesignSystem.Typography.smart(14, weight: .bold, language: language))
                                    .foregroundColor(DesignSystem.Colors.accentDark)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 10) {
                                    ForEach(group.favorites) { favorite in
                                        FavoriteRow(favorite: favorite, note: favoriteService.note(for: favorite.targetType, targetId: favorite.targetId), language: language)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            favoriteService.loadLocal()
            favoriteService.syncFromFirebaseIfSignedIn()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(DesignSystem.Colors.surface))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DesignSystem.Typography.smart(26, weight: .bold, language: language, preferLanguageFont: false))
                    .foregroundColor(DesignSystem.Colors.accentDark)

                Text(subtitle)
                    .font(DesignSystem.Typography.body(12, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            }

            Spacer()
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accentDark)

            Text(emptyTitle)
                .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(emptyMessage)
                .font(DesignSystem.Typography.body(14, language: language))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)
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

    private func sectionTitle(for dateKey: String) -> String {
        let todayKey = FavoriteService.dateKey(for: Date())
        let yesterdayKey = FavoriteService.dateKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        if dateKey == todayKey {
            switch language {
            case .chinese: return "今天"
            case .english: return "Today"
            case .korean: return "오늘"
            }
        }
        if dateKey == yesterdayKey {
            switch language {
            case .chinese: return "昨天"
            case .english: return "Yesterday"
            case .korean: return "어제"
            }
        }
        return dateKey
    }

    private var title: String {
        switch language {
        case .chinese: return "收藏夹"
        case .english: return "Favorites"
        case .korean: return "즐겨찾기"
        }
    }

    private var subtitle: String {
        switch language {
        case .chinese: return "按日期保存经文、资源和笔记"
        case .english: return "Saved verses, resources, and notes by date"
        case .korean: return "날짜별로 저장한 말씀, 자료와 노트"
        }
    }

    private var emptyTitle: String {
        switch language {
        case .chinese: return "还没有收藏"
        case .english: return "No Favorites Yet"
        case .korean: return "아직 저장한 항목이 없습니다"
        }
    }

    private var emptyMessage: String {
        switch language {
        case .chinese: return "在每日经文或圣经阅读器中点收藏后，会按日期显示在这里。"
        case .english: return "Save verses from Daily Verse or the Bible Reader, and they will appear here by date."
        case .korean: return "매일 말씀이나 성경 읽기에서 저장하면 날짜별로 여기에 표시됩니다."
        }
    }
}

private struct FavoriteRow: View {
    let favorite: FavoriteRecord
    let note: NoteRecord?
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accentDark)
                .frame(width: 32, height: 32)
                .background(Circle().fill(DesignSystem.Colors.cardBackground))

            VStack(alignment: .leading, spacing: 6) {
                Text(favorite.title.text(for: language))
                    .font(DesignSystem.Typography.smart(15, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)

                Text(favorite.snippet.text(for: language))
                    .font(DesignSystem.Typography.body(13, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(3)

                if let note, !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "note.text")
                            .font(.system(size: 11, weight: .semibold))
                        Text(note.body)
                            .lineLimit(1)
                    }
                    .font(DesignSystem.Typography.body(12, language: language))
                    .foregroundColor(DesignSystem.Colors.accentDark)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch favorite.targetType {
        case .verse: return "text.book.closed"
        case .resource: return "folder"
        case .pdfPage: return "doc.richtext"
        case .connectPost: return "bubble.left.and.bubble.right"
        case .newsletter: return "newspaper"
        }
    }
}
