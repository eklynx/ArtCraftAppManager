import AppKit
import SwiftUI

/// Settings window (docs/specs/05-settings.md).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    /// The GitHub section is an advanced setting: shown only if Option was held when Settings was activated (REQ-SET-9).
    @State private var showsGitHub = false

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
                List {
                    ForEach(model.orderedApps) { app in
                        HStack {
                            Toggle(isOn: Binding(get: { model.enabledIds.contains(app.id) }, set: { model.setEnabled(app.id, $0) })) {
                                Text(app.displayName)
                            }
                            Spacer()
                            Image(systemName: "line.3.horizontal")  // drag handle
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .contextMenu {
                            Button("Move Up") { model.moveApp(app.id, by: -1) }
                            Button("Move Down") { model.moveApp(app.id, by: 1) }
                        }
                        .accessibilityAction(named: "Move Up") { model.moveApp(app.id, by: -1) }
                        .accessibilityAction(named: "Move Down") { model.moveApp(app.id, by: 1) }
                    }
                    .onMove { model.moveApps(from: $0, to: $1) }
                }
                .listStyle(.inset)
                .frame(height: CGFloat(model.orderedApps.count) * 30 + 12)  // tall enough to show every app, no inner scrolling
                .accessibilityIdentifier("settings.apps.list")
                HStack {
                    Text("Drag to reorder. This sets the order in the main window.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset Order") { model.resetOrder() }
                        .disabled(model.isDefaultOrder)
                        .accessibilityIdentifier("settings.apps.resetOrder")
                }
            }
            Section("Updates") {
                Toggle("Automatically Download Updates", isOn: Binding(get: { model.policy.autoDownload }, set: model.setAutoDownload))
                    .disabled(model.policy.isAutoDownloadLocked)
                    .accessibilityIdentifier("settings.autoDownload")
                Toggle("Automatically Install Updates", isOn: Binding(get: { model.policy.autoInstall }, set: model.setAutoInstall))
                    .accessibilityIdentifier("settings.autoInstall")
            }
            if showsGitHub {
                Section("GitHub") {
                    SecureField("Token (optional)", text: Bindable(model).githubToken)
                        .accessibilityIdentifier("settings.githubToken")
                    Text("A token raises GitHub's rate limit and lets the registry refresh read a private repository. It is stored in your Keychain.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .accessibilityIdentifier("settings.launchAtLogin")
            }
        }
        .formStyle(.grouped)
        .onAppear { revealIfOptionHeld() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if Self.isSettingsWindow(note.object) { revealIfOptionHeld() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if Self.isSettingsWindow(note.object) { showsGitHub = false }
        }
        .frame(width: 520)
        .frame(minHeight: 560, idealHeight: 860, maxHeight: .infinity)  // tall enough to open with every app visible; the form scrolls if the screen is smaller
        .padding(.vertical, 8)
    }

    private func revealIfOptionHeld() {
        if NSEvent.modifierFlags.contains(.option) { showsGitHub = true }
    }

    private static func isSettingsWindow(_ object: Any?) -> Bool {
        (object as? NSWindow)?.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true
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
