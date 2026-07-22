import Foundation
import FirebaseFirestore

// 用户性别枚举
enum UserGender: String, Codable {
    case brother = "brother" // 弟兄
    case sister = "sister"   // 姊妹
    
    func localizedName(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .brother:
            switch language {
            case .chinese: return "弟兄"
            case .english: return "Brother"
            case .korean: return "형제"
            }
        case .sister:
            switch language {
            case .chinese: return "姊妹"
            case .english: return "Sister"
            case .korean: return "자매"
            }
        }
    }
}

// 用户个人资料模型
struct UserProfile: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    
    // 基本信息
    var name: String
    var gender: UserGender? // 性别：弟兄/姊妹（可选）
    var birthDate: Date?
    var address: String?
    var email: String
    var phoneNumber: String?
    var userId: String // Firebase Auth的用户ID
    
    // 信仰信息
    var churchCountry: String?
    var churchName: String?
    var orgId: String?
    var regionId: String?
    var regionName: String?
    var branchId: String?
    var branchName: String?
    var salvationDate: Date?
    var ministryDepartment: String? // 侍奉部署（可选）
    var confirmationPerson: String? // 圣徒信息确认人员
    
    // 系统信息
    var createdAt: Date?
    var updatedAt: Date?
    var lastLoginDate: Date? // 最后登录时间（用于检测密码重置）
    var isApproved: Bool // 是否通过审核
    var approvedAt: Date?
    var role: String?
    var accessRole: String?
    var membershipStatus: String?
    
    init(
        name: String,
        gender: UserGender? = nil,
        birthDate: Date? = nil,
        address: String? = nil,
        email: String,
        phoneNumber: String? = nil,
        userId: String,
        churchCountry: String? = nil,
        churchName: String? = nil,
        orgId: String? = nil,
        regionId: String? = nil,
        regionName: String? = nil,
        branchId: String? = nil,
        branchName: String? = nil,
        salvationDate: Date? = nil,
        ministryDepartment: String? = nil,
        confirmationPerson: String? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        lastLoginDate: Date? = nil,
        isApproved: Bool = false,
        approvedAt: Date? = nil,
        role: String? = "member",
        accessRole: String? = "member",
        membershipStatus: String? = "unassigned"
    ) {
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.address = address
        self.email = email
        self.phoneNumber = phoneNumber
        self.userId = userId
        self.churchCountry = churchCountry
        self.churchName = churchName
        self.orgId = orgId
        self.regionId = regionId
        self.regionName = regionName
        self.branchId = branchId
        self.branchName = branchName
        self.salvationDate = salvationDate
        self.ministryDepartment = ministryDepartment
        self.confirmationPerson = confirmationPerson
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastLoginDate = lastLoginDate
        self.isApproved = isApproved
        self.approvedAt = approvedAt
        self.role = role
        self.accessRole = accessRole
        self.membershipStatus = membershipStatus
    }
}

extension UserProfile {
    func displayBranchName(for language: CoreModels.VerseLanguage) -> String {
        branchName?.nilIfBlank ?? churchName?.nilIfBlank ?? localizedMissingValue(for: language)
    }

    func displayRegionName(for language: CoreModels.VerseLanguage) -> String {
        regionName?.nilIfBlank ?? churchCountry?.nilIfBlank ?? localizedMissingValue(for: language)
    }

    func displayMembershipStatus(for language: CoreModels.VerseLanguage) -> String {
        let status = (membershipStatus ?? (isApproved ? "active" : "pending")).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch status {
        case "active", "approved":
            switch language {
            case .chinese: return "已通过"
            case .english: return "Approved"
            case .korean: return "승인됨"
            }
        case "requested", "pending":
            switch language {
            case .chinese: return "审核中"
            case .english: return "Pending Review"
            case .korean: return "승인 대기"
            }
        case "revoked":
            switch language {
            case .chinese: return "已停用"
            case .english: return "Revoked"
            case .korean: return "중지됨"
            }
        case "unassigned":
            switch language {
            case .chinese: return "尚未加入教会"
            case .english: return "No church yet"
            case .korean: return "소속 교회 없음"
            }
        default:
            return status.isEmpty ? localizedMissingValue(for: language) : status
        }
    }

    func displayAccessRole(for language: CoreModels.VerseLanguage) -> String {
        let roleValue = (accessRole ?? role ?? "member").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch roleValue {
        case "admin", "global_admin":
            switch language {
            case .chinese: return "全局管理员"
            case .english: return "Global Admin"
            case .korean: return "전체 관리자"
            }
        case "region_admin":
            switch language {
            case .chinese: return "区域管理员"
            case .english: return "Region Admin"
            case .korean: return "지역 관리자"
            }
        case "branch_admin":
            switch language {
            case .chinese: return "分堂管理员"
            case .english: return "Branch Admin"
            case .korean: return "지교회 관리자"
            }
        case "member":
            switch language {
            case .chinese: return "成员"
            case .english: return "Member"
            case .korean: return "회원"
            }
        default:
            return roleValue.isEmpty ? localizedMissingValue(for: language) : roleValue
        }
    }

    private func localizedMissingValue(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return "未设置"
        case .english: return "Not set"
        case .korean: return "설정되지 않음"
        }
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
    var gender: UserGender? = nil
    var birthDate: Date? = nil
    var address: String = ""
    var email: String = ""
    var phoneNumber: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    
    var churchCountry: String = ""
    var churchName: String = ""
    var orgId: String = ""
    var regionId: String = ""
    var regionName: String = ""
    var branchId: String = ""
    var branchName: String = ""
    var salvationDate: Date? = nil
    var ministryDepartment: String = ""
    var confirmationPerson: String = ""
    
    // 表单验证
    var isValid: Bool {
        return !trimmedName.isEmpty &&
               !trimmedEmail.isEmpty &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 6
    }
    
    var passwordsMatch: Bool {
        return password == confirmPassword
    }
    
    var trimmedName: String {
        name.trimmed
    }
    
    var trimmedEmail: String {
        email.trimmed.lowercased()
    }
    
    var trimmedChurchCountry: String {
        churchCountry.trimmed
    }
    
    var trimmedChurchName: String {
        churchName.trimmed
    }

    var trimmedOrgId: String {
        orgId.trimmed
    }

    var trimmedRegionId: String {
        regionId.trimmed
    }

    var trimmedRegionName: String {
        regionName.trimmed
    }

    var trimmedBranchId: String {
        branchId.trimmed
    }

    var trimmedBranchName: String {
        branchName.trimmed
    }
    
    var trimmedConfirmationPerson: String {
        confirmationPerson.trimmed
    }
    
    var optionalAddress: String? {
        address.nilIfBlank
    }
    
    var optionalPhoneNumber: String? {
        phoneNumber.nilIfBlank
    }
    
    var optionalMinistryDepartment: String? {
        ministryDepartment.nilIfBlank
    }

    var optionalOrgId: String? {
        orgId.nilIfBlank
    }

    var optionalRegionId: String? {
        regionId.nilIfBlank
    }

    var optionalBranchId: String? {
        branchId.nilIfBlank
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
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
    @DocumentID var id: String?
    var publishDate: Timestamp
    var image_urls: [String] // Firestore中的图片URL数组
    var caption_cn: String
    var caption_en: String
    var caption_kr: String
    var published: Bool
    var createdAt: Timestamp?
    var updatedAt: Timestamp?
    var branchId: String?
    var contentType: String?
    
    // 兼容旧代码的属性
    var caption: NewsletterCaption {
        NewsletterCaption(chinese: caption_cn, english: caption_en, korean: caption_kr)
    }
    
    // 初始化方法，主要用于本地测试或预览
    init(
        id: String?,
        publishDate: Date,
        imageURLs: [String],
        caption: NewsletterCaption,
        isPublished: Bool = true,
        branchId: String? = nil,
        contentType: String? = "newsletter"
    ) {
        self.id = id
        self.publishDate = Timestamp(date: publishDate)
        self.image_urls = imageURLs
        self.caption_cn = caption.chinese
        self.caption_en = caption.english
        self.caption_kr = caption.korean
        self.published = isPublished
        self.createdAt = Timestamp(date: Date())
        self.updatedAt = Timestamp(date: Date())
        self.branchId = branchId
        self.contentType = contentType
    }
}
