@preconcurrency import AVFoundation
import Foundation
import Speech

/// Microphone and speech-recognition permissions (R-45, onboarding step 1). Only the user changes them (TCC).
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
