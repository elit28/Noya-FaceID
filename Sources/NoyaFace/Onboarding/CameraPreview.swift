import AVFoundation
import AppKit
import SwiftUI

/// Aperçu en direct de la caméra, en miroir comme un selfie. L'image n'est ni enregistrée
/// ni transmise : elle est seulement affichée pendant l'enrôlement.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.attach(session)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.attach(session)
        }
    }

    static func dismantleNSView(_ nsView: PreviewView, coordinator: ()) {
        nsView.detach()
    }

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()
        private var startObserver: NSObjectProtocol?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.backgroundColor = NSColor(white: 0.07, alpha: 1).cgColor
            previewLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(previewLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") } // noloc

        /// La connexion de l'aperçu n'existe qu'une fois la caméra configurée : le miroir est
        /// donc réappliqué au démarrage de la session.
        func attach(_ session: AVCaptureSession) {
            detach()
            previewLayer.session = session
            startObserver = NotificationCenter.default.addObserver(
                forName: AVCaptureSession.didStartRunningNotification, object: session, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.applyMirroring() }
            }
            applyMirroring()
        }

        func detach() {
            if let startObserver {
                NotificationCenter.default.removeObserver(startObserver)
            }
            startObserver = nil
        }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
            applyMirroring()
        }

        private func applyMirroring() {
            guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
