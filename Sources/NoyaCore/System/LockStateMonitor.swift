import CoreGraphics
import Foundation

/// Indique si l'écran de la session courante est verrouillé.
///
/// `CGSessionCopyCurrentDictionary` est déclarée dans le SDK CoreGraphics : elle est appelée
/// directement, sans chargement dynamique de symbole (contrairement à la version d’origine de HeyMac).
/// La clé `CGSSessionScreenIsLocked` n'est en revanche **pas documentée** par Apple :
/// elle est absente (et non `false`) quand l'écran est déverrouillé, ce que la fonction
/// ramène à `false`.
///
/// Retourne `nil` si le dictionnaire n'a pas pu être lu. Les appelants doivent traiter
/// `nil` comme « état inconnu », jamais comme « déverrouillé ».
public func isScreenLocked() -> Bool? {
    guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else {
        return nil
    }
    return dictionary["CGSSessionScreenIsLocked"] as? Bool ?? false
}
