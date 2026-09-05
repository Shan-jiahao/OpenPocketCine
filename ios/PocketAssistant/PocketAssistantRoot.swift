import SwiftUI
import UIKit

enum PocketAssistantTab: Hashable {
    case devices
    case capture
    case headTrack
}

struct PocketAssistantRoot: View {
    @State private var model = AppModel()
    @State private var selection: PocketAssistantTab = .headTrack
    @State private var didStart = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                PocketAssistantDevicesView()
            }
            .tag(PocketAssistantTab.devices)
            .tabItem { Label("设备", systemImage: "camera.fill") }

            NavigationStack {
                PocketAssistantCaptureView {
                    selection = .devices
                }
            }
            .tag(PocketAssistantTab.capture)
            .tabItem { Label("拍摄", systemImage: "record.circle") }

            NavigationStack {
                PocketAssistantHeadTrackView {
                    selection = .devices
                }
            }
            .tag(PocketAssistantTab.headTrack)
            .tabItem { Label("头追", systemImage: "viewfinder") }
        }
        .tint(PocketAssistantDesign.primary)
        .environment(model)
        .onAppear { startIfNeeded() }
        .onChange(of: model.keepScreenAwake) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onChange(of: model.headTrackingEnabled) { _, _ in
            model.headphoneMotion.sync()
        }
        .onChange(of: model.session.phase) { oldPhase, newPhase in
            if case .live = newPhase {
                model.noteBecameLive()
                model.headphoneMotion.sync()
                selection = .headTrack
            } else if case .live = oldPhase {
                model.headphoneMotion.noteLinkUnavailable()
                model.noteLeftLive()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.session.noteSceneBecameActive()
                model.headphoneMotion.sync()
            case .inactive, .background:
                model.headphoneMotion.noteSceneBecameInactive()
                model.session.noteSceneBecameInactive()
            @unknown default:
                break
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        ) { _ in
            model.headphoneMotion.noteSceneBecameInactive()
            model.session.noteSceneBecameInactive()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            model.session.noteSceneBecameActive()
            model.headphoneMotion.sync()
        }
    }

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        DiagnosticCenter.shared.install()
        AppModelDiagnosticsAnchor.model = model
        model.prepareStartup()
        model.headphoneMotion.attach(model: model)
        UIApplication.shared.isIdleTimerDisabled = model.keepScreenAwake
        if model.savedCameras.isEmpty { selection = .devices }
    }
}
