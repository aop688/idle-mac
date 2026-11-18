import Cocoa
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: 30)
    private var assertions: [IOPMAssertionID] = []
    private var active: Bool { !assertions.isEmpty }
    private var cradleLayer: CALayer?
    private var appearanceObs: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.wantsLayer = true
        appearanceObs = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.updateCradleColor()
        }
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
        button.toolTip = active ? "保持唤醒：开（点击关闭）" : "保持唤醒：关（点击开启）"
        if active {
            button.image = nil
            startCradle(on: button)
        } else {
            stopCradle()
            button.image = restingImage()
        }
    }

    // MARK: - 牛顿摆图标
    // 动画参考 LDRS「Newton's Cradle」(MIT, Griffin Johnston / UI Ball)
    // 用 Core Animation 实现：动画由系统渲染服务驱动，应用本身不需要定时器

    private enum Cradle {
        static let size: CGFloat = 18                  // 图标画布
        static let ball: CGFloat = 4                   // 球直径
        static let angle: CGFloat = 40 * .pi / 180     // 摆角
        static let duration: CFTimeInterval = 1.2      // 周期
    }

    // 关闭：4 个静止的空心球（template，自动适配深浅色菜单栏）
    private func restingImage() -> NSImage {
        let size = NSSize(width: Cradle.size, height: Cradle.size)
        let img = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            let slot = Cradle.size / 4
            for i in 0..<4 {
                let cx = slot * (CGFloat(i) + 0.5)
                let rect = NSRect(x: cx - Cradle.ball / 2, y: Cradle.size / 2 - Cradle.ball / 2,
                                  width: Cradle.ball, height: Cradle.ball).insetBy(dx: 0.6, dy: 0.6)
                let path = NSBezierPath(ovalIn: rect)
                path.lineWidth = 1.2
                path.stroke()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    // 开启：4 个实心球，最左和最右交替摆动
    private func startCradle(on button: NSStatusBarButton) {
        stopCradle()
        button.wantsLayer = true
        guard let host = button.layer else { return }

        let container = CALayer()
        container.bounds = CGRect(x: 0, y: 0, width: Cradle.size, height: Cradle.size)
        container.position = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
        container.isGeometryFlipped = host.isGeometryFlipped   // 保证内部坐标 y 向上

        let slot = Cradle.size / 4
        let animate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for i in 0..<4 {
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: slot, height: Cradle.size)
            dot.anchorPoint = CGPoint(x: 0.5, y: 1)            // 枢轴在顶部中心
            dot.position = CGPoint(x: slot * (CGFloat(i) + 0.5), y: Cradle.size)

            let ball = CALayer()
            ball.bounds = CGRect(x: 0, y: 0, width: Cradle.ball, height: Cradle.ball)
            ball.position = CGPoint(x: slot / 2, y: Cradle.size / 2)
            ball.cornerRadius = Cradle.ball / 2
            dot.addSublayer(ball)

            if animate && (i == 0 || i == 3) {
                dot.add(swing(left: i == 0), forKey: "swing")
            }
            container.addSublayer(dot)
        }
        host.addSublayer(container)
        cradleLayer = container
        updateCradleColor()
    }

    private func stopCradle() {
        cradleLayer?.removeFromSuperlayer()
        cradleLayer = nil
    }

    private func swing(left: Bool) -> CAKeyframeAnimation {
        let a = Double(Cradle.angle)
        let easeIn = CAMediaTimingFunction(name: .easeIn)
        let easeOut = CAMediaTimingFunction(name: .easeOut)
        let linear = CAMediaTimingFunction(name: .linear)
        let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        if left {   // 向左摆：顺时针，CA 中为负角度
            anim.values = [0, -a, 0, 0].map { NSNumber(value: $0) }
            anim.keyTimes = [0, 0.25, 0.5, 1].map { NSNumber(value: $0) }
            anim.timingFunctions = [easeOut, easeIn, linear]
        } else {    // 向右摆：逆时针，CA 中为正角度
            anim.values = [0, 0, a, 0].map { NSNumber(value: $0) }
            anim.keyTimes = [0, 0.5, 0.75, 1].map { NSNumber(value: $0) }
            anim.timingFunctions = [linear, easeOut, easeIn]
        }
        anim.duration = Cradle.duration
        anim.repeatCount = .infinity
        return anim
    }

    // 球的颜色跟随菜单栏的深浅外观
    private func updateCradleColor() {
        guard let button = item.button, let layer = cradleLayer else { return }
        var color = NSColor.white.cgColor
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            color = NSColor.labelColor.cgColor
        }
        layer.sublayers?.forEach { dot in
            dot.sublayers?.forEach { $0.backgroundColor = color }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // 无 Dock 图标
app.run()
