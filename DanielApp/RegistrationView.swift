import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var inviteViewModel: ChurchInviteViewModel

    @State private var step = 1
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var formData = RegistrationFormData()
    @State private var isShowingPassword = false
    @State private var isShowingConfirmation = false
    @State private var acceptedTerms = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false

    init(inviteService: ChurchInviteServicing = FirebaseChurchInviteService()) {
        _inviteViewModel = StateObject(wrappedValue: ChurchInviteViewModel(service: inviteService))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            AuthBrandHeader(showsAccount: false)
                            displayedContent
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, max(24, proxy.safeAreaInsets.top + 12))
                        .padding(.bottom, 32)
                    }
                    AuthContextTabBar()
                }
                .background(DesignSystem.Colors.background.ignoresSafeArea())
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            authManager.clearError()
            if authManager.requiresProfileCompletion, let providerEmail = authManager.currentFirebaseEmail {
                formData.email = providerEmail
            }
        }
        .sheet(isPresented: $showingTerms) {
            PilotLegalDocumentView(kind: .terms, language: appState.selectedLanguage)
        }
        .sheet(isPresented: $showingPrivacy) {
            PilotLegalDocumentView(kind: .privacy, language: appState.selectedLanguage)
        }
    }

    @ViewBuilder
    private var displayedContent: some View {
        if authManager.emailVerificationRequired {
            emailVerificationView
        } else if isMembershipRevoked {
            revokedView
        } else if inviteWasSubmitted || hasPendingBranchMembership {
            pendingView
        } else if authManager.currentUser != nil {
            churchTokenView
        } else {
            registrationContent
        }
    }

    private var registrationContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            RegistrationStepHeader(label: stepLabel, title: stepTitle, subtitle: stepSubtitle)

            Group {
                switch step {
                case 1: identityStep
                case 2: emailStep
                default: passwordStep
                }
            }

            if let errorMessage = authManager.errorMessage {
                AuthStatusMessage(message: errorMessage, kind: .error)
            }

            HStack(spacing: 12) {
                if step > 1 {
                    Button(action: { step -= 1 }) {
                        Text(copy("上一步", "Back", "이전"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.Colors.border))
                    }
                    .buttonStyle(.plain)
                }

                AuthPrimaryButton(
                    title: step == 3 ? copy("创建账户", "Create Account", "계정 만들기") : copy("继续", "Continue", "계속"),
                    isLoading: authManager.isLoading,
                    isEnabled: isCurrentStepValid && !authManager.isLoading,
                    action: continueRegistration
                )
            }

            signInPrompt
        }
    }

    private var identityStep: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                AuthTextField(title: copy("名字", "First Name", "이름"), placeholder: copy("约翰", "John", "요한"), text: $firstName, systemImage: "person")
                AuthTextField(title: copy("姓氏", "Last Name", "성"), placeholder: copy("殷", "Doe", "김"), text: $lastName)
            }
            AuthTextField(
                title: copy("手机号码（可选）", "Phone Number (Optional)", "전화번호 (선택)"),
                placeholder: "+1 (555) 000-0000",
                text: $formData.phoneNumber,
                systemImage: "phone",
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
        }
    }

    private var emailStep: some View {
        VStack(spacing: 16) {
            AuthTextField(
                title: copy("邮箱地址", "Email Address", "이메일 주소"),
                placeholder: "example@email.com",
                text: $formData.email,
                systemImage: "envelope",
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )
            AuthStatusMessage(
                message: copy("我们会发送验证邮件。验证前不能使用教会 Token。", "We'll send a verification email. A church token can only be used after verification.", "인증 이메일을 보내드립니다. 이메일 인증 후 교회 토큰을 사용할 수 있습니다."),
                kind: .information
            )
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 16) {
            AuthSecureField(title: copy("密码", "Password", "비밀번호"), placeholder: copy("创建密码", "Create a password", "비밀번호 만들기"), text: $formData.password, isRevealed: $isShowingPassword)
            AuthSecureField(title: copy("确认密码", "Confirm Password", "비밀번호 확인"), placeholder: copy("再次输入密码", "Enter your password again", "비밀번호를 다시 입력하세요"), text: $formData.confirmPassword, isRevealed: $isShowingConfirmation)

            Button { acceptedTerms.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                        .foregroundStyle(acceptedTerms ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText.opacity(0.45))
                    Text(copy("我已阅读并同意以下条款", "I have read and agree to the documents below", "아래 문서를 읽고 동의합니다"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 18) {
                Button(copy("服务条款", "Terms of Service", "서비스 약관")) { showingTerms = true }
                Button(copy("隐私政策", "Privacy Policy", "개인정보 처리방침")) { showingPrivacy = true }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.accentDark)
        }
    }

    private var emailVerificationView: some View {
        VStack(spacing: 24) {
            statusIcon("envelope.badge", color: DesignSystem.Colors.accent)
            statusHeading(
                copy("验证你的邮箱", "Verify Your Email", "이메일 인증"),
                copy("验证邮件已发送到 \(authManager.currentFirebaseEmail ?? formData.trimmedEmail)。完成验证后回到这里继续。", "We sent a verification link to \(authManager.currentFirebaseEmail ?? formData.trimmedEmail). Verify it, then return here to continue.", "\(authManager.currentFirebaseEmail ?? formData.trimmedEmail)(으)로 인증 링크를 보냈습니다. 인증 후 여기로 돌아와 계속하세요.")
            )
            if let errorMessage = authManager.errorMessage {
                AuthStatusMessage(message: errorMessage, kind: .error)
            } else if authManager.verificationEmailSent {
                AuthStatusMessage(message: copy("验证邮件已发送。", "Verification email sent.", "인증 이메일을 보냈습니다."), kind: .information)
            }
            AuthPrimaryButton(title: copy("我已完成验证", "I've Verified My Email", "이메일 인증 완료"), isLoading: authManager.isLoading, isEnabled: !authManager.isLoading) {
                authManager.checkEmailVerification()
            }
            Button(copy("重新发送验证邮件", "Resend Verification Email", "인증 이메일 다시 보내기")) {
                authManager.sendVerificationEmail()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.accentDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private var churchTokenView: some View {
        VStack(alignment: .leading, spacing: 24) {
            RegistrationStepHeader(
                label: copy("教会权限", "CHURCH ACCESS", "교회 권한"),
                title: copy("加入你的教会", "Join Your Church", "소속 교회 가입"),
                subtitle: copy("请输入教会负责人分享给你的 16 位 Token。", "Enter the 16-character token shared by your church leader.", "교회 담당자가 공유한 16자리 토큰을 입력하세요.")
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(copy("教会 Token", "Church Token", "교회 토큰"))
                    .font(.system(size: 12, weight: .semibold))
                TextField("XXXX-XXXX-XXXX-XXXX", text: Binding(
                    get: { inviteViewModel.formattedCode },
                    set: { inviteViewModel.updateCode($0) }
                ))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.Colors.border))
            }

            if case .failed(let error) = inviteViewModel.state {
                AuthStatusMessage(message: inviteErrorMessage(error), kind: .error)
            } else {
                AuthStatusMessage(
                    message: copy("Token 只用于找到你的教会。管理员批准前，你仍可使用每日经文和公开资源。", "The token only identifies your church. Daily Verse and public resources remain available until an administrator approves you.", "토큰은 소속 교회를 확인하는 용도입니다. 관리자 승인 전에도 오늘의 말씀과 공개 자료를 이용할 수 있습니다."),
                    kind: .pending
                )
            }

            AuthPrimaryButton(
                title: copy("提交加入申请", "Submit Church Request", "교회 가입 신청 제출"),
                isLoading: inviteViewModel.state == .redeeming,
                isEnabled: inviteViewModel.canSubmit,
                action: { inviteViewModel.redeem { authManager.refreshCurrentProfile() } }
            )

            Button(copy("暂时跳过，继续使用公开内容", "Skip for Now and Use Public Content", "나중에 하고 공개 콘텐츠 이용하기")) {
                dismiss()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.accentDark)
            .frame(maxWidth: .infinity)
        }
    }

    private var pendingView: some View {
        VStack(spacing: 24) {
            statusIcon("clock.badge.checkmark", color: .orange)
            statusHeading(
                copy("教会申请审核中", "Church Request Pending", "교회 가입 승인 대기"),
                copy("你的申请已提交给 \(pendingBranchName)。管理员批准后，Connect 会自动开放。", "Your request was sent to \(pendingBranchName). Connect will unlock automatically after approval.", "\(pendingBranchName)에 가입 신청을 보냈습니다. 승인 후 Connect가 자동으로 열립니다.")
            )
            AuthStatusMessage(message: copy("等待期间仍可使用每日经文和公开资源。", "Daily Verse and public resources remain available while you wait.", "대기 중에도 오늘의 말씀과 공개 자료를 이용할 수 있습니다."), kind: .pending)
            AuthPrimaryButton(title: copy("继续使用 App", "Continue to the App", "앱 계속 사용하기"), isLoading: false, isEnabled: true, action: { dismiss() })
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private var revokedView: some View {
        VStack(spacing: 24) {
            statusIcon("person.crop.circle.badge.exclamationmark", color: .red)
            statusHeading(
                copy("教会权限已停用", "Church Access Revoked", "교회 접근 권한 중지"),
                copy("你的公开内容仍然可用。如需恢复 Connect，请联系教会负责人。", "Public content is still available. Contact your church leader if you need Connect access restored.", "공개 콘텐츠는 계속 이용할 수 있습니다. Connect 권한을 복구하려면 교회 담당자에게 문의하세요.")
            )
            AuthPrimaryButton(title: copy("继续使用公开内容", "Continue with Public Content", "공개 콘텐츠 계속 이용"), isLoading: false, isEnabled: true, action: { dismiss() })
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private var signInPrompt: some View {
        HStack(spacing: 8) {
            Spacer()
            Text(copy("已有账户？", "Already have an account?", "이미 계정이 있으신가요?"))
                .foregroundStyle(DesignSystem.Colors.mutedText)
            Button(copy("登录", "Sign in", "로그인"), action: { dismiss() })
                .foregroundStyle(Color(red: 0.16, green: 0.57, blue: 0.26))
                .fontWeight(.semibold)
            Spacer()
        }
        .font(.system(size: 12))
    }

    private func statusIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name).font(.system(size: 50)).foregroundStyle(color).frame(maxWidth: .infinity)
    }

    private func statusHeading(_ title: String, _ message: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(DesignSystem.Colors.primaryText)
            Text(message).font(.system(size: 14)).foregroundStyle(DesignSystem.Colors.mutedText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var stepTitle: String {
        switch step {
        case 1: return copy("你的姓名", "Your Name", "이름")
        case 2: return copy("你的邮箱", "Your Email", "이메일")
        default: return copy("设置密码", "Set Password", "비밀번호 설정")
        }
    }

    private var stepLabel: String { "STEP \(step) OF 3" }

    private var stepSubtitle: String {
        switch step {
        case 1: return copy("只需要最基本的账户信息。", "Only the essentials are needed to create your account.", "계정 생성에 필요한 최소 정보만 받습니다.")
        case 2: return copy("我们会通过邮箱向你发送验证链接。", "We'll send a verification link to this address.", "이 주소로 인증 링크를 보내드립니다.")
        default: return copy("请选择一个安全的密码。", "Choose a secure password.", "안전한 비밀번호를 선택하세요.")
        }
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case 1: return !firstName.trimmed.isEmpty && !lastName.trimmed.isEmpty
        case 2: return formData.trimmedEmail.contains("@")
        default: return formData.password.count >= 6 && formData.passwordsMatch && acceptedTerms
        }
    }

    private var hasPendingBranchMembership: Bool {
        guard let profile = authManager.currentUser else { return false }
        let status = (profile.membershipStatus ?? "pending").lowercased()
        return status == "pending" && profile.branchId?.trimmed.isEmpty == false
    }

    private var isMembershipRevoked: Bool {
        authManager.currentUser?.membershipStatus?.lowercased() == "revoked"
    }

    private var inviteWasSubmitted: Bool {
        if case .submitted = inviteViewModel.state { return true }
        return false
    }

    private var pendingBranchName: String {
        if case .submitted(let redemption) = inviteViewModel.state, !redemption.branchName.trimmed.isEmpty {
            return redemption.branchName
        }
        return authManager.currentUser?.displayBranchName(for: appState.selectedLanguage) ?? copy("你的教会", "your church", "소속 교회")
    }

    private func continueRegistration() {
        guard isCurrentStepValid else { return }
        formData.name = [firstName.trimmed, lastName.trimmed].joined(separator: " ")

        if authManager.requiresProfileCompletion {
            authManager.register(with: formData)
        } else if step < 3 {
            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
        } else {
            authManager.register(with: formData)
        }
    }

    private func inviteErrorMessage(_ error: ChurchInviteError) -> String {
        switch error {
        case .invalid: return copy("Token 无效，请检查后重试。", "That token is invalid. Check it and try again.", "유효하지 않은 토큰입니다. 확인 후 다시 시도하세요.")
        case .expired: return copy("Token 已过期，请向教会负责人索取新 Token。", "That token has expired. Ask your church leader for a new one.", "만료된 토큰입니다. 교회 담당자에게 새 토큰을 요청하세요.")
        case .revoked: return copy("Token 已停用，请联系教会负责人。", "That token was revoked. Contact your church leader.", "중지된 토큰입니다. 교회 담당자에게 문의하세요.")
        case .exhausted: return copy("Token 使用次数已满，请索取新 Token。", "That token has reached its use limit. Ask for a new one.", "토큰 사용 한도에 도달했습니다. 새 토큰을 요청하세요.")
        case .emailNotVerified: return copy("请先验证邮箱。", "Verify your email first.", "먼저 이메일을 인증하세요.")
        case .unauthenticated: return copy("登录状态已失效，请重新登录。", "Your session expired. Sign in again.", "로그인 세션이 만료되었습니다. 다시 로그인하세요.")
        case .unavailable: return copy("暂时无法连接，请稍后重试。", "We couldn't connect. Try again shortly.", "현재 연결할 수 없습니다. 잠시 후 다시 시도하세요.")
        case .unexpected: return copy("提交失败，请稍后重试或联系教会负责人。", "Submission failed. Try again or contact your church leader.", "제출하지 못했습니다. 다시 시도하거나 교회 담당자에게 문의하세요.")
        }
    }

    private func copy(_ zh: String, _ en: String, _ ko: String) -> String {
        AuthCopy(language: appState.selectedLanguage).text(zh, en, ko)
    }
}

private struct RegistrationStepHeader: View {
    let label: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.system(size: 12, weight: .bold)).foregroundStyle(DesignSystem.Colors.accent)
            Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(DesignSystem.Colors.primaryText)
            Text(subtitle).font(.system(size: 14, weight: .medium)).foregroundStyle(DesignSystem.Colors.mutedText)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct PilotLegalDocumentView: View {
    enum Kind { case terms, privacy }

    let kind: Kind
    let language: CoreModels.VerseLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(pilotNotice)
                        .font(DesignSystem.Typography.body(14, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(14)
                        .background(DesignSystem.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(section.0)
                                .font(DesignSystem.Typography.smart(17, weight: .bold, language: language))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text(section.1)
                                .font(DesignSystem.Typography.body(14, language: language))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle) { dismiss() }
                }
            }
        }
    }

    private var title: String {
        switch (kind, language) {
        case (.terms, .chinese): return "服务条款"
        case (.terms, .english): return "Terms of Service"
        case (.terms, .korean): return "서비스 약관"
        case (.privacy, .chinese): return "隐私政策"
        case (.privacy, .english): return "Privacy Policy"
        case (.privacy, .korean): return "개인정보 처리방침"
        }
    }

    private var doneTitle: String {
        switch language { case .chinese: return "完成"; case .english: return "Done"; case .korean: return "완료" }
    }

    private var pilotNotice: String {
        text(
            "这是加拿大四教会试运行版本，生效日期为 2026 年 7 月 22 日。正式全球发布前，运营方会再次进行法律与隐私审核。",
            "This is the four-church Canada pilot, effective July 22, 2026. The operator will complete another legal and privacy review before a global launch.",
            "본 문서는 2026년 7월 22일부터 적용되는 캐나다 4개 교회 시범 운영용입니다. 글로벌 출시 전 법률 및 개인정보 검토를 다시 진행합니다."
        )
    }

    private var sections: [(String, String)] {
        switch kind {
        case .terms:
            return [
                (text("使用范围", "Pilot scope", "시범 운영 범위"), text("本应用提供每日经文、公开资料和经本堂批准的教会通讯。它不替代紧急服务、专业辅导或教会正式记录。", "The app provides Daily Verse, public resources, and church communication approved for your branch. It does not replace emergency services, professional care, or official church records.", "앱은 오늘의 말씀, 공개 자료와 소속 교회가 승인한 소통 기능을 제공합니다. 응급 서비스, 전문 상담 또는 교회의 공식 기록을 대체하지 않습니다.")),
                (text("账户与教会访问", "Accounts and church access", "계정 및 교회 접근"), text("你应提供真实的账户信息并保护登录凭据。教会 Token 只能申请普通成员权限；分堂管理员决定是否批准、撤销或恢复访问。", "Provide accurate account information and protect your credentials. A church token only requests member access; branch administrators decide approval, revocation, and restoration.", "정확한 계정 정보를 제공하고 로그인 정보를 보호해야 합니다. 교회 토큰은 일반 회원 접근만 요청하며 승인, 중지 및 복구는 교회 관리자가 결정합니다.")),
                (text("合理使用", "Acceptable use", "올바른 사용"), text("不得滥用 Token、尝试跨教会访问、上传违法或侵犯他人权利的内容，或干扰服务。", "Do not misuse tokens, attempt cross-church access, upload unlawful or rights-infringing content, or disrupt the service.", "토큰을 악용하거나 다른 교회 자료에 접근하려 하거나 불법·권리 침해 콘텐츠를 올리거나 서비스를 방해해서는 안 됩니다.")),
                (text("外部服务", "External services", "외부 서비스"), text("KakaoTalk、Apple、Google 和外部资源链接受各自服务条款约束。离开本应用后的服务由相应提供商负责。", "KakaoTalk, Apple, Google, and external resource links have their own terms. Their providers are responsible once you leave this app.", "카카오톡, Apple, Google 및 외부 링크에는 각 서비스의 약관이 적용되며 앱을 벗어난 이후에는 해당 제공자가 책임집니다."))
            ]
        case .privacy:
            return [
                (text("收集的数据", "Data we collect", "수집하는 정보"), text("试运行版本收集姓名、邮箱、可选电话、登录服务标识、所属教会与会员状态。使用收藏、笔记或阅读进度时，还会保存相应的应用数据。", "The pilot collects name, email, optional phone, sign-in identifiers, church assignment, and membership status. Favorites, notes, and reading progress are stored when you use those features.", "시범 버전은 이름, 이메일, 선택 전화번호, 로그인 식별자, 소속 교회와 회원 상태를 수집합니다. 즐겨찾기, 노트, 읽기 진행을 사용하면 해당 앱 데이터도 저장합니다.")),
                (text("使用目的", "How data is used", "이용 목적"), text("数据用于登录、邮箱验证、教会审批、分堂内容隔离、同步个人功能和保障服务安全；我们不会出售个人数据。", "Data is used for sign-in, email verification, church approval, branch isolation, personal sync, and service security. Personal data is not sold.", "정보는 로그인, 이메일 인증, 교회 승인, 지교회별 접근 분리, 개인 기능 동기화와 보안을 위해 사용되며 개인정보를 판매하지 않습니다.")),
                (text("存储与访问", "Storage and access", "저장 및 접근"), text("数据存储在 Firebase。分堂管理员只应查看和管理本堂必要的会员与内容；全局管理员负责试运行维护。", "Data is stored in Firebase. Branch administrators should access only the member and content data needed for their church; global administrators maintain the pilot.", "데이터는 Firebase에 저장됩니다. 지교회 관리자는 소속 교회 운영에 필요한 회원 및 콘텐츠만 다루며 글로벌 관리자는 시범 운영을 관리합니다.")),
                (text("你的选择", "Your choices", "이용자의 선택"), text("你可以退出登录、停止使用可选个人功能，并联系本堂管理员申请更正、撤销教会访问或提出账户数据删除请求。部分安全审计记录可能依法或为防止滥用而保留。", "You may sign out, stop using optional personal features, and ask your branch administrator to correct data, revoke church access, or request account-data deletion. Limited security audit records may be retained when required or needed to prevent abuse.", "로그아웃하거나 선택 기능 사용을 중단할 수 있으며 교회 관리자에게 정보 수정, 접근 중지 또는 계정 데이터 삭제를 요청할 수 있습니다. 법적 의무나 악용 방지를 위해 일부 보안 기록은 보관될 수 있습니다."))
            ]
        }
    }

    private func text(_ zh: String, _ en: String, _ ko: String) -> String {
        switch language { case .chinese: return zh; case .english: return en; case .korean: return ko }
    }
}

#Preview {
    RegistrationView().environmentObject(AppState())
}
