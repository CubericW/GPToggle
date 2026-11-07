// GPToggle：桌面悬浮按钮，一键开关 GlobalProtect
import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // 不显示 Dock 图标和菜单栏
    app.run()
}
