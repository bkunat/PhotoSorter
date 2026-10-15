//
//  PhotoSorter
//

import AppKit
import SwiftUI

struct SessionKeyboardMonitor: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    static func dismantleNSView(_ nsView: MonitorView, coordinator: ()) {
        nsView.removeMonitor()
    }

    final class MonitorView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window,
                      event.window === window, window.isKeyWindow,
                      window.attachedSheet == nil, NSApp.modalWindow == nil else { return event }
                if let text = window.firstResponder as? NSTextView, text.isEditable { return event }
                return self.onKeyDown?(event) == true ? nil : event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
