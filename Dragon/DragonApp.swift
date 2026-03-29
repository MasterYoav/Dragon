//
//  DragonApp.swift
//  Dragon
//
//  Created by Yoav Peretz on 24/03/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct DragonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchPanelController()
        controller.show()
        notchPanelController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        notchPanelController?.reposition()
    }
}

@MainActor
private final class NotchPanelController: NSObject {
    private static let panelAnimationDuration: TimeInterval = 0.22
    private let panel: DragonPanel
    private let panelStateBridge: PanelStateBridge
    private let panelContentView: PassthroughPanelContentView
    private var entryMode: DragonEntryMode
    private var menuBarIconStyle: DragonMenuBarIconStyle
    private var visiblePanelHeight: CGFloat = 0
    private var isExpanded = false
    private var isSettingsExpanded = false
    private var isImportPanelPresented = false
    private var isHoveringActivationZone = false
    private var collapsedAnchorX: CGFloat?
    private var isUpdatingPanelLayout = false
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var importPanelWillPresentObserver: NSObjectProtocol?
    private var importPanelDidDismissObserver: NSObjectProtocol?
    private var savePanelHostWindow: NSWindow?
    private var sharingCoordinator: SharingCoordinator?
    private var panelLevelBeforeShare: NSWindow.Level?
    private var finderTagSheetController: FinderTagSheetController?
    private var conversionSaveAccessoryController: ConversionSaveAccessoryController?
    private var statusItem: NSStatusItem?
    private var pendingPanelLayoutUpdate: DispatchWorkItem?

    override init() {
        let storedEntryMode = DragonEntryMode(
            rawValue: UserDefaults.standard.string(forKey: DragonAppearanceSettings.entryModeKey) ?? DragonEntryMode.notch.rawValue
        ) ?? .notch
        let storedMenuBarIconStyle = DragonMenuBarIconStyle(
            rawValue: UserDefaults.standard.string(forKey: DragonAppearanceSettings.menuBarIconStyleKey) ?? DragonMenuBarIconStyle.color.rawValue
        ) ?? .color
        let panelStateBridge = PanelStateBridge()
        let hostingView = NSHostingView(
            rootView: ContentView(
                onExpansionChange: panelStateBridge.handleExpansionChange,
                onSettingsExpansionChange: panelStateBridge.handleSettingsExpansionChange,
                onEntryModeChange: panelStateBridge.handleEntryModeChange,
                onMenuBarIconStyleChange: panelStateBridge.handleMenuBarIconStyleChange,
                onVisiblePanelHeightChange: panelStateBridge.handleVisiblePanelHeightChange,
                requestFileImport: panelStateBridge.handleFileImportRequest,
                requestCloudSyncFolder: panelStateBridge.handleCloudSyncFolderRequest,
                requestFinderTagSelection: panelStateBridge.handleFinderTagSelectionRequest,
                requestArchiveDestination: panelStateBridge.handleArchiveDestinationRequest,
                requestConversionDestination: panelStateBridge.handleConversionDestinationRequest,
                requestAirDropShare: panelStateBridge.handleAirDropShareRequest,
                requestQuickShare: panelStateBridge.handleQuickShareRequest
            )
        )
        let panelContentView = PassthroughPanelContentView()
        panelContentView.hostedView = hostingView

        let panel = DragonPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DragonNotchLayout.panelHostWidth,
                height: DragonNotchLayout.maximumHostHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.panel = panel
        self.panelStateBridge = panelStateBridge
        self.panelContentView = panelContentView
        self.entryMode = storedEntryMode
        self.menuBarIconStyle = storedMenuBarIconStyle

        super.init()

        panel.contentView = panelContentView
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panelStateBridge.onExpansionChange = { [weak self] isExpanded in
            self?.setExpanded(isExpanded, animated: true)
        }

        panelStateBridge.onSettingsExpansionChange = { [weak self] isSettingsExpanded in
            self?.setSettingsExpanded(isSettingsExpanded, animated: true)
        }

        panelStateBridge.onEntryModeChange = { [weak self] entryMode in
            self?.setEntryMode(entryMode)
        }

        panelStateBridge.onMenuBarIconStyleChange = { [weak self] iconStyle in
            self?.setMenuBarIconStyle(iconStyle)
        }

        panelStateBridge.onVisiblePanelHeightChange = { [weak self] height in
            self?.setVisiblePanelHeight(height)
        }

        panelStateBridge.onFileImportRequest = { [weak self] completion in
            self?.requestFileImport(completion: completion)
        }

        panelStateBridge.onCloudSyncFolderRequest = { [weak self] completion in
            self?.requestCloudSyncFolder(completion: completion)
        }

        panelStateBridge.onFinderTagSelectionRequest = { [weak self] completion in
            self?.requestFinderTagSelection(completion: completion)
        }

        panelStateBridge.onArchiveDestinationRequest = { [weak self] suggestedFileName, completion in
            self?.requestArchiveDestination(suggestedFileName: suggestedFileName, completion: completion)
        }

        panelStateBridge.onConversionDestinationRequest = { [weak self] suggestedBaseName, formats, completion in
            self?.requestConversionDestination(suggestedBaseName: suggestedBaseName, formats: formats, completion: completion)
        }

        panelStateBridge.onAirDropShareRequest = { [weak self] urls, completion in
            self?.requestAirDropShare(urls: urls, completion: completion)
        }

        panelStateBridge.onQuickShareRequest = { [weak self] urls, completion in
            self?.requestQuickShare(urls: urls, completion: completion)
        }

        importPanelWillPresentObserver = NotificationCenter.default.addObserver(
            forName: .dragonWillPresentImportPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(true)
            }
        }

        importPanelDidDismissObserver = NotificationCenter.default.addObserver(
            forName: .dragonDidDismissImportPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
            }
        }

        installMouseMonitors()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }

        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
        }

        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
        }

        if let importPanelWillPresentObserver {
            NotificationCenter.default.removeObserver(importPanelWillPresentObserver)
        }

        if let importPanelDidDismissObserver {
            NotificationCenter.default.removeObserver(importPanelDidDismissObserver)
        }
    }

    func show() {
        configureEntryModeUI()
        updateInteractiveRegion()
        updatePanelLayout(animated: false)
        panel.orderFrontRegardless()
        updatePanelVisibility()
    }

    func reposition() {
        updatePanelLayout(animated: false)
    }

    private func setExpanded(_ isExpanded: Bool, animated: Bool) {
        guard self.isExpanded != isExpanded else {
            return
        }

        pendingPanelLayoutUpdate?.cancel()
        pendingPanelLayoutUpdate = nil

        if isExpanded {
            switch entryMode {
            case .notch:
                collapsedAnchorX = panel.frame.midX
            case .menuBar:
                collapsedAnchorX = menuBarAnchorFrame?.midX
            }
        } else {
            isSettingsExpanded = false
        }

        self.isExpanded = isExpanded
        updateInteractiveRegion()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.updatePanelVisibility()

            if isExpanded {
                let shouldAnimateFrame = animated && self.entryMode == .menuBar
                self.updatePanelLayout(animated: shouldAnimateFrame)
            } else if animated {
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else {
                        return
                    }

                    self.updatePanelLayout(animated: false)
                    self.pendingPanelLayoutUpdate = nil
                }
                self.pendingPanelLayoutUpdate = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.panelAnimationDuration, execute: workItem)
            } else {
                self.updatePanelLayout(animated: false)
            }

            if isExpanded {
                self.panel.orderFrontRegardless()
            }
        }
    }

    private func setSettingsExpanded(_ isSettingsExpanded: Bool, animated: Bool) {
        guard self.isSettingsExpanded != isSettingsExpanded else {
            return
        }

        self.isSettingsExpanded = isSettingsExpanded
        updateInteractiveRegion()
        DispatchQueue.main.async { [weak self] in
            self?.updatePanelLayout(animated: animated)
        }
    }

    private func setImportPanelPresented(_ isImportPanelPresented: Bool) {
        self.isImportPanelPresented = isImportPanelPresented

        if isImportPanelPresented {
            updatePanelVisibility()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updatePanelVisibility()
            }
        }
    }

    private func setEntryMode(_ entryMode: DragonEntryMode) {
        guard self.entryMode != entryMode else {
            return
        }

        let previousEntryMode = self.entryMode
        self.entryMode = entryMode
        if entryMode == .menuBar {
            isHoveringActivationZone = false
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.configureEntryModeUI(previousEntryMode: previousEntryMode)
            self.updatePanelVisibility()
            self.updateInteractiveRegion()
            self.updatePanelLayout(animated: false)
        }
    }

    private func setMenuBarIconStyle(_ iconStyle: DragonMenuBarIconStyle) {
        guard menuBarIconStyle != iconStyle else {
            return
        }

        menuBarIconStyle = iconStyle
        refreshStatusItemImage()
    }

    private func setVisiblePanelHeight(_ height: CGFloat) {
        let sanitizedHeight = max(height, currentPanelContentHeight)
        guard abs(visiblePanelHeight - sanitizedHeight) > 0.5 else {
            return
        }

        visiblePanelHeight = sanitizedHeight
        updateInteractiveRegion()
    }

    private func requestArchiveDestination(suggestedFileName: String, completion: @escaping (URL?) -> Void) {
        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldLabel = "Archive Name:"
        savePanel.nameFieldStringValue = suggestedFileName
        savePanel.allowedContentTypes = [.zip]
        savePanel.title = "Save Archive"
        savePanel.message = "Choose where Dragon should save the compressed archive."
        let hostWindow = makeSavePanelHostWindow()
        savePanelHostWindow = hostWindow
        hostWindow.makeKeyAndOrderFront(nil)

        savePanel.beginSheetModal(for: hostWindow) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.savePanelHostWindow?.orderOut(nil)
                self?.savePanelHostWindow = nil
                completion(response == .OK ? savePanel.url : nil)
            }
        }
    }

    private func requestCloudSyncFolder(completion: @escaping (URL?) -> Void) {
        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = "Choose Folder"
        openPanel.title = "Choose Cloud Folder"
        openPanel.message = "Choose a synced folder, such as iCloud Drive, Dropbox, or Google Drive."

        let iCloudDriveURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if FileManager.default.fileExists(atPath: iCloudDriveURL.path) {
            openPanel.directoryURL = iCloudDriveURL
        }

        let hostWindow = makeSavePanelHostWindow()
        savePanelHostWindow = hostWindow
        hostWindow.makeKeyAndOrderFront(nil)

        openPanel.beginSheetModal(for: hostWindow) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.savePanelHostWindow?.orderOut(nil)
                self?.savePanelHostWindow = nil
                completion(response == .OK ? openPanel.url : nil)
            }
        }
    }

    private func requestFileImport(completion: @escaping ([URL]) -> Void) {
        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.item]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.title = "Choose Files"
        openPanel.message = "Select files or folders to stage in Dragon."

        let hostWindow = makeSavePanelHostWindow()
        savePanelHostWindow = hostWindow
        hostWindow.makeKeyAndOrderFront(nil)

        openPanel.beginSheetModal(for: hostWindow) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.savePanelHostWindow?.orderOut(nil)
                self?.savePanelHostWindow = nil
                completion(response == .OK ? openPanel.urls : [])
            }
        }
    }

    private func requestFinderTagSelection(completion: @escaping (DragonFinderTagSelection?) -> Void) {
        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)

        let hostWindow = makeSavePanelHostWindow()
        savePanelHostWindow = hostWindow
        hostWindow.makeKeyAndOrderFront(nil)

        let controller = FinderTagSheetController(initialName: "Dragon") { [weak self] selection in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.savePanelHostWindow?.orderOut(nil)
                self?.savePanelHostWindow = nil
                self?.finderTagSheetController = nil
                completion(selection)
            }
        }
        finderTagSheetController = controller
        controller.beginSheet(for: hostWindow)
    }

    private func requestConversionDestination(
        suggestedBaseName: String,
        formats: [DragonConversionFormat],
        completion: @escaping (DragonConversionSelection?) -> Void
    ) {
        guard let initialFormat = formats.first else {
            completion(nil)
            return
        }

        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldLabel = "Converted File:"
        savePanel.nameFieldStringValue = "\(suggestedBaseName).\(initialFormat.preferredFileExtension)"
        savePanel.title = "Convert File"
        savePanel.message = "Choose the output format and where Dragon should save the converted file."
        savePanel.allowedContentTypes = [initialFormat.utType].compactMap { $0 }

        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28), pullsDown: false)
        popupButton.addItems(withTitles: formats.map(\.title))
        let accessoryController = ConversionSaveAccessoryController(
            savePanel: savePanel,
            popupButton: popupButton,
            suggestedBaseName: suggestedBaseName,
            formats: formats
        )
        conversionSaveAccessoryController = accessoryController
        popupButton.target = accessoryController
        popupButton.action = #selector(ConversionSaveAccessoryController.selectionDidChange(_:))
        savePanel.accessoryView = popupButton

        let hostWindow = makeSavePanelHostWindow()
        savePanelHostWindow = hostWindow
        hostWindow.makeKeyAndOrderFront(nil)

        savePanel.beginSheetModal(for: hostWindow) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.savePanelHostWindow?.orderOut(nil)
                self?.savePanelHostWindow = nil
                self?.conversionSaveAccessoryController = nil

                guard response == .OK else {
                    completion(nil)
                    return
                }

                let selectedFormat = formats[popupButton.indexOfSelectedItem]
                let selectedURL = savePanel.url ?? URL(fileURLWithPath: suggestedBaseName)
                completion(DragonConversionSelection(format: selectedFormat, outputURL: selectedURL))
            }
        }
    }

    private func requestAirDropShare(urls: [URL], completion: @escaping (Result<String, Error>) -> Void) {
        guard urls.isEmpty == false else {
            completion(.failure(PanelShareError.unavailable("Stage one or more files before sharing.")))
            return
        }

        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            completion(.failure(PanelShareError.unavailable("AirDrop is unavailable for the staged files on this Mac.")))
            return
        }

        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)
        preparePanelForShare()

        let coordinator = SharingCoordinator(mode: .airDrop) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.restorePanelAfterShare()
                self?.sharingCoordinator = nil
                completion(result)
            }
        }

        sharingCoordinator = coordinator
        service.delegate = coordinator
        service.perform(withItems: urls)
    }

    private func requestQuickShare(urls: [URL], completion: @escaping (Result<String, Error>) -> Void) {
        guard urls.isEmpty == false else {
            completion(.failure(PanelShareError.unavailable("Stage one or more files before sharing.")))
            return
        }

        guard let contentView = panel.contentView else {
            completion(.failure(PanelShareError.unavailable("Dragon could not present the share sheet.")))
            return
        }

        setImportPanelPresented(true)
        NSApp.activate(ignoringOtherApps: true)
        preparePanelForShare()

        let coordinator = SharingCoordinator(mode: .quickShare) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.restorePanelAfterShare()
                self?.sharingCoordinator = nil
                completion(result)
            }
        }

        sharingCoordinator = coordinator

        let picker = NSSharingServicePicker(items: urls)
        picker.delegate = coordinator

        let anchorRect = NSRect(
            x: (contentView.bounds.width / 2) - 1,
            y: contentView.bounds.height - 8,
            width: 2,
            height: 2
        )
        picker.show(relativeTo: anchorRect, of: contentView, preferredEdge: .maxY)
    }

    private func preparePanelForShare() {
        guard panelLevelBeforeShare == nil else {
            return
        }

        panelLevelBeforeShare = panel.level
        panel.level = .floating
        panel.orderBack(nil)
    }

    private func restorePanelAfterShare() {
        guard let panelLevelBeforeShare else {
            return
        }

        panel.level = panelLevelBeforeShare
        self.panelLevelBeforeShare = nil
        panel.orderFrontRegardless()
        updatePanelVisibility()
    }

    private func makeSavePanelHostWindow() -> NSWindow {
        if let savePanelHostWindow {
            return savePanelHostWindow
        }

        let screenFrame = activeScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let window = NSWindow(
            contentRect: NSRect(
                x: screenFrame.midX - 1,
                y: screenFrame.midY - 1,
                width: 2,
                height: 2
            ),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.alphaValue = 0
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        return window
    }

    private func updatePanelLayout(animated: Bool) {
        guard let screen = activeScreen else {
            return
        }

        guard isUpdatingPanelLayout == false else {
            return
        }

        let contentSize = currentContentSize
        let panelFrame = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        let screenFrame = screen.frame
        let anchorX: CGFloat

        if entryMode == .menuBar, let menuBarAnchorFrame {
            collapsedAnchorX = menuBarAnchorFrame.midX
            anchorX = menuBarAnchorFrame.midX
        } else if isExpanded, let collapsedAnchorX {
            anchorX = collapsedAnchorX
        } else {
            anchorX = screenFrame.midX + DragonNotchLayout.collapsedHorizontalCenterOffset
        }

        let x = anchorX - (panelFrame.width / 2)
        let y: CGFloat

        if entryMode == .menuBar {
            y = screenFrame.maxY - panelFrame.height - 33
        } else {
            y = screenFrame.maxY - panelFrame.height
        }

        panel.setContentSize(contentSize)

        let newFrame = NSRect(x: x, y: y, width: panelFrame.width, height: panelFrame.height)

        let sizeMatches = panel.contentRect(forFrameRect: panel.frame).size.equalTo(contentSize)
        let frameMatches = panel.frame.equalTo(newFrame)
        guard sizeMatches == false || frameMatches == false else {
            return
        }

        isUpdatingPanelLayout = true
        defer { isUpdatingPanelLayout = false }

        panel.setFrame(newFrame, display: true, animate: animated && panel.isVisible)

        if isExpanded == false {
            collapsedAnchorX = panel.frame.midX
        }
    }

    private func installMouseMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseLocationChange()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseLocationChange()
            return event
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.handleOutsideClick()
            }
        }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            if event.window === self?.panel {
                return event
            }

            self?.handleOutsideClick()
            return event
        }
    }

    private func screenLocation(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }

        return NSEvent.mouseLocation
    }

    private func handleMouseLocationChange() {
        guard entryMode == .notch else {
            if isHoveringActivationZone {
                isHoveringActivationZone = false
                NotificationCenter.default.post(name: .dragonSetHoverActivation, object: false)
                updatePanelVisibility()
            }
            return
        }

        let isHoveringActivationZone = activationZone?.contains(NSEvent.mouseLocation) ?? false
        guard self.isHoveringActivationZone != isHoveringActivationZone else {
            return
        }

        self.isHoveringActivationZone = isHoveringActivationZone
        NotificationCenter.default.post(name: .dragonSetHoverActivation, object: isHoveringActivationZone)
        updatePanelVisibility()
    }

    private func updatePanelVisibility() {
        let shouldShowPanel: Bool
        switch entryMode {
        case .notch:
            shouldShowPanel = isExpanded || isHoveringActivationZone || isImportPanelPresented
        case .menuBar:
            shouldShowPanel = isExpanded || isImportPanelPresented
        }

        if shouldShowPanel {
            updatePanelLayout(animated: false)
            animatePanelAlpha(to: 1)
            panel.ignoresMouseEvents = false
        } else {
            animatePanelAlpha(to: 0)
            panel.ignoresMouseEvents = true
        }
    }

    private func handleOutsideClick() {
        guard isExpanded, isImportPanelPresented == false else {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        if entryMode == .menuBar, let menuBarAnchorFrame, menuBarAnchorFrame.contains(mouseLocation) {
            return
        }

        if panel.frame.contains(mouseLocation) {
            let windowPoint = panel.convertPoint(fromScreen: mouseLocation)
            let localPoint = panelContentView.convert(windowPoint, from: nil)
            if panelContentView.hitTest(localPoint) != nil || panelContentView.visibleContentRect.contains(localPoint) {
                return
            }
        }

        NotificationCenter.default.post(name: .dragonShouldCollapsePanel, object: nil)
    }

    private func animatePanelAlpha(to alphaValue: CGFloat) {
        guard panel.alphaValue != alphaValue else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.panelAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = alphaValue
        }
    }

    private var activationZone: NSRect? {
        guard let screen = activeScreen else {
            return nil
        }

        let screenFrame = screen.frame
        let width = DragonNotchLayout.collapsedWidth
        let height = DragonNotchLayout.collapsedHeight
        let anchorX = collapsedAnchorX ?? (screenFrame.midX + DragonNotchLayout.collapsedHorizontalCenterOffset)
        let x = anchorX - (width / 2)
        let y = screenFrame.maxY - height
        let zone = NSRect(x: x, y: y, width: width, height: height)
        return zone.insetBy(dx: -DragonNotchLayout.hoverActivationInsetX, dy: -DragonNotchLayout.hoverActivationInsetY)
    }

    private var activeScreen: NSScreen? {
        if let screen = NSApp.keyWindow?.screen {
            return screen
        }

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            return screen
        }

        return NSScreen.main
    }

    private var currentContentSize: NSSize {
        let height: CGFloat
        if entryMode == .notch {
            height = DragonNotchLayout.maximumHostHeight
        } else {
            height = reservedPanelContentHeight
        }

        return NSSize(
            width: DragonNotchLayout.panelHostWidth,
            height: height
        )
    }

    private var currentPanelContentHeight: CGFloat {
        if isExpanded {
            return max(
                0,
                DragonNotchLayout.expandedTopPadding
                + DragonNotchLayout.expandedHeight
                + (isSettingsExpanded ? DragonNotchLayout.expandedSettingsHeight : 0)
            )
        }

        return DragonNotchLayout.collapsedTopPadding + DragonNotchLayout.collapsedHeight
    }

    private var reservedPanelContentHeight: CGFloat {
        guard isExpanded else {
            return currentPanelContentHeight
        }

        return max(
            0,
            DragonNotchLayout.expandedTopPadding
            + DragonNotchLayout.expandedHeight
            + DragonNotchLayout.expandedSettingsHeight
        )
    }

    private var interactiveContentHeight: CGFloat {
        max(visiblePanelHeight, currentPanelContentHeight)
    }

    private func updateInteractiveRegion() {
        panelContentView.interactiveHeight = interactiveContentHeight
    }

    private func configureEntryModeUI(previousEntryMode: DragonEntryMode? = nil) {
        switch entryMode {
        case .notch:
            hideStatusItem()
        case .menuBar:
            installStatusItemIfNeeded()
            statusItem?.isVisible = true
        }
    }

    private func installStatusItemIfNeeded() {
        if let statusItem {
            statusItem.length = NSStatusItem.squareLength
            refreshStatusItemImage()
            statusItem.button?.target = self
            statusItem.button?.action = #selector(handleStatusItemPress)
            return
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = menuBarLogoImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Dragon"
            button.target = self
            button.action = #selector(handleStatusItemPress)
            button.sendAction(on: [.leftMouseUp])
        }
        self.statusItem = statusItem
        refreshStatusItemImage()
    }

    private func hideStatusItem() {
        guard let statusItem else {
            return
        }

        statusItem.button?.image = nil
        statusItem.button?.target = nil
        statusItem.button?.action = nil
        statusItem.length = 0
    }

    private func menuBarLogoImage() -> NSImage? {
        guard let image = NSImage(named: menuBarIconStyle.assetName) else {
            return nil
        }

        let size = NSSize(width: 22, height: 22)
        image.size = size
        image.isTemplate = false
        return image
    }

    @objc
    private func handleStatusItemPress() {
        NSApp.activate(ignoringOtherApps: true)
        toggleMenuBarPresentation()
    }

    private func toggleMenuBarPresentation() {
        NotificationCenter.default.post(name: .dragonTogglePanelExpanded, object: nil)
    }

    private func refreshStatusItemImage() {
        statusItem?.button?.image = menuBarLogoImage()
    }

    private var menuBarAnchorFrame: NSRect? {
        guard
            let button = statusItem?.button,
            let window = button.window
        else {
            return nil
        }

        return window.convertToScreen(button.frame)
    }
}

private final class DragonPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class PassthroughPanelContentView: NSView {
    var interactiveHeight: CGFloat = 0

    var hostedView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()

            guard let hostedView else {
                return
            }

            hostedView.frame = bounds
            hostedView.autoresizingMask = [.width, .height]
            addSubview(hostedView)
        }
    }

    var visibleContentRect: NSRect {
        let height = min(max(interactiveHeight, 0), bounds.height)
        return NSRect(
            x: 0,
            y: bounds.height - height,
            width: bounds.width,
            height: height
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard visibleContentRect.contains(point) else {
            return nil
        }

        return super.hitTest(point)
    }
}

@MainActor
private final class PanelStateBridge {
    var onExpansionChange: ((Bool) -> Void)?
    var onSettingsExpansionChange: ((Bool) -> Void)?
    var onEntryModeChange: ((DragonEntryMode) -> Void)?
    var onMenuBarIconStyleChange: ((DragonMenuBarIconStyle) -> Void)?
    var onVisiblePanelHeightChange: ((CGFloat) -> Void)?
    var onFileImportRequest: ((@escaping ([URL]) -> Void) -> Void)?
    var onCloudSyncFolderRequest: ((@escaping (URL?) -> Void) -> Void)?
    var onFinderTagSelectionRequest: ((@escaping (DragonFinderTagSelection?) -> Void) -> Void)?
    var onArchiveDestinationRequest: ((String, @escaping (URL?) -> Void) -> Void)?
    var onConversionDestinationRequest: ((String, [DragonConversionFormat], @escaping (DragonConversionSelection?) -> Void) -> Void)?
    var onAirDropShareRequest: (([URL], @escaping (Result<String, Error>) -> Void) -> Void)?
    var onQuickShareRequest: (([URL], @escaping (Result<String, Error>) -> Void) -> Void)?

    func handleExpansionChange(_ isExpanded: Bool) {
        onExpansionChange?(isExpanded)
    }

    func handleSettingsExpansionChange(_ isSettingsExpanded: Bool) {
        onSettingsExpansionChange?(isSettingsExpanded)
    }

    func handleEntryModeChange(_ entryMode: DragonEntryMode) {
        onEntryModeChange?(entryMode)
    }

    func handleMenuBarIconStyleChange(_ iconStyle: DragonMenuBarIconStyle) {
        onMenuBarIconStyleChange?(iconStyle)
    }

    func handleVisiblePanelHeightChange(_ height: CGFloat) {
        onVisiblePanelHeightChange?(height)
    }

    func handleFileImportRequest(_ completion: @escaping ([URL]) -> Void) {
        onFileImportRequest?(completion)
    }

    func handleCloudSyncFolderRequest(_ completion: @escaping (URL?) -> Void) {
        onCloudSyncFolderRequest?(completion)
    }

    func handleFinderTagSelectionRequest(_ completion: @escaping (DragonFinderTagSelection?) -> Void) {
        onFinderTagSelectionRequest?(completion)
    }

    func handleArchiveDestinationRequest(_ suggestedFileName: String, completion: @escaping (URL?) -> Void) {
        onArchiveDestinationRequest?(suggestedFileName, completion)
    }

    func handleConversionDestinationRequest(
        _ suggestedBaseName: String,
        _ formats: [DragonConversionFormat],
        _ completion: @escaping (DragonConversionSelection?) -> Void
    ) {
        onConversionDestinationRequest?(suggestedBaseName, formats, completion)
    }

    func handleAirDropShareRequest(_ urls: [URL], _ completion: @escaping (Result<String, Error>) -> Void) {
        onAirDropShareRequest?(urls, completion)
    }

    func handleQuickShareRequest(_ urls: [URL], _ completion: @escaping (Result<String, Error>) -> Void) {
        onQuickShareRequest?(urls, completion)
    }
}

@MainActor
private final class FinderTagSheetController: NSWindowController {
    private let completion: (DragonFinderTagSelection?) -> Void
    private let nameField = NSTextField(string: "")
    private let colorPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    init(initialName: String, completion: @escaping (DragonFinderTagSelection?) -> Void) {
        self.completion = completion

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "Finder Tag"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

        nameField.stringValue = initialName
        colorPopup.removeAllItems()
        DragonFinderLabelColorOption.allCases.forEach { option in
            colorPopup.addItem(withTitle: option.title)
        }
        colorPopup.selectItem(at: 0)

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "Choose Finder Tag")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let bodyLabel = NSTextField(wrappingLabelWithString: "Dragon will apply the selected Finder tag to all staged files.")
        bodyLabel.textColor = .secondaryLabelColor

        let nameLabel = NSTextField(labelWithString: "Tag name")
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)

        let colorLabel = NSTextField(labelWithString: "Tag color")
        colorLabel.font = .systemFont(ofSize: 12, weight: .medium)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSelection))
        let applyButton = NSButton(title: "Apply Tag", target: self, action: #selector(applySelection))
        applyButton.keyEquivalent = "\r"

        let buttonStack = NSStackView(views: [cancelButton, applyButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12

        let stack = NSStackView(views: [titleLabel, bodyLabel, nameLabel, nameField, colorLabel, colorPopup, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            colorPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginSheet(for parentWindow: NSWindow) {
        guard let window else {
            completion(nil)
            return
        }

        parentWindow.beginSheet(window)
        window.makeFirstResponder(nameField)
    }

    @objc
    private func applySelection() {
        closeSheet(
            with: DragonFinderTagSelection(
                name: nameField.stringValue,
                labelNumber: DragonFinderLabelColorOption.allCases[safe: colorPopup.indexOfSelectedItem]?.labelNumber
            )
        )
    }

    @objc
    private func cancelSelection() {
        closeSheet(with: nil)
    }

    private func closeSheet(with selection: DragonFinderTagSelection?) {
        guard let window, let parentWindow = window.sheetParent else {
            completion(selection)
            return
        }

        parentWindow.endSheet(window)
        window.orderOut(nil)
        completion(selection)
    }
}

@MainActor
private final class ConversionSaveAccessoryController: NSObject {
    private weak var savePanel: NSSavePanel?
    private weak var popupButton: NSPopUpButton?
    private let suggestedBaseName: String
    private let formats: [DragonConversionFormat]

    init(
        savePanel: NSSavePanel,
        popupButton: NSPopUpButton,
        suggestedBaseName: String,
        formats: [DragonConversionFormat]
    ) {
        self.savePanel = savePanel
        self.popupButton = popupButton
        self.suggestedBaseName = suggestedBaseName
        self.formats = formats
    }

    @objc
    func selectionDidChange(_ sender: NSPopUpButton) {
        guard formats.indices.contains(sender.indexOfSelectedItem), let savePanel else {
            return
        }

        let selectedFormat = formats[sender.indexOfSelectedItem]
        savePanel.allowedContentTypes = [selectedFormat.utType].compactMap { $0 }
        savePanel.nameFieldStringValue = "\(suggestedBaseName).\(selectedFormat.preferredFileExtension)"
    }
}

@MainActor
private final class SharingCoordinator: NSObject, NSSharingServiceDelegate, NSSharingServicePickerDelegate {
    private let mode: SharingMode
    private let completion: (Result<String, Error>) -> Void
    private var didFinish = false

    init(mode: SharingMode, completion: @escaping (Result<String, Error>) -> Void) {
        self.mode = mode
        self.completion = completion
    }

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        sharingServicesForItems items: [Any],
        proposedSharingServices proposedServices: [NSSharingService]
    ) -> [NSSharingService] {
        proposedServices
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        self
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        guard service != nil else {
            finish(.success("Share sheet dismissed."))
            return
        }
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        let detail: String
        switch mode {
        case .airDrop:
            detail = "AirDrop opened for the staged files."
        case .quickShare:
            detail = "Share completed through \(sharingService.title)."
        }
        finish(.success(detail))
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<String, Error>) {
        guard didFinish == false else {
            return
        }

        didFinish = true
        completion(result)
    }
}

private enum SharingMode {
    case airDrop
    case quickShare
}

private enum PanelShareError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            return detail
        }
    }
}

private enum DragonFinderLabelColorOption: CaseIterable {
    case none
    case gray
    case green
    case purple
    case blue
    case yellow
    case red
    case orange

    var title: String {
        switch self {
        case .none:
            return "None"
        case .gray:
            return "Gray"
        case .green:
            return "Green"
        case .purple:
            return "Purple"
        case .blue:
            return "Blue"
        case .yellow:
            return "Yellow"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        }
    }

    // Finder label numbers map to the standard macOS tag color order.
    var labelNumber: Int? {
        switch self {
        case .none:
            return nil
        case .gray:
            return 1
        case .green:
            return 2
        case .purple:
            return 3
        case .blue:
            return 4
        case .yellow:
            return 5
        case .red:
            return 6
        case .orange:
            return 7
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
