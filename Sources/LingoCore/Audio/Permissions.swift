@preconcurrency import AVFoundation
import Foundation
import Speech

/// Разрешения на микрофон и распознавание речи (R-45, шаг 1 мастера). Меняет их только пользователь (TCC).
public enum Permissions {
    public enum State: String, Sendable { case granted, denied, notDetermined }

    public static var microphone: State {
        #if os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
        #else
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .undetermined: return .notDetermined
        default: return .denied
        }
        #endif
    }

    public static var speech: State {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    public static func requestMicrophone() async -> Bool {
        #if os(macOS)
        await AVCaptureDevice.requestAccess(for: .audio)
        #else
        await AVAudioApplication.requestRecordPermission()
        #endif
    }

    public static func requestSpeech() async -> Bool { await AppleSpeechEngine.requestAuthorization() }
}
