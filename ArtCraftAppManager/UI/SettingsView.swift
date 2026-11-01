import AppKit
import SwiftUI

/// Settings window (docs/specs/05-settings.md).
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Locations") {
                folderRow("Default Install Location", url: model.defaultInstallLocation, id: "settings.defaultInstall.choose") {
                    model.chooseFolder($0, forInstall: true)
                }
                folderRow("Download File Location", url: model.downloadLocation, id: "settings.download.choose") {
                    model.chooseFolder($0, forInstall: false)
                }
            }
            Section("Applications to Show") {
                List(model.registry.apps) { app in
                    Toggle(isOn: Binding(get: { model.enabledIds.contains(app.id) }, set: { model.setEnabled(app.id, $0) })) {
                        Text(app.displayName)
                    }
                }
                .frame(height: 180)
                .accessibilityIdentifier("settings.apps.list")
            }
            Section("Updates") {
                Toggle("Automatically Download Updates", isOn: Binding(get: { model.policy.autoDownload }, set: model.setAutoDownload))
                    .disabled(model.policy.isAutoDownloadLocked)
                    .accessibilityIdentifier("settings.autoDownload")
                Toggle("Automatically Install Updates", isOn: Binding(get: { model.policy.autoInstall }, set: model.setAutoInstall))
                    .accessibilityIdentifier("settings.autoInstall")
            }
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .accessibilityIdentifier("settings.launchAtLogin")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding(.vertical, 8)
    }

    private func folderRow(_ title: String, url: URL, id: String, choose: @escaping (URL) -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                Text(url.path).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = url
                    if panel.runModal() == .OK, let picked = panel.url { choose(picked) }
                }
                .accessibilityIdentifier(id)
            }
        }
    }
}

/// Menu bar menu, shown only while "Launch at login" is on (REQ-WIN-9, REQ-WIN-19, REQ-WIN-20).
struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let menu = model.menuBarModel
        ForEach(Array(menu.lines.enumerated()), id: \.offset) { index, line in
            Button(line) {
                model.scrollTarget = menu.rowToScroll(forLine: index)
                openMain()
            }
        }
        if !menu.lines.isEmpty { Divider() }
        Button("Check Now") { Task { await model.refresh() } }
        Button("Open Manager") { openMain() }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
