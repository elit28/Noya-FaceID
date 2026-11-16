import Foundation
import OpenDirectory

public enum LoginPasswordCheck: Equatable, Sendable {
    case valid
    case invalid
    /// macOS n'a pas pu vérifier (compte introuvable, service indisponible).
    case unavailable(String)
}

/// Vérifie le mot de passe de session auprès de macOS (OpenDirectory, API publique) avant
/// qu'il soit enregistré : un mot de passe faux ne doit jamais être tapé sur l'écran verrouillé.
public enum LoginPasswordVerifier {
    /// `ODFrameworkErrorDomain` et `kODErrorCredentialsInvalid` (ODConstants.h).
    static let credentialsErrorDomain = "com.apple.OpenDirectory"
    static let credentialsInvalid = 5000

    public static func verify(_ password: String, user: String = NSUserName()) -> LoginPasswordCheck {
        guard !password.isEmpty else { return .invalid }
        do {
            let node = try ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeAuthentication))
            let record = try node.record(withRecordType: kODRecordTypeUsers, name: user, attributes: nil)
            try record.verifyPassword(password)
            return .valid
        } catch let error as NSError where error.domain == credentialsErrorDomain && error.code == credentialsInvalid {
            return .invalid
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }
}
