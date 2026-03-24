//
//  ContentView.swift
//  Dragon
//
//  Created by Yoav Peretz on 24/03/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage(DragonAppearanceSettings.backgroundRedKey) private var backgroundRed = 0.13
    @AppStorage(DragonAppearanceSettings.backgroundGreenKey) private var backgroundGreen = 0.16
    @AppStorage(DragonAppearanceSettings.backgroundBlueKey) private var backgroundBlue = 0.22
    @AppStorage(DragonAppearanceSettings.backgroundOpacityKey) private var backgroundOpacity = 0.78
    @AppStorage(DragonAppearanceSettings.fontDesignKey) private var fontDesignRawValue = DragonFontDesign.rounded.rawValue

    let onExpansionChange: (Bool) -> Void
    let onSettingsExpansionChange: (Bool) -> Void
    @State private var queuedItems: [QueuedDropItem] = []
    @State private var isDropTargeted = false
    @State private var isInspectorExpanded = false
    @State private var isSettingsExpanded = false
    @State private var hoveredActionID: DragonAction.ID?

    private let primaryActions = DragonAction.primary
    private let secondaryActions = DragonAction.secondary

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
            return "No files staged yet"
        }

        return ByteCountFormatter.string(fromByteCount: totalByteCount, countStyle: .file)
    }

    init(
        onExpansionChange: @escaping (Bool) -> Void = { _ in },
        onSettingsExpansionChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.onExpansionChange = onExpansionChange
        self.onSettingsExpansionChange = onSettingsExpansionChange
    }

    private var isPanelExpanded: Bool {
        isDropTargeted || isInspectorExpanded
    }

    private var panelWidth: CGFloat {
        DragonNotchLayout.panelHostWidth
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

    private var selectedFontDesign: DragonFontDesign {
        DragonFontDesign(rawValue: fontDesignRawValue) ?? .rounded
    }

    var body: some View {
        notchPanel
            .padding(.horizontal, 0)
            .padding(.top, isPanelExpanded ? DragonNotchLayout.expandedTopPadding : DragonNotchLayout.collapsedTopPadding)
            .padding(.bottom, isPanelExpanded ? 12 : 6)
            .frame(width: panelWidth, alignment: .top)
            .background(Color.clear)
            .onAppear {
                onExpansionChange(isPanelExpanded)
                onSettingsExpansionChange(isSettingsExpanded)
            }
            .onChange(of: isPanelExpanded) { _, isExpanded in
                onExpansionChange(isExpanded)
            }
            .onChange(of: isSettingsExpanded) { _, isExpanded in
                onSettingsExpansionChange(isExpanded)
            }
            .onChange(of: isDropTargeted) { _, isTargeted in
                guard isTargeted else {
                    return
                }

                isInspectorExpanded = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .dragonShouldCollapsePanel)) { _ in
                guard isInspectorExpanded else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.18)) {
                    isInspectorExpanded = false
                    isSettingsExpanded = false
                }
            }
            .animation(.easeOut(duration: 0.16), value: isPanelExpanded)
            .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private var notchPanel: some View {
        GlassEffectContainer(spacing: 18) {
            Group {
                if isPanelExpanded {
                    expandedPanel
                        .transition(.asymmetric(
                            insertion: .offset(y: -8).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    headerBar
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(width: isPanelExpanded ? DragonNotchLayout.expandedInnerWidth : DragonNotchLayout.collapsedInnerWidth)
    }

    private var headerBar: some View {
        CollapsedDragonToggle(isDropTargeted: isDropTargeted)
        .contentShape(RoundedRectangle(cornerRadius: DragonNotchLayout.collapsedCornerRadius, style: .continuous))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.16)) {
                isInspectorExpanded.toggle()
            }
        }
        .dropDestination(for: URL.self) { items, _ in
            queue(items)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .help(isPanelExpanded ? "Collapse Dragon" : "Expand Dragon")
    }

    private var expandedPanel: some View {
        VStack(spacing: 18) {
            topBar
            actionSection(actions: primaryActions)
            actionSection(actions: secondaryActions)
            stagedItemsSection
            if isSettingsExpanded {
                inlineSettingsSection
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(width: DragonNotchLayout.expandedInnerWidth)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(menuBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Dragon")
                .font(selectedFontDesign.font(size: 18, weight: .semibold))

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isSettingsExpanded.toggle()
                }
            } label: {
                Image(systemName: isSettingsExpanded ? "slider.horizontal.3" : "gearshape.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.glass)
            .help(isSettingsExpanded ? "Hide settings" : "Open settings")

            Button("Choose Files") {
                importFiles()
            }
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.white)
        }
    }

    private var inlineSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Appearance")
                    .font(selectedFontDesign.font(size: 13, weight: .semibold))

                Spacer()

                Button("Done") {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isSettingsExpanded = false
                    }
                }
                .buttonStyle(.glass)
            }

            DragonInlineSettingsView()
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

    private func actionSection(actions: [DragonAction]) -> some View {
        HStack(spacing: DragonNotchLayout.actionTileSpacing) {
            ForEach(actions) { action in
                actionCard(action)
            }
        }
        .frame(width: DragonNotchLayout.expandedContentWidth, alignment: .center)
    }

    private func actionCard(_ action: DragonAction) -> some View {
        let isHovered = hoveredActionID == action.id

        return Button {
            isInspectorExpanded = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(action.tint.opacity(0.16))
                    )
                    .foregroundStyle(action.tint)

                Text(action.title)
                    .font(selectedFontDesign.font(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(
                minWidth: DragonNotchLayout.actionTileMinimumWidth,
                maxWidth: DragonNotchLayout.actionTileMaximumWidth,
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
    }

    private var stagedItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Staged files")
                    .font(selectedFontDesign.font(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text(byteSummary)
                    .font(selectedFontDesign.font(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: DragonNotchLayout.expandedContentWidth, alignment: .leading)

            if queuedItems.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(queuedItems) { item in
                        stagedItemRow(item)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "macbook.and.arrow.trianglehead.clockwise")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Nothing staged yet")
                .font(selectedFontDesign.font(size: 14, weight: .semibold))

        }
        .frame(width: DragonNotchLayout.expandedContentWidth)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.12))
        )
    }

    private func stagedItemRow(_ item: QueuedDropItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent)
                    .font(selectedFontDesign.font(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(item.detailText)
                    .font(selectedFontDesign.font(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                queuedItems.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .help("Remove \(item.url.lastPathComponent)")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else {
            return
        }

        queue(panel.urls)
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
}

private struct QueuedDropItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let byteCount: Int64
    let isDirectory: Bool

    init(url: URL) {
        self.url = url

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
}

private struct DragonAction: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color

    static let primary: [DragonAction] = [
        DragonAction(
            title: "Compress",
            subtitle: "Package staged files into a smaller archive.",
            symbolName: "arrow.down.right.and.arrow.up.left",
            tint: .mint
        ),
        DragonAction(
            title: "Convert",
            subtitle: "Transform files into another format.",
            symbolName: "arrow.triangle.2.circlepath",
            tint: .orange
        ),
        DragonAction(
            title: "Quick Share",
            subtitle: "Prepare a link-ready handoff flow.",
            symbolName: "link.badge.plus",
            tint: .blue
        )
    ]

    static let secondary: [DragonAction] = [
        DragonAction(
            title: "AirDrop",
            subtitle: "Route staged files into a nearby transfer flow.",
            symbolName: "airplayaudio",
            tint: .teal
        ),
        DragonAction(
            title: "Finder Tag",
            subtitle: "Organize incoming drops before filing them away.",
            symbolName: "tag.fill",
            tint: .pink
        ),
        DragonAction(
            title: "Cloud Sync",
            subtitle: "Reserve this slot for supported cloud providers.",
            symbolName: "icloud.fill",
            tint: .indigo
        )
    ]
}

private struct CollapsedDragonToggle: View {
    let isDropTargeted: Bool

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: DragonNotchLayout.collapsedInnerWidth, height: DragonNotchLayout.collapsedHeight)
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
    static let collapsedHeight: CGFloat = 34
    static let expandedHeight: CGFloat = 430
    static let expandedSettingsHeight: CGFloat = 250
    static let collapsedTopPadding: CGFloat = 0
    static let expandedTopPadding: CGFloat = 20
    static let collapsedCornerRadius: CGFloat = 12
    static let actionTileMinimumWidth: CGFloat = 70
    static let actionTileMaximumWidth: CGFloat = 72
    static let actionTileHeight: CGFloat = 90
    static let actionTileSpacing: CGFloat = 18
    static let expandedContentWidth: CGFloat = 360
    static let collapsedHorizontalCenterOffset: CGFloat = 0
}

enum DragonAppearanceSettings {
    static let backgroundRedKey = "dragon_menu_background_red"
    static let backgroundGreenKey = "dragon_menu_background_green"
    static let backgroundBlueKey = "dragon_menu_background_blue"
    static let backgroundOpacityKey = "dragon_menu_background_opacity"
    static let fontDesignKey = "dragon_menu_font_design"
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
extension Notification.Name {
    static let dragonShouldCollapsePanel = Notification.Name("dragonShouldCollapsePanel")
    static let dragonShouldOpenSettings = Notification.Name("dragonShouldOpenSettings")
}
