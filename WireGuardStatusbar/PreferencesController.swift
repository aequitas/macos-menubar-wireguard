//

import Cocoa

class Preferences: NSWindowController {
    override var windowNibName: String {
        return "PreferencesController"
    }

    // make sure window is always brought to the front when it is opened
    override func showWindow(_: Any?) {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // close on ⌘-w (required because app has no menubar with close window action)
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.characters == "w" {
            window?.close()
        }
    }

    // close on esc key
    @objc func cancel(_: Any?) {
        window?.close()
    }
}
