//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct WindowContentSplitView<Sidebar: View, MainContent: View>: NSViewRepresentable {
    let sidebarMinWidth: CGFloat
    let sidebarIdealWidth: CGFloat
    let sidebarMaxWidth: CGFloat
    let sidebar: Sidebar
    let mainContent: MainContent
    let onSidebarContentHeightChange: (CGFloat) -> Void

    init(
        sidebarMinWidth: CGFloat,
        sidebarIdealWidth: CGFloat,
        sidebarMaxWidth: CGFloat,
        onSidebarContentHeightChange: @escaping (CGFloat) -> Void,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder mainContent: () -> MainContent
    ) {
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth
        self.onSidebarContentHeightChange = onSidebarContentHeightChange
        self.sidebar = sidebar()
        self.mainContent = mainContent()
    }

    func makeNSView(context: Context) -> ContainerView {
        let view = ContainerView(
            sidebarMinWidth: sidebarMinWidth,
            sidebarIdealWidth: sidebarIdealWidth,
            sidebarMaxWidth: sidebarMaxWidth
        )
        view.onSidebarContentHeightChange = onSidebarContentHeightChange
        view.update(
            sidebar: AnyView(sidebar),
            mainContent: AnyView(mainContent)
        )
        return view
    }

    func updateNSView(_ nsView: ContainerView, context: Context) {
        nsView.sidebarMinWidth = sidebarMinWidth
        nsView.sidebarIdealWidth = sidebarIdealWidth
        nsView.sidebarMaxWidth = sidebarMaxWidth
        nsView.onSidebarContentHeightChange = onSidebarContentHeightChange
        nsView.update(
            sidebar: AnyView(sidebar),
            mainContent: AnyView(mainContent)
        )
    }

    final class ContainerView: NSView, NSSplitViewDelegate {
        var sidebarMinWidth: CGFloat
        var sidebarIdealWidth: CGFloat
        var sidebarMaxWidth: CGFloat
        var onSidebarContentHeightChange: ((CGFloat) -> Void)?

        private let splitView = NSSplitView()
        private let sidebarScrollView = NSScrollView()
        private let sidebarDocumentView = FlippedDocumentView()
        private let sidebarHostingView = NSHostingView(rootView: AnyView(EmptyView()))
        private let mainContainerView = NSView()
        private let mainHostingView = NSHostingView(rootView: AnyView(EmptyView()))

        private var hasAppliedInitialSidebarWidth = false
        private var lastReportedSidebarContentHeight: CGFloat = 0
        private var lastLoggedMetrics: SidebarMetrics?

        init(
            sidebarMinWidth: CGFloat,
            sidebarIdealWidth: CGFloat,
            sidebarMaxWidth: CGFloat
        ) {
            self.sidebarMinWidth = sidebarMinWidth
            self.sidebarIdealWidth = sidebarIdealWidth
            self.sidebarMaxWidth = sidebarMaxWidth
            super.init(frame: .zero)
            configure()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            layoutSplitView()
            updateSidebarLayout(reason: window?.inLiveResize == true ? "live-resize" : "layout")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            DispatchQueue.main.async { [weak self] in
                self?.layoutSplitView()
                self?.updateSidebarLayout(reason: "window-attached")
            }
        }

        func update(sidebar: AnyView, mainContent: AnyView) {
            sidebarHostingView.rootView = sidebar
            mainHostingView.rootView = mainContent
            sidebarHostingView.invalidateIntrinsicContentSize()
            mainHostingView.invalidateIntrinsicContentSize()
            needsLayout = true

            DispatchQueue.main.async { [weak self] in
                self?.layoutSplitView()
                self?.updateSidebarLayout(reason: "content-update")
            }
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainSplitPosition proposedPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let minimum = sidebarMinWidth
            let maximum = min(sidebarMaxWidth, splitView.bounds.width - splitView.dividerThickness - 200)
            return min(max(proposedPosition, minimum), max(minimum, maximum))
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            updateSidebarLayout(reason: window?.inLiveResize == true ? "sidebar-resized-live" : "sidebar-resized")
        }

        private func configure() {
            splitView.isVertical = true
            splitView.dividerStyle = .thin
            splitView.delegate = self
            addSubview(splitView)

            sidebarScrollView.drawsBackground = true
            sidebarScrollView.backgroundColor = .controlBackgroundColor
            sidebarScrollView.borderType = .noBorder
            sidebarScrollView.hasVerticalScroller = true
            sidebarScrollView.hasHorizontalScroller = false
            sidebarScrollView.autohidesScrollers = true
            sidebarScrollView.verticalScrollElasticity = .automatic
            sidebarScrollView.horizontalScrollElasticity = .none
            sidebarScrollView.automaticallyAdjustsContentInsets = false
            sidebarScrollView.documentView = sidebarDocumentView
            splitView.addArrangedSubview(sidebarScrollView)

            sidebarDocumentView.addSubview(sidebarHostingView)

            mainHostingView.translatesAutoresizingMaskIntoConstraints = false
            mainContainerView.addSubview(mainHostingView)
            NSLayoutConstraint.activate([
                mainHostingView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor),
                mainHostingView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor),
                mainHostingView.topAnchor.constraint(equalTo: mainContainerView.topAnchor),
                mainHostingView.bottomAnchor.constraint(equalTo: mainContainerView.bottomAnchor)
            ])
            splitView.addArrangedSubview(mainContainerView)
        }

        private func layoutSplitView() {
            let targetFrame = resolvedVisibleContentFrame().integral
            guard targetFrame.width > 0, targetFrame.height > 0 else { return }

            if splitView.frame != targetFrame {
                splitView.frame = targetFrame
            }

            if hasAppliedInitialSidebarWidth == false {
                let initialWidth = min(max(sidebarIdealWidth, sidebarMinWidth), sidebarMaxWidth)
                splitView.setPosition(initialWidth, ofDividerAt: 0)
                hasAppliedInitialSidebarWidth = true
            } else {
                let constrainedWidth = min(max(sidebarScrollView.frame.width, sidebarMinWidth), sidebarMaxWidth)
                if abs(constrainedWidth - sidebarScrollView.frame.width) >= 1 {
                    splitView.setPosition(constrainedWidth, ofDividerAt: 0)
                }
            }

            splitView.adjustSubviews()
        }

        private func updateSidebarLayout(reason: String) {
            let sidebarWidth = sidebarScrollView.contentView.bounds.width
            let visibleHeight = ceil(sidebarScrollView.contentView.bounds.height)
            guard sidebarWidth > 0, visibleHeight > 0 else { return }

            sidebarHostingView.frame = NSRect(
                x: 0,
                y: 0,
                width: sidebarWidth,
                height: max(sidebarHostingView.frame.height, 1)
            )
            sidebarHostingView.layoutSubtreeIfNeeded()

            let contentHeight = ceil(sidebarHostingView.fittingSize.height)
            sidebarDocumentView.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: contentHeight)
            sidebarHostingView.frame = sidebarDocumentView.bounds

            if abs(contentHeight - lastReportedSidebarContentHeight) >= 1 {
                lastReportedSidebarContentHeight = contentHeight
                onSidebarContentHeightChange?(contentHeight)
            }

            let metrics = SidebarMetrics(
                contentHeight: contentHeight,
                visibleHeight: visibleHeight,
                obscuredTopInset: max(ceil(bounds.maxY - splitView.frame.maxY), 0),
                containerHeight: ceil(bounds.height),
                splitViewHeight: ceil(splitView.frame.height),
                sidebarWidth: ceil(sidebarWidth),
                requiresScrolling: contentHeight > visibleHeight + 1
            )
            logMetricsIfNeeded(metrics, reason: reason)
        }

        private func resolvedVisibleContentFrame() -> NSRect {
            guard let window else { return bounds }

            let localLayoutRect = convert(window.contentLayoutRect, from: nil)
            let visibleFrame = localLayoutRect.intersection(bounds)
            return visibleFrame.isNull ? bounds : visibleFrame
        }

        private func logMetricsIfNeeded(_ metrics: SidebarMetrics, reason: String) {
            defer { lastLoggedMetrics = metrics }

            guard let previous = lastLoggedMetrics else {
                AppLogger.debug(metrics.logMessage(reason: reason), category: .ui)
                return
            }

            let contentChanged = abs(metrics.contentHeight - previous.contentHeight) >= 1
            let visibleChanged = abs(metrics.visibleHeight - previous.visibleHeight) >= 24
            let insetChanged = abs(metrics.obscuredTopInset - previous.obscuredTopInset) >= 1
            let widthChanged = abs(metrics.sidebarWidth - previous.sidebarWidth) >= 1
            let scrollingChanged = metrics.requiresScrolling != previous.requiresScrolling

            guard contentChanged || visibleChanged || insetChanged || widthChanged || scrollingChanged else {
                return
            }

            AppLogger.debug(metrics.logMessage(reason: reason), category: .ui)
            if scrollingChanged {
                AppLogger.info(
                    """
                    Sidebar scrolling \(metrics.requiresScrolling ? "enabled" : "disabled"); \
                    contentHeight=\(Int(metrics.contentHeight)), visibleHeight=\(Int(metrics.visibleHeight)), \
                    sidebarWidth=\(Int(metrics.sidebarWidth))
                    """,
                    category: .ui
                )
            }
        }
    }

    private struct SidebarMetrics: Equatable {
        let contentHeight: CGFloat
        let visibleHeight: CGFloat
        let obscuredTopInset: CGFloat
        let containerHeight: CGFloat
        let splitViewHeight: CGFloat
        let sidebarWidth: CGFloat
        let requiresScrolling: Bool

        func logMessage(reason: String) -> String {
            """
            Sidebar layout metrics [\(reason)]: contentHeight=\(Int(contentHeight)), \
            visibleHeight=\(Int(visibleHeight)), obscuredTopInset=\(Int(obscuredTopInset)), \
            splitViewHeight=\(Int(splitViewHeight)), containerHeight=\(Int(containerHeight)), \
            sidebarWidth=\(Int(sidebarWidth)), scrolling=\(requiresScrolling)
            """
        }
    }

    final class FlippedDocumentView: NSView {
        override var isFlipped: Bool { true }
    }
}
