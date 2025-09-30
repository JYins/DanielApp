import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// 认证管理器
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var authState: AuthState = .signedOut
    @Published var currentUser: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
                    self?.loadUserProfile(for: user.uid)
                    // 设置实时监听用户资料变化
                    self?.setupUserProfileListener(for: user.uid)
                } else {
                    self?.authState = .signedOut
                    self?.currentUser = nil
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
                    let profile = try document.data(as: UserProfile.self)
                    let oldState = self?.authState
                    
                    // 更新当前用户资料
                    self?.currentUser = profile
                    
                    // 根据审核状态更新认证状态
                    if profile.isApproved {
                        self?.authState = .signedIn(profile)
                        
                        // 检查状态是否从pending变为signedIn
                        if case .pending = oldState {
                            print("🎉 用户审核已通过！状态从pending变为signedIn")
                            // 可以在这里添加通知用户的逻辑
                        } else {
                            print("✅ 用户资料已更新，状态: signedIn")
                        }
                    } else {
                        self?.authState = .pending
                        print("⏳ 用户资料已更新，状态: pending（等待审核）")
                    }
                } catch {
                    print("❌ 解析用户资料失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 注册用户
    func register(with formData: RegistrationFormData) {
        isLoading = true
        errorMessage = nil
        
        auth.createUser(withEmail: formData.email, password: formData.password) { [weak self] result, error in
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
                let userProfile = UserProfile(
                    name: formData.name,
                    gender: formData.gender,
                    birthDate: formData.birthDate,
                    address: formData.address,
                    email: formData.email,
                    phoneNumber: formData.phoneNumber,
                    userId: user.uid,
                    churchCountry: formData.churchCountry,
                    churchName: formData.churchName,
                    salvationDate: formData.salvationDate,
                    ministryDepartment: formData.ministryDepartment.isEmpty ? nil : formData.ministryDepartment,
                    confirmationPerson: formData.confirmationPerson
                )
                
                // 保存用户资料到Firestore
                self?.saveUserProfile(userProfile)
            }
        }
    }
    
    // 用户登录
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = self?.getLocalizedErrorMessage(error)
                    self?.isLoading = false
                    return
                }
                
                // 用户登录成功，状态监听器会自动处理后续逻辑
                self?.isLoading = false
            }
        }
    }
    
    // 用户注销
    func signOut() {
        do {
            try auth.signOut()
            authState = .signedOut
            currentUser = nil
        } catch {
            errorMessage = "注销失败：\(error.localizedDescription)"
        }
    }
    
    // 保存用户资料到Firestore
    private func saveUserProfile(_ profile: UserProfile) {
        print("💾 开始保存用户资料: \(profile.name)")
        
        do {
            try db.collection("users").document(profile.userId).setData(from: profile) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ 保存用户信息失败：\(error.localizedDescription)")
                        self?.errorMessage = "保存用户信息失败：\(error.localizedDescription)"
                        self?.isLoading = false
                        return
                    }
                    
                    print("✅ 用户资料保存成功，开始验证数据...")
                    
                    // 保存成功后，验证数据是否真的写入了
                    self?.verifyUserProfileSaved(profile)
                }
            }
        } catch {
            print("❌ 保存用户信息失败（异常）：\(error.localizedDescription)")
            errorMessage = "保存用户信息失败：\(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // 验证用户资料是否已保存
    private func verifyUserProfileSaved(_ profile: UserProfile, retryCount: Int = 0) {
        print("🔍 验证用户资料是否已保存，重试次数: \(retryCount)")
        
        db.collection("users").document(profile.userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 验证失败：\(error.localizedDescription)")
                    
                    // 如果验证失败且重试次数少于3次，则重试
                    if retryCount < 3 {
                        print("⏳ 1秒后重试验证...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.verifyUserProfileSaved(profile, retryCount: retryCount + 1)
                        }
                    } else {
                        self?.errorMessage = "用户注册成功，但验证失败，请重新登录"
                        self?.isLoading = false
                    }
                    return
                }
                
                if document?.exists == true {
                    print("✅ 用户资料验证成功，注册完成")
                    self?.currentUser = profile
                    self?.authState = .pending // 等待审核
                    self?.isLoading = false
                } else {
                    print("⚠️ 验证时发现用户资料不存在")
                    
                    // 如果文档不存在且重试次数少于3次，则重试
                    if retryCount < 3 {
                        print("⏳ 1秒后重试验证...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.verifyUserProfileSaved(profile, retryCount: retryCount + 1)
                        }
                    } else {
                        self?.errorMessage = "用户注册成功，但验证失败，请重新登录"
                        self?.isLoading = false
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
                    let profile = try document.data(as: UserProfile.self)
                    self?.currentUser = profile
                    
                    // 根据审核状态设置认证状态
                    if profile.isApproved {
                        self?.authState = .signedIn(profile)
                        print("✅ 用户资料加载成功，已通过审核: \(profile.name)")
                    } else {
                        self?.authState = .pending
                        print("⏳ 用户资料加载成功，等待审核: \(profile.name)")
                    }
                } catch {
                    print("❌ 解析用户信息失败：\(error.localizedDescription)")
                    self?.errorMessage = "解析用户信息失败：\(error.localizedDescription)"
                }
            }
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
    func resetPassword(email: String, newPassword: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 开始验证邮箱是否存在: \(email)")
        
        // 首先检查用户是否存在于Firestore
        db.collection("users").whereField("email", isEqualTo: email).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ 查询用户失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "查询用户失败：\(error.localizedDescription)")
                }
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("❌ 该邮箱未注册")
                DispatchQueue.main.async {
                    completion(false, "该邮箱未注册，请先注册账号")
                }
                return
            }
            
            // 用户存在，获取用户ID
            guard let userId = documents.first?.documentID else {
                DispatchQueue.main.async {
                    completion(false, "无法获取用户信息")
                }
                return
            }
            
            print("✅ 找到用户，开始更新密码和审核状态")
            
            // 使用Firebase Admin SDK的方式需要服务器端，这里我们使用Firebase Auth的密码重置
            // 但是我们需要同时更新Firestore中的审核状态
            
            // 1. 更新Firestore中的审核状态为false
            self?.db.collection("users").document(userId).updateData([
                "isApproved": false,
                "updatedAt": Date()
            ]) { error in
                if let error = error {
                    print("❌ 更新审核状态失败: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false, "更新审核状态失败：\(error.localizedDescription)")
                    }
                    return
                }
                
                print("✅ 审核状态已重置为待审核")
                
                // 2. 发送密码重置邮件（Firebase标准方式）
                self?.auth.sendPasswordReset(withEmail: email) { error in
                    if let error = error {
                        print("❌ 发送密码重置邮件失败: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(false, "发送密码重置邮件失败：\(error.localizedDescription)")
                        }
                        return
                    }
                    
                    print("✅ 密码重置邮件已发送")
                    DispatchQueue.main.async {
                        completion(true, "密码重置邮件已发送到您的邮箱，请查收。您的账号审核状态已重置，重置密码后需要重新等待审核。")
                    }
                }
            }
        }
    }
} 