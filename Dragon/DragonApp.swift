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
    private let panel: NSPanel
    private let panelStateBridge: PanelStateBridge
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

    override init() {
        let panelStateBridge = PanelStateBridge()
        let hostingController = NSHostingController(
            rootView: ContentView(
                onExpansionChange: panelStateBridge.handleExpansionChange,
                onSettingsExpansionChange: panelStateBridge.handleSettingsExpansionChange,
                requestArchiveDestination: panelStateBridge.handleArchiveDestinationRequest,
                requestConversionDestination: panelStateBridge.handleConversionDestinationRequest,
                requestAirDropShare: panelStateBridge.handleAirDropShareRequest,
                requestQuickShare: panelStateBridge.handleQuickShareRequest
            )
        )

        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DragonNotchLayout.panelHostWidth,
                height: DragonNotchLayout.collapsedHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.panel = panel
        self.panelStateBridge = panelStateBridge

        super.init()

        panel.contentViewController = hostingController
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

        if isExpanded {
            collapsedAnchorX = panel.frame.midX
        } else {
            isSettingsExpanded = false
        }

        self.isExpanded = isExpanded
        updatePanelVisibility()
        updatePanelLayout(animated: animated)
    }

    private func setSettingsExpanded(_ isSettingsExpanded: Bool, animated: Bool) {
        guard self.isSettingsExpanded != isSettingsExpanded else {
            return
        }

        self.isSettingsExpanded = isSettingsExpanded
        updatePanelLayout(animated: animated)
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

        let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28), pullsDown: false)
        popupButton.addItems(withTitles: formats.map(\.title))
        savePanel.accessoryView = popupButton

        let hostWindow = makeSavePanelHostWindow()
        savePanelHostWindow = hostWindow
        hostWindow.makeKeyAndOrderFront(nil)

        savePanel.beginSheetModal(for: hostWindow) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.setImportPanelPresented(false)
                self?.savePanelHostWindow?.orderOut(nil)
                self?.savePanelHostWindow = nil

                guard response == .OK else {
                    completion(nil)
                    return
                }

                let selectedFormat = formats[popupButton.indexOfSelectedItem]
                let selectedURL = savePanel.url ?? URL(fileURLWithPath: suggestedBaseName)
                let normalizedURL = selectedURL.deletingPathExtension().appendingPathExtension(selectedFormat.preferredFileExtension)
                completion(DragonConversionSelection(format: selectedFormat, outputURL: normalizedURL))
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

        if isExpanded, let collapsedAnchorX {
            anchorX = collapsedAnchorX
        } else {
            anchorX = screenFrame.midX + DragonNotchLayout.collapsedHorizontalCenterOffset
        }

        let x = anchorX - (panelFrame.width / 2)
        let topPadding = isExpanded ? DragonNotchLayout.expandedTopPadding : DragonNotchLayout.collapsedTopPadding
        let y = screenFrame.maxY - panelFrame.height - topPadding

        panel.setContentSize(contentSize)

        let newFrame = NSRect(x: x, y: y, width: panelFrame.width, height: panelFrame.height)

        let sizeMatches = panel.contentRect(forFrameRect: panel.frame).size.equalTo(contentSize)
        let frameMatches = panel.frame.equalTo(newFrame)
        guard sizeMatches == false || frameMatches == false else {
            return
        }

        isUpdatingPanelLayout = true
        defer { isUpdatingPanelLayout = false }

        panel.setFrame(newFrame, display: true)

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
            self?.handleOutsideClick()
            return event
        }
    }

    private func handleMouseLocationChange() {
        let isHoveringActivationZone = activationZone?.contains(NSEvent.mouseLocation) ?? false
        guard self.isHoveringActivationZone != isHoveringActivationZone else {
            return
        }

        self.isHoveringActivationZone = isHoveringActivationZone
        updatePanelVisibility()
    }

    private func updatePanelVisibility() {
        let shouldShowPanel = isExpanded || isHoveringActivationZone || isImportPanelPresented

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
        guard panel.frame.contains(mouseLocation) == false else {
            return
        }

        NotificationCenter.default.post(name: .dragonShouldCollapsePanel, object: nil)
    }

    private func animatePanelAlpha(to alphaValue: CGFloat) {
        guard panel.alphaValue != alphaValue else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
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

        return NSRect(x: x, y: y, width: width, height: height)
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
        if isExpanded {
            let height = DragonNotchLayout.expandedHeight + (isSettingsExpanded ? DragonNotchLayout.expandedSettingsHeight : 0)
            return NSSize(width: DragonNotchLayout.panelHostWidth, height: height)
        }

        return NSSize(width: DragonNotchLayout.panelHostWidth, height: DragonNotchLayout.collapsedHeight)
    }
}

@MainActor
private final class PanelStateBridge {
    var onExpansionChange: ((Bool) -> Void)?
    var onSettingsExpansionChange: ((Bool) -> Void)?
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
