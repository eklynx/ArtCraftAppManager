import AppKit
import SwiftUI

/// Main window (docs/specs/04-main-window.md): app rows, toolbar, status line.
struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.rows.isEmpty {
                VStack(spacing: 12) {
                    Text("No applications selected").font(.title2)
                        .accessibilityLabel("No applications selected").accessibilityIdentifier("emptyState")
                    SettingsLink { Text("Open Settings") }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.rows) { row in
                                AppRowView(row: row)
                                    .id(row.id)
                                    .accessibilityElement(children: .contain)
                                    .accessibilityIdentifier("appRow.\(row.id)")
                            }
                        }
                        .padding(12)
                    }
                    .accessibilityIdentifier("appList")
                    .onChange(of: model.scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation { proxy.scrollTo(target, anchor: .center) }
                        model.scrollTarget = nil
                    }
                }
            }
            Divider()
            StatusBar()
        }
        .frame(minWidth: 900, minHeight: 360)
        .toolbar {
            ToolbarItemGroup {
                if model.isChecking { ProgressView().controlSize(.small) }
                Button { Task { await model.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .accessibilityIdentifier("toolbar.refresh")
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .accessibilityIdentifier("toolbar.settings")
            }
        }
        .task { await model.start() }
    }
}

struct StatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            Text(model.status.text ?? " ")
                .font(.callout)
                .lineLimit(1)
                .accessibilityLabel(model.status.text ?? "")
                .accessibilityIdentifier("statusLine")
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { model.clearStatus() }
    }
}

/// One row, following docs/prototypes/ApplicationLine.svg: icon, name, version and path on the left;
/// Uninstall/Update and Run/Open Location in two button columns on the right.
struct AppRowView: View {
    @Environment(AppModel.self) private var model
    let row: AppModel.Row
    @State private var confirmUninstall = false

    /// All row buttons share this width (matches the prototype's equal-width buttons).
    private static let buttonWidth: CGFloat = 140

    private var vm: AppRowModel { model.rowModel(for: row) }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.name).font(.system(size: 28, weight: .regular, design: .rounded))
                    if !vm.versionText.isEmpty { Text(vm.versionText).font(.system(size: 14, design: .rounded)) }
                    if vm.showsRunningLabel { Text("Running").font(.caption).padding(.horizontal, 6)
                        .overlay(Capsule().stroke(.secondary)) }
                    if let note = vm.registryNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                }
                Text(vm.pathText).font(.system(size: 14, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            if vm.showsProgressBar { progress } else { buttons }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.4), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))  // spacers are otherwise not hit-testable
        .contextMenu { contextMenu }
        .alert("Uninstall \(row.name)?", isPresented: $confirmUninstall) {
            Button("Uninstall", role: .destructive) { model.uninstall(row) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(row.name) is moved to the Trash. Your data and preferences are kept.")
        }
    }

    /// REQ-WIN-22…24: info lines, divider, then every action (enabled state comes from `AppRowModel`).
    @ViewBuilder
    private var contextMenu: some View {
        ForEach(vm.infoLines, id: \.self) { line in
            Button(line) {}.disabled(true)
        }
        Divider()
        ForEach(vm.menuActions, id: \.self) { action in
            Button(Self.title(of: action)) { perform(action) }
                .disabled(!vm.enabledMenuActions.contains(action))
        }
    }

    private static func title(of action: RowAction) -> String {
        switch action {
        case .install: "Install"
        case .run: "Run"
        case .update: "Update"
        case .openLocation: "Open Location"
        case .uninstall: "Uninstall"
        case .cancel: "Cancel"
        case .copyPath: "Copy Install Path"
        case .openReleasesPage: "Open Releases Page"
        }
    }

    private func perform(_ action: RowAction) {
        switch action {
        case .install: chooseFolderAndInstall()
        case .run: model.run(row)
        case .update: model.update(row)
        case .openLocation: model.openLocation(row)
        case .uninstall: confirmUninstall = true
        case .cancel: model.cancel(row)
        case .copyPath: model.copyInstallPath(row)
        case .openReleasesPage: model.openReleasesPage(row)
        }
    }

    private var icon: some View {
        Group {
            if let url = row.installed?.url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().scaledToFit().padding(14).foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    private var progress: some View {
        HStack(spacing: 10) {
            ProgressView(value: model.progress[row.id] ?? 0).frame(width: 180)
            Text("\(Int((model.progress[row.id] ?? 0) * 100))%").monospacedDigit()
            if vm.visibleButtons.contains(.cancel) {
                Button("Cancel") { model.cancel(row) }.accessibilityLabel("Cancel \(row.name)")
            }
        }
    }

    private var buttons: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                slot(.install, "Install", "Install \(row.name)") { chooseFolderAndInstall() }
                slot(.uninstall, "Uninstall", "Uninstall \(row.name)") { confirmUninstall = true }
                slot(.update, "Update", "Update \(row.name)") { model.update(row) }
            }
            VStack(spacing: 8) {
                slot(.run, "Run", "Run \(row.name)") { model.run(row) }
                slot(.openLocation, "Open Location", "Open Location for \(row.name)") { model.openLocation(row) }
            }
        }
    }

    /// A button in a fixed-size slot; hidden buttons keep their space so rows stay aligned (REQ-WIN-4).
    @ViewBuilder
    private func slot(_ button: RowButton, _ title: String, _ label: String, action: @escaping () -> Void) -> some View {
        if vm.visibleButtons.contains(button) {
            Button(action: action) {
                Text(title).frame(maxWidth: .infinity)  // label fills the button so every button is the same width
            }
            .buttonStyle(.bordered).buttonBorderShape(.capsule)
            .frame(width: Self.buttonWidth)
                .disabled(!vm.enabledButtons.contains(button))
                .help(vm.tooltip(for: button) ?? "")
                .accessibilityLabel(label)
        } else if button != .install {
            // Keep the slot's space so the two button columns stay aligned.
            Color.clear.frame(width: Self.buttonWidth, height: 22)
        }
    }

    private func chooseFolderAndInstall() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Install Here"
        panel.message = "Choose where to install \(row.name)"
        panel.directoryURL = model.defaultInstallLocation
        if panel.runModal() == .OK, let url = panel.url { model.install(row, to: url) }
    }
}
