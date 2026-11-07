// 生成 App 图标（AppIcon.iconset）和按钮各状态的预览图（preview.png），与 App 共用 Artwork.swift
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build")

func png(width: Int, height: Int, scale: CGFloat = 1, _ draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// 1. 图标
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png(width: pixels, height: pixels) { Artwork.drawAppIcon(size: CGFloat(pixels)) }
            .write(to: iconset.appendingPathComponent(name))
    }
}

// 2. 预览：上排浅色背景、下排深色背景；依次为 开 / 关 / 处理中 / 开+悬停
let cell: CGFloat = 80
let looks: [(ButtonLook, Bool)] = [(.on, false), (.off, false), (.busy, false), (.on, true)]
let backgrounds = [NSColor(white: 0.93, alpha: 1), NSColor(white: 0.12, alpha: 1)]
let preview = png(width: Int(cell) * looks.count * 2, height: Int(cell) * backgrounds.count * 2, scale: 2) {
    for (row, background) in backgrounds.enumerated() {
        let y = CGFloat(backgrounds.count - 1 - row) * cell
        background.setFill()
        NSRect(x: 0, y: y, width: cell * CGFloat(looks.count), height: cell).fill()
        for (column, (look, hovering)) in looks.enumerated() {
            let d: CGFloat = 52   // 与 ButtonView.diameter 一致
            let rect = NSRect(x: CGFloat(column) * cell + (cell - d) / 2, y: y + (cell - d) / 2, width: d, height: d)
            Artwork.drawButton(in: rect, look: look, hovering: hovering, pressed: false, spin: 40)
        }
    }
}
try preview.write(to: outDir.appendingPathComponent("preview.png"))
print("✓ 图标与预览图已生成")
