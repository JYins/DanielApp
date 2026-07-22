import SwiftUI

struct BibleReaderView: View {
    let language: CoreModels.VerseLanguage
    @StateObject private var favoriteService = FavoriteService.shared
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var books: [String] = []
    @State private var chapters: [Int] = []
    @State private var selectedBook = "Genesis"
    @State private var selectedChapter = 1
    @State private var verses: [MultiLanguageVerse] = []
    @State private var editingVerse: MultiLanguageVerse?
    @State private var noteText = ""
    @State private var showingLoginRequired = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                selectorBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(verses) { verse in
                            BibleVerseRow(
                                verse: verse,
                                language: language,
                                isFavorite: favoriteService.isFavorite(targetType: .verse, targetId: verse.reference),
                                hasNote: favoriteService.note(for: .verse, targetId: verse.reference) != nil,
                                onFavorite: { toggleFavorite(verse) },
                                onNote: { openNote(verse) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadInitialData()
            favoriteService.loadLocal()
            favoriteService.syncFromFirebaseIfSignedIn()
        }
        .sheet(item: $editingVerse) { verse in
            BibleVerseNoteEditor(
                verse: verse,
                language: language,
                noteText: $noteText,
                onSave: { saveNote(for: verse) }
            )
        }
        .alert(loginRequiredTitle, isPresented: $showingLoginRequired) {
            Button(loginRequiredOK, role: .cancel) {}
        } message: {
            Text(loginRequiredMessage)
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
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var selectorBar: some View {
        HStack(spacing: 10) {
            Picker(bookPickerTitle, selection: $selectedBook) {
                ForEach(books, id: \.self) { book in
                    Text(localizedBookName(book)).tag(book)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedBook) { _, newBook in
                chapters = VerseDataService.shared.getAvailableChapters(forBook: newBook)
                selectedChapter = chapters.first ?? 1
                loadVerses()
            }

            Picker(chapterPickerTitle, selection: $selectedChapter) {
                ForEach(chapters, id: \.self) { chapter in
                    Text(chapterTitle(chapter)).tag(chapter)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedChapter) { _, _ in
                loadVerses()
            }
        }
        .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private func loadInitialData() {
        books = VerseDataService.shared.getBibleBookNames()
        selectedBook = books.first ?? "Genesis"
        chapters = VerseDataService.shared.getAvailableChapters(forBook: selectedBook)
        selectedChapter = chapters.first ?? 1
        loadVerses()
    }

    private func loadVerses() {
        verses = VerseDataService.shared.getVerses(forBook: selectedBook, chapter: selectedChapter)
    }

    private func toggleFavorite(_ verse: MultiLanguageVerse) {
        favoriteService.toggleFavorite(favoriteService.makeVerseFavorite(verse: verse))
    }

    private func openNote(_ verse: MultiLanguageVerse) {
        guard authManager.currentAuthenticatedUserID != nil else {
            showingLoginRequired = true
            return
        }
        noteText = favoriteService.note(for: .verse, targetId: verse.reference)?.body ?? ""
        editingVerse = verse
    }

    private func saveNote(for verse: MultiLanguageVerse) {
        _ = favoriteService.saveNote(
            targetType: .verse,
            targetId: verse.reference,
            reference: verse.reference,
            body: noteText,
            language: language
        )
        editingVerse = nil
        noteText = ""
    }

    private func localizedBookName(_ englishBookName: String) -> String {
        if language == .english {
            return englishBookName
        }

        let localizedReference = CoreModels.VerseLanguage.localizeReference("\(englishBookName) 1:1", to: language)
        let localizedComponents = localizedReference.components(separatedBy: " ")
        if localizedComponents.count >= 2 {
            return localizedComponents.dropLast().joined(separator: " ")
        }
        return englishBookName
    }

    private func chapterTitle(_ chapter: Int) -> String {
        switch language {
        case .chinese: return "第 \(chapter) 章"
        case .english: return "Chapter \(chapter)"
        case .korean: return "\(chapter)장"
        }
    }

    private var title: String {
        switch language {
        case .chinese: return "圣经阅读器"
        case .english: return "Bible Reader"
        case .korean: return "성경 읽기"
        }
    }

    private var subtitle: String {
        switch language {
        case .chinese: return "选择书卷和章节，收藏经文并记录笔记"
        case .english: return "Choose a book and chapter, save verses, and write notes"
        case .korean: return "성경 권과 장을 선택하고 말씀을 저장하며 노트하세요"
        }
    }

    private var bookPickerTitle: String {
        switch language {
        case .chinese: return "书卷"
        case .english: return "Book"
        case .korean: return "성경 권"
        }
    }

    private var chapterPickerTitle: String {
        switch language {
        case .chinese: return "章节"
        case .english: return "Chapter"
        case .korean: return "장"
        }
    }

    private var loginRequiredTitle: String {
        switch language {
        case .chinese: return "需要登录"
        case .english: return "Sign In Required"
        case .korean: return "로그인이 필요합니다"
        }
    }

    private var loginRequiredMessage: String {
        switch language {
        case .chinese: return "未登录可以阅读和本地收藏；写笔记需要登录，以便保存到你的账户。"
        case .english: return "You can read and save local favorites while signed out. Notes require sign-in so they can be saved to your account."
        case .korean: return "로그아웃 상태에서도 읽기와 로컬 저장은 가능합니다. 노트는 계정에 저장하기 위해 로그인이 필요합니다."
        }
    }

    private var loginRequiredOK: String {
        switch language {
        case .chinese: return "好的"
        case .english: return "OK"
        case .korean: return "확인"
        }
    }
}

private struct BibleVerseRow: View {
    let verse: MultiLanguageVerse
    let language: CoreModels.VerseLanguage
    let isFavorite: Bool
    let hasNote: Bool
    let onFavorite: () -> Void
    let onNote: () -> Void

    private var verseText: String {
        switch language {
        case .chinese: return verse.cn
        case .english: return verse.en
        case .korean: return verse.kr
        }
    }

    private var verseNumber: String {
        verse.reference.split(separator: ":").last.map(String.init) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(verseNumber)
                    .font(DesignSystem.Typography.smart(13, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.accentDark)
                    .frame(width: 28, alignment: .leading)

                Text(verseText)
                    .font(DesignSystem.Typography.body(16, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: onFavorite) {
                    Label(favoriteTitle, systemImage: isFavorite ? "heart.fill" : "heart")
                }

                Button(action: onNote) {
                    Label(noteTitle, systemImage: hasNote ? "note.text" : "square.and.pencil")
                }
            }
            .font(DesignSystem.Typography.smart(12, weight: .semibold, language: language))
            .foregroundColor(DesignSystem.Colors.accentDark)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private var favoriteTitle: String {
        switch language {
        case .chinese: return isFavorite ? "已收藏" : "收藏"
        case .english: return isFavorite ? "Saved" : "Save"
        case .korean: return isFavorite ? "저장됨" : "저장"
        }
    }

    private var noteTitle: String {
        switch language {
        case .chinese: return hasNote ? "查看笔记" : "写笔记"
        case .english: return hasNote ? "View Note" : "Note"
        case .korean: return hasNote ? "노트 보기" : "노트"
        }
    }
}

struct BibleVerseNoteEditor: View {
    let verse: MultiLanguageVerse
    let language: CoreModels.VerseLanguage
    @Binding var noteText: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text(verse.reference)
                        .font(DesignSystem.Typography.smart(18, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.accentDark)

                    TextEditor(text: $noteText)
                        .font(DesignSystem.Typography.body(16, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .padding(12)
                        .frame(minHeight: 220)
                        .background(DesignSystem.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }

    private var title: String {
        switch language {
        case .chinese: return "经文笔记"
        case .english: return "Verse Note"
        case .korean: return "말씀 노트"
        }
    }

    private var cancelTitle: String {
        switch language {
        case .chinese: return "取消"
        case .english: return "Cancel"
        case .korean: return "취소"
        }
    }

    private var saveTitle: String {
        switch language {
        case .chinese: return "保存"
        case .english: return "Save"
        case .korean: return "저장"
        }
    }
}
