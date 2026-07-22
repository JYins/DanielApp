import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import GoogleSignIn

// 认证管理器
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var authState: AuthState = .signedOut
    @Published var currentUser: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var requiresProfileCompletion = false
    @Published var emailVerificationRequired = false
    @Published var verificationEmailSent = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var userProfileListener: ListenerRegistration?
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
        userProfileListener?.remove()
    }
    
    // 设置认证状态监听器
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.requiresProfileCompletion = false
                    self?.emailVerificationRequired = self?.requiresEmailVerification(user) ?? false
                    self?.loadUserProfile(for: user.uid)
                    // 设置实时监听用户资料变化
                    self?.setupUserProfileListener(for: user.uid)
                } else {
                    self?.authState = .signedOut
                    self?.currentUser = nil
                    self?.requiresProfileCompletion = false
                    self?.emailVerificationRequired = false
                    self?.verificationEmailSent = false
                    // 移除监听器
                    self?.userProfileListener?.remove()
                    self?.userProfileListener = nil
                }
            }
        }
    }
    
    // 设置用户资料实时监听器（监听审核状态变化）
    private func setupUserProfileListener(for userId: String) {
        // 移除旧的监听器
        userProfileListener?.remove()
        
        print("📡 开始监听用户资料变化，用户ID: \(userId)")
        
        // 添加新的实时监听器
        userProfileListener = db.collection("users").document(userId).addSnapshotListener { [weak self] documentSnapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 监听用户资料失败: \(error.localizedDescription)")
                    return
                }
                
                guard let document = documentSnapshot, document.exists else {
                    print("⚠️ 用户资料文档不存在")
                    return
                }
                
                do {
                    guard let self = self else {
                        return
                    }
                    
                    let profile = try self.parseUserProfile(from: document)
                    let oldProfile = self.currentUser
                    
                    // 更新当前用户资料
                    self.currentUser = profile
                    
                    self.applyAuthenticationState(for: profile)

                    let oldStatus = self.normalizedMembershipStatus(for: oldProfile)
                    let newStatus = self.normalizedMembershipStatus(for: profile)
                    if oldStatus != newStatus {
                        self.refreshIDToken(completion: nil)
                    }
                } catch {
                    print("❌ 解析用户资料失败: \(error.localizedDescription)")
                    self?.errorMessage = "用户资料不完整，请联系管理员补全账户信息"
                }
            }
        }
    }
    
    // 注册用户
    func register(with formData: RegistrationFormData) {
        if requiresProfileCompletion, auth.currentUser != nil {
            completeProviderRegistration(with: formData)
            return
        }

        isLoading = true
        errorMessage = nil
        
        auth.createUser(withEmail: formData.trimmedEmail, password: formData.password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = self?.getLocalizedErrorMessage(error)
                    self?.isLoading = false
                    return
                }
                
                guard let user = result?.user else {
                    self?.errorMessage = "注册失败：无法创建用户"
                    self?.isLoading = false
                    return
                }
                
                // 创建用户资料
                let userProfile = self?.makeProfile(from: formData, userID: user.uid)
                
                // 保存用户资料到Firestore
                guard let self, let userProfile else { return }
                self.saveUserProfile(userProfile) { saved in
                    guard saved else { return }
                    self.sendVerificationEmail()
                }
            }
        }
    }
    
    // 用户登录
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        auth.signIn(withEmail: normalizedEmail, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = self?.getLocalizedErrorMessage(error)
                    self?.isLoading = false
                    return
                }
                
                // 登录成功，检查用户的密码是否最近被重置
                if let user = result?.user {
                    self?.checkAndHandlePasswordReset(userId: user.uid, email: normalizedEmail)
                }
                
                // 用户登录成功，状态监听器会自动处理后续逻辑
                self?.isLoading = false
            }
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) {
        isLoading = true
        errorMessage = nil

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )

        auth.signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    self.isLoading = false
                    return
                }

                guard let user = result?.user else {
                    self.errorMessage = "Apple 登录失败：无法读取 Firebase 用户"
                    self.isLoading = false
                    return
                }

                if let fullName, user.displayName?.isEmpty != false {
                    let formatter = PersonNameComponentsFormatter()
                    let displayName = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !displayName.isEmpty {
                        let changeRequest = user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        changeRequest.commitChanges(completion: nil)
                    }
                }

                self.loadUserProfile(for: user.uid)
            }
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) {
        isLoading = true
        errorMessage = nil

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )

        auth.signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    self.isLoading = false
                    return
                }

                guard let user = result?.user else {
                    self.errorMessage = "Google 登录失败：无法读取 Firebase 用户"
                    self.isLoading = false
                    return
                }

                self.loadUserProfile(for: user.uid)
            }
        }
    }
    
    // 检查并处理密码重置情况
    private func checkAndHandlePasswordReset(userId: String, email: String) {
        // 获取用户的最后密码修改时间
        // Firebase Auth 没有直接的API，我们使用另一个方法：
        // 在用户文档中存储一个"最后登录时间"，如果发现用户很久没登录了，
        // 可能是重置了密码，我们就重置审核状态
        
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let error = error {
                print("⚠️ 检查用户信息失败: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data(),
                  let lastLoginDate = data["lastLoginDate"] as? Timestamp else {
                // 第一次登录或没有记录，更新最后登录时间
                self?.updateLastLoginDate(userId: userId)
                return
            }
            
            // 审核状态现在只允许管理员在服务端维护。
            // 客户端登录时仅更新最后登录时间，不再自行重置 isApproved。
            let daysSinceLastLogin = Calendar.current.dateComponents([.day], from: lastLoginDate.dateValue(), to: Date()).day ?? 0
            if daysSinceLastLogin > 7 {
                print("ℹ️ 用户距离上次登录已超过7天，仅记录登录时间，审核状态保持由管理员控制")
            }
            
            // 正常登录，只更新最后登录时间
            self?.updateLastLoginDate(userId: userId)
        }
    }
    
    // 更新最后登录时间
    private func updateLastLoginDate(userId: String) {
        db.collection("users").document(userId).updateData([
            "lastLoginDate": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("⚠️ 更新登录时间失败: \(error.localizedDescription)")
            } else {
                print("✅ 已更新最后登录时间")
            }
        }
    }
    
    // 用户注销
    func signOut() {
        do {
            GIDSignIn.sharedInstance.signOut()
            try auth.signOut()
            authState = .signedOut
            currentUser = nil
            requiresProfileCompletion = false
            emailVerificationRequired = false
            verificationEmailSent = false
        } catch {
            errorMessage = "注销失败：\(error.localizedDescription)"
        }
    }
    
    // 保存用户资料到Firestore
    private func saveUserProfile(_ profile: UserProfile, completion: ((Bool) -> Void)? = nil) {
        print("💾 开始保存用户资料: \(profile.name)")
        
        do {
            try db.collection("users").document(profile.userId).setData(from: profile) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ 保存用户信息失败：\(error.localizedDescription)")
                        self?.errorMessage = "保存用户信息失败：\(error.localizedDescription)"
                        self?.isLoading = false
                        completion?(false)
                        return
                    }
                    
                    print("✅ 用户资料保存成功，开始验证数据...")
                    
                    // 保存成功后，验证数据是否真的写入了
                    self?.verifyUserProfileSaved(profile, completion: completion)
                }
            }
        } catch {
            print("❌ 保存用户信息失败（异常）：\(error.localizedDescription)")
            errorMessage = "保存用户信息失败：\(error.localizedDescription)"
            isLoading = false
            completion?(false)
        }
    }

    private func completeProviderRegistration(with formData: RegistrationFormData) {
        guard let user = auth.currentUser else {
            errorMessage = "登录状态已失效，请重新登录"
            requiresProfileCompletion = false
            return
        }

        isLoading = true
        errorMessage = nil
        let resolvedEmail = user.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let resolvedEmail, !resolvedEmail.isEmpty else {
            errorMessage = "Apple 账户没有提供可用邮箱，请联系管理员"
            isLoading = false
            return
        }

        let profile = makeProfile(from: formData, userID: user.uid, email: resolvedEmail)
        saveUserProfile(profile) { [weak self] saved in
            guard saved else { return }
            self?.emailVerificationRequired = false
            self?.verificationEmailSent = false
        }
    }

    private func makeProfile(from formData: RegistrationFormData, userID: String, email: String? = nil) -> UserProfile {
        UserProfile(
            name: formData.trimmedName,
            email: email ?? formData.trimmedEmail,
            phoneNumber: formData.optionalPhoneNumber,
            userId: userID,
            role: "member",
            accessRole: "member",
            membershipStatus: "unassigned"
        )
    }
    
    // 验证用户资料是否已保存
    private func verifyUserProfileSaved(_ profile: UserProfile, retryCount: Int = 0, completion: ((Bool) -> Void)? = nil) {
        print("🔍 验证用户资料是否已保存，重试次数: \(retryCount)")
        
        db.collection("users").document(profile.userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 验证失败：\(error.localizedDescription)")
                    
                    // 如果验证失败且重试次数少于3次，则重试
                    if retryCount < 3 {
                        print("⏳ 1秒后重试验证...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.verifyUserProfileSaved(profile, retryCount: retryCount + 1, completion: completion)
                        }
                    } else {
                        self?.errorMessage = "用户注册成功，但验证失败，请重新登录"
                        self?.isLoading = false
                        completion?(false)
                    }
                    return
                }
                
                if document?.exists == true {
                    print("✅ 用户资料验证成功，注册完成")
                    self?.currentUser = profile
                    self?.requiresProfileCompletion = false
                    self?.applyAuthenticationState(for: profile)
                    self?.isLoading = false
                    completion?(true)
                } else {
                    print("⚠️ 验证时发现用户资料不存在")
                    
                    // 如果文档不存在且重试次数少于3次，则重试
                    if retryCount < 3 {
                        print("⏳ 1秒后重试验证...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.verifyUserProfileSaved(profile, retryCount: retryCount + 1, completion: completion)
                        }
                    } else {
                        self?.errorMessage = "用户注册成功，但验证失败，请重新登录"
                        self?.isLoading = false
                        completion?(false)
                    }
                }
            }
        }
    }
    
    // 从Firestore加载用户资料
    private func loadUserProfile(for userId: String, retryCount: Int = 0) {
        print("🔄 开始加载用户资料，用户ID: \(userId)，重试次数: \(retryCount)")
        
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 加载用户信息失败：\(error.localizedDescription)")
                    
                    // 如果加载失败且重试次数少于3次，则在1秒后重试
                    if retryCount < 3 {
                        print("⏳ 1秒后重试加载用户资料...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.loadUserProfile(for: userId, retryCount: retryCount + 1)
                        }
                    } else {
                        self?.errorMessage = "加载用户信息失败：\(error.localizedDescription)"
                    }
                    return
                }
                
                guard let document = document, document.exists else {
                    print("⚠️ 用户信息不存在")

                    if self?.isCurrentUserUsingExternalProvider == true {
                        self?.requiresProfileCompletion = true
                        self?.authState = .signedOut
                        self?.isLoading = false
                        self?.errorMessage = nil
                        return
                    }
                    
                    // 如果文档不存在且是首次尝试，可能是数据还没有同步，稍后重试
                    if retryCount < 3 {
                        print("⏳ 1秒后重试加载用户资料...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.loadUserProfile(for: userId, retryCount: retryCount + 1)
                        }
                    } else {
                        self?.errorMessage = "用户信息不存在"
                    }
                    return
                }
                
                do {
                    guard let self = self else {
                        return
                    }
                    
                    let profile = try self.parseUserProfile(from: document)
                    
                    self.currentUser = profile
                    
                    self.applyAuthenticationState(for: profile)
                } catch {
                    print("❌ 解析用户信息失败：\(error.localizedDescription)")
                    self?.errorMessage = "用户资料不完整，请联系管理员补全账户信息"
                }
            }
        }
    }

    func sendVerificationEmail() {
        guard let user = auth.currentUser, requiresEmailVerification(user) else {
            emailVerificationRequired = false
            verificationEmailSent = false
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        user.sendEmailVerification { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.verificationEmailSent = false
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    return
                }
                self.emailVerificationRequired = true
                self.verificationEmailSent = true
            }
        }
    }

    func checkEmailVerification(completion: ((Bool) -> Void)? = nil) {
        guard let user = auth.currentUser else {
            completion?(false)
            return
        }

        isLoading = true
        errorMessage = nil
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    completion?(false)
                    return
                }

                let isVerified = self.auth.currentUser?.isEmailVerified == true
                self.emailVerificationRequired = !isVerified && self.isCurrentUserUsingPasswordProvider
                if isVerified {
                    self.refreshIDToken(completion: nil)
                }
                completion?(isVerified)
            }
        }
    }

    func refreshIDToken(completion: ((Bool) -> Void)? = nil) {
        guard let user = auth.currentUser else {
            completion?(false)
            return
        }
        user.getIDTokenForcingRefresh(true) { _, error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }

    func refreshCurrentProfile() {
        guard let userID = auth.currentUser?.uid else { return }
        refreshIDToken { [weak self] _ in
            self?.loadUserProfile(for: userID)
        }
    }

    private func applyAuthenticationState(for profile: UserProfile) {
        let status = normalizedMembershipStatus(for: profile)
        if status == "revoked" {
            authState = .rejected
        } else if status == "active" || profile.isApproved {
            authState = .signedIn(profile)
        } else {
            // Authenticated unassigned and pending members retain public access,
            // while church-scoped content remains unavailable.
            authState = .pending
        }
    }

    private func normalizedMembershipStatus(for profile: UserProfile?) -> String? {
        guard let profile else { return nil }
        return (profile.membershipStatus ?? (profile.isApproved ? "active" : "pending"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func requiresEmailVerification(_ user: FirebaseAuth.User) -> Bool {
        isPasswordProvider(user) && !user.isEmailVerified
    }

    private func isPasswordProvider(_ user: FirebaseAuth.User) -> Bool {
        user.providerData.contains { $0.providerID == EmailAuthProviderID }
    }

    private func parseUserProfile(from document: DocumentSnapshot) throws -> UserProfile {
        guard let data = document.data() else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "用户资料文档为空"
            ])
        }
        
        let userId = self.stringValue(from: data["userId"]) ?? document.documentID
        let resolvedEmail = self.stringValue(from: data["email"]) ?? auth.currentUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard let email = resolvedEmail, !email.isEmpty else {
            throw NSError(domain: "AuthManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "缺少邮箱字段"
            ])
        }
        
        let fallbackName = email.components(separatedBy: "@").first ?? "Member"
        let name = self.stringValue(from: data["name"]) ?? self.stringValue(from: data["displayName"]) ?? fallbackName
        
        var profile = UserProfile(
            name: name,
            gender: UserGender(rawValue: self.stringValue(from: data["gender"]) ?? ""),
            birthDate: self.dateValue(from: data["birthDate"]),
            address: self.stringValue(from: data["address"]),
            email: email,
            phoneNumber: self.stringValue(from: data["phoneNumber"]),
            userId: userId,
            churchCountry: self.stringValue(from: data["churchCountry"]),
            churchName: self.stringValue(from: data["churchName"]),
            orgId: self.stringValue(from: data["orgId"]),
            regionId: self.stringValue(from: data["regionId"]),
            regionName: self.stringValue(from: data["regionName"]) ?? self.stringValue(from: data["churchCountry"]),
            branchId: self.stringValue(from: data["branchId"]),
            branchName: self.stringValue(from: data["branchName"]) ?? self.stringValue(from: data["churchName"]),
            salvationDate: self.dateValue(from: data["salvationDate"]),
            ministryDepartment: self.stringValue(from: data["ministryDepartment"]),
            confirmationPerson: self.stringValue(from: data["confirmationPerson"]),
            createdAt: self.dateValue(from: data["createdAt"]),
            updatedAt: self.dateValue(from: data["updatedAt"]),
            lastLoginDate: self.dateValue(from: data["lastLoginDate"]),
            isApproved: data["isApproved"] as? Bool ?? false,
            approvedAt: self.dateValue(from: data["approvedAt"]),
            role: self.stringValue(from: data["role"]) ?? "member",
            accessRole: self.stringValue(from: data["accessRole"]) ?? self.stringValue(from: data["role"]) ?? "member",
            membershipStatus: self.stringValue(from: data["membershipStatus"])
        )
        profile.id = document.documentID
        return profile
    }
    
    private func stringValue(from value: Any?) -> String? {
        guard let value else {
            return nil
        }
        
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        return nil
    }
    
    private func dateValue(from value: Any?) -> Date? {
        switch value {
        case let timestamp as Timestamp:
            return timestamp.dateValue()
        case let date as Date:
            return date
        case let string as String:
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: string)
        case let dictionary as [String: Any]:
            if let seconds = dictionary["seconds"] as? TimeInterval {
                return Date(timeIntervalSince1970: seconds)
            }
            return nil
        default:
            return nil
        }
    }
    
    // 检查用户是否有权限访问内容
    func hasContentAccess() -> Bool {
        switch authState {
        case .signedIn(_):
            return true
        default:
            return false
        }
    }

    var currentAuthenticatedUserID: String? {
        if let profileUserID = currentUser?.userId, !profileUserID.isEmpty {
            return profileUserID
        }

        return auth.currentUser?.uid
    }

    var currentFirebaseEmail: String? {
        auth.currentUser?.email
    }

    private var isCurrentUserUsingExternalProvider: Bool {
        auth.currentUser?.providerData.contains(where: { $0.providerID != EmailAuthProviderID }) == true
    }

    private var isCurrentUserUsingPasswordProvider: Bool {
        guard let user = auth.currentUser else { return false }
        return isPasswordProvider(user)
    }
    
    // 获取本地化错误消息
    private func getLocalizedErrorMessage(_ error: Error) -> String {
        if let authError = error as? AuthErrorCode {
            switch authError {
            case .emailAlreadyInUse:
                return "该邮箱已被使用"
            case .invalidEmail:
                return "邮箱格式无效"
            case .weakPassword:
                return "密码强度不够（至少6位）"
            case .userNotFound:
                return "用户不存在"
            case .wrongPassword:
                return "密码错误"
            case .tooManyRequests:
                return "请求过于频繁，请稍后再试"
            case .networkError:
                return "网络连接错误"
            default:
                return "认证失败：\(error.localizedDescription)"
            }
        }
        return "未知错误：\(error.localizedDescription)"
    }
    
    // 清除错误消息
    func clearError() {
        errorMessage = nil
    }
    
    // 重置密码（忘记密码功能）
    // 简化版：直接发送密码重置邮件，不验证邮箱是否存在（避免暴露用户信息）
    func resetPassword(email: String, newPassword: String, completion: @escaping (Bool, String?) -> Void) {
        print("📧 开始发送密码重置邮件: \(email)")
        
        // 直接使用 Firebase Auth 发送密码重置邮件
        // Firebase 会自动检查邮箱是否存在，如果不存在会返回错误
        auth.sendPasswordReset(withEmail: email) { [weak self] error in
            if let error = error {
                print("❌ 发送密码重置邮件失败: \(error.localizedDescription)")
                
                // 解析错误类型
                let nsError = error as NSError
                var errorMessage = "发送失败"
                
                if let errorCode = AuthErrorCode(rawValue: nsError.code) {
                    switch errorCode {
                    case .userNotFound:
                        errorMessage = "该邮箱未注册，请先注册账号"
                    case .invalidEmail:
                        errorMessage = "邮箱格式不正确"
                    case .networkError:
                        errorMessage = "网络连接失败，请检查网络"
                    default:
                        errorMessage = "发送失败：\(error.localizedDescription)"
                    }
                }
                
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
                return
            }
            
            print("✅ 密码重置邮件已发送")
            
            DispatchQueue.main.async {
                completion(true, "密码重置邮件已发送到您的邮箱，请查收。")
            }
        }
    }
}
