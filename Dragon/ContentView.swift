//
//  ContentView.swift
//  Dragon
//
//  Created by Yoav Peretz on 24/03/2026.
//

import AppKit
import AVFoundation
import CoreText
import ImageIO
import PDFKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private let panelAnimation = Animation.easeInOut(duration: 0.22)
    @AppStorage(DragonAppearanceSettings.backgroundRedKey) private var backgroundRed = 0.13
    @AppStorage(DragonAppearanceSettings.backgroundGreenKey) private var backgroundGreen = 0.16
    @AppStorage(DragonAppearanceSettings.backgroundBlueKey) private var backgroundBlue = 0.22
    @AppStorage(DragonAppearanceSettings.backgroundOpacityKey) private var backgroundOpacity = 0.78
    @AppStorage(DragonAppearanceSettings.fontDesignKey) private var fontDesignRawValue = DragonFontDesign.rounded.rawValue
    @AppStorage(DragonAppearanceSettings.enabledActionsKey) private var enabledActionsRawValue = DragonActionKind.allCases.map(\.rawValue).joined(separator: ",")
    @AppStorage(DragonAppearanceSettings.entryModeKey) private var entryModeRawValue = DragonEntryMode.notch.rawValue
    @AppStorage(DragonAppearanceSettings.menuBarIconStyleKey) private var menuBarIconStyleRawValue = DragonMenuBarIconStyle.color.rawValue
    @AppStorage(DragonAppearanceSettings.skipQuitConfirmationKey) private var skipQuitConfirmation = false

    let onExpansionChange: (Bool) -> Void
    let onSettingsExpansionChange: (Bool) -> Void
    let onEntryModeChange: (DragonEntryMode) -> Void
    let onMenuBarIconStyleChange: (DragonMenuBarIconStyle) -> Void
    let onVisiblePanelHeightChange: (CGFloat) -> Void
    let requestFileImport: (@escaping ([URL]) -> Void) -> Void
    let requestCloudSyncFolder: (@escaping (URL?) -> Void) -> Void
    let requestFinderTagSelection: (@escaping (DragonFinderTagSelection?) -> Void) -> Void
    let requestArchiveDestination: (String, @escaping (URL?) -> Void) -> Void
    let requestConversionDestination: (String, [DragonConversionFormat], @escaping (DragonConversionSelection?) -> Void) -> Void
    let requestAirDropShare: ([URL], @escaping (Result<String, Error>) -> Void) -> Void
    let requestQuickShare: ([URL], @escaping (Result<String, Error>) -> Void) -> Void
    @State private var queuedItems: [QueuedDropItem] = []
    @State private var isDropTargeted = false
    @State private var isInspectorExpanded = false
    @State private var isSettingsExpanded = false
    @State private var hoveredActionID: DragonAction.ID?
    @State private var actionStatus: DragonActionStatus?
    @State private var isPerformingAction = false
    @State private var selectedSettingsTab: DragonSettingsTab = .appearance
    @State private var pendingModeSwitchReopen = false
    @State private var pendingModeSwitchRestoreSettings = false
    @State private var notchRevealProgress: CGFloat = 0
    @State private var isHoveringActivationZone = false

    private let primaryActions = DragonAction.primary
    private let secondaryActions = DragonAction.secondary

    private var allActions: [DragonAction] {
        availableActions.filter { enabledActionKinds.contains($0.kind) }
    }

    private var availableActions: [DragonAction] {
        primaryActions + secondaryActions
    }

    private var enabledActionKinds: Set<DragonActionKind> {
        let kinds = enabledActionsRawValue
            .split(separator: ",")
            .compactMap { DragonActionKind(rawValue: String($0)) }
        return kinds.isEmpty ? Set(DragonActionKind.allCases) : Set(kinds)
    }

    private var totalByteCount: Int64 {
        queuedItems.reduce(0) { $0 + $1.byteCount }
    }

    private var itemSummary: String {
        switch queuedItems.count {
        case 0:
            return "Drop files into the notch to stage a workflow."
        case 1:
            return queuedItems[0].url.lastPathComponent
        default:
            return "\(queuedItems.count) items ready"
        }
    }

    private var byteSummary: String {
        guard totalByteCount > 0 else {
            return "Add Files"
        }

        return ByteCountFormatter.string(fromByteCount: totalByteCount, countStyle: .file)
    }

    init(
        onExpansionChange: @escaping (Bool) -> Void = { _ in },
        onSettingsExpansionChange: @escaping (Bool) -> Void = { _ in },
        onEntryModeChange: @escaping (DragonEntryMode) -> Void = { _ in },
        onMenuBarIconStyleChange: @escaping (DragonMenuBarIconStyle) -> Void = { _ in },
        onVisiblePanelHeightChange: @escaping (CGFloat) -> Void = { _ in },
        requestFileImport: @escaping (@escaping ([URL]) -> Void) -> Void = { completion in completion([]) },
        requestCloudSyncFolder: @escaping (@escaping (URL?) -> Void) -> Void = { completion in completion(nil) },
        requestFinderTagSelection: @escaping (@escaping (DragonFinderTagSelection?) -> Void) -> Void = { completion in completion(nil) },
        requestArchiveDestination: @escaping (String, @escaping (URL?) -> Void) -> Void = { _, completion in completion(nil) },
        requestConversionDestination: @escaping (String, [DragonConversionFormat], @escaping (DragonConversionSelection?) -> Void) -> Void = { _, _, completion in completion(nil) },
        requestAirDropShare: @escaping ([URL], @escaping (Result<String, Error>) -> Void) -> Void = { _, completion in completion(.failure(DragonShareError.unavailable("AirDrop is unavailable."))) },
        requestQuickShare: @escaping ([URL], @escaping (Result<String, Error>) -> Void) -> Void = { _, completion in completion(.failure(DragonShareError.unavailable("Share sheet is unavailable."))) }
    ) {
        self.onExpansionChange = onExpansionChange
        self.onSettingsExpansionChange = onSettingsExpansionChange
        self.onEntryModeChange = onEntryModeChange
        self.onMenuBarIconStyleChange = onMenuBarIconStyleChange
        self.onVisiblePanelHeightChange = onVisiblePanelHeightChange
        self.requestFileImport = requestFileImport
        self.requestCloudSyncFolder = requestCloudSyncFolder
        self.requestFinderTagSelection = requestFinderTagSelection
        self.requestArchiveDestination = requestArchiveDestination
        self.requestConversionDestination = requestConversionDestination
        self.requestAirDropShare = requestAirDropShare
        self.requestQuickShare = requestQuickShare
    }

    private var isPanelExpanded: Bool {
        isDropTargeted || isInspectorExpanded
    }

    private var panelWidth: CGFloat {
        DragonNotchLayout.panelHostWidth
    }

    private var notchShellWidth: CGFloat {
        let collapsedWidth = DragonNotchLayout.collapsedInnerWidth + (isHoveringActivationZone && isPanelExpanded == false ? DragonNotchLayout.collapsedHoverWidthIncrease : 0)
        return collapsedWidth
            + ((DragonNotchLayout.expandedInnerWidth - DragonNotchLayout.collapsedInnerWidth) * notchRevealProgress)
    }

    private var notchShellHeight: CGFloat {
        let collapsedHeight = DragonNotchLayout.collapsedHeight + (isHoveringActivationZone && isPanelExpanded == false ? DragonNotchLayout.collapsedHoverHeightIncrease : 0)
        return collapsedHeight
            + ((notchExpandedShellHeight - DragonNotchLayout.collapsedHeight) * notchRevealProgress)
    }

    private var notchExpandedShellHeight: CGFloat {
        DragonNotchLayout.expandedHeight + (isSettingsExpanded ? DragonNotchLayout.expandedSettingsHeight : 0)
    }

    private var menuBackgroundColor: Color {
        Color(
            .sRGB,
            red: backgroundRed,
            green: backgroundGreen,
            blue: backgroundBlue,
            opacity: backgroundOpacity
        )
    }

    private var usesMaterialShellBackground: Bool {
        backgroundOpacity < 0.999
    }

    private var menuColorScheme: ColorScheme {
        let luminance = (0.2126 * backgroundRed) + (0.7152 * backgroundGreen) + (0.0722 * backgroundBlue)
        let prefersLightAppearance = backgroundOpacity > 0.98 && luminance > 0.92
        return prefersLightAppearance ? .light : .dark
    }

    private var primaryLabelColor: Color {
        menuColorScheme == .light ? .black : .white
    }

    private var selectedFontDesign: DragonFontDesign {
        DragonFontDesign(rawValue: fontDesignRawValue) ?? .rounded
    }

    private var selectedEntryMode: DragonEntryMode {
        DragonEntryMode(rawValue: entryModeRawValue) ?? .notch
    }

    private var topPanelPadding: CGFloat {
        isPanelExpanded ? DragonNotchLayout.expandedTopPadding : DragonNotchLayout.collapsedTopPadding
    }

    private var entryModeTopInset: CGFloat { 0 }

    private var visiblePanelHeight: CGFloat {
        if isPanelExpanded {
            let settingsHeight = isSettingsExpanded ? DragonNotchLayout.expandedSettingsHeight : 0
            return max(0, DragonNotchLayout.expandedTopPadding + entryModeTopInset + DragonNotchLayout.expandedHeight + settingsHeight)
        }

        return max(0, DragonNotchLayout.collapsedTopPadding + entryModeTopInset + DragonNotchLayout.collapsedHeight)
    }

    private var selectedMenuBarIconStyle: DragonMenuBarIconStyle {
        DragonMenuBarIconStyle(rawValue: menuBarIconStyleRawValue) ?? .color
    }

    var body: some View {
        VStack(spacing: 0) {
            notchPanel
                .padding(.horizontal, 0)
                .padding(.top, topPanelPadding + entryModeTopInset)
                .frame(width: panelWidth, alignment: .top)
        }
        .frame(width: panelWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .onAppear {
            notchRevealProgress = isPanelExpanded ? 1 : 0
            onExpansionChange(isPanelExpanded)
            onSettingsExpansionChange(isSettingsExpanded)
            onEntryModeChange(selectedEntryMode)
            onMenuBarIconStyleChange(selectedMenuBarIconStyle)
        }
        .onChange(of: isPanelExpanded) { _, isExpanded in
            let targetProgress: CGFloat = isExpanded ? 1 : 0
            if selectedEntryMode == .notch {
                withAnimation(panelAnimation) {
                    notchRevealProgress = targetProgress
                }
            } else {
                notchRevealProgress = targetProgress
            }
            onExpansionChange(isExpanded)
        }
        .onChange(of: isSettingsExpanded) { _, isExpanded in
            onSettingsExpansionChange(isExpanded)
        }
        .onChange(of: entryModeRawValue) { _, _ in
            onEntryModeChange(selectedEntryMode)
            notchRevealProgress = isPanelExpanded ? 1 : 0

            let shouldReopen = pendingModeSwitchReopen
            let shouldRestoreSettings = pendingModeSwitchRestoreSettings
            pendingModeSwitchReopen = false
            pendingModeSwitchRestoreSettings = false

            guard shouldReopen else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(panelAnimation) {
                    isInspectorExpanded = true
                    isSettingsExpanded = shouldRestoreSettings
                }
            }
        }
        .onChange(of: menuBarIconStyleRawValue) { _, _ in
            onMenuBarIconStyleChange(selectedMenuBarIconStyle)
        }
        .onChange(of: isDropTargeted) { _, isTargeted in
            guard isTargeted else {
                return
            }

            isInspectorExpanded = true
        }
        .onPreferenceChange(DragonVisiblePanelHeightPreferenceKey.self) { height in
            onVisiblePanelHeightChange(max(height, visiblePanelHeight))
        }
        .onReceive(NotificationCenter.default.publisher(for: .dragonSetHoverActivation)) { notification in
            guard let value = notification.object as? Bool else {
                return
            }

            withAnimation(panelAnimation) {
                isHoveringActivationZone = value
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dragonShouldCollapsePanel)) { _ in
            guard isInspectorExpanded else {
                return
            }

            withAnimation(panelAnimation) {
                isInspectorExpanded = false
                isSettingsExpanded = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dragonSetPanelExpanded)) { notification in
            guard
                let value = notification.object as? Bool,
                selectedEntryMode == .menuBar
            else {
                return
            }

            withAnimation(panelAnimation) {
                isInspectorExpanded = value
                if value == false {
                    isSettingsExpanded = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dragonTogglePanelExpanded)) { _ in
            guard selectedEntryMode == .menuBar else {
                return
            }

            withAnimation(panelAnimation) {
                isInspectorExpanded.toggle()
                if isInspectorExpanded == false {
                    isSettingsExpanded = false
                }
            }
        }
    }

    private var notchPanel: some View {
        Group {
            if selectedEntryMode == .notch {
                notchModePanel
            } else {
                menuBarModePanel
            }
        }
        .frame(width: notchShellWidth)
        .animation(panelAnimation, value: notchRevealProgress)
        .animation(panelAnimation, value: isSettingsExpanded)
        .dropDestination(for: URL.self) { items, _ in
            queue(items)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
    }

    private var notchModePanel: some View {
        GlassEffectContainer(spacing: 18) {
            ZStack(alignment: .top) {
                expandedPanel
                    .frame(
                        width: DragonNotchLayout.expandedInnerWidth,
                        height: notchExpandedShellHeight,
                        alignment: .top
                    )
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle()
                                .frame(width: DragonNotchLayout.expandedInnerWidth, height: notchShellHeight)
                            Spacer(minLength: 0)
                        }
                        .frame(
                            width: DragonNotchLayout.expandedInnerWidth,
                            height: notchExpandedShellHeight,
                            alignment: .top
                        )
                    )
                    .allowsHitTesting(isPanelExpanded)

                if notchRevealProgress < 0.001 {
                    headerBar
                        .allowsHitTesting(true)
                }
            }
            .frame(width: notchShellWidth, height: notchShellHeight, alignment: .top)
            .clipShape(
                DragonCollapsedNotchShape(
                    cornerRadius: DragonNotchLayout.collapsedCornerRadius * max(0, 1 - notchRevealProgress)
                )
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: DragonVisiblePanelHeightPreferenceKey.self,
                            value: proxy.size.height + topPanelPadding + entryModeTopInset
                        )
                }
            )
        }
        .frame(width: notchShellWidth, height: notchShellHeight, alignment: .top)
    }

    private var menuBarModePanel: some View {
        GlassEffectContainer(spacing: 18) {
            Group {
                if isPanelExpanded {
                    expandedPanel
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: DragonVisiblePanelHeightPreferenceKey.self,
                                        value: proxy.size.height + topPanelPadding + entryModeTopInset
                                    )
                            }
                        )
                        .transition(.opacity)
                } else {
                    headerBar
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: DragonVisiblePanelHeightPreferenceKey.self,
                                        value: proxy.size.height + topPanelPadding + entryModeTopInset
                                    )
                            }
                        )
                }
            }
        }
    }

    private var headerBar: some View {
        Button {
            withAnimation(panelAnimation) {
                isInspectorExpanded.toggle()
            }
        } label: {
            CollapsedDragonToggle(isDropTargeted: isDropTargeted, isHoveringActivationZone: isHoveringActivationZone)
                .contentShape(DragonCollapsedNotchShape(cornerRadius: DragonNotchLayout.collapsedCornerRadius))
        }
        .buttonStyle(.plain)
        .help(isPanelExpanded ? "Collapse Dragon" : "Expand Dragon")
    }

    private var expandedPanel: some View {
        VStack(spacing: 12) {
            topBar
            if let actionStatus {
                actionStatusView(actionStatus)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            actionGrid
            stagedItemsSection
            if isSettingsExpanded {
                inlineSettingsSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(12)
        .frame(width: DragonNotchLayout.expandedInnerWidth)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(usesMaterialShellBackground ? 1 : 0)
        )
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(menuBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .environment(\.colorScheme, menuColorScheme)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("DragonLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 26)

            Spacer(minLength: 0)

            Button {
                withAnimation(panelAnimation) {
                    isSettingsExpanded.toggle()
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primaryLabelColor)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(isSettingsExpanded ? "Hide settings" : "Open settings")
            .overlay {
                RightClickOverlay {
                    confirmQuitIfNeeded()
                }
            }
        }
    }

    private var inlineSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ForEach(DragonSettingsTab.allCases) { tab in
                    settingsTabButton(tab)
                }
            }

            switch selectedSettingsTab {
            case .appearance:
                DragonInlineSettingsView()
            case .actions:
                actionsSettingsView
            case .settings:
                placeholderSettingsView
            }
        }
        .padding(14)
        .frame(width: DragonNotchLayout.expandedContentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func confirmQuitIfNeeded() {
        guard skipQuitConfirmation == false else {
            NSApp.terminate(nil)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This will quit the app. Are you sure?"
        alert.informativeText = "Dragon will close immediately."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        let checkbox = NSButton(checkboxWithTitle: "Don't ask me this in the future", target: nil, action: nil)
        alert.accessoryView = checkbox

        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    skipQuitConfirmation = checkbox.state == .on
                    NSApp.terminate(nil)
                }
            }
            return
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            skipQuitConfirmation = checkbox.state == .on
            NSApp.terminate(nil)
        }
    }

    private func settingsTabButton(_ tab: DragonSettingsTab) -> some View {
        Button {
            selectedSettingsTab = tab
        } label: {
            Text(tab.title)
                .font(selectedFontDesign.font(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedSettingsTab == tab ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selectedSettingsTab == tab ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionsSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose which actions appear in Dragon.")
                .font(selectedFontDesign.font(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(availableActions, id: \.kind) { action in
                    actionVisibilityRow(action)
                }
            }
        }
    }

    private func actionVisibilityRow(_ action: DragonAction) -> some View {
        let isEnabled = enabledActionKinds.contains(action.kind)

        return Button {
            toggleActionVisibility(action.kind)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(action.tint.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(selectedFontDesign.font(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(action.subtitle)
                        .font(selectedFontDesign.font(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.white.opacity(0.35))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderSettingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose how Dragon is opened.")
                .font(selectedFontDesign.font(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(DragonEntryMode.allCases) { mode in
                    entryModeButton(mode)
                }
            }

            Text(selectedEntryMode == .notch
                 ? "Notch mode reveals Dragon from the top-center hover target."
                 : "Menu Bar mode opens Dragon from the menu bar logo instead of the notch target.")
                .font(selectedFontDesign.font(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if selectedEntryMode == .menuBar {
                menuBarIconStylePicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func entryModeButton(_ mode: DragonEntryMode) -> some View {
        Button {
            let shouldReopen = isInspectorExpanded
            let shouldRestoreSettings = isSettingsExpanded
            pendingModeSwitchReopen = shouldReopen
            pendingModeSwitchRestoreSettings = shouldRestoreSettings

            if shouldReopen {
                withAnimation(.easeOut(duration: 0.14)) {
                    isInspectorExpanded = false
                    isSettingsExpanded = false
                }
            }

            entryModeRawValue = mode.rawValue
        } label: {
            Text(mode.title)
                .font(selectedFontDesign.font(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedEntryMode == mode ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selectedEntryMode == mode ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var menuBarIconStylePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar icon")
                .font(selectedFontDesign.font(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(DragonMenuBarIconStyle.allCases) { style in
                    menuBarIconStyleButton(style)
                }
            }
        }
        .padding(.top, 4)
    }

    private func menuBarIconStyleButton(_ style: DragonMenuBarIconStyle) -> some View {
        Button {
            menuBarIconStyleRawValue = style.rawValue
        } label: {
            HStack(spacing: 8) {
                Image(style.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text(style.title)
                    .font(selectedFontDesign.font(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedMenuBarIconStyle == style ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selectedMenuBarIconStyle == style ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(minimum: DragonNotchLayout.actionTileWidth), spacing: DragonNotchLayout.actionTileSpacing),
                count: 5
            ),
            alignment: .center,
            spacing: 8
        ) {
            ForEach(allActions) { action in
                actionCard(action)
            }
        }
        .frame(width: DragonNotchLayout.expandedContentWidth, alignment: .center)
    }

    private func actionCard(_ action: DragonAction) -> some View {
        let isHovered = hoveredActionID == action.id

        return Button {
            perform(action)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(action.tint.opacity(0.16))
                    )
                    .foregroundStyle(action.tint)

                Text(action.title)
                    .font(selectedFontDesign.font(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(
                minWidth: DragonNotchLayout.actionTileWidth,
                maxWidth: .infinity,
                minHeight: DragonNotchLayout.actionTileHeight,
                alignment: .center
            )
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(isHovered ? 0.18 : 0.0), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.05 : 0.0))
        )
        .onHover { hovering in
            hoveredActionID = hovering ? action.id : nil
        }
        .help(action.title)
        .disabled(isActionDisabled(action))
        .opacity(isActionDisabled(action) ? 0.45 : 1)
    }

    private func actionStatusView(_ status: DragonActionStatus) -> some View {
        HStack(spacing: 10) {
            Image(systemName: status.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(status.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(selectedFontDesign.font(size: 12, weight: .semibold))

                if let detail = status.detail {
                    Text(detail)
                        .font(selectedFontDesign.font(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if let outputURL = status.outputURL {
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                }
                .buttonStyle(.glass)
            }

            Button {
                let text = [status.title, status.detail].compactMap { $0 }.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
            .help("Copy status")
        }
        .padding(12)
        .frame(width: DragonNotchLayout.expandedContentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var stagedItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Staged files")
                    .font(selectedFontDesign.font(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if queuedItems.isEmpty == false {
                    Button("Clear") {
                        queuedItems.removeAll()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                Spacer()

                Text(byteSummary)
                    .font(selectedFontDesign.font(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if queuedItems.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(queuedItems) { item in
                            stagedItemTile(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: DragonNotchLayout.stagedItemsViewportHeight, alignment: .topLeading)
            }
        }
        .padding(10)
        .frame(width: DragonNotchLayout.expandedContentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            importFiles()
        }
        .help("Click empty space here or drop files to stage them")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Nothing staged yet")
                .font(selectedFontDesign.font(size: 14, weight: .semibold))

        }
        .frame(width: DragonNotchLayout.expandedContentWidth - 28)
        .frame(height: DragonNotchLayout.stagedItemsViewportHeight)
    }

    private func stagedItemTile(_ item: QueuedDropItem) -> some View {
        ZStack(alignment: .topTrailing) {
            stagedItemTileContent(item)
                .draggable(item.accessibleURL()) {
                    stagedItemTileContent(item)
                }

            Button {
                queuedItems.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .padding(.trailing, 2)
                .help("Remove \(item.displayName)")
        }
        .frame(width: DragonNotchLayout.stagedItemTileWidth, alignment: .top)
    }

    private func stagedItemTileContent(_ item: QueuedDropItem) -> some View {
        VStack(spacing: 6) {
            StagedFilePreviewIcon(item: item)
                .frame(width: 52, height: 52)

            Text(item.displayName)
                .font(selectedFontDesign.font(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: DragonNotchLayout.stagedItemTileWidth - 8)
        }
        .frame(width: DragonNotchLayout.stagedItemTileWidth, height: DragonNotchLayout.stagedItemsViewportHeight, alignment: .top)
    }

    private func stagedFileIcon(for item: QueuedDropItem) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: item.accessibleURL().path)
        image.size = NSSize(width: 64, height: 64)
        return image
    }
    private func importFiles() {
        requestFileImport { urls in
            guard urls.isEmpty == false else {
                return
            }

            queue(urls)
            isInspectorExpanded = true
        }
    }

    private func queue(_ urls: [URL]) {
        let deduplicatedURLs = urls.filter { url in
            queuedItems.contains(where: { $0.url == url }) == false
        }

        let newItems = deduplicatedURLs.map { url in
            QueuedDropItem(url: url)
        }
        guard newItems.isEmpty == false else {
            isInspectorExpanded = true
            return
        }

        queuedItems.append(contentsOf: newItems)
        isInspectorExpanded = true
    }

    private func perform(_ action: DragonAction) {
        guard isPerformingAction == false else {
            return
        }

        switch action.kind {
        case .compress:
            guard queuedItems.isEmpty == false else {
                actionStatus = .error(title: "Nothing to compress", detail: "Stage one or more files first.")
                return
            }

            let items = queuedItems
            requestArchiveDestination(DragonCompressionService.suggestedArchiveFileName(for: queuedItems)) { outputURL in
                guard let outputURL else {
                    return
                }

                isPerformingAction = true
                actionStatus = .working(title: "Compressing files", detail: "Building a zip archive from the staged items.")

                Task {
                    do {
                        let archiveURL = try await DragonCompressionService.compress(items: items, outputURL: outputURL)

                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .success(
                                title: "Archive created",
                                detail: archiveURL.lastPathComponent,
                                outputURL: archiveURL
                            )
                        }
                    } catch {
                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .error(
                                title: "Compression failed",
                                detail: error.localizedDescription
                            )
                        }
                    }
                }
            }
        case .convert:
            guard let item = queuedItems.first, queuedItems.count == 1 else {
                actionStatus = .error(title: "Choose one file", detail: "Convert currently supports one staged file at a time.")
                return
            }

            let formats = item.availableConversionFormats
            guard formats.isEmpty == false else {
                actionStatus = .error(title: "Conversion unavailable", detail: "This file type is not currently supported for conversion.")
                return
            }

            requestConversionDestination(item.suggestedConvertedBaseName, formats) { selection in
                guard let selection else {
                    return
                }

                isPerformingAction = true
                actionStatus = .working(title: "Converting file", detail: "Creating a \(selection.format.title) version of \(item.url.lastPathComponent).")

                Task {
                    do {
                        let convertedURL = try await DragonConversionService.convert(item: item, to: selection.format, outputURL: selection.outputURL)

                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .success(
                                title: "Conversion complete",
                                detail: convertedURL.lastPathComponent,
                                outputURL: convertedURL
                            )
                        }
                    } catch {
                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .error(
                                title: "Conversion failed",
                                detail: error.localizedDescription
                            )
                        }
                    }
                }
            }
        case .quickShare, .airDrop, .finderTag, .cloudSync:
            performShareAction(action)
        }
    }

    private func isActionDisabled(_ action: DragonAction) -> Bool {
        if isPerformingAction {
            return true
        }

        switch action.kind {
        case .compress:
            return queuedItems.isEmpty
        case .convert:
            return canConvertQueuedItems == false
        case .quickShare, .airDrop, .finderTag, .cloudSync:
            return queuedItems.isEmpty
        }
    }

    private func toggleActionVisibility(_ kind: DragonActionKind) {
        var updatedKinds = enabledActionKinds
        if updatedKinds.contains(kind) {
            updatedKinds.remove(kind)
        } else {
            updatedKinds.insert(kind)
        }

        enabledActionsRawValue = DragonActionKind.allCases
            .filter { updatedKinds.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private var canConvertQueuedItems: Bool {
        guard queuedItems.count == 1, let item = queuedItems.first else {
            return false
        }

        return item.availableConversionFormats.isEmpty == false
    }

    private var stagedShareURLs: [URL] {
        queuedItems.map { $0.accessibleURL() }
    }

    private func performShareAction(_ action: DragonAction) {
        switch action.kind {
        case .airDrop:
            guard stagedShareURLs.isEmpty == false else {
                actionStatus = .error(title: "Nothing to share", detail: "Stage one or more files first.")
                return
            }

            isPerformingAction = true
            actionStatus = .working(title: "Opening AirDrop", detail: "Preparing staged files for AirDrop.")
            requestAirDropShare(stagedShareURLs) { result in
                handleShareResult(result, actionTitle: action.title)
            }
        case .quickShare:
            guard stagedShareURLs.isEmpty == false else {
                actionStatus = .error(title: "Nothing to share", detail: "Stage one or more files first.")
                return
            }

            isPerformingAction = true
            actionStatus = .working(title: "Opening share sheet", detail: "Preparing staged files for sharing.")
            requestQuickShare(stagedShareURLs) { result in
                handleShareResult(result, actionTitle: action.title)
            }
        case .finderTag:
            guard queuedItems.isEmpty == false else {
                actionStatus = .error(title: "Nothing to tag", detail: "Stage one or more files first.")
                return
            }

            requestFinderTagSelection { selection in
                guard let selection else {
                    return
                }

                isPerformingAction = true
                actionStatus = .working(
                    title: "Applying Finder tag",
                    detail: "Adding the \(selection.name) tag to the staged files."
                )

                let items = queuedItems
                Task {
                    do {
                        try DragonFinderTagService.applyTag(selection, to: items)

                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .success(
                                title: "Finder tag applied",
                                detail: DragonFinderTagService.successDetail(for: selection.name, itemCount: items.count),
                                outputURL: items.first?.url.deletingLastPathComponent()
                            )
                        }
                    } catch {
                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .error(title: "Finder Tag failed", detail: error.localizedDescription)
                        }
                    }
                }
            }
        case .cloudSync:
            guard queuedItems.isEmpty == false else {
                actionStatus = .error(title: "Nothing to sync", detail: "Stage one or more files first.")
                return
            }

            requestCloudSyncFolder { destinationFolder in
                guard let destinationFolder else {
                    return
                }

                let items = queuedItems
                isPerformingAction = true
                actionStatus = .working(title: "Syncing to cloud folder", detail: "Copying staged files into the selected synced folder.")

                Task {
                    do {
                        let syncedFolderURL = try DragonCloudSyncService.sync(items: items, into: destinationFolder)

                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .success(
                                title: "Cloud sync complete",
                                detail: syncedFolderURL.lastPathComponent,
                                outputURL: syncedFolderURL
                            )
                        }
                    } catch {
                        await MainActor.run {
                            isPerformingAction = false
                            actionStatus = .error(title: "Cloud Sync failed", detail: error.localizedDescription)
                        }
                    }
                }
            }
        case .compress, .convert:
            return
        }
    }

    private func handleShareResult(_ result: Result<String, Error>, actionTitle: String) {
        switch result {
        case .success(let detail):
            isPerformingAction = false
            actionStatus = .success(title: "\(actionTitle) ready", detail: detail, outputURL: nil)
        case .failure(let error):
            isPerformingAction = false
            actionStatus = .error(title: "\(actionTitle) failed", detail: error.localizedDescription)
        }
    }
}

private struct QueuedDropItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let bookmarkData: Data?
    let byteCount: Int64
    let isDirectory: Bool

    init(url: URL) {
        self.url = url
        self.bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentTypeKey])
        self.byteCount = Int64(values?.fileSize ?? 0)
        self.isDirectory = values?.isDirectory ?? false
    }

    var detailText: String {
        if isDirectory {
            return "Folder"
        }

        let sizeText = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
        return sizeText
    }

    var displayName: String {
        if isDirectory {
            return url.lastPathComponent
        }

        return url.deletingPathExtension().lastPathComponent
    }

    var symbolName: String {
        if isDirectory {
            return "folder.fill"
        }

        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif", "webp":
            return "photo.fill"
        case "zip", "rar", "7z", "tar":
            return "archivebox.fill"
        case "mp4", "mov", "mkv":
            return "film.fill"
        case "mp3", "wav", "m4a":
            return "waveform"
        case "pdf":
            return "doc.richtext.fill"
        default:
            return "doc.fill"
        }
    }

    var isConvertible: Bool {
        availableConversionFormats.isEmpty == false
    }

    func accessibleURL() -> URL {
        guard let bookmarkData else {
            return url
        }

        var isStale = false
        let resolvedURL = (try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )) ?? url

        return resolvedURL
    }

    var conversionCategory: DragonConversionCategory? {
        DragonConversionCatalog.category(forFileExtension: url.pathExtension, isDirectory: isDirectory)
    }

    var canonicalExtension: String {
        url.pathExtension.lowercased()
    }

    var availableConversionFormats: [DragonConversionFormat] {
        DragonConversionCatalog.availableFormats(forFileExtension: canonicalExtension, isDirectory: isDirectory)
    }

    var suggestedConvertedBaseName: String {
        url.deletingPathExtension().lastPathComponent
    }
}

private struct StagedFilePreviewIcon: View {
    let item: QueuedDropItem

    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? fallbackIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .task(id: item.id) {
                thumbnail = await DragonFilePreview.thumbnail(for: item, size: CGSize(width: 96, height: 96))
            }
    }

    private var fallbackIcon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: item.accessibleURL().path)
        image.size = NSSize(width: 64, height: 64)
        return image
    }
}

private enum DragonFilePreview {
    static func thumbnail(for item: QueuedDropItem, size: CGSize) async -> NSImage? {
        let url = item.accessibleURL()
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                guard error == nil, let representation else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: representation.nsImage)
            }
        }
    }
}

private struct DragonAction: Identifiable, Hashable {
    let id = UUID()
    let kind: DragonActionKind
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color

    static let primary: [DragonAction] = [
        DragonAction(
            kind: .compress,
            title: "Compress",
            subtitle: "Package staged files into a smaller archive.",
            symbolName: "arrow.down.right.and.arrow.up.left",
            tint: .mint
        ),
        DragonAction(
            kind: .convert,
            title: "Convert",
            subtitle: "Transform files into another format.",
            symbolName: "arrow.triangle.2.circlepath",
            tint: .orange
        ),
        DragonAction(
            kind: .quickShare,
            title: "Share",
            subtitle: "Prepare a link-ready handoff flow.",
            symbolName: "link.badge.plus",
            tint: .blue
        )
    ]

    static let secondary: [DragonAction] = [
        DragonAction(
            kind: .airDrop,
            title: "AirDrop",
            subtitle: "Route staged files into a nearby transfer flow.",
            symbolName: "airplayaudio",
            tint: .teal
        ),
        DragonAction(
            kind: .finderTag,
            title: "Tag",
            subtitle: "Organize incoming drops before filing them away.",
            symbolName: "tag.fill",
            tint: .pink
        ),
        DragonAction(
            kind: .cloudSync,
            title: "Cloud Sync",
            subtitle: "Reserve this slot for supported cloud providers.",
            symbolName: "icloud.fill",
            tint: .indigo
        )
    ]
}

private enum DragonActionKind: String, Hashable, CaseIterable {
    case compress
    case convert
    case quickShare
    case airDrop
    case finderTag
    case cloudSync
}

private enum DragonSettingsTab: String, CaseIterable, Identifiable {
    case appearance
    case actions
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .actions:
            return "Actions"
        case .settings:
            return "Settings"
        }
    }
}

enum DragonEntryMode: String, CaseIterable, Identifiable {
    case notch
    case menuBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notch:
            return "Notch"
        case .menuBar:
            return "Menu Bar"
        }
    }
}

enum DragonMenuBarIconStyle: String, CaseIterable, Identifiable {
    case color
    case white

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color:
            return "Color"
        case .white:
            return "White"
        }
    }

    var assetName: String {
        switch self {
        case .color:
            return "DragonLogo"
        case .white:
            return "WhiteDragonLogo"
        }
    }
}

private enum DragonShareError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            return detail
        }
    }
}

private enum DragonFinderTagError: LocalizedError {
    case noItems
    case invalidName

    var errorDescription: String? {
        switch self {
        case .noItems:
            return "Stage one or more files before applying a Finder tag."
        case .invalidName:
            return "Enter a Finder tag name before applying the tag."
        }
    }
}

private enum DragonCloudSyncError: LocalizedError {
    case noItems

    var errorDescription: String? {
        switch self {
        case .noItems:
            return "Stage one or more files before syncing."
        }
    }
}

enum DragonConversionCategory: String, Hashable {
    case image
    case audio
    case video
    case document

    init?(fileExtension: String) {
        let normalizedExtension = fileExtension.lowercased()

        switch normalizedExtension {
        case "png", "jpg", "jpeg", "heic", "tif", "tiff", "bmp", "gif":
            self = .image
        case "wav", "wave", "aif", "aiff", "aifc", "caf", "m4a", "mp3", "aac", "adts", "flac", "ogg", "oga", "opus", "ac3", "3gp", "3gpp", "3g2", "3gp2":
            self = .audio
        case "mp4", "m4v", "mov", "avi", "mkv", "mpeg", "mpg":
            self = .video
        case "txt", "rtf", "html", "htm", "md", "doc", "docx", "odt", "wordml", "webarchive", "pdf", "pptx":
            self = .document
        default:
            return nil
        }
    }

    var supportedFormats: [DragonConversionFormat] {
        switch self {
        case .image:
            return [.png, .jpeg, .heic, .tiff, .bmp, .gif, .webP]
        case .audio:
            if DragonBundledTool.ffmpeg.isAvailable {
                return [.wav, .aiff, .aifc, .caf, .m4a, .aac, .flac, .ogg, .ac3, .threeGPP, .threeGPPTwo]
            }

            return [.m4a, .aac, .flac, .threeGPP, .threeGPPTwo]
        case .video:
            var formats: [DragonConversionFormat] = [.mp4Video, .m4vVideo, .movVideo]
            if DragonBundledTool.ffmpeg.isAvailable {
                formats.append(contentsOf: [.aviVideo, .mkvVideo, .mpegVideo])
            }
            return formats
        case .document:
            return [.pdf, .plainText, .rtf, .html, .doc, .docx, .odt, .wordML, .webArchive, .markdown]
        }
    }
}

enum DragonConversionFormat: String, CaseIterable, Identifiable, Hashable {
    case png
    case jpeg
    case heic
    case tiff
    case bmp
    case gif
    case webP
    case wav
    case aiff
    case aifc
    case caf
    case m4a
    case aac
    case flac
    case mp3
    case ogg
    case ac3
    case threeGPP
    case threeGPPTwo
    case mp4Video
    case m4vVideo
    case movVideo
    case aviVideo
    case mkvVideo
    case mpegVideo
    case pdf
    case plainText
    case rtf
    case html
    case doc
    case docx
    case odt
    case wordML
    case webArchive
    case markdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        case .bmp: return "BMP"
        case .gif: return "GIF"
        case .webP: return "WebP"
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        case .aifc: return "AIFC"
        case .caf: return "CAF"
        case .m4a: return "M4A"
        case .aac: return "AAC"
        case .flac: return "FLAC"
        case .mp3: return "MP3"
        case .ogg: return "OGG"
        case .ac3: return "AC3"
        case .threeGPP: return "3GPP"
        case .threeGPPTwo: return "3GPP-2"
        case .mp4Video: return "MP4"
        case .m4vVideo: return "M4V"
        case .movVideo: return "MOV"
        case .aviVideo: return "AVI"
        case .mkvVideo: return "MKV"
        case .mpegVideo: return "MPEG"
        case .pdf: return "PDF"
        case .plainText: return "TXT"
        case .rtf: return "RTF"
        case .html: return "HTML"
        case .doc: return "DOC"
        case .docx: return "DOCX"
        case .odt: return "ODT"
        case .wordML: return "WordML"
        case .webArchive: return "WebArchive"
        case .markdown: return "Markdown"
        }
    }

    var preferredFileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .tiff: return "tiff"
        case .bmp: return "bmp"
        case .gif: return "gif"
        case .webP: return "webp"
        case .wav: return "wav"
        case .aiff: return "aiff"
        case .aifc: return "aifc"
        case .caf: return "caf"
        case .m4a: return "m4a"
        case .aac: return "aac"
        case .flac: return "flac"
        case .mp3: return "mp3"
        case .ogg: return "ogg"
        case .ac3: return "ac3"
        case .threeGPP: return "3gp"
        case .threeGPPTwo: return "3g2"
        case .mp4Video: return "mp4"
        case .m4vVideo: return "m4v"
        case .movVideo: return "mov"
        case .aviVideo: return "avi"
        case .mkvVideo: return "mkv"
        case .mpegVideo: return "mpeg"
        case .pdf: return "pdf"
        case .plainText: return "txt"
        case .rtf: return "rtf"
        case .html: return "html"
        case .doc: return "doc"
        case .docx: return "docx"
        case .odt: return "odt"
        case .wordML: return "xml"
        case .webArchive: return "webarchive"
        case .markdown: return "md"
        }
    }

    var fileExtensions: Set<String> {
        switch self {
        case .png: return ["png"]
        case .jpeg: return ["jpg", "jpeg"]
        case .heic: return ["heic"]
        case .tiff: return ["tif", "tiff"]
        case .bmp: return ["bmp"]
        case .gif: return ["gif"]
        case .webP: return ["webp"]
        case .wav: return ["wav", "wave"]
        case .aiff: return ["aif", "aiff"]
        case .aifc: return ["aifc"]
        case .caf: return ["caf"]
        case .m4a: return ["m4a"]
        case .aac: return ["aac", "adts"]
        case .flac: return ["flac"]
        case .mp3: return ["mp3"]
        case .ogg: return ["ogg", "oga", "opus"]
        case .ac3: return ["ac3"]
        case .threeGPP: return ["3gp", "3gpp"]
        case .threeGPPTwo: return ["3g2", "3gp2"]
        case .mp4Video: return ["mp4"]
        case .m4vVideo: return ["m4v"]
        case .movVideo: return ["mov"]
        case .aviVideo: return ["avi"]
        case .mkvVideo: return ["mkv"]
        case .mpegVideo: return ["mpeg", "mpg"]
        case .pdf: return ["pdf"]
        case .plainText: return ["txt"]
        case .rtf: return ["rtf"]
        case .html: return ["html", "htm"]
        case .doc: return ["doc"]
        case .docx: return ["docx"]
        case .odt: return ["odt"]
        case .wordML: return ["wordml", "xml"]
        case .webArchive: return ["webarchive"]
        case .markdown: return ["md"]
        }
    }

    var category: DragonConversionCategory {
        switch self {
        case .png, .jpeg, .heic, .tiff, .bmp, .gif, .webP:
            return .image
        case .wav, .aiff, .aifc, .caf, .m4a, .aac, .flac, .mp3, .ogg, .ac3, .threeGPP, .threeGPPTwo:
            return .audio
        case .mp4Video, .m4vVideo, .movVideo, .aviVideo, .mkvVideo, .mpegVideo:
            return .video
        case .pdf, .plainText, .rtf, .html, .doc, .docx, .odt, .wordML, .webArchive, .markdown:
            return .document
        }
    }

    var utType: UTType? {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        case .webP: return .webP
        case .wav: return .wav
        case .aiff: return .aiff
        case .aifc: return UTType(filenameExtension: "aifc")
        case .caf: return UTType(filenameExtension: "caf")
        case .m4a: return UTType(filenameExtension: "m4a")
        case .aac: return UTType(filenameExtension: "aac")
        case .flac: return UTType(filenameExtension: "flac")
        case .mp3: return UTType.mp3
        case .ogg: return UTType(filenameExtension: "ogg")
        case .ac3: return UTType(filenameExtension: "ac3")
        case .threeGPP: return UTType(filenameExtension: "3gp")
        case .threeGPPTwo: return UTType(filenameExtension: "3g2")
        case .mp4Video: return .mpeg4Movie
        case .m4vVideo: return UTType(filenameExtension: "m4v")
        case .movVideo: return .quickTimeMovie
        case .aviVideo: return .avi
        case .mkvVideo: return UTType(filenameExtension: "mkv")
        case .mpegVideo: return .mpeg
        case .pdf: return .pdf
        case .plainText: return .plainText
        case .rtf: return .rtf
        case .html: return .html
        case .doc: return UTType(filenameExtension: "doc")
        case .docx: return UTType(filenameExtension: "docx")
        case .odt: return UTType(filenameExtension: "odt")
        case .wordML: return UTType(filenameExtension: "xml")
        case .webArchive: return UTType(filenameExtension: "webarchive")
        case .markdown: return UTType(filenameExtension: "md")
        }
    }
}

struct DragonConversionSelection {
    let format: DragonConversionFormat
    let outputURL: URL
}

struct DragonFinderTagSelection {
    let name: String
    let labelNumber: Int?
}

enum DragonConversionCatalog {
    static func category(forFileExtension fileExtension: String, isDirectory: Bool = false) -> DragonConversionCategory? {
        guard isDirectory == false else {
            return nil
        }

        return DragonConversionCategory(fileExtension: fileExtension)
    }

    static func availableFormats(forFileExtension fileExtension: String, isDirectory: Bool = false) -> [DragonConversionFormat] {
        guard
            isDirectory == false,
            let category = DragonConversionCategory(fileExtension: fileExtension)
        else {
            return []
        }

        let canonicalExtension = fileExtension.lowercased()

        switch canonicalExtension {
        case "pdf":
            return [.plainText, .rtf, .html, .markdown]
        case "pptx":
            return [.pdf, .plainText, .rtf, .html, .markdown]
        default:
            return category.supportedFormats.filter { format in
                format.fileExtensions.contains(canonicalExtension) == false && format.isAvailableWithCurrentEngines
            }
        }
    }
}

enum DragonBundledTool: String, CaseIterable {
    case ditto
    case textutil
    case afconvert
    case unzip
    case ffmpeg
    case libreOffice

    var isAvailable: Bool {
        (try? resolvedExecutableURL()) != nil
    }

    func resolvedExecutableURL(bundle: Bundle = .main) throws -> URL {
        // Dragon prefers bundled engines from ConversionEngines/ when present so release
        // builds can remain self-contained without changing the conversion call sites.
        if let bundledURL = bundledExecutableURL(bundle: bundle) {
            return bundledURL
        }

        if let fallbackPath = fallbackExecutablePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: fallbackPath)
        }

        throw DragonToolResolutionError.missingExecutable(displayName)
    }

    private func bundledExecutableURL(bundle: Bundle) -> URL? {
        guard let resourceURL = bundle.resourceURL else {
            return nil
        }

        for relativePath in bundledRelativePaths {
            let candidate = resourceURL.appendingPathComponent(relativePath)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private var bundledRelativePaths: [String] {
        switch self {
        case .libreOffice:
            return [
                "LibreOffice.app/Contents/MacOS/soffice",
                "ConversionEngines/LibreOffice.app/Contents/MacOS/soffice"
            ]
        default:
            return [
                displayName,
                "ConversionEngines/\(displayName)"
            ]
        }
    }

    private var fallbackExecutablePaths: [String] {
        switch self {
        case .ditto:
            return ["/usr/bin/ditto"]
        case .textutil:
            return ["/usr/bin/textutil"]
        case .afconvert:
            return ["/usr/bin/afconvert"]
        case .unzip:
            return ["/usr/bin/unzip"]
        case .ffmpeg:
            return developmentOverridePaths + ["/usr/local/bin/ffmpeg"]
        case .libreOffice:
            return developmentOverridePaths + ["/Applications/LibreOffice.app/Contents/MacOS/soffice"]
        }
    }

    private var displayName: String {
        switch self {
        case .libreOffice:
            return "soffice"
        default:
            return rawValue
        }
    }

    private var developmentOverridePaths: [String] {
        switch self {
        case .ffmpeg:
            var paths: [String] = []

            if let environmentPath = ProcessInfo.processInfo.environment["DRAGON_FFMPEG_PATH"], environmentPath.isEmpty == false {
                paths.append(environmentPath)
            }

            let searchRoots = [
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                Bundle.main.bundleURL,
                URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            ]

            for root in searchRoots {
                paths.append(contentsOf: candidateDevelopmentPaths(startingAt: root))
            }

            return paths
        case .libreOffice:
            var paths: [String] = []

            if let environmentPath = ProcessInfo.processInfo.environment["DRAGON_LIBREOFFICE_PATH"], environmentPath.isEmpty == false {
                paths.append(environmentPath)
            }

            let searchRoots = [
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                Bundle.main.bundleURL
            ]

            for root in searchRoots {
                paths.append(contentsOf: candidateDevelopmentPaths(startingAt: root))
            }

            return paths
        default:
            return []
        }
    }

    private func candidateDevelopmentPaths(startingAt startURL: URL) -> [String] {
        var candidates: [String] = []
        var currentURL = startURL.standardizedFileURL

        for _ in 0..<8 {
            switch self {
            case .ffmpeg:
                candidates.append(
                    currentURL
                        .appendingPathComponent(".build/ffmpeg/install/bin/ffmpeg")
                        .path
                )
            case .libreOffice:
                candidates.append(
                    currentURL
                        .appendingPathComponent(".build/libreoffice/LibreOffice.app/Contents/MacOS/soffice")
                        .path
                )
            default:
                break
            }

            currentURL.deleteLastPathComponent()
        }

        return candidates
    }
}

private struct DragonActionStatus: Equatable {
    let title: String
    let detail: String?
    let symbolName: String
    let tint: Color
    let outputURL: URL?

    static func working(title: String, detail: String?) -> DragonActionStatus {
        DragonActionStatus(title: title, detail: detail, symbolName: "gearshape.2.fill", tint: .orange, outputURL: nil)
    }

    static func success(title: String, detail: String?, outputURL: URL?) -> DragonActionStatus {
        DragonActionStatus(title: title, detail: detail, symbolName: "checkmark.circle.fill", tint: .green, outputURL: outputURL)
    }

    static func error(title: String, detail: String?) -> DragonActionStatus {
        DragonActionStatus(title: title, detail: detail, symbolName: "xmark.octagon.fill", tint: .red, outputURL: nil)
    }

    static func info(title: String, detail: String?) -> DragonActionStatus {
        DragonActionStatus(title: title, detail: detail, symbolName: "info.circle.fill", tint: .blue, outputURL: nil)
    }
}

private enum DragonCompressionService {
    static func compress(items: [QueuedDropItem], outputURL: URL) async throws -> URL {
        guard items.isEmpty == false else {
            throw DragonCompressionError.noItems
        }

        let stagingDirectoryURL = try makeStagingDirectory(for: items)

        defer {
            try? FileManager.default.removeItem(at: stagingDirectoryURL)
        }

        try stageItems(items: items, in: stagingDirectoryURL)
        try await runDitto(sourceURL: stagingDirectoryURL, outputURL: outputURL)
        return outputURL
    }

    static func suggestedArchiveFileName(for items: [QueuedDropItem]) -> String {
        "\(archiveBaseName(for: items)).zip"
    }

    private static func runDitto(sourceURL: URL, outputURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            do {
                process.executableURL = try DragonBundledTool.ditto.resolvedExecutableURL()
                process.environment = sanitizedProcessEnvironment()
                process.arguments = [
                    "-c",
                    "-k",
                    "--sequesterRsrc",
                    "--keepParent",
                    sourceURL.path,
                    outputURL.path
                ]

                let errorPipe = Pipe()
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let detail = (errorOutput?.isEmpty == false ? errorOutput : nil) ?? "ditto exited with status \(process.terminationStatus)."
                        continuation.resume(throwing: DragonCompressionError.processFailed(detail))
                    }
                }

                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func makeStagingDirectory(for items: [QueuedDropItem]) throws -> URL {
        let baseName = archiveBaseName(for: items)
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dragon-staging-\(UUID().uuidString)")
            .appendingPathComponent(baseName, isDirectory: true)

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func stageItems(items: [QueuedDropItem], in stagingDirectoryURL: URL) throws {
        let fileManager = FileManager.default

        for item in items {
            let sourceURL = item.accessibleURL()
            let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            var candidateURL = stagingDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: sourceURL.hasDirectoryPath)
            var suffix = 2

            while fileManager.fileExists(atPath: candidateURL.path) {
                let baseName = sourceURL.deletingPathExtension().lastPathComponent
                let pathExtension = sourceURL.pathExtension
                let uniqueName = pathExtension.isEmpty ? "\(baseName) \(suffix)" : "\(baseName) \(suffix).\(pathExtension)"
                candidateURL = stagingDirectoryURL.appendingPathComponent(uniqueName, isDirectory: sourceURL.hasDirectoryPath)
                suffix += 1
            }

            try copyItem(at: sourceURL, to: candidateURL)
        }
    }

    private static func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        var coordinationError: NSError?
        var readError: Error?

        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try FileManager.default.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                readError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        if let readError {
            throw readError
        }
    }

    private static func archiveBaseName(for items: [QueuedDropItem]) -> String {
        if items.count == 1 {
            let source = items[0].url
            return source.deletingPathExtension().lastPathComponent
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        return "Dragon Archive \(formatter.string(from: .now))"
    }
}

private enum DragonFinderTagService {
    static func applyTag(_ selection: DragonFinderTagSelection, to items: [QueuedDropItem]) throws {
        guard items.isEmpty == false else {
            throw DragonFinderTagError.noItems
        }

        let tagName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tagName.isEmpty == false else {
            throw DragonFinderTagError.invalidName
        }

        for item in items {
            let sourceURL = item.accessibleURL()
            let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            var coordinationError: NSError?
            var writeError: Error?

            NSFileCoordinator().coordinate(writingItemAt: sourceURL, options: .forMerging, error: &coordinationError) { coordinatedURL in
                do {
                    var resourceValues = try coordinatedURL.resourceValues(forKeys: [.tagNamesKey, .labelNumberKey])
                    var tagNames = resourceValues.tagNames ?? []
                    if tagNames.contains(tagName) == false {
                        tagNames.append(tagName)
                    }
                    resourceValues.tagNames = tagNames
                    resourceValues.labelNumber = selection.labelNumber
                    var mutableURL = coordinatedURL
                    try mutableURL.setResourceValues(resourceValues)
                } catch {
                    writeError = error
                }
            }

            if let coordinationError {
                throw coordinationError
            }

            if let writeError {
                throw writeError
            }
        }
    }

    static func successDetail(for tagName: String, itemCount: Int) -> String {
        if itemCount == 1 {
            return "Added the \(tagName) tag to 1 item."
        }

        return "Added the \(tagName) tag to \(itemCount) items."
    }
}

private enum DragonCloudSyncService {
    static func sync(items: [QueuedDropItem], into destinationFolder: URL) throws -> URL {
        guard items.isEmpty == false else {
            throw DragonCloudSyncError.noItems
        }

        let folderURL = try makeSyncFolder(in: destinationFolder, itemCount: items.count)
        let destinationIsSecurityScoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if destinationIsSecurityScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for item in items {
            let sourceURL = item.accessibleURL()
            let sourceIsSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if sourceIsSecurityScoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            var candidateURL = uniqueDestinationURL(for: sourceURL, in: folderURL)
            var suffix = 2

            while FileManager.default.fileExists(atPath: candidateURL.path) {
                candidateURL = uniqueDestinationURL(for: sourceURL, in: folderURL, suffix: suffix)
                suffix += 1
            }

            try copyItem(at: sourceURL, to: candidateURL)
        }

        return folderURL
    }

    private static func makeSyncFolder(in destinationFolder: URL, itemCount: Int) throws -> URL {
        if itemCount == 1 {
            return destinationFolder
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        let folderName = "Dragon Sync \(formatter.string(from: .now))"
        return destinationFolder.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func uniqueDestinationURL(for sourceURL: URL, in folderURL: URL, suffix: Int? = nil) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        let finalName: String

        if let suffix {
            finalName = pathExtension.isEmpty ? "\(baseName) \(suffix)" : "\(baseName) \(suffix).\(pathExtension)"
        } else {
            finalName = sourceURL.lastPathComponent
        }

        return folderURL.appendingPathComponent(finalName, isDirectory: sourceURL.hasDirectoryPath)
    }

    private static func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        var coordinationError: NSError?
        var readError: Error?

        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try FileManager.default.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                readError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        if let readError {
            throw readError
        }
    }
}

private enum DragonConversionService {
    static func convert(item: QueuedDropItem, to format: DragonConversionFormat, outputURL: URL) async throws -> URL {
        let sourceURL = item.accessibleURL()
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        switch format.category {
        case .image:
            try convertImage(at: sourceURL, to: format, outputURL: outputURL)
        case .audio:
            try await convertAudio(at: sourceURL, to: format, outputURL: outputURL)
        case .video:
            try await convertVideo(at: sourceURL, to: format, outputURL: outputURL)
        case .document:
            try convertDocument(at: sourceURL, sourceExtension: item.canonicalExtension, to: format, outputURL: outputURL)
        }

        return outputURL
    }

    private static func convertImage(at sourceURL: URL, to format: DragonConversionFormat, outputURL: URL) throws {
        switch format {
        case .jpeg, .png, .tiff, .bmp, .gif:
            try convertBitmapImage(at: sourceURL, to: format, outputURL: outputURL)
        case .heic, .webP:
            try convertImageWithImageIO(at: sourceURL, to: format, outputURL: outputURL)
        default:
            throw DragonConversionError.unsupportedConversion("Dragon does not support exporting this image format.")
        }
    }

    private static func convertBitmapImage(at sourceURL: URL, to format: DragonConversionFormat, outputURL: URL) throws {
        guard
            let image = NSImage(contentsOf: sourceURL),
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let fileType = bitmapFileType(for: format)
        else {
            throw DragonConversionError.unsupportedConversion("Dragon could not read this image.")
        }

        let properties: [NSBitmapImageRep.PropertyKey: Any]
        switch format {
        case .jpeg:
            properties = [.compressionFactor: 0.92]
        default:
            properties = [:]
        }

        guard let data = bitmap.representation(using: fileType, properties: properties) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not export this image as \(format.title).")
        }

        try data.write(to: outputURL, options: .atomic)
    }

    private static func convertImageWithImageIO(at sourceURL: URL, to format: DragonConversionFormat, outputURL: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not read this image.")
        }

        guard let destinationType = format.utType?.identifier else {
            throw DragonConversionError.unsupportedConversion("Dragon does not support exporting \(format.title) on this Mac.")
        }

        let supportedDestinationTypes = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        guard supportedDestinationTypes.contains(destinationType) else {
            throw DragonConversionError.unsupportedConversion("Dragon does not support exporting \(format.title) on this Mac.")
        }

        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not decode this image.")
        }

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, destinationType as CFString, 1, nil) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not prepare the \(format.title) exporter.")
        }

        let properties: CFDictionary
        switch format {
        case .heic:
            properties = [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        default:
            properties = [:] as CFDictionary
        }

        CGImageDestinationAddImage(destination, image, properties)

        guard CGImageDestinationFinalize(destination) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not write the converted image.")
        }
    }

    private static func bitmapFileType(for format: DragonConversionFormat) -> NSBitmapImageRep.FileType? {
        switch format {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .tiff:
            return .tiff
        case .bmp:
            return .bmp
        case .gif:
            return .gif
        default:
            return nil
        }
    }

    private static func convertAudio(at sourceURL: URL, to format: DragonConversionFormat, outputURL: URL) async throws {
        if DragonBundledTool.ffmpeg.isAvailable {
            try await runProcess(
                tool: .ffmpeg,
                arguments: ffmpegAudioArguments(for: sourceURL, format: format, outputURL: outputURL)
            )
            return
        }

        switch format {
        case .m4a:
            try await exportAudioAsset(at: sourceURL, to: outputURL)
        case .aac, .flac, .threeGPP, .threeGPPTwo:
            try await runProcess(
                tool: .afconvert,
                arguments: afconvertArguments(for: sourceURL, format: format, outputURL: outputURL)
            )
        default:
            throw DragonConversionError.unsupportedConversion("Dragon does not currently support exporting \(format.title) audio on this Mac.")
        }
    }

    private static func exportAudioAsset(at sourceURL: URL, to outputURL: URL) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not create an M4A exporter for this audio file.")
        }

        try await exportSession.export(to: outputURL, as: .m4a)
    }

    private static func convertVideo(at sourceURL: URL, to format: DragonConversionFormat, outputURL: URL) async throws {
        if DragonBundledTool.ffmpeg.isAvailable {
            try await runProcess(
                tool: .ffmpeg,
                arguments: ffmpegVideoArguments(for: sourceURL, format: format, outputURL: outputURL)
            )
            return
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not create a video exporter for this file.")
        }

        let fileType: AVFileType
        switch format {
        case .mp4Video:
            fileType = .mp4
        case .m4vVideo:
            fileType = .m4v
        case .movVideo:
            fileType = .mov
        default:
            throw DragonConversionError.unsupportedConversion("Dragon does not support this video target yet.")
        }

        try await exportSession.export(to: outputURL, as: fileType)
    }

    private static func convertDocument(at sourceURL: URL, sourceExtension: String, to format: DragonConversionFormat, outputURL: URL) throws {
        switch format {
        case .pdf, .plainText, .rtf, .html, .markdown:
            let attributedString = try loadAttributedDocument(at: sourceURL, sourceExtension: sourceExtension)
            try writeAttributedDocument(attributedString, to: format, outputURL: outputURL)
        case .doc:
            guard sourceExtension != "pptx" else {
                throw DragonConversionError.unsupportedConversion("Dragon can export PowerPoint files to PDF, text, RTF, HTML, or Markdown unless a bundled office engine is installed.")
            }
            try runTextUtil(sourceURL: sourceURL, format: "doc", outputURL: outputURL)
        case .docx:
            if sourceExtension == "pptx" {
                try convertPresentationWithLibreOffice(at: sourceURL, to: format, outputURL: outputURL)
            } else {
                try runTextUtil(sourceURL: sourceURL, format: "docx", outputURL: outputURL)
            }
        case .odt:
            if sourceExtension == "pptx" {
                try convertPresentationWithLibreOffice(at: sourceURL, to: format, outputURL: outputURL)
            } else {
                try runTextUtil(sourceURL: sourceURL, format: "odt", outputURL: outputURL)
            }
        case .wordML:
            guard sourceExtension != "pptx" else {
                throw DragonConversionError.unsupportedConversion("Dragon does not support exporting PowerPoint files as WordML.")
            }
            try runTextUtil(sourceURL: sourceURL, format: "wordml", outputURL: outputURL)
        case .webArchive:
            guard sourceExtension != "pptx" else {
                throw DragonConversionError.unsupportedConversion("Dragon does not support exporting PowerPoint files as a web archive.")
            }
            try runTextUtil(sourceURL: sourceURL, format: "webarchive", outputURL: outputURL)
        default:
            throw DragonConversionError.unsupportedConversion("Dragon does not support this document target yet.")
        }
    }

    private static func loadAttributedDocument(at sourceURL: URL, sourceExtension: String) throws -> NSAttributedString {
        switch sourceExtension {
        case "txt", "md":
            let text = try String(contentsOf: sourceURL, encoding: .utf8)
            return NSAttributedString(string: text)
        case "pdf":
            return try loadPDFAttributedDocument(at: sourceURL)
        case "pptx":
            return try loadPPTXAttributedDocument(at: sourceURL)
        case "rtf":
            return try NSAttributedString(url: sourceURL, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        case "html", "htm":
            return try NSAttributedString(url: sourceURL, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil)
        case "doc", "docx", "odt", "wordml", "webarchive":
            return try NSAttributedString(url: sourceURL, options: [:], documentAttributes: nil)
        default:
            throw DragonConversionError.unsupportedConversion("Dragon does not support this document source yet.")
        }
    }

    private static func loadPDFAttributedDocument(at sourceURL: URL) throws -> NSAttributedString {
        guard let document = PDFDocument(url: sourceURL) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not read this PDF document.")
        }

        let text = (0 ..< document.pageCount).compactMap { index in
            document.page(at: index)?.string
        }.joined(separator: "\n\n")

        return NSAttributedString(string: text)
    }

    private static func loadPPTXAttributedDocument(at sourceURL: URL) throws -> NSAttributedString {
        let slideEntries = try archiveEntries(in: sourceURL)
            .filter { entryPath in
                entryPath.hasPrefix("ppt/slides/slide") &&
                entryPath.hasSuffix(".xml") &&
                entryPath.contains("/_rels/") == false
            }
            .sorted { slideIndex(in: $0) < slideIndex(in: $1) }

        guard slideEntries.isEmpty == false else {
            throw DragonConversionError.unsupportedConversion("Dragon could not find readable slides inside this PowerPoint file.")
        }

        let slideText = try slideEntries.enumerated().compactMap { index, entryPath -> String? in
            let data = try archiveEntryData(in: sourceURL, entryPath: entryPath)
            let text = DragonPPTXTextExtractor.extractText(from: data)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard text.isEmpty == false else {
                return nil
            }

            return "Slide \(index + 1)\n\(text)"
        }

        guard slideText.isEmpty == false else {
            throw DragonConversionError.unsupportedConversion("Dragon could not read text from this PowerPoint file.")
        }

        return NSAttributedString(string: slideText.joined(separator: "\n\n"))
    }

    private static func writeAttributedDocument(_ attributedString: NSAttributedString, to format: DragonConversionFormat, outputURL: URL) throws {
        switch format {
        case .plainText, .markdown:
            guard let data = attributedString.string.data(using: .utf8) else {
                throw DragonConversionError.unsupportedConversion("Dragon could not write the converted text file.")
            }
            try data.write(to: outputURL, options: .atomic)
        case .pdf:
            try writePDFDocument(attributedString, to: outputURL)
        case .rtf:
            let data = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            try data.write(to: outputURL, options: .atomic)
        case .html:
            let data = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue]
            )
            try data.write(to: outputURL, options: .atomic)
        default:
            throw DragonConversionError.unsupportedConversion("Dragon could not write this converted document format.")
        }
    }

    private static func writePDFDocument(_ attributedString: NSAttributedString, to outputURL: URL) throws {
        let document = attributedString.length == 0 ? NSAttributedString(string: "\n") : attributedString
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printableRect = pageRect.insetBy(dx: 40, dy: 40)

        guard
            let consumer = CGDataConsumer(url: outputURL as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else {
            throw DragonConversionError.unsupportedConversion("Dragon could not create the converted PDF document.")
        }

        let framesetter = CTFramesetterCreateWithAttributedString(document as CFAttributedString)
        var currentLocation = 0

        repeat {
            let mediaBox = pageRect
            context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)
            context.textMatrix = .identity
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)

            let path = CGMutablePath()
            path.addRect(printableRect)

            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: currentLocation, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentLocation += visibleRange.length
            context.endPDFPage()
        } while currentLocation < document.length

        context.closePDF()
    }

    private static func runTextUtil(sourceURL: URL, format: String, outputURL: URL) throws {
        try runSynchronousProcess(
            tool: .textutil,
            arguments: ["-convert", format, sourceURL.path, "-output", outputURL.path]
        )
    }

    private static func convertPresentationWithLibreOffice(at sourceURL: URL, to format: DragonConversionFormat, outputURL: URL) throws {
        guard DragonBundledTool.libreOffice.isAvailable else {
            throw DragonConversionError.unsupportedConversion("Dragon needs a bundled office engine to export PowerPoint files as \(format.title).")
        }

        let outputDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("dragon-office-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputDirectoryURL)
        }

        try runSynchronousProcess(
            tool: .libreOffice,
            arguments: [
                "--headless",
                "--convert-to", libreOfficeFilter(for: format),
                "--outdir", outputDirectoryURL.path,
                sourceURL.path
            ]
        )

        let convertedURL = outputDirectoryURL
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(format.preferredFileExtension)

        guard FileManager.default.fileExists(atPath: convertedURL.path) else {
            throw DragonConversionError.unsupportedConversion("Dragon could not locate the converted PowerPoint file from the bundled office engine.")
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        try FileManager.default.moveItem(at: convertedURL, to: outputURL)
    }

    private static func libreOfficeFilter(for format: DragonConversionFormat) -> String {
        switch format {
        case .pdf:
            return "pdf"
        case .docx:
            return "docx:Office Open XML Text"
        case .odt:
            return "odt"
        default:
            return format.preferredFileExtension
        }
    }

    private static func afconvertArguments(for sourceURL: URL, format: DragonConversionFormat, outputURL: URL) -> [String] {
        let fileFormatCode: String

        switch format {
        case .wav:
            fileFormatCode = "WAVE"
        case .aiff:
            fileFormatCode = "AIFF"
        case .aifc:
            fileFormatCode = "AIFC"
        case .caf:
            fileFormatCode = "caff"
        case .m4a:
            fileFormatCode = "m4af"
        case .aac:
            fileFormatCode = "adts"
        case .flac:
            fileFormatCode = "flac"
        case .mp3:
            fileFormatCode = "MPG3"
        case .ogg:
            fileFormatCode = "Oggf"
        case .ac3:
            fileFormatCode = "ac-3"
        case .threeGPP:
            fileFormatCode = "3gpp"
        case .threeGPPTwo:
            fileFormatCode = "3gp2"
        default:
            fileFormatCode = "m4af"
        }

        return [sourceURL.path, "-o", outputURL.path, "-f", fileFormatCode]
    }

    private static func ffmpegAudioArguments(for sourceURL: URL, format: DragonConversionFormat, outputURL: URL) -> [String] {
        let codecArguments: [String]

        switch format {
        case .wav:
            codecArguments = ["-c:a", "pcm_s16le"]
        case .aiff:
            codecArguments = ["-c:a", "pcm_s16be"]
        case .aifc:
            codecArguments = ["-c:a", "pcm_s16be"]
        case .caf:
            codecArguments = ["-c:a", "alac"]
        case .m4a:
            codecArguments = ["-c:a", "aac", "-b:a", "192k"]
        case .aac:
            codecArguments = ["-c:a", "aac", "-b:a", "192k"]
        case .flac:
            codecArguments = ["-c:a", "flac"]
        case .ogg:
            codecArguments = ["-ac", "2", "-strict", "-2", "-c:a", "vorbis", "-q:a", "5"]
        case .ac3:
            codecArguments = ["-c:a", "ac3", "-b:a", "192k"]
        case .threeGPP, .threeGPPTwo:
            codecArguments = ["-c:a", "aac", "-b:a", "128k"]
        default:
            codecArguments = ["-c:a", "copy"]
        }

        return [
            "-y",
            "-i", sourceURL.path
        ] + codecArguments + [outputURL.path]
    }

    private static func ffmpegVideoArguments(for sourceURL: URL, format: DragonConversionFormat, outputURL: URL) -> [String] {
        let codecArguments: [String]

        switch format {
        case .mp4Video, .m4vVideo, .movVideo:
            codecArguments = ["-c:v", "mpeg4", "-c:a", "aac", "-movflags", "+faststart"]
        case .aviVideo:
            codecArguments = ["-c:v", "mpeg4", "-c:a", "mp3"]
        case .mkvVideo:
            codecArguments = ["-c:v", "mpeg4", "-c:a", "aac"]
        case .mpegVideo:
            codecArguments = ["-c:v", "mpeg2video", "-c:a", "mp2"]
        default:
            codecArguments = ["-c", "copy"]
        }

        return [
            "-y",
            "-i", sourceURL.path
        ] + codecArguments + [outputURL.path]
    }

    private static func archiveEntries(in archiveURL: URL) throws -> [String] {
        let output = try runSynchronousProcessCapturingOutput(
            tool: .unzip,
            arguments: ["-Z1", archiveURL.path]
        )

        return output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private static func archiveEntryData(in archiveURL: URL, entryPath: String) throws -> Data {
        try runSynchronousProcessCapturingData(
            tool: .unzip,
            arguments: ["-p", archiveURL.path, entryPath]
        )
    }

    private static func presentationSlideOrder(_ lhs: String, _ rhs: String) -> Bool {
        slideIndex(in: lhs) < slideIndex(in: rhs)
    }

    private static func slideIndex(in path: String) -> Int {
        let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let digits = fileName.filter(\.isNumber)
        return Int(digits) ?? 0
    }

    private static func runProcess(tool: DragonBundledTool, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            do {
                process.executableURL = try tool.resolvedExecutableURL()
                process.environment = sanitizedProcessEnvironment()
                process.arguments = arguments

                let errorPipe = Pipe()
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let detail = (errorOutput?.isEmpty == false ? errorOutput : nil) ?? "\(tool.rawValue) exited with status \(process.terminationStatus)."
                        continuation.resume(throwing: DragonConversionError.unsupportedConversion(detail))
                    }
                }

                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func runSynchronousProcess(tool: DragonBundledTool, arguments: [String]) throws {
        let process = Process()
        process.executableURL = try tool.resolvedExecutableURL()
        process.environment = sanitizedProcessEnvironment()
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = (errorOutput?.isEmpty == false ? errorOutput : nil) ?? "\(tool.rawValue) exited with status \(process.terminationStatus)."
            throw DragonConversionError.unsupportedConversion(detail)
        }
    }

    private static func runSynchronousProcessCapturingOutput(tool: DragonBundledTool, arguments: [String]) throws -> String {
        let data = try runSynchronousProcessCapturingData(tool: tool, arguments: arguments)
        return String(decoding: data, as: UTF8.self)
    }

    private static func runSynchronousProcessCapturingData(tool: DragonBundledTool, arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = try tool.resolvedExecutableURL()
        process.environment = sanitizedProcessEnvironment()
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus == 0 {
            return outputData
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = (errorOutput?.isEmpty == false ? errorOutput : nil) ?? "\(tool.rawValue) exited with status \(process.terminationStatus)."
        throw DragonConversionError.unsupportedConversion(detail)
    }

}

private func sanitizedProcessEnvironment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let blockedKeys = [
        "DYLD_INSERT_LIBRARIES",
        "__XPC_DYLD_INSERT_LIBRARIES",
        "XCODE_RUNNING_FOR_PREVIEWS"
    ]

    for key in blockedKeys {
        environment.removeValue(forKey: key)
    }

    return environment
}

private enum DragonPPTXTextExtractor {
    static func extractText(from data: Data) -> String {
        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.paragraphs.joined(separator: "\n")
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var paragraphs: [String] = []
        private var isInsideTextNode = false
        private var currentParagraph = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            switch normalizedName(for: elementName) {
            case "t":
                isInsideTextNode = true
            case "br":
                currentParagraph.append("\n")
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInsideTextNode else {
                return
            }

            currentParagraph.append(string)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch normalizedName(for: elementName) {
            case "t":
                isInsideTextNode = false
            case "p":
                let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    paragraphs.append(trimmed)
                }
                currentParagraph = ""
            default:
                break
            }
        }

        private func normalizedName(for elementName: String) -> String {
            elementName.split(separator: ":").last.map(String.init) ?? elementName
        }
    }
}

private enum DragonToolResolutionError: LocalizedError {
    case missingExecutable(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let executableName):
            return "Dragon could not find the required conversion engine \(executableName)."
        }
    }
}

private enum DragonConversionError: LocalizedError {
    case unsupportedConversion(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedConversion(let detail):
            return detail
        }
    }
}

private enum DragonCompressionError: LocalizedError {
    case noItems
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .noItems:
            return "No staged files were available."
        case .processFailed(let detail):
            return detail
        }
    }
}

private extension DragonConversionFormat {
    var isAvailableWithCurrentEngines: Bool {
        switch self {
        case .webP:
            guard let utType else {
                return false
            }
            return DragonImageDestinationSupport.supports(utType: utType)
        case .aviVideo, .mkvVideo, .mpegVideo:
            return DragonBundledTool.ffmpeg.isAvailable
        default:
            return true
        }
    }
}

private enum DragonImageDestinationSupport {
    private static let supportedTypeIdentifiers = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])

    static func supports(utType: UTType) -> Bool {
        supportedTypeIdentifiers.contains(utType.identifier)
    }
}

private struct CollapsedDragonToggle: View {
    let isDropTargeted: Bool
    let isHoveringActivationZone: Bool

    private var isActive: Bool {
        isDropTargeted || isHoveringActivationZone
    }

    var body: some View {
        DragonCollapsedNotchShape(cornerRadius: DragonNotchLayout.collapsedCornerRadius)
            .fill(Color.black.opacity(isActive ? 1 : 0.001))
            .frame(
                width: DragonNotchLayout.collapsedInnerWidth + (isActive ? DragonNotchLayout.collapsedHoverWidthIncrease : 0),
                height: DragonNotchLayout.collapsedHeight + (isActive ? DragonNotchLayout.collapsedHoverHeightIncrease : 0)
            )
    }
}

private struct DragonCollapsedNotchShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.height / 2, rect.width / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    ContentView()
}

enum DragonNotchLayout {
    static let panelHostWidth: CGFloat = 392
    static let collapsedWidth: CGFloat = 184
    static let expandedWidth: CGFloat = 392
    static let collapsedInnerWidth: CGFloat = 184
    static let expandedInnerWidth: CGFloat = 392
    static let collapsedHeight: CGFloat = 30
    static let expandedHeight: CGFloat = 405
    static let expandedSettingsHeight: CGFloat = 380
    static let maximumHostHeight: CGFloat = expandedTopPadding + expandedHeight + expandedSettingsHeight + 12
    static let collapsedTopPadding: CGFloat = 0
    static let expandedTopPadding: CGFloat = -1
    static let collapsedCornerRadius: CGFloat = 24
    static let actionTileWidth: CGFloat = 60
    static let actionTileHeight: CGFloat = 62
    static let actionTileSpacing: CGFloat = 8
    static let stagedItemsViewportHeight: CGFloat = 80
    static let stagedItemTileWidth: CGFloat = 78
    static let expandedContentWidth: CGFloat = 360
    static let collapsedHorizontalCenterOffset: CGFloat = 0
    static let collapsedHoverWidthIncrease: CGFloat = 18
    static let collapsedHoverHeightIncrease: CGFloat = 6
    static let hoverActivationInsetX: CGFloat = 40
    static let hoverActivationInsetY: CGFloat = 18
}

enum DragonAppearanceSettings {
    static let backgroundRedKey = "dragon_menu_background_red"
    static let backgroundGreenKey = "dragon_menu_background_green"
    static let backgroundBlueKey = "dragon_menu_background_blue"
    static let backgroundOpacityKey = "dragon_menu_background_opacity"
    static let fontDesignKey = "dragon_menu_font_design"
    static let enabledActionsKey = "dragon_menu_enabled_actions"
    static let entryModeKey = "dragon_menu_entry_mode"
    static let menuBarIconStyleKey = "dragon_menu_bar_icon_style"
    static let skipQuitConfirmationKey = "dragon_skip_quit_confirmation"
}

struct DragonInlineSettingsView: View {
    @AppStorage(DragonAppearanceSettings.backgroundRedKey) private var backgroundRed = 0.13
    @AppStorage(DragonAppearanceSettings.backgroundGreenKey) private var backgroundGreen = 0.16
    @AppStorage(DragonAppearanceSettings.backgroundBlueKey) private var backgroundBlue = 0.22
    @AppStorage(DragonAppearanceSettings.backgroundOpacityKey) private var backgroundOpacity = 0.78
    @AppStorage(DragonAppearanceSettings.fontDesignKey) private var fontDesignRawValue = DragonFontDesign.rounded.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            colorSlider(title: "Red", value: $backgroundRed, tint: .red)
            colorSlider(title: "Green", value: $backgroundGreen, tint: .green)
            colorSlider(title: "Blue", value: $backgroundBlue, tint: .blue)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Background opacity")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int(backgroundOpacity * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $backgroundOpacity, in: 0...1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Font style")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(DragonFontDesign.allCases) { design in
                        Button {
                            fontDesignRawValue = design.rawValue
                        } label: {
                            Text(design.title)
                                .font(design.font(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(fontDesignRawValue == design.rawValue ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(fontDesignRawValue == design.rawValue ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func colorSlider(title: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(value.wrappedValue * 255))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: 0...1)
                .tint(tint)
        }
    }
}

enum DragonFontDesign: String, CaseIterable, Identifiable {
    case rounded
    case `default`
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rounded: "Rounded"
        case .default: "Default"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        }
    }

    var swiftUIFontDesign: Font.Design {
        switch self {
        case .rounded: .rounded
        case .default: .default
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: swiftUIFontDesign)
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private struct DragonVisiblePanelHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RightClickOverlay: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickPassthroughView {
        let view = RightClickPassthroughView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickPassthroughView, context: Context) {
        nsView.onRightClick = onRightClick
    }
}

private final class RightClickPassthroughView: NSView {
    var onRightClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else {
            return nil
        }

        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp:
            return self
        default:
            return nil
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
}

extension Notification.Name {
    static let dragonShouldCollapsePanel = Notification.Name("dragonShouldCollapsePanel")
    static let dragonSetPanelExpanded = Notification.Name("dragonSetPanelExpanded")
    static let dragonTogglePanelExpanded = Notification.Name("dragonTogglePanelExpanded")
    static let dragonSetHoverActivation = Notification.Name("dragonSetHoverActivation")
    static let dragonShouldOpenSettings = Notification.Name("dragonShouldOpenSettings")
    static let dragonWillPresentImportPanel = Notification.Name("dragonWillPresentImportPanel")
    static let dragonDidDismissImportPanel = Notification.Name("dragonDidDismissImportPanel")
}
