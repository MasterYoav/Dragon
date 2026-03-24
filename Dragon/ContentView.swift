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
    let requestArchiveDestination: (String, @escaping (URL?) -> Void) -> Void
    @State private var queuedItems: [QueuedDropItem] = []
    @State private var isDropTargeted = false
    @State private var isInspectorExpanded = false
    @State private var isSettingsExpanded = false
    @State private var hoveredActionID: DragonAction.ID?
    @State private var actionStatus: DragonActionStatus?
    @State private var isPerformingAction = false

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
        onSettingsExpansionChange: @escaping (Bool) -> Void = { _ in },
        requestArchiveDestination: @escaping (String, @escaping (URL?) -> Void) -> Void = { _, completion in completion(nil) }
    ) {
        self.onExpansionChange = onExpansionChange
        self.onSettingsExpansionChange = onSettingsExpansionChange
        self.requestArchiveDestination = requestArchiveDestination
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
        .dropDestination(for: URL.self) { items, _ in
            queue(items)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
    }

    private var headerBar: some View {
        CollapsedDragonToggle(isDropTargeted: isDropTargeted)
        .contentShape(RoundedRectangle(cornerRadius: DragonNotchLayout.collapsedCornerRadius, style: .continuous))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.16)) {
                isInspectorExpanded.toggle()
            }
        }
        .help(isPanelExpanded ? "Collapse Dragon" : "Expand Dragon")
    }

    private var expandedPanel: some View {
        VStack(spacing: 18) {
            topBar
            if let actionStatus {
                actionStatusView(actionStatus)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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
            perform(action)
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
        VStack(alignment: .leading, spacing: 10) {
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
            Image(systemName: "tray.and.arrow.down.fill")
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
        NotificationCenter.default.post(name: .dragonWillPresentImportPanel, object: nil)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        let response = panel.runModal()
        NotificationCenter.default.post(name: .dragonDidDismissImportPanel, object: nil)

        guard response == .OK else {
            return
        }

        queue(panel.urls)
        isInspectorExpanded = true
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
        case .convert, .quickShare, .airDrop, .finderTag, .cloudSync:
            actionStatus = .info(
                title: "\(action.title) is next",
                detail: "This action is still a placeholder. Compress is the first live workflow."
            )
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
            return false
        }
    }

    private var canConvertQueuedItems: Bool {
        guard queuedItems.isEmpty == false else {
            return false
        }

        return queuedItems.allSatisfy(\.isConvertible)
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
        guard isDirectory == false else {
            return false
        }

        let supportedExtensions: Set<String> = [
            "png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp",
            "mp4", "mov", "m4v",
            "wav", "aif", "aiff", "m4a", "mp3",
            "txt", "rtf", "html", "md", "pdf"
        ]

        return supportedExtensions.contains(url.pathExtension.lowercased())
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
            title: "Quick Share",
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
            title: "Finder Tag",
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

private enum DragonActionKind: String, Hashable {
    case compress
    case convert
    case quickShare
    case airDrop
    case finderTag
    case cloudSync
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
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
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

            do {
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
    static let dragonWillPresentImportPanel = Notification.Name("dragonWillPresentImportPanel")
    static let dragonDidDismissImportPanel = Notification.Name("dragonDidDismissImportPanel")
}
