import Foundation
import FirebaseFirestore

// 用户个人资料模型
struct UserProfile: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    
    // 基本信息
    var name: String
    var birthDate: Date
    var address: String
    var email: String
    var phoneNumber: String
    var userId: String // Firebase Auth的用户ID
    
    // 信仰信息
    var churchCountry: String
    var churchName: String
    var salvationDate: Date
    var ministryDepartment: String? // 侍奉部署（可选）
    var confirmationPerson: String // 圣徒信息确认人员
    
    // 系统信息
    var createdAt: Date
    var updatedAt: Date
    var isApproved: Bool // 是否通过审核
    var approvedAt: Date?
    
    init(name: String, birthDate: Date, address: String, email: String, phoneNumber: String, userId: String, churchCountry: String, churchName: String, salvationDate: Date, ministryDepartment: String? = nil, confirmationPerson: String) {
        self.name = name
        self.birthDate = birthDate
        self.address = address
        self.email = email
        self.phoneNumber = phoneNumber
        self.userId = userId
        self.churchCountry = churchCountry
        self.churchName = churchName
        self.salvationDate = salvationDate
        self.ministryDepartment = ministryDepartment
        self.confirmationPerson = confirmationPerson
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isApproved = false // 需要管理员审核
        self.approvedAt = nil
    }
}

// 用户认证状态
enum AuthState: Equatable {
    case signedOut
    case signedIn(UserProfile)
    case pending // 等待审核
    case rejected // 审核被拒绝
    
    // 实现Equatable协议
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.signedOut, .signedOut):
            return true
        case (.pending, .pending):
            return true
        case (.rejected, .rejected):
            return true
        case let (.signedIn(lhsProfile), .signedIn(rhsProfile)):
            return lhsProfile.id == rhsProfile.id
        default:
            return false
        }
    }
    
    // 便利属性检查状态
    var isPending: Bool {
        if case .pending = self {
            return true
        }
        return false
    }
    
    var isSignedIn: Bool {
        if case .signedIn(_) = self {
            return true
        }
        return false
    }
}

// 注册表单数据
struct RegistrationFormData {
    var name: String = ""
    var birthDate: Date = Date()
    var address: String = ""
    var email: String = ""
    var phoneNumber: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    
    var churchCountry: String = ""
    var churchName: String = ""
    var salvationDate: Date = Date()
    var ministryDepartment: String = ""
    var confirmationPerson: String = ""
    
    // 表单验证
    var isValid: Bool {
        return !name.isEmpty &&
               !address.isEmpty &&
               !email.isEmpty &&
               !phoneNumber.isEmpty &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 6 &&
               !churchCountry.isEmpty &&
               !churchName.isEmpty &&
               !confirmationPerson.isEmpty
    }
    
    var passwordsMatch: Bool {
        return password == confirmPassword
    }
}

// Newsletter文案的多语言支持
struct NewsletterCaption: Codable {
    let chinese: String
    let english: String
    let korean: String
    
    func text(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese:
            return chinese
        case .english:
            return english
        case .korean:
            return korean
        }
    }
}

// Newsletter数据模型
struct Newsletter: Codable, Identifiable {
    var id: String
    var publishDate: Date
    var imageURLs: [String] // Firebase Storage中的图片路径
    var caption: NewsletterCaption
    var isPublished: Bool
    
    // Newsletter配置文件模型（与话语卡片一致）
    struct NewsletterConfig: Codable {
        let captions: CaptionData
        let publishDate: String  // 格式: "2025-01-15"
        let isPublished: Bool?
        
        struct CaptionData: Codable {
            let chinese: String
            let english: String
            let korean: String
        }
    }
    
    init(id: String, publishDate: Date, imageURLs: [String], caption: NewsletterCaption, isPublished: Bool = true) {
        self.id = id
        self.publishDate = publishDate
        self.imageURLs = imageURLs
        self.caption = caption
        self.isPublished = isPublished
    }
} 