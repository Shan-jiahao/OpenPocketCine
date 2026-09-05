import OpenPocketViewCore
import SwiftUI

struct PocketAssistantDevicesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            PocketAssistantBackground()
            if model.shouldShowWizard {
                pairingView
            } else {
                deviceList
            }
        }
        .navigationTitle("设备")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !model.shouldShowWizard {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.pairNewCamera()
                    } label: {
                        Label("添加 Pocket", systemImage: "plus")
                    }
                    .disabled(model.isBusy || model.session.isControlLinkReady)
                }
            }
        }
        .accessibilityIdentifier("pocketAssistant.devices")
    }

    private var pairingView: some View {
        VStack(spacing: 10) {
            if model.session.isControlLinkReady {
                connectedCard
            } else {
                ConnectionSetupView(compact: true, pocketOnly: true)
                    .environment(model)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var deviceList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.session.isControlLinkReady {
                    connectedCard
                } else {
                    PocketAssistantLinkBanner {
                        if let first = model.savedCameras.first { model.reconnect(first) }
                    }
                }

                savedCameraCard
                connectionHelpCard
                preferencesCard
                StartupShareDiagnosticsButton()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var connectedCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(PocketAssistantDesign.primary)
                        .frame(width: 44, height: 44)
                        .background(PocketAssistantDesign.primary.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.session.connectedCamera?.name ?? "Pocket")
                            .font(.headline)
                            .foregroundStyle(PocketAssistantDesign.text)
                        Text("蓝牙、Wi-Fi 和数据链路已就绪")
                            .font(.caption)
                            .foregroundStyle(PocketAssistantDesign.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(PocketAssistantDesign.success)
                        .frame(width: 10, height: 10)
                }
                HStack(spacing: 10) {
                    PocketAssistantMetric(
                        title: "相机电量",
                        value: model.session.status.batteryPercent >= 0
                            ? "\(model.session.status.batteryPercent)%" : "—"
                    )
                    PocketAssistantMetric(
                        title: "相机 Wi-Fi",
                        value: model.session.joinedSSID ?? "已连接"
                    )
                }
                Button(role: .destructive) {
                    model.disconnect()
                } label: {
                    Text("断开连接")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PocketAssistantDesign.danger)
                .background(
                    PocketAssistantDesign.danger.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var savedCameraCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 13) {
                PocketAssistantSectionTitle("已保存的 Pocket", detail: "相机开机并在附近时，点击即可重新连接。")
                if model.savedCameras.isEmpty {
                    Text("还没有保存的设备。首次连接成功后会自动出现在这里。")
                        .font(.footnote)
                        .foregroundStyle(PocketAssistantDesign.secondary)
                } else {
                    ForEach(model.savedCameras) { camera in
                        savedCameraRow(camera)
                    }
                }
                Button {
                    model.pairNewCamera()
                } label: {
                    Label("添加新的 Pocket", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PocketAssistantDesign.onPrimary)
                .background(PocketAssistantDesign.primary, in: RoundedRectangle(cornerRadius: 14))
                .disabled(model.isBusy || model.session.isControlLinkReady)
                .opacity(model.isBusy || model.session.isControlLinkReady ? 0.42 : 1)
            }
        }
    }

    private func savedCameraRow(_ camera: SavedCamera) -> some View {
        HStack(spacing: 12) {
            Button {
                model.reconnect(camera)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.title3)
                        .foregroundStyle(PocketAssistantDesign.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(camera.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PocketAssistantDesign.text)
                        Text(savedCameraDetail(camera))
                            .font(.caption)
                            .foregroundStyle(PocketAssistantDesign.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(nearby(camera) ? "连接" : "等待相机")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            nearby(camera)
                                ? PocketAssistantDesign.primary : PocketAssistantDesign.secondary
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy || model.session.isControlLinkReady)

            Menu {
                Button(role: .destructive) {
                    model.forget(camera)
                } label: {
                    Label("忘记此设备", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(PocketAssistantDesign.secondary)
                    .frame(width: 34, height: 34)
            }
            .disabled(model.isBusy || model.session.isControlLinkReady)
        }
        .padding(13)
        .background(PocketAssistantDesign.raised, in: RoundedRectangle(cornerRadius: 15))
    }

    private var connectionHelpCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 12) {
                PocketAssistantSectionTitle("连接说明", detail: "开发签名版本可能需要手动连接相机 Wi-Fi。")
                helpRow(number: "1", text: "打开 Pocket，保持手机蓝牙开启。")
                helpRow(number: "2", text: "选择相机并在 Pocket 屏幕上确认配对。")
                helpRow(number: "3", text: "如果没有系统加入提示，到“设置 → 无线局域网”连接页面显示的相机名称。")
                helpRow(number: "4", text: "看到蓝色对勾后直接返回 Pocket助手，连接会自动继续。")
                Text("Pocket Wi-Fi 没有互联网属于正常现象，请不要选择“忽略此网络”。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PocketAssistantDesign.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var preferencesCard: some View {
        PocketAssistantCard {
            VStack(alignment: .leading, spacing: 14) {
                PocketAssistantSectionTitle("使用偏好")
                Toggle("保持屏幕常亮", isOn: Bindable(model).keepScreenAwake)
                Toggle("触感反馈", isOn: Bindable(model).hapticsEnabled)
            }
            .tint(PocketAssistantDesign.primary)
            .foregroundStyle(PocketAssistantDesign.text)
        }
    }

    private func helpRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(PocketAssistantDesign.onPrimary)
                .frame(width: 23, height: 23)
                .background(PocketAssistantDesign.primary, in: Circle())
            Text(text)
                .font(.footnote)
                .foregroundStyle(PocketAssistantDesign.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nearby(_ camera: SavedCamera) -> Bool {
        model.session.found.contains { $0.id == camera.id }
    }

    private func savedCameraDetail(_ camera: SavedCamera) -> String {
        if let ssid = camera.lastSSID, !ssid.isEmpty { return ssid }
        return camera.modelName
    }
}
