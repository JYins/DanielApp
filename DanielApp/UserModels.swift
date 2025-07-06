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

// Newsletter数据模型
struct Newsletter: Codable, Identifiable {
    @DocumentID var id: String?
    
    var title: String
    var titleKorean: String
    var titleChinese: String
    var year: Int
    var month: Int
    var publishDate: Date
    var imageURLs: [String] // Firebase Storage中的图片路径
    var description: String?
    var descriptionKorean: String?
    var descriptionChinese: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, titleKorean: String, titleChinese: String, year: Int, month: Int, publishDate: Date, imageURLs: [String], description: String? = nil, descriptionKorean: String? = nil, descriptionChinese: String? = nil) {
        self.title = title
        self.titleKorean = titleKorean
        self.titleChinese = titleChinese
        self.year = year
        self.month = month
        self.publishDate = publishDate
        self.imageURLs = imageURLs
        self.description = description
        self.descriptionKorean = descriptionKorean
        self.descriptionChinese = descriptionChinese
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 