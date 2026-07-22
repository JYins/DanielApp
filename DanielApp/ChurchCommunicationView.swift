import SwiftUI

struct ChurchCommunicationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = NewsletterViewModel()
    @State private var selectedSection: ConnectSection = .announcements
    @State private var showingLogin = false

    private var language: CoreModels.VerseLanguage {
        appState.selectedLanguage
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ConnectHeader(language: language)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                ConnectSectionPicker(
                    selectedSection: $selectedSection,
                    language: language
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Group {
                    switch selectedSection {
                    case .announcements:
                        gatedNewsletterContent(mode: .announcement)
                    case .newsletter:
                        gatedNewsletterContent(mode: .newsletter)
                    case .messages:
                        MessagesComingSoonView(language: language)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: loadContentIfAllowed)
        .onChange(of: authManager.authState) { _, _ in
            loadContentIfAllowed()
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func gatedNewsletterContent(mode: ConnectNewsletterMode) -> some View {
        if authManager.hasContentAccess() {
            ConnectNewsletterList(
                viewModel: viewModel,
                mode: mode,
                language: language
            )
        } else {
            VStack(spacing: 0) {
                ConnectAccessCard(
                    showingLogin: $showingLogin,
                    mode: mode,
                    language: language
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer(minLength: 0)
            }
        }
    }

    private func loadContentIfAllowed() {
        if authManager.hasContentAccess() {
            viewModel.loadNewsletters()
        }
    }
}

private enum ConnectSection: CaseIterable {
    case announcements
    case newsletter
    case messages

    var icon: String {
        switch self {
        case .announcements: return "megaphone"
        case .newsletter: return "newspaper"
        case .messages: return "message"
        }
    }

    func title(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .announcements:
            return ConnectCopy.announcementsTab.text(for: language)
        case .newsletter:
            return ConnectCopy.newsletterTab.text(for: language)
        case .messages:
            return ConnectCopy.messagesTab.text(for: language)
        }
    }
}

private enum ConnectNewsletterMode {
    case announcement
    case newsletter

    var icon: String {
        switch self {
        case .announcement: return "megaphone"
        case .newsletter: return "newspaper"
        }
    }

    func emptyTitle(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .announcement:
            return ConnectCopy.emptyAnnouncementsTitle.text(for: language)
        case .newsletter:
            return ConnectCopy.emptyNewsletterTitle.text(for: language)
        }
    }

    func emptyMessage(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .announcement:
            return ConnectCopy.emptyAnnouncementsMessage.text(for: language)
        case .newsletter:
            return ConnectCopy.emptyNewsletterMessage.text(for: language)
        }
    }
}

private enum ConnectCopy {
    case headerSubtitle
    case announcementsTab
    case newsletterTab
    case messagesTab
    case announcementEyebrow
    case announcementSource
    case newsletterEyebrow
    case newsletterImageCount
    case emptyAnnouncementsTitle
    case emptyAnnouncementsMessage
    case emptyNewsletterTitle
    case emptyNewsletterMessage
    case accessTitle
    case accessAnnouncementsMessage
    case accessNewsletterMessage
    case signIn
    case errorTitle
    case errorMessage
    case retry
    case messagesTitle
    case messagesMessage
    case messagesDetail
    case messagesStatus
    case messagesPreviewOne
    case messagesPreviewTwo

    func text(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .headerSubtitle:
            switch language {
            case .chinese: return "教会公告、周报与分堂沟通"
            case .english: return "Church announcements, newsletters, and branch communication"
            case .korean: return "교회 공지, 주보와 지교회 소통"
            }
        case .announcementsTab:
            switch language {
            case .chinese: return "公告"
            case .english: return "Announcements"
            case .korean: return "공지"
            }
        case .newsletterTab:
            switch language {
            case .chinese: return "周报"
            case .english: return "Newsletter"
            case .korean: return "주보"
            }
        case .messagesTab:
            switch language {
            case .chinese: return "消息"
            case .english: return "Messages"
            case .korean: return "메시지"
            }
        case .announcementEyebrow:
            switch language {
            case .chinese: return "教会公告"
            case .english: return "Church Announcement"
            case .korean: return "교회 공지"
            }
        case .announcementSource:
            switch language {
            case .chinese: return "来自现有周报内容"
            case .english: return "From the existing newsletter stream"
            case .korean: return "기존 주보 소식에서 가져옴"
            }
        case .newsletterEyebrow:
            switch language {
            case .chinese: return "每周 Newsletter"
            case .english: return "Weekly Newsletter"
            case .korean: return "주간 주보"
            }
        case .newsletterImageCount:
            switch language {
            case .chinese: return "张图片"
            case .english: return "images"
            case .korean: return "장 이미지"
            }
        case .emptyAnnouncementsTitle:
            switch language {
            case .chinese: return "暂无公告"
            case .english: return "No Announcements Yet"
            case .korean: return "아직 공지가 없습니다"
            }
        case .emptyAnnouncementsMessage:
            switch language {
            case .chinese: return "教会公告和重要提醒发布后会显示在这里。"
            case .english: return "Church announcements and important reminders will appear here after publication."
            case .korean: return "교회 공지와 중요한 알림이 게시되면 여기에 표시됩니다."
            }
        case .emptyNewsletterTitle:
            switch language {
            case .chinese: return "暂无周报"
            case .english: return "No Newsletter Yet"
            case .korean: return "아직 주보가 없습니다"
            }
        case .emptyNewsletterMessage:
            switch language {
            case .chinese: return "每周 Newsletter 发布后会显示在这里。"
            case .english: return "Weekly newsletters will appear here after publication."
            case .korean: return "주간 주보가 게시되면 여기에 표시됩니다."
            }
        case .accessTitle:
            switch language {
            case .chinese: return "登录后查看 Connect"
            case .english: return "Sign in for Connect"
            case .korean: return "로그인 후 커넥트 보기"
            }
        case .accessAnnouncementsMessage:
            switch language {
            case .chinese: return "公告沿用现有内容权限。登录并通过教会确认后，就可以查看发布给成员的沟通内容。"
            case .english: return "Announcements use the existing content access model. Sign in and complete church approval to view member communication."
            case .korean: return "공지는 기존 콘텐츠 권한을 사용합니다. 로그인 후 교회 승인이 완료되면 멤버 공지를 볼 수 있습니다."
            }
        case .accessNewsletterMessage:
            switch language {
            case .chinese: return "周报沿用现有内容权限。登录并通过教会确认后，就可以查看每周发布的教会通讯。"
            case .english: return "Newsletters use the existing content access model. Sign in and complete church approval to view weekly church updates."
            case .korean: return "주보는 기존 콘텐츠 권한을 사용합니다. 로그인 후 교회 승인이 완료되면 매주 교회 소식을 볼 수 있습니다."
            }
        case .signIn:
            switch language {
            case .chinese: return "登录"
            case .english: return "Sign In"
            case .korean: return "로그인"
            }
        case .errorTitle:
            switch language {
            case .chinese: return "加载出错"
            case .english: return "Could Not Load"
            case .korean: return "불러오지 못했습니다"
            }
        case .errorMessage:
            switch language {
            case .chinese: return "暂时无法读取教会通讯，请稍后再试。"
            case .english: return "Church communication could not be loaded right now. Please try again soon."
            case .korean: return "지금은 교회 소식을 불러올 수 없습니다. 잠시 후 다시 시도해 주세요."
            }
        case .retry:
            switch language {
            case .chinese: return "重试"
            case .english: return "Retry"
            case .korean: return "다시 시도"
            }
        case .messagesTitle:
            switch language {
            case .chinese: return "消息功能准备中"
            case .english: return "Messages Coming Soon"
            case .korean: return "메시지 기능 준비 중"
            }
        case .messagesMessage:
            switch language {
            case .chinese: return "分堂和小组消息会在教会访问权限配置完成后开放。"
            case .english: return "Branch and group messages will be available after church access is configured."
            case .korean: return "지교회와 그룹 메시지는 교회 접근 권한이 구성된 후 사용할 수 있습니다."
            }
        case .messagesDetail:
            switch language {
            case .chinese: return "第一版先保留清晰入口，避免在区域、分堂和小组权限确定前接入实时聊天。"
            case .english: return "This first version keeps the entry ready while real-time chat waits for branch and group access rules."
            case .korean: return "첫 버전에서는 입구를 준비해 두고, 실시간 채팅은 지교회와 그룹 권한 규칙 이후에 연결합니다."
            }
        case .messagesStatus:
            switch language {
            case .chinese: return "访问配置后开放"
            case .english: return "Available after access setup"
            case .korean: return "접근 설정 후 사용 가능"
            }
        case .messagesPreviewOne:
            switch language {
            case .chinese: return "主日服事提醒、代祷和小组沟通会集中在这里。"
            case .english: return "Serving reminders, prayer needs, and group updates will live here."
            case .korean: return "섬김 알림, 기도 제목, 그룹 소식이 이곳에 모입니다."
            }
        case .messagesPreviewTwo:
            switch language {
            case .chinese: return "未来会按教会访问权限显示相关对话。"
            case .english: return "Future conversations will follow church access permissions."
            case .korean: return "향후 대화는 교회 접근 권한에 따라 표시됩니다."
            }
        }
    }
}

private struct ConnectHeader: View {
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedText.Common.communicationTab.text(for: language))
                    .font(DesignSystem.Typography.smart(26, weight: .bold, language: language, preferLanguageFont: false))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(ConnectCopy.headerSubtitle.text(for: language))
                    .font(DesignSystem.Typography.smart(13, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            VerseUserButtonView()
        }
    }
}

private struct ConnectSectionPicker: View {
    @Binding var selectedSection: ConnectSection
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ConnectSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 13, weight: .semibold))

                        Text(section.title(for: language))
                            .font(DesignSystem.Typography.smart(12, weight: .semibold, language: language))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }
                    .foregroundColor(selectedSection == section ? .white : DesignSystem.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedSection == section ? DesignSystem.Colors.accent : DesignSystem.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedSection == section ? DesignSystem.Colors.accent : DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ConnectNewsletterList: View {
    @ObservedObject var viewModel: NewsletterViewModel
    let mode: ConnectNewsletterMode
    let language: CoreModels.VerseLanguage

    var body: some View {
        Group {
            if viewModel.isLoading {
                ConnectLoadingView(mode: mode, language: language)
            } else if viewModel.errorMessage != nil {
                ConnectErrorCard(retry: viewModel.loadNewsletters, language: language)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            } else if viewModel.newsletters.isEmpty {
                ConnectEmptyCard(
                    icon: mode.icon,
                    title: mode.emptyTitle(for: language),
                    message: mode.emptyMessage(for: language),
                    language: language
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.newsletters) { newsletter in
                            if mode == .announcement {
                                ConnectAnnouncementCard(newsletter: newsletter, language: language)
                            } else {
                                ConnectWeeklyNewsletterCard(newsletter: newsletter, language: language)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct ConnectLoadingView: View {
    let mode: ConnectNewsletterMode
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.accent.opacity(0.18))
                            .frame(width: 92, height: 12)

                        Spacer()
                    }

                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Colors.border.opacity(0.55))
                        .frame(height: mode == .announcement ? 18 : 64)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Colors.border.opacity(0.4))
                        .frame(width: 160, height: 12)
                }
                .padding(18)
                .background(DesignSystem.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .accessibilityLabel(mode.emptyTitle(for: language))
    }
}

private struct ConnectAnnouncementCard: View {
    let newsletter: Newsletter
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.accent.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accentDark)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(ConnectCopy.announcementEyebrow.text(for: language))
                        .font(DesignSystem.Typography.smart(12, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.accentDark)

                    Text(newsletter.caption.text(for: language))
                        .font(DesignSystem.Typography.body(15, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineSpacing(4)
                        .lineLimit(4)
                }
            }

            HStack(spacing: 8) {
                Text(DateFormatter.newsletterFormatter.string(from: newsletter.publishDate.dateValue()))
                    .font(DesignSystem.Typography.smart(12, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)

                Circle()
                    .fill(DesignSystem.Colors.border)
                    .frame(width: 4, height: 4)

                Text(ConnectCopy.announcementSource.text(for: language))
                    .font(DesignSystem.Typography.smart(12, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(18)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct ConnectWeeklyNewsletterCard: View {
    let newsletter: Newsletter
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let firstImageURL = newsletter.image_urls.first, let url = URL(string: firstImageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        newsletterImageFallback
                    } else {
                        Rectangle()
                            .fill(DesignSystem.Colors.cardBackground)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                            )
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(ConnectCopy.newsletterEyebrow.text(for: language))
                        .font(DesignSystem.Typography.smart(12, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.accentDark)

                    Spacer()

                    if newsletter.image_urls.count > 1 {
                        Text("\(newsletter.image_urls.count) \(ConnectCopy.newsletterImageCount.text(for: language))")
                            .font(DesignSystem.Typography.smart(11, weight: .medium, language: language))
                            .foregroundColor(DesignSystem.Colors.mutedText)
                            .lineLimit(1)
                    }
                }

                Text(newsletter.caption.text(for: language))
                    .font(DesignSystem.Typography.body(15, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineSpacing(4)
                    .lineLimit(5)

                Text(DateFormatter.newsletterFormatter.string(from: newsletter.publishDate.dateValue()))
                    .font(DesignSystem.Typography.smart(12, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private var newsletterImageFallback: some View {
        Rectangle()
            .fill(DesignSystem.Colors.cardBackground)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            )
    }
}

private struct ConnectAccessCard: View {
    @Binding var showingLogin: Bool
    let mode: ConnectNewsletterMode
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignSystem.Colors.accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accentDark)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(ConnectCopy.accessTitle.text(for: language))
                        .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(message)
                        .font(DesignSystem.Typography.body(15, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineSpacing(4)
                }
            }

            Button {
                showingLogin = true
            } label: {
                Text(ConnectCopy.signIn.text(for: language))
                    .font(DesignSystem.Typography.smart(15, weight: .semibold, language: language))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignSystem.Colors.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private var message: String {
        switch mode {
        case .announcement:
            return ConnectCopy.accessAnnouncementsMessage.text(for: language)
        case .newsletter:
            return ConnectCopy.accessNewsletterMessage.text(for: language)
        }
    }
}

private struct MessagesComingSoonView: View {
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "message.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.accentDark)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(ConnectCopy.messagesTitle.text(for: language))
                            .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(ConnectCopy.messagesMessage.text(for: language))
                            .font(DesignSystem.Typography.body(15, language: language))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(4)
                    }
                }

                Text(ConnectCopy.messagesDetail.text(for: language))
                    .font(DesignSystem.Typography.body(14, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .lineSpacing(4)

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 13, weight: .semibold))

                    Text(ConnectCopy.messagesStatus.text(for: language))
                        .font(DesignSystem.Typography.smart(12, weight: .semibold, language: language))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .foregroundColor(DesignSystem.Colors.accentDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.cardBackground)
                        .overlay(Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1))
                )

                VStack(alignment: .leading, spacing: 10) {
                    ConnectMessagePreviewBubble(
                        text: ConnectCopy.messagesPreviewOne.text(for: language),
                        isOutgoing: false,
                        language: language
                    )

                    ConnectMessagePreviewBubble(
                        text: ConnectCopy.messagesPreviewTwo.text(for: language),
                        isOutgoing: true,
                        language: language
                    )
                }
            }
            .padding(20)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
    }
}

private struct ConnectMessagePreviewBubble: View {
    let text: String
    let isOutgoing: Bool
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack {
            if isOutgoing {
                Spacer(minLength: 32)
            }

            Text(text)
                .font(DesignSystem.Typography.body(13, language: language))
                .foregroundColor(isOutgoing ? .white : DesignSystem.Colors.secondaryText)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isOutgoing ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if !isOutgoing {
                Spacer(minLength: 32)
            }
        }
    }
}

private struct ConnectEmptyCard: View {
    let icon: String
    let title: String
    let message: String
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Colors.accent.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accentDark)
                )

            Text(title)
                .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(message)
                .font(DesignSystem.Typography.body(15, language: language))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

private struct ConnectErrorCard: View {
    let retry: () -> Void
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Colors.accent.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accentDark)
                )

            Text(ConnectCopy.errorTitle.text(for: language))
                .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(ConnectCopy.errorMessage.text(for: language))
                .font(DesignSystem.Typography.body(15, language: language))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)

            Button(action: retry) {
                Text(ConnectCopy.retry.text(for: language))
                    .font(DesignSystem.Typography.smart(15, weight: .semibold, language: language))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignSystem.Colors.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}
