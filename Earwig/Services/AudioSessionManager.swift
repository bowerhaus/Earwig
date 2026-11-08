import AVFoundation
import Observation

/// The audio route as Earwig cares about it (PRD §4.3): what is playing the prompt, what is
/// listening, and whether either is wrong for a take.
struct AudioRoute: Equatable, Sendable {
    struct Port: Equatable, Sendable {
        let type: String
        let name: String
    }

    var outputs: [Port] = []
    var inputs: [Port] = []

    /// The earpiece has fallen into the hands-free profile: telephone-quality output and its
    /// own microphone.
    var isHandsFree: Bool {
        (outputs + inputs).contains { $0.type == AVAudioSession.Port.bluetoothHFP.rawValue }
    }

    var isBluetoothA2DP: Bool {
        outputs.contains { $0.type == AVAudioSession.Port.bluetoothA2DP.rawValue }
    }

    /// The prompt is coming out of the phone's own speaker, where the mic will hear it.
    var isSpeaker: Bool {
        outputs.contains { $0.type == AVAudioSession.Port.builtInSpeaker.rawValue }
    }

    var inputIsBuiltInMic: Bool {
        inputs.contains { $0.type == AVAudioSession.Port.builtInMic.rawValue }
    }

    /// Right for a take: no hands-free profile and the iPhone's own mic listening.
    var isGoodForTake: Bool { !isHandsFree && inputIsBuiltInMic }

    var summary: String {
        let out = outputs.map { "\($0.name) (\(Self.label($0.type)))" }.joined(separator: ", ")
        let inp = inputs.map { "\($0.name) (\(Self.label($0.type)))" }.joined(separator: ", ")
        return "out: \(out.isEmpty ? "none" : out); in: \(inp.isEmpty ? "none" : inp)"
    }

    static func label(_ type: String) -> String {
        switch AVAudioSession.Port(rawValue: type) {
        case .bluetoothA2DP: "A2DP"
        case .bluetoothHFP: "hands-free"
        case .bluetoothLE: "Bluetooth LE"
        case .builtInMic: "built-in mic"
        case .builtInSpeaker: "speaker"
        case .builtInReceiver: "receiver"
        case .headphones: "wired"
        case .headsetMic: "headset mic"
        default: type
        }
    }

    init() {}

    init(_ route: AVAudioSessionRouteDescription) {
        outputs = route.outputs.map { Port(type: $0.portType.rawValue, name: $0.portName) }
        inputs = route.inputs.map { Port(type: $0.portType.rawValue, name: $0.portName) }
    }
}

/// Configures the shared audio session for a take and reports the route (PRD §4.3, §7.2):
/// `.playAndRecord`, Bluetooth allowed for A2DP output only (never the hands-free profile),
/// the built-in mic as preferred input. Reports route changes and interruptions.
@MainActor
@Observable
final class AudioSessionManager {
    private(set) var route = AudioRoute()
    private(set) var isConfigured = false
    private(set) var microphoneGranted = false
    private(set) var lastError: String?

    /// Called with a one-line description of every route change, interruption and error.
    @ObservationIgnored var onEvent: ((String) -> Void)?
    /// Called when an interruption begins (`true`) or ends (`false`).
    @ObservationIgnored var onInterruption: ((Bool) -> Void)?
    /// Called when the output device has gone (the earpiece taken out or switched off).
    @ObservationIgnored var onDeviceLost: (() -> Void)?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Every manager configures the one shared session. Each configure takes the next number,
    /// so a take's teardown that finishes after the next take has configured the session leaves
    /// it alone instead of turning it off under that take (review C1, plan 005).
    private static var configurations = 0
    @ObservationIgnored private var configuration: Int?

    init() {
        let centre = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(centre.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            MainActor.assumeIsolated { self?.routeChanged(reason: reason) }
        })
        observers.append(centre.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated { self?.interrupted(type: type) }
        })
        observers.append(centre.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onEvent?("media services were reset; reconfiguring")
                self?.isConfigured = false
                try? self?.configure()
            }
        })
        route = AudioRoute(session.currentRoute)
    }

    /// Asks for the microphone once; later calls return the stored answer.
    func requestMicrophone() async -> Bool {
        microphoneGranted = await AVAudioApplication.requestRecordPermission()
        return microphoneGranted
    }

    /// Sets the category, mode and options, activates the session and pins the built-in mic.
    func configure() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
            Self.configurations += 1
            configuration = Self.configurations
            try preferBuiltInMic()
            isConfigured = true
            lastError = nil
            route = AudioRoute(session.currentRoute)
            onEvent?("session configured: \(route.summary)")
        } catch {
            lastError = error.localizedDescription
            onEvent?("session configure failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Lets the session go, unless another manager has configured it since this one did.
    func deactivate() {
        defer {
            isConfigured = false
            configuration = nil
        }
        guard configuration == Self.configurations else {
            onEvent?("session left active: configured since for another take")
            return
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onEvent?("session deactivated")
    }

    private func preferBuiltInMic() throws {
        let session = AVAudioSession.sharedInstance()
        guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            onEvent?("no built-in mic among available inputs")
            return
        }
        if session.preferredInput?.portType != .builtInMic {
            try session.setPreferredInput(builtIn)
        }
    }

    private func routeChanged(reason: AVAudioSession.RouteChangeReason?) {
        let session = AVAudioSession.sharedInstance()
        let previous = route
        route = AudioRoute(session.currentRoute)
        onEvent?("route change (\(reason.map(Self.describe) ?? "unknown")): \(route.summary)")
        if isConfigured, !route.inputIsBuiltInMic, previous.inputIsBuiltInMic {
            try? preferBuiltInMic()
        }
        if reason == .oldDeviceUnavailable { onDeviceLost?() }
    }

    private func interrupted(type: AVAudioSession.InterruptionType?) {
        switch type {
        case .began:
            onEvent?("interruption began")
            onInterruption?(true)
        case .ended:
            onEvent?("interruption ended")
            onInterruption?(false)
        default:
            break
        }
    }

    private static func describe(_ reason: AVAudioSession.RouteChangeReason) -> String {
        switch reason {
        case .newDeviceAvailable: "new device"
        case .oldDeviceUnavailable: "device gone"
        case .categoryChange: "category change"
        case .override: "override"
        case .wakeFromSleep: "wake from sleep"
        case .noSuitableRouteForCategory: "no suitable route"
        case .routeConfigurationChange: "configuration change"
        default: "other"
        }
    }
}
