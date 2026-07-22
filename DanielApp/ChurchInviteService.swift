import Foundation
import FirebaseAuth
import FirebaseFunctions

struct ChurchInviteRedemption: Equatable {
    let branchID: String
    let branchName: String
    let membershipStatus: String
}

enum ChurchInviteError: LocalizedError, Equatable {
    case invalid
    case expired
    case revoked
    case exhausted
    case emailNotVerified
    case unauthenticated
    case unavailable
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .invalid: return "invalid"
        case .expired: return "expired"
        case .revoked: return "revoked"
        case .exhausted: return "exhausted"
        case .emailNotVerified: return "email-not-verified"
        case .unauthenticated: return "unauthenticated"
        case .unavailable: return "unavailable"
        case .unexpected(let message): return message
        }
    }
}

protocol ChurchInviteServicing {
    func redeem(code: String, completion: @escaping (Result<ChurchInviteRedemption, ChurchInviteError>) -> Void)
}

final class FirebaseChurchInviteService: ChurchInviteServicing {
    private let functions: Functions
    private let auth: Auth

    init(functions: Functions = .functions(), auth: Auth = .auth()) {
        self.functions = functions
        self.auth = auth
    }

    func redeem(code: String, completion: @escaping (Result<ChurchInviteRedemption, ChurchInviteError>) -> Void) {
        let normalizedCode = code
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        guard normalizedCode.count == 16 else {
            completion(.failure(.invalid))
            return
        }

        guard auth.currentUser != nil else {
            completion(.failure(.unauthenticated))
            return
        }

        functions.httpsCallable("redeemBranchInvite").call(["code": normalizedCode]) { [weak self] result, error in
            if let error {
                completion(.failure(Self.map(error: error)))
                return
            }

            guard let payload = result?.data as? [String: Any],
                  let branchID = payload["branchId"] as? String else {
                completion(.failure(.unexpected("invalid-response")))
                return
            }

            let redemption = ChurchInviteRedemption(
                branchID: branchID,
                branchName: payload["branchName"] as? String ?? "",
                membershipStatus: payload["membershipStatus"] as? String ?? "pending"
            )

            self?.auth.currentUser?.getIDTokenForcingRefresh(true) { _, refreshError in
                if let refreshError {
                    completion(.failure(.unexpected(refreshError.localizedDescription)))
                } else {
                    completion(.success(redemption))
                }
            }
        }
    }

    private static func map(error: Error) -> ChurchInviteError {
        let nsError = error as NSError
        let details = nsError.userInfo["details"]
        let reason: String = {
            if let value = details as? String { return value }
            if let dictionary = details as? [String: Any] {
                return (dictionary["reason"] as? String) ?? (dictionary["code"] as? String) ?? ""
            }
            return ""
        }()
        .lowercased()

        let combined = "\(reason) \(nsError.localizedDescription.lowercased())"
        if combined.contains("expired") { return .expired }
        if combined.contains("revoked") { return .revoked }
        if combined.contains("exhausted") || combined.contains("max-use") { return .exhausted }
        if combined.contains("email-not-verified") || combined.contains("verify your email") { return .emailNotVerified }
        if combined.contains("unauthenticated") { return .unauthenticated }
        if combined.contains("invalid") || combined.contains("not-found") { return .invalid }
        if nsError.domain == NSURLErrorDomain { return .unavailable }
        return .unexpected(nsError.localizedDescription)
    }
}

@MainActor
final class ChurchInviteViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case redeeming
        case failed(ChurchInviteError)
        case submitted(ChurchInviteRedemption)
    }

    @Published private(set) var state: State = .idle
    @Published var code = ""

    private let service: ChurchInviteServicing

    init(service: ChurchInviteServicing = FirebaseChurchInviteService()) {
        self.service = service
    }

    var formattedCode: String {
        let characters = Array(code.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(16))
        return stride(from: 0, to: characters.count, by: 4)
            .map { String(characters[$0..<min($0 + 4, characters.count)]) }
            .joined(separator: "-")
    }

    var canSubmit: Bool {
        code.filter { $0.isLetter || $0.isNumber }.count == 16 && state != .redeeming
    }

    func updateCode(_ newValue: String) {
        code = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(16))
        if case .failed = state { state = .idle }
    }

    func redeem(onSuccess: @escaping () -> Void) {
        guard canSubmit else {
            state = .failed(.invalid)
            return
        }

        state = .redeeming
        service.redeem(code: code) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let redemption):
                    self.state = .submitted(redemption)
                    onSuccess()
                case .failure(let error):
                    self.state = .failed(error)
                }
            }
        }
    }
}
