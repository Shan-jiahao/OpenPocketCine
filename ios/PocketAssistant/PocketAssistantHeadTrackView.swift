import OpenPocketViewCore
import SwiftUI

struct PocketAssistantHeadTrackView: View {
    @Environment(AppModel.self) private var model
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
        .accessibilityIdentifier("pocketAssistant.headTrack")
    }

    private var headLockCard: some View {
        PocketAssistantCard {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.headTrackCalibrated ? "头部锁定已启动" : "用头部方向控制云台")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PocketAssistantDesign.text)
                        Text(heroDetail)
                            .font(.footnote)
                            .foregroundStyle(PocketAssistantDesign.secondary)
                    }
                    Spacer()
                    Text(model.headTrackCalibrated ? "跟随中" : "待校准")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            model.headTrackCalibrated
                                ? PocketAssistantDesign.success : PocketAssistantDesign.primary
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (model.headTrackCalibrated
                                ? PocketAssistantDesign.success : PocketAssistantDesign.primary)
                                .opacity(0.12),
                            in: Capsule()
                        )
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
                        detail: model.headTrackGimbalYawDeg == nil ? "等待角度" : "角度正常",
                        ready: model.headTrackGimbalYawDeg != nil
                            && model.session.isControlLinkReady
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
                        value: model.headTrackGimbalYawDeg?.pocketAssistantDegrees ?? "—"
                    )
                    PocketAssistantMetric(
                        title: "云台 · 俯仰",
                        value: model.headTrackGimbalPitchDeg?.pocketAssistantDegrees ?? "—"
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
            && model.session.isControlLinkReady && model.headTrackGimbalYawDeg != nil
    }

    private var heroDetail: String {
        if !model.headTrackingEnabled { return "先打开右上角的头追开关。" }
        if !model.session.isControlLinkReady { return "先在“设备”页连接 Pocket。" }
        if !model.headTrackMotionFresh { return "请戴上支持动态头部跟踪的 AirPods。" }
        if model.headTrackGimbalYawDeg == nil { return "正在等待云台姿态数据。" }
        return model.headTrackCalibrated ? "转动头部即可平滑控制云台。" : "面向正前方并保持静止，然后点击校准。"
    }

    private var airPodsDetail: String {
        if model.headTrackMotionFresh { return "动作数据正常" }
        if model.headTrackAirPodsConnected { return "等待动作数据" }
        return "未连接"
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
                    .fill(active ? PocketAssistantDesign.primary : Color.white.opacity(0.22))
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
