import Testing
@testable import NoyaCore

@Test func isScreenLockedReadsSessionDictionarySuccessfully() {
    // N'impose pas d'état particulier (il dépend de la machine qui exécute le test) :
    // vérifie seulement que le dictionnaire de session est lisible.
    let result = isScreenLocked()
    #expect(result != nil, "isScreenLocked() doit pouvoir lire CGSessionCopyCurrentDictionary sur macOS")
}
