//
//  DragonApp.swift
//  Dragon
//
//  Created by Yoav Peretz on 24/03/2026.
//

import AppKit
import SwiftUI

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
    private var isHoveringActivationZone = false
    private var collapsedAnchorX: CGFloat?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?

    override init() {
        let panelStateBridge = PanelStateBridge()
        let hostingController = NSHostingController(
            rootView: ContentView(
                onExpansionChange: panelStateBridge.handleExpansionChange,
                onSettingsExpansionChange: panelStateBridge.handleSettingsExpansionChange
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

    private func updatePanelLayout(animated: Bool) {
        guard let screen = activeScreen else {
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

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }

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
        let shouldShowPanel = isExpanded || isHoveringActivationZone

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
        guard isExpanded else {
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

    func handleExpansionChange(_ isExpanded: Bool) {
        onExpansionChange?(isExpanded)
    }

    func handleSettingsExpansionChange(_ isSettingsExpanded: Bool) {
        onSettingsExpansionChange?(isSettingsExpanded)
    }
}
