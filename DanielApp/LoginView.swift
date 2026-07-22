import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var showingRegistration = false
    @State private var showingForgotPassword = false
    @State private var showingSocialSignInNotice = false
    @State private var appleCoordinator: AppleSignInCoordinator?
    @AppStorage("auth.rememberEmail") private var rememberEmail = false
    @AppStorage("auth.rememberedEmail") private var rememberedEmail = ""

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            AuthBrandHeader(showsAccount: true)
                            form
                            registrationPrompt
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
        .fullScreenCover(isPresented: $showingRegistration) {
            RegistrationView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
                .environmentObject(appState)
        }
        .alert(socialNoticeTitle, isPresented: $showingSocialSignInNotice) {
            Button(commonOK, role: .cancel) {}
        } message: {
            Text(socialNoticeMessage)
        }
        .onAppear {
            authManager.clearError()
            if rememberEmail {
                email = rememberedEmail
            }
        }
        .onChange(of: authManager.authState) { _, newState in
            if newState.isSignedIn {
                if rememberEmail {
                    rememberedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                } else {
                    rememberedEmail = ""
                }
                dismiss()
            }
        }
        .onChange(of: authManager.requiresProfileCompletion) { _, requiresCompletion in
            if requiresCompletion {
                showingRegistration = true
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(copy.signIn)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.primaryText)

            VStack(spacing: 20) {
                AuthTextField(
                    title: copy.emailAddress,
                    placeholder: "example@email.com",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                VStack(spacing: 16) {
                    AuthSecureField(
                        title: copy.password,
                        placeholder: copy.passwordPlaceholder,
                        text: $password,
                        isRevealed: $isShowingPassword,
                        trailingLabel: copy.forgotPassword,
                        trailingAction: { showingForgotPassword = true }
                    )

                    Button {
                        rememberEmail.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: rememberEmail ? "checkmark.square.fill" : "square")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(rememberEmail ? DesignSystem.Colors.accent : Color.secondary.opacity(0.45))
                            Text(copy.rememberMe)
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Colors.mutedText)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let errorMessage = authManager.errorMessage {
                AuthStatusMessage(message: errorMessage, kind: .error)
            } else if authManager.emailVerificationRequired {
                AuthStatusMessage(message: copy.verifyEmailMessage, kind: .information)
                Button(copy.completeSetup) { showingRegistration = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accentDark)
            } else if authManager.authState.isPending, let profile = authManager.currentUser {
                AuthStatusMessage(message: pendingMessage(for: profile), kind: .pending)
                HStack(spacing: 12) {
                    AuthPrimaryButton(title: copy.churchAccess, isLoading: false, isEnabled: true) {
                        showingRegistration = true
                    }
                    Button(copy.usePublicContent) { dismiss() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accentDark)
                }
            }

            AuthPrimaryButton(title: copy.signIn, isLoading: authManager.isLoading, isEnabled: canSignIn) {
                authManager.signIn(email: email, password: password)
            }

            AuthDivider(label: copy.continueWith)

            HStack(spacing: 12) {
                AuthProviderButton(title: "Google", systemImage: "g.circle.fill") {
                    showingSocialSignInNotice = true
                }
                AuthProviderButton(title: "Apple", systemImage: "apple.logo") {
                    startAppleSignIn()
                }
            }
        }
    }

    private var registrationPrompt: some View {
        HStack(spacing: 8) {
            Spacer()
            Text(copy.newCommunity)
                .foregroundStyle(DesignSystem.Colors.mutedText)
            Button(copy.createAccount) {
                showingRegistration = true
            }
            .foregroundStyle(Color(red: 0.16, green: 0.57, blue: 0.26))
            .fontWeight(.semibold)
            Spacer()
        }
        .font(.system(size: 12))
    }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !authManager.isLoading
    }

    private func startAppleSignIn() {
        let coordinator = AppleSignInCoordinator(authManager: authManager)
        appleCoordinator = coordinator
        coordinator.start()
    }

    private func pendingMessage(for profile: UserProfile) -> String {
        let status = (profile.membershipStatus ?? "pending").lowercased()
        if status == "unassigned" || profile.branchId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return copy.noChurchMessage
        }
        return copy.pendingMessage
    }

    private var copy: AuthCopy { AuthCopy(language: appState.selectedLanguage) }

    private var socialNoticeTitle: String {
        switch appState.selectedLanguage {
        case .chinese: return "第三方登录尚未连接"
        case .english: return "Social sign-in is not connected yet"
        case .korean: return "소셜 로그인이 아직 연결되지 않았습니다"
        }
    }

    private var socialNoticeMessage: String {
        switch appState.selectedLanguage {
        case .chinese: return "Google 与 Apple 的视觉入口已按 Figma 实现；Firebase Provider 会在下一阶段接入。现在请使用邮箱和密码登录。"
        case .english: return "The Google and Apple entry points now match Figma. Firebase providers will be connected in the next implementation phase. Please use email and password for now."
        case .korean: return "Google 및 Apple 화면은 Figma에 맞게 구현되었습니다. Firebase 제공자는 다음 구현 단계에서 연결됩니다. 지금은 이메일과 비밀번호를 사용해 주세요."
        }
    }

    private var commonOK: String {
        switch appState.selectedLanguage {
        case .chinese: return "知道了"
        case .english: return "OK"
        case .korean: return "확인"
        }
    }
}

struct AuthBrandHeader: View {
    @EnvironmentObject private var appState: AppState
    let showsAccount: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("D")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            Text("Daniel App")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.accentDark)

            Spacer(minLength: 8)

            if showsAccount {
                Menu {
                    Button("中文") { appState.selectedLanguage = .chinese }
                    Button("English") { appState.selectedLanguage = .english }
                    Button("한국어") { appState.selectedLanguage = .korean }
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                        .frame(width: 24, height: 40)
                }

                Image("jesus_icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)

            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                }
                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .separator).opacity(0.35)))
        }
    }
}

struct AuthSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var isRevealed: Bool
    var trailingLabel: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                Spacer()
                if let trailingLabel, let trailingAction {
                    Button(trailingLabel, action: trailingAction)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.16, green: 0.57, blue: 0.26))
                }
            }

            HStack {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 14))
                .textContentType(.password)

                Button { isRevealed.toggle() } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.mutedText)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .separator).opacity(0.35)))
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .foregroundStyle(.white)
            .background(isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct AuthProviderButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 16))
            }
            .foregroundStyle(DesignSystem.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(uiColor: .separator).opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}

struct AuthDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 16) {
            Rectangle().fill(DesignSystem.Colors.mutedText.opacity(0.55)).frame(height: 1)
            Text(label.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.mutedText.opacity(0.6))
                .fixedSize()
            Rectangle().fill(DesignSystem.Colors.mutedText.opacity(0.55)).frame(height: 1)
        }
    }
}

struct AuthContextTabBar: View {
    @EnvironmentObject private var appState: AppState

    private var items: [(String, String)] {
        [
            ("house", LocalizedText.Common.dailyVerse.text(for: appState.selectedLanguage)),
            ("paperclip", LocalizedText.Common.resourcesTab.text(for: appState.selectedLanguage)),
            ("person.2", LocalizedText.Common.communicationTab.text(for: appState.selectedLanguage)),
            ("gearshape", LocalizedText.Common.settings.text(for: appState.selectedLanguage))
        ]
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 4) {
                    Image(systemName: item.0).font(.system(size: 21))
                    Text(item.1).font(.system(size: 12)).lineLimit(1)
                }
                .foregroundStyle(index == 0 ? DesignSystem.Colors.accentDark : DesignSystem.Colors.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(index == 0 ? DesignSystem.Colors.cardBackground : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(DesignSystem.Colors.surface)
        .overlay(alignment: .top) { Rectangle().fill(DesignSystem.Colors.divider).frame(height: 1) }
        .allowsHitTesting(false)
    }
}

struct AuthStatusMessage: View {
    enum Kind { case error, pending, information }
    let message: String
    let kind: Kind

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
            Text(message).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13))
        .foregroundStyle(foreground)
        .padding(14)
        .background(foreground.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(foreground.opacity(0.25)))
    }

    private var icon: String {
        switch kind { case .error: return "exclamationmark.circle"; case .pending: return "clock"; case .information: return "info.circle" }
    }

    private var foreground: Color {
        switch kind { case .error: return .red; case .pending: return .orange; case .information: return .blue }
    }
}

struct AuthCopy {
    let language: CoreModels.VerseLanguage

    var signIn: String { text("登录", "Sign In", "로그인") }
    var emailAddress: String { text("邮箱地址", "Email Address", "이메일 주소") }
    var password: String { text("密码", "Password", "비밀번호") }
    var passwordPlaceholder: String { text("请输入密码", "Enter your password", "비밀번호를 입력하세요") }
    var forgotPassword: String { text("忘记密码？", "Forgot password?", "비밀번호를 잊으셨나요?") }
    var rememberMe: String { text("记住我 30 天", "Remember me for 30 days", "30일 동안 기억하기") }
    var continueWith: String { text("或使用以下方式", "or continue with", "또는 다음으로 계속") }
    var newCommunity: String { text("第一次加入这个社区？", "New to the community?", "커뮤니티가 처음이신가요?") }
    var createAccount: String { text("创建账户", "Create an account", "계정 만들기") }
    var pendingMessage: String { text("你的账户正在等待所属教会管理员审核。", "Your account is waiting for approval from your church administrator.", "소속 교회 관리자의 승인을 기다리고 있습니다.") }
    var noChurchMessage: String { text("账户已建立。输入教会 Token，或先继续使用每日经文和公开资源。", "Your account is ready. Enter a church token, or continue with Daily Verse and public resources.", "계정이 준비되었습니다. 교회 토큰을 입력하거나 오늘의 말씀과 공개 자료를 먼저 이용하세요.") }
    var verifyEmailMessage: String { text("请验证邮箱后再输入教会 Token。", "Verify your email before entering a church token.", "교회 토큰을 입력하기 전에 이메일을 인증하세요.") }
    var completeSetup: String { text("继续账户设置", "Continue Account Setup", "계정 설정 계속하기") }
    var churchAccess: String { text("教会 Token", "Church Token", "교회 토큰") }
    var usePublicContent: String { text("使用公开内容", "Use Public Content", "공개 콘텐츠 이용") }

    func text(_ zh: String, _ en: String, _ ko: String) -> String {
        switch language { case .chinese: return zh; case .english: return en; case .korean: return ko }
    }
}

#Preview {
    LoginView().environmentObject(AppState())
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let authManager: AuthManager
    private var currentNonce: String?

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func start() {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            authManager.errorMessage = "Apple 登录失败：无法读取身份凭证"
            authManager.isLoading = false
            return
        }

        authManager.signInWithApple(idToken: idToken, rawNonce: nonce, fullName: credential.fullName)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as? ASAuthorizationError)?.code != .canceled {
            authManager.errorMessage = error.localizedDescription
        }
        authManager.isLoading = false
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            precondition(status == errSecSuccess)

            for byte in bytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }
}
