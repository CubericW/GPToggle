import AppKit

/// 圆形悬浮按钮：单击开关，拖动移动，右键（或 Control+单击）弹出菜单
final class ButtonView: NSView {
    static let diameter: CGFloat = 52
    static let windowSize = NSSize(width: 64, height: 66)   // 四周留出画阴影的空间

    var look = ButtonLook.off {
        didSet { if look != oldValue { lookChanged() } }
    }
    var onClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var onDragEnded: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?

    private var hovering = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private var clickArmed = false
    private var dragging = false
    private var mouseDownLocation = NSPoint.zero
    private var windowOriginAtMouseDown = NSPoint.zero
    private var spinAngle: CGFloat = 0
    private var spinTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("GlobalProtect 开关")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var circleRect: NSRect {
        let d = Self.diameter
        return NSRect(x: (bounds.width - d) / 2, y: (bounds.height - d) / 2 + 2, width: d, height: d)
    }

    private func isInsideCircle(_ point: NSPoint) -> Bool {
        let c = circleRect
        let dx = point.x - c.midX, dy = point.y - c.midY
        return dx * dx + dy * dy <= c.width * c.width / 4
    }

    override func draw(_ dirtyRect: NSRect) {
        Artwork.drawButton(in: circleRect, look: look, hovering: hovering, pressed: pressed, spin: spinAngle)
    }

    // MARK: 鼠标

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isInsideCircle(convert(point, from: superview)) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: circleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        onHover?(false)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showMenu(for: event)
            return
        }
        clickArmed = true
        dragging = false
        pressed = true
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard clickArmed || dragging, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - mouseDownLocation.x, dy = now.y - mouseDownLocation.y
        if !dragging {
            guard dx * dx + dy * dy > 9 else { return }   // 移动超过 3pt 才算拖动，避免手抖误判
            dragging = true
            clickArmed = false
            pressed = false
            onHover?(false)
        }
        window.setFrameOrigin(NSPoint(x: windowOriginAtMouseDown.x + dx, y: windowOriginAtMouseDown.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        pressed = false
        if dragging {
            dragging = false
            onDragEnded?()
        } else if clickArmed {
            clickArmed = false
            if isInsideCircle(convert(event.locationInWindow, from: nil)) { onClick?() }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(for: event)
    }

    private func showMenu(for event: NSEvent) {
        onHover?(false)
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    // MARK: 处理中的转圈动画

    private func lookChanged() {
        needsDisplay = true
        if look == .busy, spinTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, target: self, selector: #selector(spinTick), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            spinTimer = timer
        } else if look != .busy {
            spinTimer?.invalidate()
            spinTimer = nil
        }
    }

    @objc private func spinTick() {
        spinAngle = (spinAngle + 6).truncatingRemainder(dividingBy: 360)   // 每秒一圈
        needsDisplay = true
    }
}
