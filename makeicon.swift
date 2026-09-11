import AppKit
import Foundation

// Draws the app icon: the thing the app does, which is a screen leaning away
// from you. A receding trapezoid reads at 16pt where a drawn laptop would not.
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = { (v: CGFloat) in v / 1024 * size }

    // macOS leaves the outer tenth clear and rounds the rest.
    let plate = NSRect(x: s(100), y: s(100), width: s(824), height: s(824))
    let squircle = NSBezierPath(roundedRect: plate, xRadius: s(185), yRadius: s(185))
    NSGradient(colors: [NSColor(srgbRed: 0.20, green: 0.21, blue: 0.23, alpha: 1),
                        NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1)])?
        .draw(in: squircle, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()

    // The panel, hinged on its bottom edge and tipped back.
    let panel = NSBezierPath()
    panel.move(to: NSPoint(x: s(300), y: s(330)))
    panel.line(to: NSPoint(x: s(724), y: s(330)))
    panel.line(to: NSPoint(x: s(622), y: s(700)))
    panel.line(to: NSPoint(x: s(402), y: s(700)))
    panel.close()
    NSGradient(colors: [NSColor(srgbRed: 0.29, green: 0.56, blue: 0.99, alpha: 1),
                        NSColor(srgbRed: 0.09, green: 0.25, blue: 0.72, alpha: 1)])?
        .draw(in: panel, angle: -90)

    // The far end falls off across the whole panel, the way the app dims it.
    // A band over part of it read as a separate flap.
    NSGraphicsContext.saveGraphicsState()
    panel.addClip()
    NSGradient(colors: [NSColor(white: 0, alpha: 0),
                        NSColor(white: 0, alpha: 0.55)])?
        .draw(in: NSRect(x: 0, y: s(330), width: size, height: s(370)), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // The lit hinge.
    let hinge = NSBezierPath(roundedRect:
        NSRect(x: s(300), y: s(316), width: s(424), height: s(24)),
        xRadius: s(12), yRadius: s(12))
    NSColor(white: 1, alpha: 0.92).setFill()
    hinge.fill()

    NSGraphicsContext.restoreGraphicsState()
    image.unlockFocus()
    return image
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let icon = drawIcon(size: 1024)
guard let tiff = icon.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
