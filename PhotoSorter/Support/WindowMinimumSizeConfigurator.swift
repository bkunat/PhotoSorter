//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct WindowMinimumSizeConfigurator: NSViewRepresentable {
    let minimumVisibleContentSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(minimumVisibleContentSize: minimumVisibleContentSize)
    }

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onWindowChange = context.coordinator.handleWindowChange(_:)
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        context.coordinator.minimumVisibleContentSize = minimumVisibleContentSize
        nsView.onWindowChange = context.coordinator.handleWindowChange(_:)

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.attach(to: window)
            context.coordinator.applyMinimumSize(to: window, reason: "swiftui-update")
        }
    }

    final class Coordinator: NSObject {
        var minimumVisibleContentSize: CGSize

        private weak var observedWindow: NSWindow?
        private var didResizeObserver: NSObjectProtocol?
        private var didEndLiveResizeObserver: NSObjectProtocol?
        private var lastAppliedContentSize: NSSize = .zero
        private var lastAppliedFrameSize: NSSize = .zero
        private var lastAppliedVisibleSize: NSSize = .zero
        private var lastLoggedResizeFrameSize: NSSize = .zero

        init(minimumVisibleContentSize: CGSize) {
            self.minimumVisibleContentSize = minimumVisibleContentSize
        }

        deinit {
            detach()
        }

        func handleWindowChange(_ window: NSWindow?) {
            guard let window else {
                detach()
                return
            }

            attach(to: window)
            applyMinimumSize(to: window, reason: "window-attached")
        }

        func attach(to window: NSWindow) {
            guard observedWindow !== window else { return }

            detach()
            observedWindow = window

            let notificationCenter = NotificationCenter.default
            didResizeObserver = notificationCenter.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let self, let window else { return }
                self.handleResize(for: window)
            }

            didEndLiveResizeObserver = notificationCenter.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let self, let window else { return }
                self.logWindowMetrics(for: window, reason: "did-end-live-resize", force: true)
                self.applyMinimumSize(to: window, reason: "did-end-live-resize")
            }

            logWindowMetrics(for: window, reason: "attached", force: true)
        }

        func detach() {
            let notificationCenter = NotificationCenter.default

            if let didResizeObserver {
                notificationCenter.removeObserver(didResizeObserver)
                self.didResizeObserver = nil
            }

            if let didEndLiveResizeObserver {
                notificationCenter.removeObserver(didEndLiveResizeObserver)
                self.didEndLiveResizeObserver = nil
            }

            observedWindow = nil
            lastLoggedResizeFrameSize = .zero
        }

        func applyMinimumSize(to window: NSWindow, reason: String) {
            let roundedVisibleSize = NSSize(
                width: ceil(minimumVisibleContentSize.width),
                height: ceil(minimumVisibleContentSize.height)
            )
            let metrics = WindowMetrics(window: window)
            let minimumContentSize = NSSize(
                width: roundedVisibleSize.width,
                height: roundedVisibleSize.height + metrics.obscuredTopInset
            )
            let minimumFrameRect = window.frameRect(forContentRect: NSRect(origin: .zero, size: minimumContentSize))
            let minimumFrameSize = NSSize(
                width: ceil(minimumFrameRect.width),
                height: ceil(minimumFrameRect.height)
            )

            window.contentMinSize = minimumContentSize
            window.minSize = minimumFrameSize

            if window.frame.width < minimumFrameSize.width || window.frame.height < minimumFrameSize.height {
                var targetFrame = window.frame
                let widthDelta = max(minimumFrameSize.width - targetFrame.width, 0)
                let heightDelta = max(minimumFrameSize.height - targetFrame.height, 0)

                targetFrame.size.width = max(targetFrame.width, minimumFrameSize.width)
                targetFrame.size.height = max(targetFrame.height, minimumFrameSize.height)
                targetFrame.origin.x -= widthDelta / 2
                targetFrame.origin.y -= heightDelta

                AppLogger.info(
                    """
                    Expanding window to enforce minimum size: targetFrame=\(Int(targetFrame.width))x\(Int(targetFrame.height)), \
                    reason=\(reason)
                    """,
                    category: .ui
                )
                window.setFrame(targetFrame, display: true, animate: false)
            }

            guard lastAppliedVisibleSize != roundedVisibleSize ||
                lastAppliedContentSize != minimumContentSize ||
                lastAppliedFrameSize != minimumFrameSize else {
                return
            }

            lastAppliedVisibleSize = roundedVisibleSize
            lastAppliedContentSize = minimumContentSize
            lastAppliedFrameSize = minimumFrameSize

            AppLogger.debug(
                """
                Applied window minimum size: visible=\(Int(roundedVisibleSize.width))x\(Int(roundedVisibleSize.height)), \
                content=\(Int(minimumContentSize.width))x\(Int(minimumContentSize.height)), \
                frame=\(Int(minimumFrameSize.width))x\(Int(minimumFrameSize.height)), \
                obscuredTopInset=\(Int(metrics.obscuredTopInset)), reason=\(reason)
                """,
                category: .ui
            )
            logWindowMetrics(for: window, reason: "applied-\(reason)", force: true)
        }

        private func handleResize(for window: NSWindow) {
            let metrics = WindowMetrics(window: window)
            let widthDelta = abs(metrics.frameSize.width - lastLoggedResizeFrameSize.width)
            let heightDelta = abs(metrics.frameSize.height - lastLoggedResizeFrameSize.height)
            let shouldForceLog = !window.inLiveResize || widthDelta >= 24 || heightDelta >= 24

            logWindowMetrics(for: window, reason: window.inLiveResize ? "did-resize-live" : "did-resize", force: shouldForceLog)
            applyMinimumSize(to: window, reason: window.inLiveResize ? "did-resize-live" : "did-resize")

            if shouldForceLog {
                lastLoggedResizeFrameSize = metrics.frameSize
            }
        }

        private func logWindowMetrics(for window: NSWindow, reason: String, force: Bool) {
            guard force else { return }

            let metrics = WindowMetrics(window: window)
            AppLogger.debug(
                """
                Window layout metrics [\(reason)]: frame=\(Int(metrics.frameSize.width))x\(Int(metrics.frameSize.height)), \
                content=\(Int(metrics.contentSize.width))x\(Int(metrics.contentSize.height)), \
                contentLayout=\(Int(metrics.contentLayoutSize.width))x\(Int(metrics.contentLayoutSize.height)), \
                frameChromeHeight=\(Int(metrics.frameChromeHeight)), \
                obscuredTopInset=\(Int(metrics.obscuredTopInset))
                """,
                category: .ui
            )
        }
    }

    private struct WindowMetrics {
        let frameSize: NSSize
        let contentSize: NSSize
        let contentLayoutSize: NSSize
        let frameChromeHeight: CGFloat
        let obscuredTopInset: CGFloat

        init(window: NSWindow) {
            frameSize = window.frame.size
            contentSize = window.contentRect(forFrameRect: window.frame).size
            contentLayoutSize = window.contentLayoutRect.size
            frameChromeHeight = max(frameSize.height - contentLayoutSize.height, 0)
            obscuredTopInset = max(contentSize.height - contentLayoutSize.height, 0)
        }
    }

    final class ObserverView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)

            if newWindow == nil {
                onWindowChange?(nil)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}
