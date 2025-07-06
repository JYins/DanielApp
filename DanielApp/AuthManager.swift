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
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // 设置认证状态监听器
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.loadUserProfile(for: user.uid)
                } else {
                    self?.authState = .signedOut
                    self?.currentUser = nil
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
        do {
            try db.collection("users").document(profile.userId).setData(from: profile) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = "保存用户信息失败：\(error.localizedDescription)"
                        self?.isLoading = false
                        return
                    }
                    
                    self?.currentUser = profile
                    self?.authState = .pending // 等待审核
                    self?.isLoading = false
                    
                    print("✅ 用户注册成功，等待管理员审核")
                }
            }
        } catch {
            errorMessage = "保存用户信息失败：\(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // 从Firestore加载用户资料
    private func loadUserProfile(for userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "加载用户信息失败：\(error.localizedDescription)"
                    return
                }
                
                guard let document = document, document.exists else {
                    self?.errorMessage = "用户信息不存在"
                    return
                }
                
                do {
                    let profile = try document.data(as: UserProfile.self)
                    self?.currentUser = profile
                    
                    // 根据审核状态设置认证状态
                    if profile.isApproved {
                        self?.authState = .signedIn(profile)
                        print("✅ 用户资料加载成功，已通过审核")
                    } else {
                        self?.authState = .pending
                        print("⏳ 用户资料加载成功，等待审核")
                    }
                } catch {
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
} 