import ApplicationServices
import AVFoundation
import Foundation
import Observation
import ServiceManagement

/// Autorisations demandées par l'assistant. Rien n'est demandé sans action de l'utilisateur.
@MainActor
@Observable
final class PermissionsModel {
    private(set) var camera: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var accessibilityGranted = AXIsProcessTrusted()
    private(set) var openAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var loginItemNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    private(set) var loginItemError: String?
    private var pollTask: Task<Void, Never>?

    var cameraGranted: Bool { camera == .authorized }
    var cameraDenied: Bool { camera == .denied || camera == .restricted }

    func refresh() {
        camera = AVCaptureDevice.authorizationStatus(for: .video)
        accessibilityGranted = AXIsProcessTrusted()
        let status = SMAppService.mainApp.status
        openAtLogin = status == .enabled
        loginItemNeedsApproval = status == .requiresApproval
    }

    /// Affiche l'invite système d'autorisation de la caméra (une seule fois ; ensuite, seul
    /// Réglages Système permet de changer d'avis).
    func requestCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        refresh()
    }

    /// Ouvre l'invite de macOS qui mène à Réglages Système › Accessibilité, puis surveille
    /// l'autorisation pendant une minute (macOS ne prévient pas l'app quand elle change).
    func requestAccessibility() {
        let options = [SystemKeys.accessibilityPromptOption: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.accessibilityGranted = AXIsProcessTrusted()
                if self.accessibilityGranted { return }
            }
        }
    }

    func setOpenAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
        }
        refresh()
    }
}
