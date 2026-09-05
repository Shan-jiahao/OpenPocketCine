import SwiftUI

struct PocketAssistantGimbalControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            controlCard
            poseCard
            sensitivityCard
        }
        .accessibilityIdentifier("pocketAssistant.capture.gimbalControls")
    }

    private var controlCard: some View {
        PocketAssistantCard {
            VStack(spacing: 18) {
                PocketAssistantSectionTitle(
                    "手动摇杆",
                    detail: "按住圆盘拖动控制方向，松手会立即回中。头追会在手动控制期间自动让位。"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                PocketAssistantGimbalPad(enabled: model.session.isControlLinkReady)
                    .frame(width: 224, height: 224)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    quickButton(title: "回正", systemImage: "scope") {
                        model.session.recenterGimbal()
                    }
                    quickButton(title: "旋转 180°", systemImage: "arrow.triangle.2.circlepath") {
                        model.session.flipGimbal()
                    }
                }
            }
        }
    }

    private var poseCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 13) {
                PocketAssistantSectionTitle("云台姿态", detail: "角度来自相机实时数据。")
                HStack(spacing: 10) {
                    PocketAssistantMetric(
                        title: "水平角度",
                        value: model.session.gimbalYawTenthDeg.map {
                            (Double($0) / 10).pocketAssistantDegrees
                        } ?? "—",
                        accent: true
                    )
                    PocketAssistantMetric(
                        title: "俯仰角度",
                        value: model.session.gimbalPitchTenthDeg.map {
                            (Double($0) / 10).pocketAssistantDegrees
                        } ?? "—",
                        accent: true
                    )
                }
            }
        }
    }

    private var sensitivityCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PocketAssistantSectionTitle("摇杆速度", detail: "仅影响手动摇杆，不改变头追参数。")
                    Spacer()
                    Text("\(model.gimbalStickSensitivity) 档")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(PocketAssistantDesign.primary)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.gimbalStickSensitivity) },
                        set: { model.gimbalStickSensitivity = Int($0.rounded()) }
                    ),
                    in: 1...5,
                    step: 1
                )
                .tint(PocketAssistantDesign.primary)
                .accessibilityLabel("摇杆速度")
            }
        }
    }

    private func quickButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(PocketAssistantDesign.text)
        .background(PocketAssistantDesign.raised, in: RoundedRectangle(cornerRadius: 15))
        .disabled(!model.session.isControlLinkReady)
        .opacity(model.session.isControlLinkReady ? 1 : 0.42)
    }
}

private struct PocketAssistantGimbalPad: View {
    @Environment(AppModel.self) private var model
    let enabled: Bool
    @State private var knobOffset = CGSize.zero
    @State private var dragging = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let knobSize = side * 0.28
            let travel = (side - knobSize) * 0.46
            ZStack {
                Circle()
                    .fill(PocketAssistantDesign.controlWell)
                Circle()
                    .stroke(PocketAssistantDesign.primary.opacity(0.2), lineWidth: 1)
                    .padding(side * 0.19)
                Rectangle()
                    .fill(PocketAssistantDesign.border)
                    .frame(width: side * 0.68, height: 1)
                Rectangle()
                    .fill(PocketAssistantDesign.border)
                    .frame(width: 1, height: side * 0.68)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                PocketAssistantDesign.primary, PocketAssistantDesign.primaryDeep,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .overlay(Circle().stroke(PocketAssistantDesign.knobBorder, lineWidth: 1))
                    .shadow(color: PocketAssistantDesign.primary.opacity(0.38), radius: 14)
                    .offset(knobOffset)
            }
            .contentShape(Circle())
            .gesture(drag(travel: travel), including: enabled ? .gesture : .none)
            .opacity(enabled ? 1 : 0.38)
        }
        .onChange(of: enabled) { _, ready in
            if !ready { release() }
        }
        .onDisappear { release() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("云台手动摇杆")
        .accessibilityHint("按住并拖动来控制云台，松手停止")
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard enabled else { return }
                dragging = true
                model.gimbalScreenHeld = true
                knobOffset = clamped(value.translation, limit: travel)
                model.session.updateGimbalStick(
                    x: Double(knobOffset.width / max(travel, 1)),
                    y: Double(-knobOffset.height / max(travel, 1)),
                    sensitivity: model.gimbalStickSensitivity
                )
            }
            .onEnded { _ in release() }
    }

    private func clamped(_ offset: CGSize, limit: CGFloat) -> CGSize {
        let length = hypot(offset.width, offset.height)
        guard length > limit, length > 0 else { return offset }
        return CGSize(width: offset.width / length * limit, height: offset.height / length * limit)
    }

    private func release() {
        guard dragging || model.gimbalScreenHeld else { return }
        dragging = false
        model.gimbalScreenHeld = false
        knobOffset = .zero
        model.session.endGimbalStick()
    }
}
