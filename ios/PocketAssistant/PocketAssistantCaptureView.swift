import OpenPocketViewCore
import SwiftUI

struct PocketAssistantCaptureView: View {
    @Environment(AppModel.self) private var model
    let openDevices: () -> Void

    var body: some View {
        ZStack {
            PocketAssistantBackground()
            ScrollView {
                VStack(spacing: 16) {
                    PocketAssistantLinkBanner(action: openDevices)
                    recordCard
                    cameraStateCard
                    formatCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("拍摄助手")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("pocketAssistant.capture")
    }

    private var recordCard: some View {
        PocketAssistantCard {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(captureTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PocketAssistantDesign.text)
                        Text(captureDetail)
                            .font(.footnote)
                            .foregroundStyle(PocketAssistantDesign.secondary)
                    }
                    Spacer()
                    if model.session.status.isRecording {
                        Text(Self.clock(model.session.status.recordElapsedSec))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(PocketAssistantDesign.danger)
                    }
                }

                Button {
                    model.session.pressShutter()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 4)
                            .frame(width: 86, height: 86)
                        RoundedRectangle(
                            cornerRadius: model.session.status.isRecording ? 8 : 36,
                            style: .continuous
                        )
                        .fill(PocketAssistantDesign.danger)
                        .frame(
                            width: model.session.status.isRecording ? 34 : 68,
                            height: model.session.status.isRecording ? 34 : 68
                        )
                        .animation(
                            .easeInOut(duration: 0.18), value: model.session.status.isRecording)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(!model.session.isControlLinkReady || model.session.controlBusy)
                .opacity(model.session.isControlLinkReady && !model.session.controlBusy ? 1 : 0.38)
                .accessibilityLabel(recordAccessibilityLabel)
            }
        }
    }

    private var cameraStateCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 13) {
                PocketAssistantSectionTitle("相机状态", detail: "不打开监看画面，也能确认拍摄准备情况。")
                HStack(spacing: 10) {
                    PocketAssistantMetric(
                        title: "电量",
                        value: model.session.status.batteryPercent >= 0
                            ? "\(model.session.status.batteryPercent)%" : "—",
                        accent: true
                    )
                    PocketAssistantMetric(
                        title: "剩余空间",
                        value: storageLabel,
                        accent: true
                    )
                }
                HStack(spacing: 10) {
                    PocketAssistantMetric(
                        title: "拍摄模式",
                        value: shootingModeLabel
                    )
                    PocketAssistantMetric(
                        title: "曝光模式",
                        value: exposureLabel
                    )
                }
            }
        }
    }

    private var formatCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 13) {
                PocketAssistantSectionTitle(
                    "画面参数",
                    detail: "这里只显示相机实时状态，避免误触改变正在使用的拍摄配置。"
                )
                HStack(spacing: 10) {
                    PocketAssistantMetric(
                        title: "分辨率与帧率",
                        value: formatLabel
                    )
                    PocketAssistantMetric(
                        title: "色彩模式",
                        value: colorLabel
                    )
                }
            }
        }
    }

    private var captureTitle: String {
        if model.session.status.isRecording { return "正在录制" }
        if model.session.currentShootingMode?.isPhoto == true { return "拍摄照片" }
        return "开始录制"
    }

    private var captureDetail: String {
        if !model.session.isControlLinkReady { return "连接 Pocket 后即可遥控拍摄。" }
        if model.session.status.isRecording { return "再次点击红色按钮即可停止。" }
        return "录制直接写入相机存储卡。"
    }

    private var recordAccessibilityLabel: String {
        if model.session.status.isRecording { return "停止录制" }
        if model.session.currentShootingMode?.isPhoto == true { return "拍摄照片" }
        return "开始录制"
    }

    private var shootingModeLabel: String {
        switch model.session.currentShootingMode {
        case .slowMo: "慢动作"
        case .video: "视频"
        case .timeLapse: "延时摄影"
        case .photo: "照片"
        case .hyperLapse: "运动延时"
        case .superNight: "超级夜景"
        case nil: model.session.status.inPlayback ? "回放" : "等待状态"
        }
    }

    private var exposureLabel: String {
        switch model.session.status.expoMode {
        case .auto: "自动"
        case .manual: "手动"
        case nil: "—"
        }
    }

    private var formatLabel: String {
        if let format = model.session.status.videoFormat { return format.chipLabel }
        if let resolution = model.session.status.videoResolution, model.session.status.fps > 0 {
            return "\(resolution.label) · \(model.session.status.fps)p"
        }
        return "—"
    }

    private var colorLabel: String {
        guard let mode = model.session.status.colorMode else { return "—" }
        return switch mode {
        case .normal: "普通"
        case .hdr: "HDR"
        case .dLog: "D-Log"
        case .dLog2: "D-Log2"
        case .normal10: "普通 10-bit"
        case .dLogM: "D-Log M"
        }
    }

    private var storageLabel: String {
        let free =
            model.session.status.storageFreeMb > 0
            ? model.session.status.storageFreeMb : model.session.status.sdFreeMb
        guard free > 0 else { return "—" }
        if free >= 1024 { return String(format: "%.1f GB", Double(free) / 1024) }
        return "\(free) MB"
    }

    private static func clock(_ seconds: Int) -> String {
        let safe = max(seconds, 0)
        return String(format: "%02d:%02d:%02d", safe / 3600, (safe / 60) % 60, safe % 60)
    }
}
