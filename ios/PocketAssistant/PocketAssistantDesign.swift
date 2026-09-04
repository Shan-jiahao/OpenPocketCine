import SwiftUI

enum PocketAssistantDesign {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.06)
    static let surface = Color(red: 0.075, green: 0.09, blue: 0.115)
    static let raised = Color(red: 0.105, green: 0.125, blue: 0.155)
    static let border = Color.white.opacity(0.09)
    static let primary = Color(red: 0.12, green: 0.76, blue: 0.98)
    static let primaryDeep = Color(red: 0.08, green: 0.45, blue: 0.96)
    static let success = Color(red: 0.23, green: 0.82, blue: 0.57)
    static let warning = Color(red: 1.0, green: 0.69, blue: 0.25)
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.32)
    static let text = Color.white.opacity(0.96)
    static let secondary = Color.white.opacity(0.62)
}

struct PocketAssistantBackground: View {
    var body: some View {
        ZStack {
            PocketAssistantDesign.background
            RadialGradient(
                colors: [PocketAssistantDesign.primary.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 430
            )
        }
        .ignoresSafeArea()
    }
}

struct PocketAssistantCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PocketAssistantDesign.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PocketAssistantDesign.border, lineWidth: 1)
            )
    }
}

struct PocketAssistantSectionTitle: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PocketAssistantDesign.text)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(PocketAssistantDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PocketAssistantStatusDot: View {
    let title: String
    let detail: String
    let ready: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ready ? PocketAssistantDesign.success : Color.white.opacity(0.2))
                .frame(width: 9, height: 9)
                .shadow(
                    color: ready ? PocketAssistantDesign.success.opacity(0.55) : .clear,
                    radius: 5
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PocketAssistantDesign.secondary)
                Text(detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PocketAssistantDesign.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            PocketAssistantDesign.raised,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }
}

struct PocketAssistantMetric: View {
    let title: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PocketAssistantDesign.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(
                    accent ? PocketAssistantDesign.primary : PocketAssistantDesign.text
                )
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(
            PocketAssistantDesign.raised,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }
}

struct PocketAssistantLinkBanner: View {
    @Environment(AppModel.self) private var model
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: model.session.isControlLinkReady ? "checkmark.circle.fill" : icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PocketAssistantDesign.text)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PocketAssistantDesign.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PocketAssistantDesign.secondary)
            }
            .padding(14)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        if model.session.isControlLinkReady { return "Pocket 已连接" }
        if model.isBusy { return "正在连接 Pocket" }
        if case .failed = model.session.phase { return "连接未完成" }
        return "尚未连接 Pocket"
    }

    private var detail: String {
        if model.session.isControlLinkReady {
            return model.session.connectedCamera?.name ?? "数据链路可用"
        }
        if model.session.wifiJoinNeedsManualAction, let ssid = model.session.joiningSSID {
            return "请到系统设置连接 Wi-Fi：\(ssid)"
        }
        return model.session.phase.opcLocalizedLabel
    }

    private var icon: String {
        if model.isBusy { return "antenna.radiowaves.left.and.right" }
        if case .failed = model.session.phase { return "exclamationmark.triangle.fill" }
        return "link.badge.plus"
    }

    private var color: Color {
        if model.session.isControlLinkReady { return PocketAssistantDesign.success }
        if case .failed = model.session.phase { return PocketAssistantDesign.warning }
        return PocketAssistantDesign.primary
    }
}

extension Double {
    var pocketAssistantDegrees: String { String(format: "%+.1f°", self) }
}
