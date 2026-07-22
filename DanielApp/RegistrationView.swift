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
                    Text(copy("我同意服务条款和隐私政策", "I agree to the Terms of Service and Privacy Policy", "서비스 약관 및 개인정보 처리방침에 동의합니다"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
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

#Preview {
    RegistrationView().environmentObject(AppState())
}
