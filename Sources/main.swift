import Cocoa
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var assertions: [IOPMAssertionID] = []
    private var active: Bool { !assertions.isEmpty }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        render()
    }

    func applicationWillTerminate(_ notification: Notification) {
        release()
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isRight {
            showMenu()
        } else {
            active ? release() : acquire()
            render()
        }
    }

    // 右键 / Control+点击：弹出退出菜单
    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "退出 Idle",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func acquire() {
        // 阻止屏幕休眠 + 阻止系统空闲休眠（等价于 caffeinate -di）
        // 若只想让屏幕可以熄灭，删掉第一项即可
        let types = [kIOPMAssertionTypePreventUserIdleDisplaySleep,
                     kIOPMAssertionTypePreventUserIdleSystemSleep]
        for type in types {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Idle: keep awake" as CFString,
                &id)
            if result == kIOReturnSuccess { assertions.append(id) }
        }
    }

    private func release() {
        assertions.forEach { IOPMAssertionRelease($0) }
        assertions.removeAll()
    }

    private func render() {
        guard let button = item.button else { return }
        // 关闭：灰色月亮 zzz（跟随菜单栏颜色）；开启：橙色太阳（醒目）
        let name = active ? "sun.max.fill" : "moon.zzz"
        if let sym = NSImage(systemSymbolName: name, accessibilityDescription: "Idle") {
            if active {
                button.image = tinted(sym, .systemOrange)
            } else {
                sym.isTemplate = true   // 自动适配深色/浅色菜单栏
                button.image = sym
            }
            button.title = ""
        } else {
            button.image = nil
            button.title = active ? "●" : "○"
        }
        button.toolTip = active ? "保持唤醒：开（点击关闭）" : "保持唤醒：关（点击开启）"
    }

    // 给 SF Symbol 上色（非 template，保持固定颜色）
    private func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        let out = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        out.isTemplate = false
        return out
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // 无 Dock 图标
app.run()
