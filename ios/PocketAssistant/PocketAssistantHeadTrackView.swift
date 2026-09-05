import OpenPocketViewCore
import SwiftUI

struct PocketAssistantHeadTrackView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSupportedHeadphones = false
    let openDevices: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            PocketAssistantBackground()
            ScrollView {
                VStack(spacing: 16) {
                    PocketAssistantLinkBanner(action: openDevices)
                    headLockCard
                    readinessCard
                    angleCard
                    responseCard
                    safetyCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("头追控制")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("启用头追", isOn: Bindable(model).headTrackingEnabled)
                    .labelsHidden()
                    .tint(PocketAssistantDesign.primary)
                    .accessibilityLabel("启用头追")
            }
        }
        .onAppear { model.headphoneMotion.sync() }
        .sheet(isPresented: $showsSupportedHeadphones) {
            SupportedHeadphonesSheet()
        }
        .accessibilityIdentifier("pocketAssistant.headTrack")
    }

    private var headLockCard: some View {
        PocketAssistantCard {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(
                            model.headTrackCalibrated
                                ? "头部锁定已启动" : "用头部方向控制云台"
                        )
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PocketAssistantDesign.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        Button("查看支持耳机") {
                            showsSupportedHeadphones = true
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PocketAssistantDesign.primary)
                        .fixedSize()
                        .accessibilityHint("打开支持动态头部跟踪的耳机型号列表")
                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Text(heroDetail)
                            .font(.footnote)
                            .foregroundStyle(PocketAssistantDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(model.headTrackCalibrated ? "跟随中" : "待校准")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    model.headTrackCalibrated
                                        ? PocketAssistantDesign.success
                                        : PocketAssistantDesign.primary
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    (model.headTrackCalibrated
                                        ? PocketAssistantDesign.success
                                        : PocketAssistantDesign.primary)
                                        .opacity(0.12),
                                    in: Capsule()
                                )

                            if !model.headTrackCalibrated {
                                Button {
                                    model.session.recenterGimbal()
                                } label: {
                                    Label("云台回中", systemImage: "scope")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PocketAssistantDesign.text)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(PocketAssistantDesign.raised, in: Capsule())
                                .disabled(!model.session.isControlLinkReady)
                                .opacity(model.session.isControlLinkReady ? 1 : 0.42)
                                .accessibilityHint("将 Pocket 云台恢复到正前方")
                                .accessibilityIdentifier("pocketAssistant.headTrack.recenter")
                            }
                        }
                    }
                }

                HeadDirectionIndicator(
                    yaw: model.headTrackHeadYawDeg ?? 0,
                    pitch: model.headTrackHeadPitchDeg ?? 0,
                    active: model.headTrackMotionFresh
                )
                .frame(height: 190)

                Button {
                    model.headphoneMotion.tapControl()
                } label: {
                    Label(
                        model.headTrackCalibrated ? "立即停止" : "校准并锁定前方",
                        systemImage: model.headTrackCalibrated ? "stop.fill" : "scope"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    model.headTrackCalibrated
                        ? PocketAssistantDesign.danger : PocketAssistantDesign.primaryDeep,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .disabled(!model.headTrackCalibrated && !canCalibrate)
                .opacity(!model.headTrackCalibrated && !canCalibrate ? 0.42 : 1)
                .accessibilityIdentifier("pocketAssistant.headTrack.control")

                if let note = model.session.controlNote, !note.isEmpty {
                    Text(note.opcLocalized)
                        .font(.footnote)
                        .foregroundStyle(PocketAssistantDesign.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    private var readinessCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 13) {
                PocketAssistantSectionTitle("启动条件", detail: "四项全部就绪后，保持头部静止并校准。")
                LazyVGrid(columns: columns, spacing: 10) {
                    PocketAssistantStatusDot(
                        title: "AirPods",
                        detail: airPodsDetail,
                        ready: model.headTrackMotionFresh
                    )
                    PocketAssistantStatusDot(
                        title: "Pocket",
                        detail: model.session.isControlLinkReady ? "已连接" : "未就绪",
                        ready: model.session.isControlLinkReady
                    )
                    PocketAssistantStatusDot(
                        title: "数据链路",
                        detail: model.session.isControlLinkReady ? "控制可用" : "等待连接",
                        ready: model.session.isControlLinkReady
                    )
                    PocketAssistantStatusDot(
                        title: "云台姿态",
                        detail: gimbalYawDeg == nil ? "等待角度" : "角度正常",
                        ready: gimbalYawDeg != nil && model.session.isControlLinkReady
                    )
                }
            }
        }
    }

    private var angleCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 13) {
                PocketAssistantSectionTitle("实时角度", detail: "目标角度是头部动作换算后的云台目标。")
                LazyVGrid(columns: columns, spacing: 10) {
                    PocketAssistantMetric(
                        title: "头部 · 水平",
                        value: model.headTrackHeadYawDeg?.pocketAssistantDegrees ?? "—"
                    )
                    PocketAssistantMetric(
                        title: "头部 · 俯仰",
                        value: model.headTrackHeadPitchDeg?.pocketAssistantDegrees ?? "—"
                    )
                    PocketAssistantMetric(
                        title: "云台 · 水平",
                        value: gimbalYawDeg?.pocketAssistantDegrees ?? "—"
                    )
                    PocketAssistantMetric(
                        title: "云台 · 俯仰",
                        value: gimbalPitchDeg?.pocketAssistantDegrees ?? "—"
                    )
                    PocketAssistantMetric(
                        title: "目标 · 水平",
                        value: model.headTrackTargetYawDeg?.pocketAssistantDegrees ?? "—",
                        accent: true
                    )
                    PocketAssistantMetric(
                        title: "目标 · 俯仰",
                        value: model.headTrackTargetPitchDeg?.pocketAssistantDegrees ?? "—",
                        accent: true
                    )
                }
            }
        }
    }

    private var responseCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 17) {
                PocketAssistantSectionTitle("跟随手感", detail: "设置会自动保存，下次启动继续使用。")
                HStack(spacing: 10) {
                    ForEach(HeadTrack.ResponsePreset.allCases, id: \.self) { preset in
                        responsePresetButton(preset)
                    }
                }
                responseSlider(
                    title: "灵敏度",
                    detail: "头部转动映射到云台的幅度",
                    value: Bindable(model).headTrackSensitivity,
                    range: 0.5...2,
                    step: 0.05,
                    display: { String(format: "× %.2f", $0) }
                )
                responseSlider(
                    title: "死区",
                    detail: "忽略轻微晃动，数值越大越稳定",
                    value: Bindable(model).headTrackDeadZoneDeg,
                    range: 0...10,
                    step: 0.5,
                    display: { String(format: "%.1f°", $0) }
                )
                responseSlider(
                    title: "平滑度",
                    detail: "提高会更柔和，但响应会稍慢",
                    value: Bindable(model).headTrackSmoothness,
                    range: 0...1,
                    step: 0.05,
                    display: { String(format: "%.0f%%", $0 * 100) }
                )
                responseSlider(
                    title: "最大速度",
                    detail: "限制云台追随头部时的最高速度",
                    value: Bindable(model).headTrackMaxSpeedDegPerSec,
                    range: 10...HeadTrack.stickRateDegPerSec,
                    step: 1,
                    display: { String(format: "%.0f°/秒", $0) }
                )
            }
        }
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(PocketAssistantDesign.success)
            VStack(alignment: .leading, spacing: 4) {
                Text("安全停止始终生效")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocketAssistantDesign.text)
                Text("AirPods 断开、动作数据超时、Pocket 断开或 App 进入后台时，云台会立即停止；恢复后需要重新校准。")
                    .font(.footnote)
                    .foregroundStyle(PocketAssistantDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            PocketAssistantDesign.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private var canCalibrate: Bool {
        model.headTrackingEnabled && model.headTrackMotionFresh
            && model.session.isControlLinkReady && gimbalYawDeg != nil
    }

    private var heroDetail: String {
        if !model.headTrackingEnabled { return "先打开右上角的头追开关。" }
        if !model.session.isControlLinkReady { return "先在“设备”页连接 Pocket。" }
        if !model.headTrackMotionFresh {
            return model.headTrackAirPodsConnected
                ? "已识别 AirPods，但尚未收到动作数据。请确认至少一只耳机已戴入耳中。"
                : "请戴上支持动态头部跟踪的 AirPods。"
        }
        if gimbalYawDeg == nil { return "正在等待云台姿态数据。" }
        return model.headTrackCalibrated ? "转动头部即可平滑控制云台。" : "面向正前方并保持静止，然后点击校准。"
    }

    private var airPodsDetail: String {
        if model.headTrackMotionFresh { return "动作数据正常" }
        if model.headTrackAirPodsConnected { return "等待动作数据" }
        return "未连接"
    }

    private var gimbalYawDeg: Double? {
        model.session.gimbalYawTenthDeg.map { Double($0) / 10 }
    }

    private var gimbalPitchDeg: Double? {
        model.session.gimbalPitchTenthDeg.map { Double($0) / 10 }
    }

    private var currentResponseConfiguration: HeadTrack.Configuration {
        HeadTrack.Configuration(
            sensitivity: model.headTrackSensitivity,
            deadZoneDeg: model.headTrackDeadZoneDeg,
            smoothness: model.headTrackSmoothness,
            maxSpeedDegPerSec: model.headTrackMaxSpeedDegPerSec)
    }

    private func responsePresetButton(_ preset: HeadTrack.ResponsePreset) -> some View {
        let isSelected = preset.configuration == currentResponseConfiguration
        return Button {
            let configuration = preset.configuration
            model.headTrackSensitivity = configuration.sensitivity
            model.headTrackDeadZoneDeg = configuration.deadZoneDeg
            model.headTrackSmoothness = configuration.smoothness
            model.headTrackMaxSpeedDegPerSec = configuration.maxSpeedDegPerSec
        } label: {
            Text(preset.pocketAssistantTitle)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : PocketAssistantDesign.text)
        .background(
            isSelected ? PocketAssistantDesign.primaryDeep : PocketAssistantDesign.raised,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityLabel("\(preset.pocketAssistantTitle)跟随预设")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private func responseSlider(
        title: String,
        detail: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PocketAssistantDesign.text)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PocketAssistantDesign.secondary)
                }
                Spacer()
                Text(display(value.wrappedValue))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PocketAssistantDesign.primary)
            }
            Slider(value: value, in: range, step: step)
                .tint(PocketAssistantDesign.primary)
                .accessibilityLabel(title)
        }
    }
}

extension HeadTrack.ResponsePreset {
    fileprivate var pocketAssistantTitle: String {
        switch self {
        case .fast: "快速"
        case .standard: "标准"
        case .gentle: "轻柔"
        }
    }
}

private struct SupportedHeadphonesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "以下型号由 Apple 标注支持动态头部跟踪。Pocket助手仍以 iPhone 是否实际收到耳机动作数据作为最终判断。"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("AirPods") {
                    supportedModel("AirPods（第 3 代及后续型号）")
                    supportedModel("AirPods Pro（各代）")
                    supportedModel("AirPods Max")
                }

                Section("Beats") {
                    supportedModel("Beats Fit Pro")
                    supportedModel("Beats Solo 4")
                    supportedModel("Beats Studio Pro")
                    supportedModel("Powerbeats Pro 2")
                }

                Section("使用提示") {
                    Label("至少佩戴一只耳机，连接后播放一段声音。", systemImage: "earbuds")
                    Label(
                        "蓝牙显示“已连接”不等于动作数据已经就绪，请以“动作数据正常”为准。",
                        systemImage: "waveform.path.ecg"
                    )
                    Label(
                        "如果一直等待动作数据，请重新佩戴耳机，或关闭再打开右上角头追开关。",
                        systemImage: "arrow.clockwise"
                    )
                }

                Section("Apple 官方资料") {
                    Link(
                        "AirPods：控制空间音频和头部跟踪",
                        destination: URL(
                            string: "https://support.apple.com/zh-cn/guide/airpods/dev00eb7e0a3/web"
                        )!)
                    Link(
                        "Beats：支持动态头部跟踪的型号",
                        destination: URL(
                            string:
                                "https://support.apple.com/zh-cn/guide/beats/aside/dev2cbe8451a/1.0/web/1.0"
                        )!)
                }
            }
            .navigationTitle("支持的头追耳机")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func supportedModel(_ name: String) -> some View {
        Label(name, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
    }
}

private struct HeadDirectionIndicator: View {
    let yaw: Double
    let pitch: Double
    let active: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let x = CGFloat(max(-1, min(1, yaw / 45))) * side * 0.28
            let y = CGFloat(max(-1, min(1, pitch / 30))) * side * -0.28
            ZStack {
                Circle()
                    .fill(PocketAssistantDesign.background.opacity(0.75))
                Circle()
                    .stroke(PocketAssistantDesign.border, lineWidth: 1)
                    .padding(side * 0.18)
                Circle()
                    .stroke(PocketAssistantDesign.primary.opacity(0.35), lineWidth: 1)
                    .padding(side * 0.34)
                Rectangle()
                    .fill(PocketAssistantDesign.border)
                    .frame(width: side * 0.76, height: 1)
                Rectangle()
                    .fill(PocketAssistantDesign.border)
                    .frame(width: 1, height: side * 0.76)
                Circle()
                    .fill(active ? PocketAssistantDesign.primary : PocketAssistantDesign.inactive)
                    .frame(width: 22, height: 22)
                    .shadow(
                        color: PocketAssistantDesign.primary.opacity(active ? 0.65 : 0), radius: 12
                    )
                    .offset(x: x, y: y)
                    .animation(.linear(duration: 0.08), value: x)
                    .animation(.linear(duration: 0.08), value: y)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}
