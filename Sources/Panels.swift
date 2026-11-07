import AppKit

/// 无边框、不抢焦点、始终置顶，并在所有桌面空间（包括全屏 App 上方）显示的面板
class FloatingPanel: NSPanel {
    init(contentSize: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: contentSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 鼠标悬停时显示在按钮旁边的说明
final class TipPanel: FloatingPanel {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    init() {
        super.init(contentSize: .zero)
        ignoresMouseEvents = true
        hasShadow = true

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = NSColor(white: 1, alpha: 0.6)

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 10, bottom: 7, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.94).cgColor
        background.layer?.cornerRadius = 8
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentView = background
    }

    func show(title: String, subtitle: String, beside anchor: NSRect) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        guard let content = contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        let area = (NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main)?.visibleFrame ?? anchor
        // 按钮在屏幕右半边就把说明放左边，反之放右边
        let x = anchor.midX > area.midX ? anchor.minX - size.width : anchor.maxX
        let y = min(max(anchor.midY - size.height / 2, area.minY), area.maxY - size.height)
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        orderFrontRegardless()
    }
}
