import AppKit
import ServiceManagement

enum GPState {
    case running, stopped, starting, stopping, notInstalled
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var button: ButtonView!
    private let tip = TipPanel()
    private var hoverTimer: Timer?
    private let originKey = "ButtonOrigin"

    private var state = GPState.stopped {
        didSet { if state != oldValue { render() } }
    }
    private var isBusy: Bool { state == .starting || state == .stopping }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.trimIfNeeded()

        button = ButtonView(frame: NSRect(origin: .zero, size: ButtonView.windowSize))
        button.onClick = { [weak self] in self?.toggle() }
        button.onHover = { [weak self] inside in self?.hoverChanged(inside) }
        button.onDragEnded = { [weak self] in self?.dragEnded() }
        button.menuProvider = { [weak self] in self?.makeMenu() }

        panel = FloatingPanel(contentSize: ButtonView.windowSize)
        panel.contentView = button
        restorePosition()
        panel.orderFrontRegardless()

        refresh()
        render()
        let poll = Timer(timeInterval: 2, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        RunLoop.main.add(poll, forMode: .common)

        NotificationCenter.default.addObserver(self, selector: #selector(ensureOnScreen),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        let snap = GlobalProtect.snapshot()
        let agents = GlobalProtect.agents.map { "\($0.label) \(GlobalProtect.isLoaded($0) ? "已加载" : "未加载")" }
        Log.write("悬浮按钮已启动。GlobalProtect \(statusText)：界面\(snap.hasUI ? "在" : "不在")，PanGPS \(snap.hasService ? "在" : "不在")；"
                  + agents.joined(separator: "，"))
    }

    /// 再次打开 App 时，把按钮拉回屏幕内并置前
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ensureOnScreen()
        panel.orderFrontRegardless()
        return false
    }

    // MARK: 状态

    @objc private func refresh() {
        guard !isBusy else { return }
        if !GlobalProtect.isInstalled {
            state = .notInstalled
        } else {
            state = GlobalProtect.snapshot().isRunning ? .running : .stopped
        }
    }

    private func render() {
        switch state {
        case .running: button.look = .on
        case .stopped: button.look = .off
        case .starting, .stopping: button.look = .busy
        case .notInstalled: button.look = .unavailable
        }
        button.setAccessibilityValue(statusText)
        if tip.isVisible { showTip() }
    }

    private var statusText: String {
        switch state {
        case .running: return "运行中"
        case .stopped: return "已关闭"
        case .starting: return "正在开启…"
        case .stopping: return "正在关闭…"
        case .notInstalled: return "未安装"
        }
    }

    // MARK: 开关

    private func toggle() {
        hideTip()
        switch state {
        case .running: perform(stop: true)
        case .stopped: perform(stop: false)
        case .notInstalled: showAlert("没有找到 GlobalProtect", "它应该安装在 \(GlobalProtect.appPath)。")
        case .starting, .stopping: break
        }
    }

    private func perform(stop: Bool) {
        state = stop ? .stopping : .starting
        DispatchQueue.global(qos: .userInitiated).async {
            let error = stop ? GlobalProtect.stop() : GlobalProtect.start()
            let running = GlobalProtect.snapshot().isRunning
            DispatchQueue.main.async {
                self.state = running ? .running : .stopped
                Log.write(error.map { "失败：\($0)" } ?? "完成，GlobalProtect \(self.statusText)")
                if let error {
                    self.showAlert(stop ? "关闭 GlobalProtect 失败" : "开启 GlobalProtect 失败", error)
                }
            }
        }
    }

    // MARK: 右键菜单

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let header = NSMenuItem(title: "GlobalProtect：\(statusText)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if state == .running || state == .stopped {
            menu.addItem(.separator())
            menu.addItem(item(state == .running ? "关闭 GlobalProtect" : "开启 GlobalProtect", #selector(menuToggle)))
        }
        menu.addItem(.separator())
        let login = item("登录时自动显示悬浮按钮", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("查看日志", #selector(openLog)))
        menu.addItem(.separator())
        menu.addItem(item("退出悬浮按钮", #selector(quit)))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func menuToggle() { toggle() }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showAlert("无法修改登录项", error.localizedDescription)
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        Log.write("登录时自动显示：\(service.status == .enabled ? "开" : "关")")
    }

    @objc private func openLog() { NSWorkspace.shared.open(Log.url) }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: 悬停提示

    private func hoverChanged(_ inside: Bool) {
        hoverTimer?.invalidate()
        if inside {
            hoverTimer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(showTip), userInfo: nil, repeats: false)
        } else {
            tip.orderOut(nil)
        }
    }

    @objc private func showTip() {
        let title: String
        switch state {
        case .running: title = "GlobalProtect 运行中 · 点击关闭"
        case .stopped: title = "GlobalProtect 已关闭 · 点击开启"
        case .starting: title = "正在开启 GlobalProtect…"
        case .stopping: title = "正在关闭 GlobalProtect…"
        case .notInstalled: title = "没有找到 GlobalProtect"
        }
        tip.show(title: title, subtitle: "拖动可移动 · 右键更多选项", beside: panel.frame)
    }

    private func hideTip() {
        hoverTimer?.invalidate()
        tip.orderOut(nil)
    }

    // MARK: 位置

    private func restorePosition() {
        if let saved = UserDefaults.standard.string(forKey: originKey) {
            panel.setFrameOrigin(NSPointFromString(saved))
        } else if let area = NSScreen.main?.visibleFrame {
            // 默认：主屏幕右侧、偏下的位置
            panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 16, y: area.minY + area.height * 0.3))
        }
        ensureOnScreen()
    }

    private func dragEnded() {
        ensureOnScreen()
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: originKey)
    }

    /// 把按钮夹回离它最近的屏幕可见区域内（比如外接显示器拔掉后也不会"丢失"）
    @objc private func ensureOnScreen() {
        let frame = panel.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        func distance(to area: NSRect) -> CGFloat {
            let dx = max(area.minX - center.x, 0, center.x - area.maxX)
            let dy = max(area.minY - center.y, 0, center.y - area.maxY)
            return dx * dx + dy * dy
        }
        guard let area = NSScreen.screens.map(\.visibleFrame).min(by: { distance(to: $0) < distance(to: $1) }) else { return }
        panel.setFrameOrigin(NSPoint(x: min(max(frame.minX, area.minX), area.maxX - frame.width),
                                     y: min(max(frame.minY, area.minY), area.maxY - frame.height)))
    }

    // MARK: 提示框

    private func showAlert(_ title: String, _ message: String) {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message + "\n\n详细记录见日志：~/Library/Logs/GPToggle.log"
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "查看日志")
        if alert.runModal() == .alertSecondButtonReturn { openLog() }
    }
}
