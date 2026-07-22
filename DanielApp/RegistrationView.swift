import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var branchViewModel: RegistrationBranchViewModel

    @State private var step = 1
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var formData = RegistrationFormData()
    @State private var isShowingPassword = false
    @State private var isShowingConfirmation = false
    @State private var acceptedTerms = false
    @State private var usesManualChurchFields = false

    init(branchViewModel: RegistrationBranchViewModel = RegistrationBranchViewModel()) {
        _branchViewModel = StateObject(wrappedValue: branchViewModel)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            AuthBrandHeader(showsAccount: false)

                            if authManager.authState.isPending {
                                pendingView
                            } else {
                                registrationContent
                            }
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
            branchViewModel.loadBranchesIfNeeded()
        }
        .onChange(of: branchViewModel.branches) { _, branches in
            guard !usesManualChurchFields, formData.branchId.isEmpty, let first = branches.first else { return }
            applyBranch(first)
        }
    }

    private var registrationContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            RegistrationStepHeader(label: stepLabel, title: stepTitle, subtitle: stepSubtitle)

            Group {
                switch step {
                case 1: identityStep
                case 2: emailStep
                case 3: passwordStep
                default: churchStep
                }
            }

            if let errorMessage = authManager.errorMessage {
                AuthStatusMessage(message: errorMessage, kind: .error)
            }

            HStack(spacing: 12) {
                if step > 1 {
                    Button(action: { step = authManager.requiresProfileCompletion ? 1 : step - 1 }) {
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
                    title: step == 4 ? copy("提交加入申请", "Submit Church Request", "교회 가입 신청 제출") : copy("继续", "Continue", "계속"),
                    isLoading: authManager.isLoading,
                    isEnabled: isCurrentStepValid && !authManager.isLoading,
                    action: continueRegistration
                )
            }

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
    }

    private var identityStep: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                AuthTextField(
                    title: copy("名字", "First Name", "이름"),
                    placeholder: copy("约翰", "John", "요한"),
                    text: $firstName,
                    systemImage: "person"
                )
                AuthTextField(
                    title: copy("姓氏", "Last Name", "성"),
                    placeholder: copy("殷", "Doe", "김"),
                    text: $lastName
                )
            }

            AuthTextField(
                title: copy("手机号码（可选）", "Phone Number (Optional)", "전화번호 (선택)"),
                placeholder: "+1 (555) 000-0000",
                text: $formData.phoneNumber,
                systemImage: "phone",
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )

            AuthStatusMessage(
                message: copy(
                    "手机号码可帮助教会向你发送重要通知。",
                    "Your phone number helps us send you important church announcements.",
                    "전화번호는 중요한 교회 공지를 보내는 데 사용됩니다."
                ),
                kind: .information
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

            VStack(alignment: .leading, spacing: 8) {
                Text(copy("你的邮箱将用于：", "What your email is used for:", "이메일 사용 목적:"))
                    .font(.system(size: 14, weight: .semibold))
                Text(copy(
                    "• 每日经文通知\n• 小组动态与公告\n• 账户恢复",
                    "• Daily Bible verse notifications\n• Group updates and announcements\n• Account recovery",
                    "• 매일 성경 구절 알림\n• 그룹 소식 및 공지\n• 계정 복구"
                ))
                .font(.system(size: 14))
                .lineSpacing(5)
            }
            .foregroundStyle(Color(red: 0.16, green: 0.57, blue: 0.26))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.green.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3)))

            Text(copy(
                "我们绝不会向教会以外的任何人分享你的邮箱。",
                "We will never share your email with anyone outside the church.",
                "교회 외부의 누구와도 이메일을 공유하지 않습니다."
            ))
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Colors.mutedText)
            .frame(maxWidth: .infinity)
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 16) {
            AuthSecureField(
                title: copy("密码", "Password", "비밀번호"),
                placeholder: copy("创建密码", "Create a password", "비밀번호 만들기"),
                text: $formData.password,
                isRevealed: $isShowingPassword
            )

            AuthSecureField(
                title: copy("确认密码", "Confirm Password", "비밀번호 확인"),
                placeholder: copy("再次输入密码", "Enter your password again", "비밀번호를 다시 입력하세요"),
                text: $formData.confirmPassword,
                isRevealed: $isShowingConfirmation
            )

            if !formData.confirmPassword.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: formData.passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(formData.passwordsMatch
                         ? copy("密码一致", "Passwords match", "비밀번호가 일치합니다")
                         : copy("密码不一致", "Passwords do not match", "비밀번호가 일치하지 않습니다"))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(formData.passwordsMatch ? Color.green : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { acceptedTerms.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(acceptedTerms ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText.opacity(0.45))
                    Text(copy(
                        "我同意服务条款和隐私政策",
                        "I agree to the Terms of Service and Privacy Policy",
                        "서비스 약관 및 개인정보 처리방침에 동의합니다"
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var churchStep: some View {
        VStack(spacing: 16) {
            if branchViewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(copy("正在加载教会列表…", "Loading churches…", "교회 목록을 불러오는 중…"))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                    Spacer()
                }
            }

            if !branchViewModel.branches.isEmpty && !usesManualChurchFields {
                RegistrationBranchPicker(
                    selectedBranchID: $formData.branchId,
                    branches: branchViewModel.branches,
                    language: appState.selectedLanguage,
                    onSelect: applyBranch
                )

                Button(copy("找不到你的教会？手动填写", "Church not listed? Enter it manually", "교회가 목록에 없나요? 직접 입력")) {
                    usesManualChurchFields = true
                    clearBranchSelection()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.57, blue: 0.26))
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                AuthTextField(
                    title: copy("教会所在国家", "Church Country", "교회 국가"),
                    placeholder: copy("加拿大", "Canada", "캐나다"),
                    text: $formData.churchCountry,
                    systemImage: "globe.americas"
                )
                AuthTextField(
                    title: copy("教会名称", "Church Name", "교회 이름"),
                    placeholder: copy("请输入你的教会名称", "Enter your church name", "교회 이름을 입력하세요"),
                    text: $formData.churchName,
                    systemImage: "building.2"
                )

                if !branchViewModel.branches.isEmpty {
                    Button(copy("返回教会列表", "Choose from church list", "교회 목록에서 선택")) {
                        usesManualChurchFields = false
                        if let first = branchViewModel.branches.first { applyBranch(first) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.16, green: 0.57, blue: 0.26))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            AuthTextField(
                title: copy("教会确认人", "Church Contact", "교회 확인 담당자"),
                placeholder: copy("例如：小组长或执事姓名", "For example, a group leader or deacon", "예: 구역장 또는 집사 이름"),
                text: $formData.confirmationPerson,
                systemImage: "person.badge.shield.checkmark"
            )

            AuthStatusMessage(
                message: copy(
                    "提交后，你的所属教会管理员会确认账户并分配小组。审核完成前仍可使用每日经文和公开资源。",
                    "After submission, your church administrator will confirm your account and assign your groups. Daily Verse and public resources remain available while you wait.",
                    "제출 후 소속 교회 관리자가 계정을 확인하고 그룹을 배정합니다. 승인 대기 중에도 오늘의 말씀과 공개 자료를 사용할 수 있습니다."
                ),
                kind: .pending
            )
        }
    }

    private var pendingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.green)

            VStack(spacing: 8) {
                Text(copy("注册申请已提交", "Registration Submitted", "가입 신청이 제출되었습니다"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                Text(copy(
                    "你的教会管理员会审核资料并分配小组。通过后，Connect 会自动开放相应的教会与小组内容。",
                    "Your church administrator will review your details and assign your groups. Connect will unlock the relevant church and group content after approval.",
                    "교회 관리자가 정보를 검토하고 그룹을 배정합니다. 승인 후 Connect에서 해당 교회 및 그룹 콘텐츠가 열립니다."
                ))
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.mutedText)
                .multilineTextAlignment(.center)
            }

            AuthPrimaryButton(
                title: copy("返回登录", "Back to Sign In", "로그인으로 돌아가기"),
                isLoading: false,
                isEnabled: true,
                action: { dismiss() }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var stepTitle: String {
        switch step {
        case 1: return copy("你的姓名", "Your Name", "이름")
        case 2: return copy("你的邮箱", "Your Email", "이메일")
        case 3: return copy("设置密码", "Set Password", "비밀번호 설정")
        default: return copy("加入你的教会", "Join Your Church", "소속 교회 가입")
        }
    }

    private var stepLabel: String {
        if step <= 3 { return "STEP \(step) OF 3" }
        return copy("教会权限", "CHURCH ACCESS", "교회 권한")
    }

    private var stepSubtitle: String {
        switch step {
        case 1: return copy("告诉我们你是谁。", "Tell us who you are.", "본인을 알려 주세요.")
        case 2: return copy("我们会通过邮箱向你发送更新。", "We'll use this to send you updates.", "업데이트를 보내는 데 사용됩니다.")
        case 3: return copy("请选择一个安全的密码。", "Choose a secure password.", "안전한 비밀번호를 선택하세요.")
        default: return copy("选择所属教会，管理员将确认你的身份。", "Choose your church so an administrator can confirm your membership.", "소속 교회를 선택하면 관리자가 교인 여부를 확인합니다.")
        }
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case 1:
            return !firstName.trimmed.isEmpty && !lastName.trimmed.isEmpty
        case 2:
            return formData.trimmedEmail.contains("@")
        case 3:
            return formData.password.count >= 6 && formData.passwordsMatch && acceptedTerms
        default:
            return !formData.trimmedChurchCountry.isEmpty &&
                !formData.trimmedChurchName.isEmpty &&
                !formData.trimmedConfirmationPerson.isEmpty
        }
    }

    private func continueRegistration() {
        guard isCurrentStepValid else { return }
        if step < 4 {
            withAnimation(.easeInOut(duration: 0.2)) {
                step = authManager.requiresProfileCompletion ? 4 : step + 1
            }
            return
        }

        formData.name = [firstName.trimmed, lastName.trimmed].filter { !$0.isEmpty }.joined(separator: " ")
        authManager.register(with: formData)
    }

    private func applyBranch(_ branch: RegistrationBranch) {
        formData.orgId = branch.orgId
        formData.regionId = branch.regionId
        formData.regionName = branch.regionName(for: appState.selectedLanguage)
        formData.branchId = branch.id
        formData.branchName = branch.name(for: appState.selectedLanguage)
        formData.churchCountry = branch.country.isEmpty ? formData.regionName : branch.country
        formData.churchName = formData.branchName
    }

    private func clearBranchSelection() {
        formData.orgId = ""
        formData.regionId = ""
        formData.regionName = ""
        formData.branchId = ""
        formData.branchName = ""
        formData.churchCountry = ""
        formData.churchName = ""
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
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.accent)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.mutedText)

        }
    }
}

private struct RegistrationBranchPicker: View {
    @Binding var selectedBranchID: String
    let branches: [RegistrationBranch]
    let language: CoreModels.VerseLanguage
    let onSelect: (RegistrationBranch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)

            Menu {
                ForEach(branches) { branch in
                    Button("\(branch.name(for: language)) · \(branch.regionName(for: language))") {
                        selectedBranchID = branch.id
                        onSelect(branch)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "building.2")
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedBranch?.name(for: language) ?? placeholder)
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                        if let selectedBranch {
                            Text(selectedBranch.regionName(for: language))
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.Colors.mutedText)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .separator).opacity(0.35)))
            }
        }
    }

    private var selectedBranch: RegistrationBranch? { branches.first { $0.id == selectedBranchID } }

    private var label: String {
        switch language { case .chinese: return "所属教会"; case .english: return "Your Church"; case .korean: return "소속 교회" }
    }

    private var placeholder: String {
        switch language { case .chinese: return "请选择所属教会"; case .english: return "Select your church"; case .korean: return "소속 교회를 선택하세요" }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    RegistrationView().environmentObject(AppState())
}
