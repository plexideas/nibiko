import AppKit

@MainActor
enum ApplicationCommandMenu {
    static func install(appName: String, on application: NSApplication = .shared) {
        application.mainMenu = makeMainMenu(appName: appName)
    }

    private static func makeMainMenu(appName: String) -> NSMenu {
        let mainMenu = NSMenu(title: appName)

        let appMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        appMenuItem.submenu = NSMenu(title: appName)
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = makeEditMenu()
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    private static func makeEditMenu() -> NSMenu {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(commandItem("Undo", action: Selector(("undo:")), keyEquivalent: "z", modifiers: [.command]))
        editMenu.addItem(commandItem("Redo", action: Selector(("redo:")), keyEquivalent: "Z", modifiers: [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(commandItem("Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x", modifiers: [.command]))
        editMenu.addItem(commandItem("Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c", modifiers: [.command]))
        editMenu.addItem(commandItem("Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v", modifiers: [.command]))
        editMenu.addItem(commandItem("Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a", modifiers: [.command]))
        return editMenu
    }

    private static func commandItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        item.target = nil
        return item
    }
}
