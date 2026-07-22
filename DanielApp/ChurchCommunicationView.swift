import SwiftUI
import FirebaseFirestore

struct ChurchCommunicationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = NewsletterViewModel()
    @StateObject private var branchConnectViewModel = BranchConnectViewModel()
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
                    case .kakaoTalk:
                        KakaoTalkConnectView(
                            viewModel: branchConnectViewModel,
                            profile: authManager.currentUser,
                            language: language,
                            showingLogin: $showingLogin
                        )
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
                    profile: authManager.currentUser,
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
            if let branchId = authManager.currentUser?.branchId {
                branchConnectViewModel.load(branchId: branchId)
            }
        } else {
            branchConnectViewModel.clear()
        }
    }
}

private enum ConnectSection: CaseIterable {
    case announcements
    case newsletter
    case kakaoTalk

    var icon: String {
        switch self {
        case .announcements: return "megaphone"
        case .newsletter: return "newspaper"
        case .kakaoTalk: return "bubble.left.and.bubble.right.fill"
        }
    }

    func title(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .announcements:
            return ConnectCopy.announcementsTab.text(for: language)
        case .newsletter:
            return ConnectCopy.newsletterTab.text(for: language)
        case .kakaoTalk:
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
            case .chinese: return "本堂公告、周报与 KakaoTalk"
            case .english: return "Your church announcements, newsletters, and KakaoTalk"
            case .korean: return "소속 교회 공지, 주보 및 카카오톡"
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
            case .chinese: return "KakaoTalk"
            case .english: return "KakaoTalk"
            case .korean: return "카카오톡"
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

    private var filteredNewsletters: [Newsletter] {
        viewModel.newsletters.filter { newsletter in
            switch mode {
            case .announcement:
                return newsletter.contentType == "announcement"
            case .newsletter:
                return newsletter.contentType == nil || newsletter.contentType == "newsletter"
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ConnectLoadingView(mode: mode, language: language)
            } else if viewModel.errorMessage != nil {
                ConnectErrorCard(retry: viewModel.loadNewsletters, language: language)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            } else if filteredNewsletters.isEmpty {
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
                        ForEach(filteredNewsletters) { newsletter in
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
    @State private var showingMediaViewer = false

    private var imageURLs: [URL] {
        newsletter.image_urls.compactMap(URL.init(string:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let firstImageURL = imageURLs.first {
                NewsletterMediaThumbnail(
                    url: firstImageURL,
                    height: 180,
                    cornerRadius: 12,
                    imageCount: imageURLs.count,
                    language: language
                ) {
                    showingMediaViewer = true
                }
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
        .fullScreenCover(isPresented: $showingMediaViewer) {
            NewsletterMediaViewer(imageURLs: imageURLs, language: language)
        }
    }
}

private struct ConnectAccessCard: View {
    @Binding var showingLogin: Bool
    let mode: ConnectNewsletterMode
    let profile: UserProfile?
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
                    Text(title)
                        .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(message)
                        .font(DesignSystem.Typography.body(15, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineSpacing(4)
                }
            }

            if let buttonTitle {
                Button {
                    showingLogin = true
                } label: {
                    Text(buttonTitle)
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
        let status = profile?.membershipStatus?.lowercased()
        if status == "revoked" {
            return text(
                "你的教会访问权限已停用。公开的每日经文和 Resources 仍可使用；请联系本堂负责人恢复权限。",
                "Your church access has been revoked. Daily Verse and public Resources remain available; contact your church leader for help.",
                "교회 접근 권한이 중지되었습니다. 오늘의 말씀과 공개 자료는 계속 이용할 수 있으며, 교회 담당자에게 문의해 주세요."
            )
        }
        if status == "pending" {
            return text(
                "你的申请已经提交。管理员批准后，本堂公告和周报会自动开放。",
                "Your request has been submitted. Church announcements and newsletters will unlock after approval.",
                "가입 요청이 제출되었습니다. 관리자 승인 후 교회 공지와 주보가 자동으로 열립니다."
            )
        }
        if profile != nil {
            return text(
                "输入本堂 Token 提交加入申请；等待期间仍可使用每日经文和公开 Resources。",
                "Enter your church token to request access. Daily Verse and public Resources remain available while you wait.",
                "교회 토큰을 입력해 가입을 요청하세요. 기다리는 동안 오늘의 말씀과 공개 자료를 계속 이용할 수 있습니다."
            )
        }
        switch mode {
        case .announcement:
            return ConnectCopy.accessAnnouncementsMessage.text(for: language)
        case .newsletter:
            return ConnectCopy.accessNewsletterMessage.text(for: language)
        }
    }

    private var title: String {
        let status = profile?.membershipStatus?.lowercased()
        if status == "revoked" { return text("需要教会协助", "Church access needs attention", "교회 확인이 필요합니다") }
        if status == "pending" { return text("等待教会审核", "Church approval pending", "교회 승인 대기 중") }
        if profile != nil { return text("加入你的教会", "Join your church", "교회에 가입하세요") }
        return ConnectCopy.accessTitle.text(for: language)
    }

    private var buttonTitle: String? {
        let status = profile?.membershipStatus?.lowercased()
        if status == "pending" || status == "revoked" { return nil }
        if profile != nil { return text("输入教会 Token", "Enter Church Token", "교회 토큰 입력") }
        return ConnectCopy.signIn.text(for: language)
    }

    private func text(_ zh: String, _ en: String, _ ko: String) -> String {
        switch language {
        case .chinese: return zh
        case .english: return en
        case .korean: return ko
        }
    }
}

private struct KakaoTalkConnectView: View {
    @ObservedObject var viewModel: BranchConnectViewModel
    let profile: UserProfile?
    let language: CoreModels.VerseLanguage
    @Binding var showingLogin: Bool
    @Environment(\.openURL) private var openURL
    @State private var openError = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if profile == nil {
                    kakaoStatusCard(
                        icon: "person.badge.key.fill",
                        title: text("登录后加入群聊", "Sign in to join", "로그인 후 참여하세요"),
                        message: text("登录并完成所属教会审核后，即可打开本堂 KakaoTalk 群。", "Sign in and complete church approval to open your church KakaoTalk group.", "로그인하고 교회 승인을 완료하면 소속 교회 카카오톡 그룹을 열 수 있습니다."),
                        buttonTitle: text("登录", "Sign In", "로그인"),
                        action: { showingLogin = true }
                    )
                } else if profile?.membershipStatus?.lowercased() == "revoked" {
                    kakaoStatusCard(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: text("群聊权限已停用", "Group access revoked", "그룹 접근이 중지되었습니다"),
                        message: text("请联系本堂管理员恢复教会访问权限。", "Contact your church admin to restore access.", "교회 관리자에게 접근 권한 복구를 문의하세요."),
                        buttonTitle: nil,
                        action: nil
                    )
                } else if profile?.isApproved != true || (profile?.membershipStatus != nil && profile?.membershipStatus != "active") {
                    kakaoStatusCard(
                        icon: "clock.badge.checkmark",
                        title: text("等待教会审核", "Church approval pending", "교회 승인 대기 중"),
                        message: text("管理员批准后，KakaoTalk 群入口会自动开放。", "The KakaoTalk group will unlock after a church admin approves your membership.", "교회 관리자가 회원 승인을 완료하면 카카오톡 그룹이 열립니다."),
                        buttonTitle: nil,
                        action: nil
                    )
                } else if viewModel.isLoading {
                    ProgressView(text("正在加载群聊…", "Loading church group…", "교회 그룹을 불러오는 중…"))
                        .tint(DesignSystem.Colors.accent)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if viewModel.errorMessage != nil {
                    kakaoStatusCard(
                        icon: "wifi.exclamationmark",
                        title: text("暂时无法读取", "Could not load", "불러오지 못했습니다"),
                        message: text("请检查网络后重试。", "Check your connection and try again.", "네트워크를 확인한 후 다시 시도하세요."),
                        buttonTitle: text("重试", "Retry", "다시 시도"),
                        action: reload
                    )
                } else if let info = viewModel.info, info.isActive {
                    kakaoGroupCard(info)
                } else {
                    kakaoStatusCard(
                        icon: "bubble.left.and.exclamationmark.bubble.right",
                        title: text("群聊尚未设置", "Group not configured", "그룹이 아직 설정되지 않았습니다"),
                        message: text("请联系本堂管理员添加 KakaoTalk 群链接。", "Ask your church admin to add the KakaoTalk group link.", "교회 관리자에게 카카오톡 그룹 링크 등록을 요청하세요."),
                        buttonTitle: nil,
                        action: nil
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .alert(text("无法打开 KakaoTalk", "Could not open KakaoTalk", "카카오톡을 열 수 없습니다"), isPresented: $openError) {
            Button(text("知道了", "OK", "확인"), role: .cancel) {}
        } message: {
            Text(text("请确认 KakaoTalk 已安装，或联系管理员检查群链接。", "Make sure KakaoTalk is installed or ask an admin to verify the group link.", "카카오톡 설치 여부를 확인하거나 관리자에게 그룹 링크 확인을 요청하세요."))
        }
    }

    private func kakaoGroupCard(_ info: BranchConnectInfo) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(red: 1.0, green: 0.91, blue: 0.0))
                    .frame(width: 54, height: 54)
                    .overlay(Image(systemName: "bubble.left.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(.black))

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.groupName(for: language))
                        .font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                    Text(text("本堂会员 KakaoTalk 群", "Church members KakaoTalk group", "교회 회원 카카오톡 그룹"))
                        .font(DesignSystem.Typography.body(13, language: language))
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                }
            }

            Text(text("公告和周报保留在 Daniel App；日常群聊会在 KakaoTalk 中打开。", "Announcements and newsletters stay in Daniel App; everyday conversation opens in KakaoTalk.", "공지와 주보는 Daniel App에 남고 일상 대화는 카카오톡에서 진행됩니다."))
                .font(DesignSystem.Typography.body(14, language: language))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)

            Button {
                guard let url = URL(string: info.kakaoURL), ["https", "kakaolink", "kakaotalk"].contains(url.scheme?.lowercased() ?? "") else {
                    openError = true
                    return
                }
                openURL(url) { accepted in
                    if !accepted { openError = true }
                }
            } label: {
                Label(text("打开 KakaoTalk", "Open KakaoTalk", "카카오톡 열기"), systemImage: "arrow.up.forward.app.fill")
                    .font(DesignSystem.Typography.smart(15, weight: .semibold, language: language))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.Colors.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(DesignSystem.Colors.border))
    }

    private func kakaoStatusCard(icon: String, title: String, message: String, buttonTitle: String?, action: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.accentDark)
                .frame(width: 48, height: 48)
                .background(DesignSystem.Colors.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(title).font(DesignSystem.Typography.smart(20, weight: .bold, language: language))
            Text(message)
                .font(DesignSystem.Typography.body(15, language: language))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(ModernButtonStyle(language: language, variant: .primary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(DesignSystem.Colors.border))
    }

    private func reload() {
        guard let branchId = profile?.branchId else { return }
        viewModel.load(branchId: branchId)
    }

    private func text(_ zh: String, _ en: String, _ ko: String) -> String {
        switch language { case .chinese: return zh; case .english: return en; case .korean: return ko }
    }
}

struct BranchConnectInfo: Codable {
    var groupNameZh: String?
    var groupNameEn: String?
    var groupNameKo: String?
    var kakaoURL: String
    var isActive: Bool

    func groupName(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return groupNameZh ?? groupNameEn ?? "KakaoTalk"
        case .english: return groupNameEn ?? groupNameZh ?? "KakaoTalk"
        case .korean: return groupNameKo ?? groupNameEn ?? "카카오톡"
        }
    }
}

protocol BranchConnectRemoteStore {
    func fetch(branchId: String, completion: @escaping (Result<BranchConnectInfo?, Error>) -> Void)
}

final class FirestoreBranchConnectRemoteStore: BranchConnectRemoteStore {
    private let db: Firestore
    init(db: Firestore = Firestore.firestore()) { self.db = db }

    func fetch(branchId: String, completion: @escaping (Result<BranchConnectInfo?, Error>) -> Void) {
        db.collection("branchConnect").document(branchId).getDocument { snapshot, error in
            if let error { completion(.failure(error)); return }
            guard let snapshot, snapshot.exists else { completion(.success(nil)); return }
            do { completion(.success(try snapshot.data(as: BranchConnectInfo.self))) }
            catch { completion(.failure(error)) }
        }
    }
}

final class BranchConnectViewModel: ObservableObject {
    @Published private(set) var info: BranchConnectInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let store: BranchConnectRemoteStore

    init(store: BranchConnectRemoteStore = FirestoreBranchConnectRemoteStore()) { self.store = store }

    func load(branchId: String) {
        guard !branchId.isEmpty else { clear(); return }
        isLoading = true
        errorMessage = nil
        store.fetch(branchId: branchId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let info): self?.info = info
                case .failure(let error): self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clear() { info = nil; isLoading = false; errorMessage = nil }
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
