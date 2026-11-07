import AppKit

/// 按钮外观，对应 GlobalProtect 的状态
enum ButtonLook {
    case on, off, busy, unavailable
}

/// 按钮与 App 图标的绘制代码（App 和图标生成工具共用）
enum Artwork {
    private struct Palette {
        let top: NSColor
        let bottom: NSColor
        let glyph: NSColor
        let rim: NSColor
    }

    private static func palette(_ look: ButtonLook) -> Palette {
        let darkTop = NSColor(srgbRed: 0.33, green: 0.33, blue: 0.36, alpha: 1)
        let darkBottom = NSColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1)
        let darkRim = NSColor(white: 1, alpha: 0.16)
        switch look {
        case .on:
            return Palette(top: NSColor(srgbRed: 0.29, green: 0.85, blue: 0.52, alpha: 1),
                           bottom: NSColor(srgbRed: 0.10, green: 0.62, blue: 0.33, alpha: 1),
                           glyph: .white, rim: NSColor(white: 1, alpha: 0.35))
        case .off:
            return Palette(top: darkTop, bottom: darkBottom,
                           glyph: NSColor(white: 0.66, alpha: 1), rim: darkRim)
        case .busy:
            return Palette(top: darkTop, bottom: darkBottom,
                           glyph: NSColor(srgbRed: 1.0, green: 0.71, blue: 0.25, alpha: 1), rim: darkRim)
        case .unavailable:
            return Palette(top: darkTop, bottom: darkBottom,
                           glyph: NSColor(srgbRed: 1.0, green: 0.42, blue: 0.40, alpha: 1), rim: darkRim)
        }
    }

    /// 在正方形 rect 内画圆形按钮。尺寸按 52pt 设计，可任意缩放。
    static func drawButton(in rect: NSRect, look: ButtonLook, hovering: Bool, pressed: Bool, spin: CGFloat) {
        let colors = palette(look)
        let circle = NSBezierPath(ovalIn: rect)
        let unit = rect.width / 52

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
        shadow.shadowBlurRadius = 5 * unit
        shadow.shadowOffset = NSSize(width: 0, height: -1.5 * unit)
        shadow.set()
        colors.bottom.setFill()
        circle.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(starting: colors.top, ending: colors.bottom)?.draw(in: circle, angle: -90)
        if pressed {
            NSColor(white: 0, alpha: 0.2).setFill()
            circle.fill()
        } else if hovering {
            NSColor(white: 1, alpha: 0.12).setFill()
            circle.fill()
        }

        let rim = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit))
        rim.lineWidth = unit
        colors.rim.setStroke()
        rim.stroke()

        drawGlyphAndLabel(in: rect, color: colors.glyph)

        if look == .busy {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2 - 3 * unit,
                          startAngle: -spin, endAngle: -spin + 100, clockwise: false)
            arc.lineWidth = 2.5 * unit
            arc.lineCapStyle = .round
            colors.glyph.setStroke()
            arc.stroke()
        }
    }

    /// 电源符号 + "GP" 字样，按 52pt 的圆布局
    private static func drawGlyphAndLabel(in rect: NSRect, color: NSColor) {
        let unit = rect.width / 52
        let center = NSPoint(x: rect.midX, y: rect.midY + 4.5 * unit)
        let radius = 8.5 * unit

        let glyph = NSBezierPath()
        glyph.appendArc(withCenter: center, radius: radius, startAngle: 128, endAngle: 52, clockwise: false)
        glyph.move(to: NSPoint(x: center.x, y: center.y + radius + 1.2 * unit))
        glyph.line(to: NSPoint(x: center.x, y: center.y + 1.5 * unit))
        glyph.lineWidth = 2.4 * unit
        glyph.lineCapStyle = .round
        color.setStroke()
        glyph.stroke()

        let label = NSAttributedString(string: "GP", attributes: [
            .font: NSFont.systemFont(ofSize: 9 * unit, weight: .heavy),
            .foregroundColor: color,
            .kern: 0.5 * unit,
        ])
        let size = label.size()
        label.draw(at: NSPoint(x: rect.midX - size.width / 2 + 0.25 * unit, y: rect.midY - 16 * unit))
    }

    /// App 图标：绿色圆角方块 + 同样的电源符号（size 为画布边长，单位像素）
    static func drawAppIcon(size: CGFloat) {
        let body = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * 0.1, dy: size * 0.1)
        let shape = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
        let colors = palette(.on)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
        shadow.shadowBlurRadius = size * 0.02
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
        shadow.set()
        colors.bottom.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(starting: colors.top, ending: colors.bottom)?.draw(in: shape, angle: -90)
        drawGlyphAndLabel(in: body.insetBy(dx: body.width * 0.1, dy: body.width * 0.1), color: .white)
    }
}
