import AppKit
import CoreMedia
import IOKit.hid
import QuartzCore
import ScreenCaptureKit

// MARK: - Lid angle

/// Reads the MacBook lid angle in degrees.
///
/// The sensor shows up as a HID device on the sensor page (0x20) with an
/// "orientation: compound" usage (0x8A). Feature report 1 is three bytes -
/// report id, then the angle as a little-endian u16 of degrees. Verified on
/// Mac15,10 / macOS 26.1: a lid open at eye height reads 111.
final class LidAngleSensor {
    /// Held for the object's lifetime on purpose: the devices it vends die with
    /// it, and at -O the optimiser releases it right after its last use, so a
    /// local would be gone before the first report is read.
    private let manager: IOHIDManager
    private let device: IOHIDDevice?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Ask for the sensor and nothing else. Matching nil claims every HID
        // device on the machine, the keyboard among them, and macOS answers that
        // by asking the user for input monitoring - a keystroke prompt on an app
        // that reads a hinge. Measured 2026-09-14 on Mac15,10: nil raises the
        // prompt with no window on screen at all, this dictionary raises none and
        // still matches exactly one device, which answers report 1 with the lid
        // angle.
        //
        // A dictionary was tried before and fell through to every HID device.
        // The keys are why: a matching dictionary takes DeviceUsagePage and
        // DeviceUsage, while the hand check below reads PrimaryUsagePage and
        // PrimaryUsage. They are different keys, and the wrong pair matches
        // nothing, which IOKit treats as matching everything.
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: 0x20,
            kIOHIDDeviceUsageKey: 0x8A,
        ] as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        let all = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []

        // Still checked by hand, and still only a device that answers the report.
        // The dictionary narrows the field; this is what proves the sensor.
        device = all.first { candidate in
            let page = IOHIDDeviceGetProperty(candidate, kIOHIDPrimaryUsagePageKey as CFString) as? Int
            let usage = IOHIDDeviceGetProperty(candidate, kIOHIDPrimaryUsageKey as CFString) as? Int
            guard page == 0x20, usage == 0x8A else { return false }
            return Self.angle(from: candidate) != nil
        }
    }

    private static func angle(from device: IOHIDDevice) -> Double? {
        var buffer = [UInt8](repeating: 0, count: 8)
        var length = buffer.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &buffer, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        return Double(Int(buffer[1]) | Int(buffer[2]) << 8)
    }

    var isAvailable: Bool { device != nil }

    func read() -> Double? {
        #if TILT_TEST_HOOK
        // Only in a binary built by `build.sh --test`, which writes TiltTest.app
        // and never touches Tilt.app. An earlier version of this hook was an
        // ordinary `if` and shipped inside the signed binary, where any local
        // process could have driven the overlay by writing to /tmp.
        if let fake = try? String(contentsOfFile: "/tmp/tilt-fake-lid", encoding: .utf8) {
            let text = fake.trimmingCharacters(in: .whitespacesAndNewlines)
            if text == "nil" { return nil }
            // isFinite, because Double("nan") parses and Int(_:) traps on it:
            // a typo in the file would take the test build down.
            if let value = Double(text), value.isFinite { return value }
        }
        #endif
        guard let device else { return nil }
        return Self.angle(from: device)
    }
}

// MARK: - Stage

/// Black stage holding the captured desktop as a single layer, hinged along its
/// bottom edge the way the real lid is hinged, and pitched by how far the lid
/// has closed past the engage threshold.
final class StageView: NSView {
    private let backdrop = CALayer()
    private let backdropTint = CAGradientLayer()
    private let stage = CALayer()
    private let screen = CALayer()
    private let blurred = CALayer()
    private let blurMask = CAGradientLayer()
    private let dim = CAGradientLayer()
    private let hint = CATextLayer()
    private var heldFrame: CVPixelBuffer?
    private var hasFrame = false

    /// Fired once per engage, when there is finally something to look at.
    var onFirstFrame: (() -> Void)?
    private var aspect: CGFloat = 16.0 / 10.0
    private var lid: Double?

    /// The angle that renders flat. Set by the controller from the menu.
    var threshold = 90.0

    // ponytail: hand-tuned constants, adjustable at runtime because no two lids
    // or seating positions agree. Nothing here is derived from anything.
    /// Where the viewer's eye is assumed to be. The projection is built around
    /// it, so this is not a matter of taste: assume half the real distance and
    /// the fold looks twice as violent as it is. Held in centimetres and
    /// converted using the display's own physical size, so it means the same
    /// thing on a 14-inch panel and a 16-inch one. It does not carry to an
    /// external display at all: that screen does not turn with the lid, which is
    /// why the app only ever runs on the built-in one.
    var viewingDistanceCm = 55.0 { didSet { needsLayout = true } }
    var pointsPerCm = 59.5 { didSet { needsLayout = true } }
    private let hingeBelowGlassCm = 1.0
    private var depth: CGFloat { CGFloat(viewingDistanceCm * pointsPerCm) }

    /// How hard the glass treatment is applied, from the menu bar. Everything
    /// below is written at full strength and scaled by this.
    var glass = 0.65
    private var appliedBlurRadius = -1.0
    private var appliedLid: Double?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let root = layer!
        root.backgroundColor = NSColor.black.cgColor

        // What shows once the panel stops filling the screen: the desktop picture
        // alone, enlarged. Stretching the whole captured frame instead smeared
        // window chrome across the surround, and the wallpaper at its own scale
        // read as the same picture twice. Enlarged it reads as a further-off
        // layer, and the enlargement grows with the fold, so the background
        // pushes in as the panel goes away.
        backdrop.contentsGravity = .resizeAspectFill
        backdrop.masksToBounds = true
        backdrop.opacity = 0

        // A flat tint left the surround within forty levels of the panel, so the
        // panel stopped reading as an object in front of anything. Darkest at the
        // edges, lightest behind the panel: the frame recedes and what is left
        // looks like spill from the screen rather than fog over it.
        root.addSublayer(backdrop)

        backdropTint.type = .radial
        backdropTint.colors = [NSColor.black.withAlphaComponent(0.22).cgColor,
                               NSColor.black.withAlphaComponent(0.72).cgColor]
        backdropTint.locations = [0.0, 1.0]
        backdropTint.startPoint = CGPoint(x: 0.5, y: 0.55)
        backdropTint.endPoint = CGPoint(x: 1.15, y: 1.2)
        backdropTint.opacity = 0
        root.addSublayer(backdropTint)

        screen.anchorPoint = CGPoint(x: 0.5, y: 0) // reset each layout, see below
        screen.contentsGravity = .resizeAspect

        // Depth of field and grazing-angle falloff, both strongest along the far
        // edge. A blurred copy of the same surface, revealed by a gradient mask,
        // is the cheapest way to get a blur that varies across the image - the
        // layer filter itself can only be uniform.
        let clamp = CIFilter(name: "CIAffineClamp")!
        clamp.setValue(CGAffineTransform.identity, forKey: kCIInputTransformKey)
        clamp.name = "clamp"
        let blur = CIFilter(name: "CIGaussianBlur")!
        blur.setValue(0, forKey: kCIInputRadiusKey)
        blur.name = "blur"
        blurred.filters = [clamp, blur]
        blurred.masksToBounds = true
        blurred.opacity = 0

        blurMask.colors = [NSColor.clear.cgColor, NSColor.black.cgColor]
        blurMask.startPoint = CGPoint(x: 0.5, y: 0.45) // sharp up to here
        blurMask.endPoint = CGPoint(x: 0.5, y: 1)
        blurred.mask = blurMask

        // Only where there is a window. Without this the gradient paints the empty
        // space between windows too, putting a dark sheet over the wallpaper.
        dim.compositingFilter = CIFilter(name: "CISourceAtopCompositing")
        dim.colors = [NSColor.clear.cgColor, NSColor.black.cgColor]
        dim.startPoint = CGPoint(x: 0.5, y: 0)
        dim.endPoint = CGPoint(x: 0.5, y: 1)
        dim.opacity = 0

        // Rounded like a panel rather than a bitmap - but only once folded. At
        // rest the radius is zero, because anything else would shave the corners
        // off the real desktop the moment the overlay engages.
        screen.masksToBounds = true

        screen.addSublayer(blurred)
        screen.addSublayer(dim)
        stage.addSublayer(screen)

        hint.fontSize = 13
        hint.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        hint.foregroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
        hint.alignmentMode = .center
        hint.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        hint.opacity = 0
        root.addSublayer(stage)
        // Above the stage: under it a maximised window hides the caption on the
        // single engage it is ever shown, and the key burns either way.
        root.addSublayer(hint)

    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stage.frame = bounds
        // Oversized so the blur never pulls the screen's own edges inward.
        backdropTint.frame = bounds

        // Exactly the screen at lean 0, hinged on its bottom edge where the real
        // lid is hinged. Anything smaller would make the desktop jump the moment
        // the overlay engages.
        let width = bounds.width
        let height = width / aspect
        screen.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        // The real hinge sits a bezel's height below the glass, so rotating about
        // the image's own bottom edge is a systematic error of roughly a tenth of
        // the screen height. Put the axis where the metal is.
        // ponytail: 1.0 cm eyeballed off the chassis, not measured with callipers.
        // If the illusion drifts worst near the hinge, this is the number to check.
        let hinge = CGFloat(hingeBelowGlassCm * pointsPerCm)
        screen.anchorPoint = CGPoint(x: 0.5, y: -hinge / height)
        screen.position = CGPoint(x: bounds.midX, y: -hinge)
        let face = CGRect(x: 0, y: 0, width: width, height: height)
        blurred.frame = face
        blurMask.frame = face
        dim.frame = face
        hint.frame = CGRect(x: bounds.midX - 160, y: 48, width: 320, height: 20)
        applyGeometry()
        CATransaction.commit()
    }

    /// New desktop pixels. Called on the main queue whenever the capture has
    /// something new, which on a still desktop can be never - which is why the
    /// geometry below is driven by the display instead.
    func present(_ pixelBuffer: CVPixelBuffer) {
        heldFrame = pixelBuffer // keep the surface alive until the next frame lands

        let newAspect = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        if abs(newAspect - aspect) > 0.001 {
            aspect = newAspect
            needsLayout = true
        }

        let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        screen.contents = surface
        blurred.contents = surface
        CATransaction.commit()

        if !hasFrame {
            hasFrame = true
            onFirstFrame?()
        }
    }

    /// New lid angle. Called every display refresh, whether or not the desktop
    /// underneath has changed a single pixel.
    func setLid(_ angle: Double?) {
        // The whole subtree recomposites on every geometry write, and the blurred
        // copy is a full-resolution CIGaussianBlur. A lid that is not moving does
        // not need any of that.
        if let angle, let applied = appliedLid, abs(angle - applied) < 0.01 { return }
        appliedLid = angle
        lid = angle
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyGeometry()
        CATransaction.commit()
    }

    /// The desktop picture, drawn behind everything. Kept across sessions: it is
    /// the room the screen sits in, not part of a capture.
    func setWallpaper(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdrop.contents = image
        CATransaction.commit()
    }

    /// Drops the last frame so the next engage cannot flash a stale desktop.
    func reset() {
        hasFrame = false
        heldFrame = nil
        lid = nil
        appliedLid = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        screen.contents = nil
        blurred.contents = nil // a full-resolution surface, held for nothing
        CATransaction.commit()
    }

    /// Degrees the lid has closed past the threshold. The screen has leaned this
    /// far toward the viewer; everything below undoes exactly that.
    private var lean: Double {
        guard let lid else { return 0 }
        // Past about 79 degrees the eye crosses the panel plane and the
        // projection stops meaning anything. Clamping the angle says that;
        // clamping eyeZ afterwards just substituted a number for an undefined
        // view. The lid is nearly shut by then in any case.
        return min(75, max(0, threshold - lid))
    }

    /// Draws the desktop as a plane that stays put in the room while the lid
    /// turns in front of it.
    ///
    /// Rotating the image alone does not read as "fixed" - it reads as an image
    /// lying down, because the projection still looks from straight ahead. In
    /// the lid's own frame a viewer sitting still is *also* swinging around the
    /// hinge, so the eye has to travel with it. Both the plane and the eye are
    /// world-fixed; both are expressed here in the lid's rotating frame.
    private func applyGeometry() {
        let radians = CGFloat(lean) * .pi / 180
        let height = screen.bounds.height
        guard height > 0 else { return }

        // Eye at rest: level with the middle of the screen, `depth` in front of
        // it, measured from the hinge the panel actually turns on.
        let restY = height / 2 + CGFloat(hingeBelowGlassCm * pointsPerCm)
        let eyeY = restY * cos(radians) + depth * sin(radians)
        let eyeZ = max(120, -restY * sin(radians) + depth * cos(radians))

        // Projection centred on where the eye now sits, not on the middle of
        // the stage, which is what turns the rotation into a fixed window.
        // Zero while layout() keeps the screen layer centred, which it does.
        // Left in rather than folded away so both axes read the same if the
        // layer ever moves off centre.
        let offsetX = screen.position.x - bounds.midX
        let offsetY = screen.position.y + eyeY - bounds.midY

        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / eyeZ
        var projection = CATransform3DMakeTranslation(-offsetX, -offsetY, 0)
        projection = CATransform3DConcat(projection, perspective)
        projection = CATransform3DConcat(
            projection, CATransform3DMakeTranslation(offsetX, offsetY, 0))
        stage.sublayerTransform = projection

        screen.transform = CATransform3DRotate(
            CATransform3DIdentity, -radians, 1, 0, 0)

        // Parallax, starting at exactly 1. Anything else and the wallpaper would
        // not line up with the windows sitting on it at lean 0.
        let zoom = 1 + 0.22 * CGFloat(min(1, lean / 45))
        backdrop.bounds = CGRect(x: 0, y: 0, width: bounds.width * zoom,
                                 height: bounds.height * zoom)
        backdrop.position = CGPoint(x: bounds.midX, y: bounds.midY)

        applyDepthCues()
    }

    /// The published numbers - 72px of blur, dimming at twice the fold's progress
    /// - come from a transition that ends with the panel closed and gone. A lid
    /// has to stay readable the whole way, and at twice the progress the dim hits
    /// its ceiling barely a third of the way in, so these are the same cues at
    /// roughly half the strength.
    private func applyDepthCues() {
        // Full strength the whole time. The panel carries only the windows now, so
        // the wallpaper behind is not a backdrop that appears when the fold
        // starts - it is the desktop, and at lean 0 the two together have to be
        // the screen exactly as it was.
        backdrop.opacity = 1
        backdropTint.opacity = Float(min(1, max(0, lean / 18)))

        guard glass > 0 else {
            blurred.opacity = 0
            dim.opacity = 0
            screen.opacity = 1
            return
        }
        let full = 60.0
        let t = min(1, max(0, lean / full))

        // Opacity and radius used to be scaled by the same two factors, so at
        // Medium the far edge was a third of a 14px blur over a sharp original:
        // arithmetically present, visually absent. The mask already confines the
        // blurred copy to the far end, so it may as well be fully opaque there,
        // and the strength belongs entirely to the radius.
        blurred.opacity = Float(min(1, t * 3))
        let radius = 40 * t * glass
        if abs(radius - appliedBlurRadius) > 0.4 {
            appliedBlurRadius = radius
            blurred.setValue(radius, forKeyPath: "filters.blur.inputRadius")
        }
        dim.opacity = Float(min(0.45, t) * glass)

        // Closing dims the whole panel, not just the end that is tilting away -
        // the stage behind is black, so leaning on the layer's own opacity costs
        // nothing and reverses exactly as the lid opens again.
        screen.opacity = Float(1 - 0.55 * t * glass)

        // No corner radius: there is no panel any more, only the windows, and each
        // already carries its own rounding.
    }


    /// Shown on the first engage of the app's life and never again. Two ways out
    /// exist and neither is discoverable: a permanent caption would be chrome on
    /// an effect whose whole point is the picture, and none at all leaves a user
    /// covered by something they were never told how to dismiss.
    func showHint() {
        hint.string = "esc or click to dismiss"
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hint.opacity = 1
        CATransaction.commit()

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 2.5
        fade.duration = 0.8
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        hint.add(fade, forKey: "fade")
    }

    /// A click is the escape hatch that does not need the app to be frontmost.
    ///
    /// Both halves are load-bearing. Without `acceptsFirstMouse` AppKit spends the
    /// first click on activating the window and never delivers it, which is
    /// exactly the case this hatch exists for: the app did not have focus.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }

    var onDismiss: (() -> Void)?
}

// MARK: - Capture

/// Owns the ScreenCaptureKit session.
///
/// Every lifecycle method runs on the main actor and carries a generation token.
/// Starting and stopping are both asynchronous, and they used to be invisible to
/// each other: cancel an engagement while the stream was still spinning up and
/// the completed start installed a live capture that nothing was watching and
/// nothing would ever stop.
final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "tilt.capture")
    private var stream: SCStream?
    private var filter: SCContentFilter?
    private var config: SCStreamConfiguration?
    private var filterExcludedSelf = false
    private var preparation: Task<Void, Error>?
    private var generation = 0
    private weak var view: StageView?

    /// Called on the main queue when the system stops the stream underneath us -
    /// permission revoked, display detached, and so on. Without it the overlay
    /// sits frozen over the desktop while this class still believes it is
    /// capturing.
    var onStreamStopped: ((Error) -> Void)?

    // The capture queue can outrun the main thread, and a backlog of stale
    // frames delivered in order is exactly the stutter this app cannot have.
    // Only the newest frame is ever worth presenting.
    private let pendingLock = NSLock()
    private var pendingBuffer: CVPixelBuffer?
    private var deliveryScheduled = false

    init(view: StageView) {
        self.view = view
    }

    @MainActor var isRunning: Bool { stream != nil }

    /// Builds the filter ahead of time. Enumerating every window on screen took
    /// 1.8 seconds on this machine, so doing it on the first engage meant closing
    /// the lid and waiting two seconds for anything to appear.
    @MainActor
    func prepare(on nsScreen: NSScreen, excludingWindow windowNumber: Int) async {
        try? await ensureFilter(on: nsScreen, excludingWindow: windowNumber)
    }

    /// One still of the desktop with every window excluded, which is the
    /// wallpaper. It changes about never, so a single shot beats a second stream.
    ///
    /// `excludingDesktopWindows: true` keeps the desktop out of the returned list,
    /// so excluding everything in that list leaves the desktop behind, which is
    /// the point. Asking for the full list excluded the wallpaper too, left
    /// nothing to capture, and the shot failed outright.
    @MainActor
    func captureWallpaper(on nsScreen: NSScreen) async -> CGImage? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true) else { return nil }
        let displayID = (nsScreen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == displayID })
        else { return nil }

        let filter = SCContentFilter(display: display, excludingWindows: content.windows)
        let configuration = SCStreamConfiguration()
        let scale = nsScreen.backingScaleFactor
        configuration.width = Int(CGFloat(display.width) * scale)
        configuration.height = Int(CGFloat(display.height) * scale)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        return try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration)
    }

    /// Drops the cached filter. The display it describes can stop existing.
    @MainActor
    func invalidateFilter() {
        filter = nil
        config = nil
        filterExcludedSelf = false
    }

    @MainActor
    private func ensureFilter(on nsScreen: NSScreen, excludingWindow windowNumber: Int) async throws {
        if filter != nil, config != nil, filterExcludedSelf { return }
        // One build at a time. Prewarming at launch and a fast first engage used
        // to enter here together and enumerate the window list twice, both
        // writing the result.
        if let preparation {
            try await preparation.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try await self.buildFilter(on: nsScreen, excludingWindow: windowNumber)
        }
        preparation = task
        defer { preparation = nil }
        try await task.value
    }

    /// Captures the display the overlay sits on, minus the overlay itself -
    /// without the exclusion the stage would film its own output forever.
    @MainActor
    private func buildFilter(on nsScreen: NSScreen, excludingWindow windowNumber: Int) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true)
        let displayID = (nsScreen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        // No falling back to whatever display comes first: showing another
        // monitor's contents on this one is worse than showing nothing.
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }

        // Windows only, over nothing. The desktop picture is already drawn flat
        // behind the panel, and capturing it again put the same wallpaper on
        // screen twice at two different angles. Leaving it out of the panel is
        // what turns the effect from "the screen tilted" into "the windows came
        // off the desktop".
        let mine = CGWindowID(windowNumber)
        let lifted = content.windows.filter { $0.windowID != mine && $0.isOnScreen }
        filter = SCContentFilter(display: display, including: lifted)
        // Reverted to the original condition. Setting this true unconditionally
        // caches the prewarm's filter on every path, including the launch-time
        // one a fast first close reuses, and that is the shape of a reported
        // fault this machine cannot reproduce. The redundant enumeration it
        // costs on a bare desktop is a measured price; this is not.
        filterExcludedSelf = !lifted.isEmpty

        let configuration = SCStreamConfiguration()
        let scale = nsScreen.backingScaleFactor
        configuration.width = Int(CGFloat(display.width) * scale)
        configuration.height = Int(CGFloat(display.height) * scale)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.backgroundColor = .clear // everything but the windows
        configuration.showsCursor = true
        configuration.queueDepth = 5
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 120)
        config = configuration
    }

    @MainActor
    func start(on nsScreen: NSScreen, excludingWindow windowNumber: Int) async throws {
        guard stream == nil else { return }
        generation += 1
        let token = generation

        try await ensureFilter(on: nsScreen, excludingWindow: windowNumber)
        guard token == generation else { return } // stopped while preparing
        guard let filter, let config else { throw CaptureError.noDisplay }

        let created = SCStream(filter: filter, configuration: config, delegate: self)
        try created.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await created.startCapture()
        guard token == generation else { // stopped while the stream spun up
            try? await created.stopCapture()
            return
        }
        stream = created
    }

    /// Stopped rather than left idle: a full-resolution capture running behind a
    /// hidden window is battery spent on nothing.
    /// Windows open, close and move while the overlay is up, and the filter is a
    /// fixed list. Cheap to refresh once the content has been enumerated at least
    /// once, and updating the filter does not interrupt the stream.
    @MainActor
    func refreshWindows(on nsScreen: NSScreen, excludingWindow windowNumber: Int) async {
        guard let stream else { return }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true) else { return }
        let displayID = (nsScreen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == displayID })
        else { return }
        let mine = CGWindowID(windowNumber)
        let lifted = content.windows.filter { $0.windowID != mine && $0.isOnScreen }
        guard !lifted.isEmpty else { return }
        let updated = SCContentFilter(display: display, including: lifted)
        filter = updated
        do {
            try await stream.updateContentFilter(updated)
        } catch {
            // A refused update leaves the panel folding the window list it had.
            // Drop the cache so the next engagement builds a fresh one rather
            // than showing a stale desktop for the rest of the session.
            invalidateFilter()
        }
    }

    @MainActor
    func stop() {
        generation += 1 // any start still in flight is now stale
        pendingLock.lock()
        pendingBuffer = nil
        pendingLock.unlock()
        guard let stream else { return }
        self.stream = nil
        Task { try? await stream.stopCapture() }
    }

    enum CaptureError: LocalizedError {
        case noDisplay
        case noWallpaper

        var errorDescription: String? {
            switch self {
            case .noDisplay: return "the display Tilt draws on went away"
            case .noWallpaper: return "the desktop picture could not be read"
            }
        }
    }

    func stream(_ stopped: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stopped else { return }
            self.stream = nil
            self.generation += 1
            self.onStreamStopped?(error)
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer,
              isComplete(sampleBuffer) else { return }

        pendingLock.lock()
        pendingBuffer = pixelBuffer
        let needsDelivery = !deliveryScheduled
        deliveryScheduled = true
        pendingLock.unlock()
        guard needsDelivery else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingLock.lock()
            let buffer = self.pendingBuffer
            self.pendingBuffer = nil
            self.deliveryScheduled = false
            self.pendingLock.unlock()
            if let buffer { self.view?.present(buffer) }
        }
    }

    /// ScreenCaptureKit also emits idle and blank frames whose pixels are stale.
    private func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let raw = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: raw)
        else { return false }
        return status == .complete
    }
}

// MARK: - App

/// One Euro filter (Casiez, Roussel & Vogel, CHI 2012).
///
/// The sensor only resolves whole degrees, and a plain lowpass has to pick a
/// side: smooth enough to hide a 1 degree step and it lags a fast close, quick
/// enough to keep up and the steps show whenever the lid creeps. This moves its
/// own cutoff with the measured speed, so it can do both.
struct OneEuroFilter {
    var minCutoff = 0.6 // Hz, how hard it smooths when nothing is moving
    var beta = 0.05 // how fast the cutoff opens up as the lid speeds up
    var derivativeCutoff = 1.0

    private var value: Double?
    private var speed = 0.0

    private func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * .pi * cutoff)
        return 1 / (1 + tau / dt)
    }

    mutating func callAsFunction(_ x: Double, dt: Double) -> Double {
        guard let previous = value else { value = x; return x }
        speed += alpha(cutoff: derivativeCutoff, dt: dt) * ((x - previous) / dt - speed)
        let filtered = previous + alpha(cutoff: minCutoff + beta * abs(speed), dt: dt) * (x - previous)
        value = filtered
        return filtered
    }

    mutating func reset(to x: Double?) {
        value = x
        speed = 0
    }
}

/// One labelled slider, sized to sit inside an NSMenuItem.
///
/// All three settings are continuous quantities - an angle, a distance, an
/// intensity - and were being offered as five or seven fixed stops because a
/// plain menu cannot do better. A menu item with a custom view can.
final class SliderRow: NSView {
    let slider = NSSlider()
    private let readout = NSTextField(labelWithString: "")
    private let caption: (Double) -> String

    /// `step` is what the control is actually for. Neither setting is meaningful
    /// to the degree or the centimetre - a lid does not rest that precisely and
    /// nobody measures where they sit - so the slider snaps, and the ticks say
    /// where it will land.
    init(title: String, range: ClosedRange<Double>, step: Double, value: Double,
         caption: @escaping (Double) -> String, target: AnyObject, action: Selector) {
        self.caption = caption
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 56))

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 13)
        label.frame = NSRect(x: 16, y: 34, width: 180, height: 17)
        addSubview(label)

        readout.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        readout.textColor = .secondaryLabelColor
        readout.alignment = .right
        readout.frame = NSRect(x: 194, y: 35, width: 92, height: 14) // +2 for its alignment inset
        addSubview(readout)

        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.numberOfTickMarks = Int((range.upperBound - range.lowerBound) / step) + 1
        slider.allowsTickMarkValuesOnly = true
        slider.tickMarkPosition = .below
        slider.doubleValue = value
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = target
        slider.action = action
        slider.frame = NSRect(x: 16, y: 6, width: 268, height: 22)
        addSubview(slider)

        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refresh() { readout.stringValue = caption(slider.doubleValue) }
}

/// A labelled segmented control, sized to sit inside an NSMenuItem.
///
/// Used where the choices are named presets rather than a quantity: four stops a
/// reader can compare at a glance beat a percentage they have to interpret.
final class SegmentRow: NSView {
    let segments = NSSegmentedControl()
    let values: [Double]

    init(title: String, labels: [String], values: [Double], current: Double,
         target: AnyObject, action: Selector) {
        self.values = values
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 56))

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 13)
        label.frame = NSRect(x: 16, y: 34, width: 268, height: 17)
        addSubview(label)

        segments.segmentCount = labels.count
        segments.trackingMode = .selectOne
        segments.controlSize = .regular
        segments.segmentDistribution = .fillEqually
        for (i, text) in labels.enumerated() {
            segments.setLabel(text, forSegment: i)
            segments.setWidth(0, forSegment: i) // 0 means let the control divide it up
        }
        // Nearest, not equal: the value can have come from an older build, and
        // no segment selected reads as broken.
        segments.selectedSegment = values.enumerated()
            .min { abs($0.element - current) < abs($1.element - current) }?.offset ?? 0
        segments.target = target
        segments.action = action
        segments.frame = NSRect(x: 16, y: 6, width: 268, height: 24)
        addSubview(segments)
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// A labelled switch, sized to sit inside an NSMenuItem. The on/off state of the
/// whole app is a toggle, and a checkmark beside a word is a weaker way to say so.
/// One paragraph, wrapped, at the width the other rows use. Three disabled
/// items in a row read as a wall of text in a menu; a menu item is a line, and
/// prose that needs more than one belongs in one view rather than stacked.
final class NoteRow: NSView {
    init(_ text: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 0))
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .menuFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.isSelectable = false
        // The width has to be settled before the height is asked for. sizeToFit
        // on a wrapping label widens it to one line instead of wrapping, which
        // is the whole point of the row.
        label.preferredMaxLayoutWidth = 268
        let height = label.sizeThatFits(
            NSSize(width: 268, height: CGFloat.greatestFiniteMagnitude)).height
        label.frame = NSRect(x: 16, y: 8, width: 268, height: height)
        addSubview(label)
        setFrameSize(NSSize(width: 300, height: height + 16))
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class SwitchRow: NSView {
    let toggle = NSSwitch()

    init(title: String, isOn: Bool, target: AnyObject, action: Selector) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 34))

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 13)
        label.frame = NSRect(x: 16, y: 9, width: 160, height: 17)
        addSubview(label)

        toggle.state = isOn ? .on : .off
        // No controlSize here. `.mini` shrinks what NSSwitch draws but not what
        // sizeToFit reports, so the pill ends up left-aligned inside a 54pt box
        // and sits visibly short of the sliders it is meant to line up with.
        toggle.target = target
        toggle.action = action
        toggle.sizeToFit()
        toggle.setFrameOrigin(NSPoint(x: 284 - toggle.frame.width,
                                      y: (34 - toggle.frame.height) / 2))
        addSubview(toggle)
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let sensor = LidAngleSensor()
    private var window: OverlayWindow!
    private var view: StageView!
    private var capture: DesktopCapture!
    private var statusItem: NSStatusItem!
    private var escapeMonitor: Any?
    private var needsScreenRecording = false
    private var sampler: DispatchSourceTimer?
    private var windowRefresh: Timer?
    private let sensorQueue = DispatchQueue(label: "tilt.sensor")
    private var displayLink: CADisplayLink?
    private var rawLid: Double? // main thread only
    private var smoothLid: Double? // main thread only
    private var filter = OneEuroFilter()
    private var shownDegrees = Int.min
    private var lastGoodSample = Date()
    private var transition = 0
    /// Why the overlay is being held off the screen. Empty means armed.
    ///
    /// One flag could not carry this. The lid coming back past the threshold has
    /// to re-arm a dismissal, and with a single flag it re-armed a sleep, a lock
    /// and a missing panel along with it: locking at an angle and opening again
    /// could put the overlay over the lock screen, and a panel that came back
    /// stayed suppressed because nothing here knew why it had been set. Each
    /// reason is now lifted by the thing that set it.
    private struct Suppression: OptionSet {
        let rawValue: Int
        /// esc or a click while the overlay was up.
        static let dismissed = Suppression(rawValue: 1 << 0)
        /// A capture that failed to start.
        static let capture = Suppression(rawValue: 1 << 1)
        /// Sleep, lock, or another user taking the session.
        static let session = Suppression(rawValue: 1 << 2)
        /// The built-in panel left the screen list: clamshell, or never there.
        static let panel = Suppression(rawValue: 1 << 3)
    }
    private var suppression: Suppression = []
    private var suppressed: Bool { !suppression.isEmpty }
    private var captureFailure: Error?
    private var lastStep: CFTimeInterval = 0
    private var engaged = false
    private var nsScreen: NSScreen!

    /// The built-in panel, never merely the main one. The whole illusion is that
    /// this plane is fixed while the lid turns in front of it, and an external
    /// display does not turn.
    static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first(where: isBuiltIn)
    }

    static func isBuiltIn(_ screen: NSScreen) -> Bool {
        let id = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return CGDisplayIsBuiltin(id) != 0
    }

    private static let fade = 0.16
    /// Below this the panel is nearly shut and the machine is usually on its way
    /// to sleep. Closing a laptop to walk away should not start a capture.
    private static let floorDegrees = 20.0
    private static let idleSampleHz = 30.0
    private static let activeSampleHz = 120.0

    private static let thresholdKey = "engageBelowDegrees"
    private static let enabledKey = "enabled"
    private static let hintShownKey = "dismissHintShown"
    private static let glassKey = "glassIntensity"
    private static let distanceKey = "viewingDistanceCm"
    private static let showsAngleKey = "showsAngleInMenuBar"

    private var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            if !enabled { disengage() }
        }
    }

    /// On by default, and worth keeping that way: the number is the only sign
    /// from outside that the sensor is being read at all. With it off a working
    /// app and a dead one look the same in the menu bar.
    private var showsAngle: Bool {
        didSet {
            UserDefaults.standard.set(showsAngle, forKey: Self.showsAngleKey)
            shownDegrees = Int.min          // force the next sample to redraw
            statusItem.button?.title = ""
        }
    }

    private var distanceCm: Double {
        didSet {
            UserDefaults.standard.set(distanceCm, forKey: Self.distanceKey)
            view?.viewingDistanceCm = distanceCm
        }
    }

    private var glass: Double {
        didSet {
            UserDefaults.standard.set(glass, forKey: Self.glassKey)
            view?.glass = glass
        }
    }
    private var threshold: Double {
        didSet {
            UserDefaults.standard.set(threshold, forKey: Self.thresholdKey)
            view?.threshold = threshold
        }
    }

    override init() {
        let stored = UserDefaults.standard.double(forKey: Self.thresholdKey)
        threshold = stored > 0 ? stored : 90
        // `object(forKey:)` rather than `double(forKey:)`: zero is a real setting
        // here, and the two are indistinguishable otherwise.
        glass = UserDefaults.standard.object(forKey: Self.glassKey) as? Double ?? 0.65
        distanceCm = UserDefaults.standard.object(forKey: Self.distanceKey) as? Double ?? 55
        enabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        showsAngle = UserDefaults.standard.object(forKey: Self.showsAngleKey) as? Bool ?? true
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        // Before the permission guard: these only register notifications, and
        // installed after it a permission granted later is never picked up.
        installObservers()
        guard hasScreenRecordingAccess() else { return }
        // Clamshell at launch, or an external display only: the panel this app
        // is about does not exist yet. Everything above is already installed, so
        // opening the lid later reaches displayConfigurationChanged and sets up
        // then, instead of leaving a live-looking menu attached to nothing.
        guard let screen = Self.builtInScreen() else {
            rebuildMenu()
            return
        }
        setUp(on: screen)
    }

    private func setUp(on screen: NSScreen) {
        nsScreen = screen

        view = StageView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.threshold = threshold
        view.glass = glass
        view.viewingDistanceCm = distanceCm
        applyScreenMetrics(screen)
        window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                               backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.fullScreenNone, .stationary, .ignoresCycle, .canJoinAllSpaces]
        window.backgroundColor = .black
        window.isOpaque = true
        window.contentView = view
        capture = DesktopCapture(view: view)
        // Guarded on `engaged`: stopping the stream is asynchronous, so a frame
        // can still land after disengaging, and with the view just reset it
        // looks like the first frame of a new session and puts the window back
        // up with nothing left to take it down again.
        view.onFirstFrame = { [weak self] in
            guard let self, self.engaged else { return }
            self.show()
            if !UserDefaults.standard.bool(forKey: Self.hintShownKey) {
                UserDefaults.standard.set(true, forKey: Self.hintShownKey)
                self.view.showHint()
            }
        }
        capture.onStreamStopped = { [weak self] _ in
            // Permission revoked, display gone, the system deciding otherwise.
            // Whatever it was, the overlay is now a frozen picture over the
            // desktop, so take it down rather than leave it there.
            self?.disengage()
        }
        Task {
            await capture.prepare(on: screen, excludingWindow: window.windowNumber)
            self.view.setWallpaper(await capture.captureWallpaper(on: screen))
        }

        // A second way out that does not depend on the app winning activation.
        // A click on an inactive app's window still reaches it, so this works in
        // the case where escape cannot: a fullscreen app holding the foreground
        // when the lid dips.
        view.onDismiss = { [weak self] in
            self?.suppression.insert(.dismissed)
            self?.disengage()
        }

        // Escape, and nothing else. Every other key used to be swallowed here and
        // fed to hidden state that no menu item could see or undo: one stray "0"
        // flipped the fold direction for the rest of the process's life.
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.engaged, event.keyCode == 53 else { return event }
            self.suppression.insert(.dismissed)
            self.disengage()
            return nil
        }
        rebuildMenu()

        // A feature report costs 0.4 ms, far too much to spend on the main thread
        // every frame, so sampling runs off to the side and the display link
        // interpolates between the samples. The rate follows the need: while the
        // overlay is up every millisecond of sampling delay is lag you can see,
        // and while it is not, the only question is whether the lid has crossed
        // the threshold yet.
        let sampler = DispatchSource.makeTimerSource(queue: sensorQueue)
        sampler.schedule(deadline: .now(), repeating: 1.0 / Self.idleSampleHz)
        sampler.setEventHandler { [weak self] in
            let angle = self?.sensor.read()
            DispatchQueue.main.async { self?.sample(angle) }
        }
        sampler.resume()
        self.sampler = sampler

        // The filter names specific windows, and windows come and go. One second
        // is slack enough not to matter and cheap once the content has been
        // enumerated: updateContentFilter does not interrupt the stream.
        windowRefresh = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Timer fires on the main run loop; the compiler cannot see that
            // through a Sendable closure.
            MainActor.assumeIsolated {
                guard let self, self.engaged else { return }
                Task { @MainActor in
                    await self.capture.refreshWindows(
                        on: self.nsScreen, excludingWindow: self.window.windowNumber)
                }
            }
        }

        // Off the screen rather than the view: the view's window is hidden most
        // of the time, and a link bound to it would not tick.
        installDisplayLink(on: screen)
    }

    /// One HID sample. Decides engagement; the smoothing happens per frame.
    private func sample(_ sensorAngle: Double?) {
        let angle = sensorAngle
        // A sensor that stops answering used to mean the last angle stood
        // forever: open the lid with the overlay up and it would keep covering
        // the screen. Silence for long enough is a reason to get out of the way.
        guard let angle else {
            if engaged, Date().timeIntervalSince(lastGoodSample) > 1.5 {
                disengage()
            }
            return
        }
        lastGoodSample = Date()
        rawLid = angle
        let degrees = Int(angle.rounded())
        if degrees != shownDegrees, showsAngle {
            shownDegrees = degrees
            statusItem.button?.title = " \(degrees)°"
        }
        // 2 degrees of slack: without it a lid resting on the threshold flickers
        // the overlay on and off several times a second.
        //
        // Only what the lid itself is the answer to. A sleep, a lock and a
        // missing panel are not re-armed by an angle, and lifting those here is
        // how the overlay reached a lock screen.
        if angle > threshold + 2 { suppression.subtract([.dismissed, .capture]) }
        if engaged {
            if angle > threshold + 2 || angle < Self.floorDegrees { disengage() }
        } else if enabled, !suppressed, angle < threshold, angle > Self.floorDegrees + 2 {
            engage()
        }
    }

    /// Measured at a steady 120Hz on this display, so the only thing left between
    /// the lid and the screen is the filter.
    @objc private func step(_ link: CADisplayLink) {
        // On the main thread on purpose. The staleness check in sample() runs
        // inside the sampler's own handler, so it cannot fire when the sampler
        // is what stopped, and this overlay covers everything.
        if engaged, Date().timeIntervalSince(lastGoodSample) > 1.5 {
            disengage()
            return
        }
        guard let raw = rawLid else { return }
        // Elapsed, not `targetTimestamp - timestamp`. That is the display's
        // nominal cadence, so under dropped frames it tells the filter less time
        // passed than did and the smoothing comes out wrong exactly when the
        // machine is busiest.
        let now = link.timestamp
        let dt = lastStep > 0 ? min(0.1, max(1.0 / 240, now - lastStep)) : 1.0 / 120
        lastStep = now
        smoothLid = filter(raw, dt: dt)
        view.setLid(smoothLid)
    }

    // MARK: engage / disengage

    /// The window waits for the first captured frame. Ordering it front here
    /// instead put a black rectangle on screen for as long as the stream took to
    /// spin up, which read as the picture cutting out. Focus is taken in show(),
    /// and the reason is written there.
    private func engage() {
        guard !engaged else { return }
        // nsScreen outlives the screen it names: when the built-in panel goes
        // away the app stands down but keeps the reference, and several paths
        // clear the suppression independently, so check the screen itself rather
        // than trusting the state to have caught every route back here.
        guard nsScreen.map(Self.isBuiltIn) == true else { return }
        engaged = true
        transition += 1
        smoothLid = rawLid // start exactly where the lid is, not where it was
        filter.reset(to: rawLid)
        lastStep = 0
        view.setLid(rawLid)

 // or the first frame draws with the last session's angle
        sampler?.schedule(deadline: .now(), repeating: 1.0 / Self.activeSampleHz)
        displayLink?.isPaused = false

        // Re-engaging mid fade-out: the stream never stopped, so no first frame
        // is coming and the window has to be brought back by hand.
        if capture.isRunning {
            show()
            return
        }
        Task { @MainActor in
            do {
                // Before the stream, not after it. The desktop picture is
                // changed only while the overlay is down, so the start of an
                // engagement is the one moment it can be stale. Taken after
                // start() the shot raced the first frame: show() puts the
                // overlay on screen between this call's window enumeration and
                // its screenshot, a window absent from that list cannot be
                // excluded from the shot, and the still came back with the
                // overlay's own output baked into it. The windows were then on
                // screen twice, once flat in the backdrop and once folded over
                // it, which is decision 002's fault arriving by another road.
                if let fresh = await capture.captureWallpaper(on: nsScreen) {
                    self.view.setWallpaper(fresh)
                    // A shot that arrived retires whatever failed last time.
                    // Without this the menu offers Try again for the rest of the
                    // session over a failure that is long over.
                    self.captureFailure = nil
                } else {
                    // A still that did not arrive is the black surround decision
                    // 002 describes, and it used to happen with nothing said.
                    self.captureFailure = DesktopCapture.CaptureError.noWallpaper
                }
                try await capture.start(on: nsScreen, excludingWindow: window.windowNumber)
                self.rebuildMenu()
            } catch {
                // No modal here. disengage() has already cleared `engaged`, the
                // main queue keeps draining inside a modal run loop, and the
                // sampler re-enters engage() on the next tick, so an alert here
                // stacks alerts for as long as the failure lasts.
                self.suppression.insert(.capture)
                self.captureFailure = error
                self.disengage()
                self.rebuildMenu()
            }
        }
    }

    /// Fades rather than appears. The smoothed angle trails the lid by a degree
    /// or so, so at the moment of crossing the stage is never quite flat, and
    /// snapping it on and off reads as a jolt.
    private func show() {
        if !window.isVisible {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        // Taking focus is not cosmetic. Without it the overlay covers the screen
        // while every keystroke still reaches whatever app is underneath, so a
        // lid closing over a terminal means typing blind into a live session -
        // and the escape key cannot reach us either, because a local event
        // monitor only sees events already dispatched to this process.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fade
            window.animator().alphaValue = 1
        }
    }

    private func disengage() {
        guard engaged else { return }
        engaged = false
        transition += 1
        let token = transition
        guard window.isVisible else {
            finishDisengage()
            return
        }
        // Capture and the display link stay up for the length of the fade, so
        // what fades out is still live and still tracking the lid.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fade
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // NSAnimationContext calls this on the main thread; the compiler
            // cannot see that through a Sendable closure.
            MainActor.assumeIsolated {
                guard let self, !self.engaged, self.transition == token else { return }
                self.finishDisengage()
            }
        })

        // Belt and braces. If that completion never arrives the window stays
        // ordered in - invisible, but still capturing, and one stuck overlay was
        // enough. finishDisengage is idempotent.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fade + 0.2) { [weak self] in
            guard let self, !self.engaged, self.transition == token else { return }
            self.finishDisengage()
        }
    }

    private func finishDisengage() {
        // Hand focus back to whatever the user was in before the lid moved.
        if NSApp.isActive { NSApp.hide(nil) }
        sampler?.schedule(deadline: .now(), repeating: 1.0 / Self.idleSampleHz)
        displayLink?.isPaused = true
        capture.stop()
        window.orderOut(nil)
        view.reset()
    }

    private func installObservers() {
        // The cached filter describes a display that can stop existing, and the
        // overlay's own frame is the launch screen's. Both have to be rebuilt.
        NotificationCenter.default.addObserver(
            self, selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)

        // Every other way the session can go out from under a fullscreen overlay.
        // None of them changes the screen list, so none reaches the observer
        // above, and all of them end with the overlay covering something that is
        // no longer ours.
        for name in [NSWorkspace.willSleepNotification,
                     NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(standDown), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(standDown),
            name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)

        // Every stand-down needs its matching resume. Without them the
        // suppression outlives the condition that set it, and the next thing the
        // user does - usually opening the lid - happens with the app still
        // hiding from a sleep that ended.
        for name in [NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(standUp), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(standUp),
            name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    /// Sleep, lock, or another user taking the session. Get off the screen and
    /// stay off, so waking up does not find the overlay already there.
    @objc private func standDown() {
        suppression.insert(.session)
        disengage()
    }

    /// The screen came back, or the session did. Arm again.
    @objc private func standUp() {
        suppression.remove(.session)
    }

    /// Waking lifts that suppression, and it has to.
    ///
    /// Going to sleep is almost always a lid being shut, so the suppression
    /// standDown sets is still in force on the way back up - and it only cleared
    /// above the threshold. The whole opening arc, which is the half of the fold
    /// worth watching, was being skipped because the app was still hiding from a
    /// sleep that had already ended.
    @objc private func systemDidWake() {
        suppression.remove(.session)
        displayConfigurationChanged()
    }

    /// Off the screen rather than the view: the view's window is hidden most of
    /// the time, and a link bound to it would not tick.
    private func installDisplayLink(on screen: NSScreen) {
        displayLink?.invalidate()
        let link = screen.displayLink(target: self, selector: #selector(step(_:)))
        link.isPaused = !engaged
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// A resolution change, a display plugged or unplugged, or a wake from
    /// sleep. The capture filter names a display by id and the window was sized
    /// to whatever screen existed at launch, so both are rebuilt from scratch.
    @objc private func displayConfigurationChanged() {
        guard let screen = Self.builtInScreen() else {
            // The panel went away: clamshell, or it was never there. Off the
            // screen and wait; the observers stay installed. Not standDown: its
            // reason is the session, and this one is lifted by the panel.
            suppression.insert(.panel)
            disengage()
            rebuildMenu()
            return
        }
        // The panel is back, so the reason the branch above set is over. Nothing
        // else lifts it: systemDidWake does it for a sleep, but closing onto an
        // external display is clamshell rather than sleep, so that never arrives
        // and the whole opening arc was skipped. A sleep or a lock keeps hiding.
        suppression.remove(.panel)
        guard window != nil else { // first time the panel has existed
            setUp(on: screen)
            return
        }
        disengage()
        capture.invalidateFilter()
        nsScreen = screen
        window.setFrame(screen.frame, display: false)
        view.frame = NSRect(origin: .zero, size: screen.frame.size)
        view.needsLayout = true
        applyScreenMetrics(screen)
        // The link is bound to a specific screen. Left alone it keeps the old
        // one's cadence or stops ticking, and step() is the only thing that ever
        // updates the geometry, so the stage would freeze mid-fold.
        installDisplayLink(on: screen)
        Task {
            await capture.prepare(on: screen, excludingWindow: window.windowNumber)
            self.view.setWallpaper(await capture.captureWallpaper(on: screen))
        }
    }

    /// Points per centimetre from the panel itself, so the viewing distance is a
    /// real distance rather than a number that happens to look right here.
    private func applyScreenMetrics(_ screen: NSScreen) {
        let displayID = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let millimetres = CGDisplayScreenSize(displayID)
        if millimetres.height > 0 {
            view.pointsPerCm = Double(screen.frame.height) / (Double(millimetres.height) / 10)
        }
    }

    // MARK: menu bar

    /// The menu bar glyph, from Tabler Icons (MIT). NSImage reads SVG directly,
    /// so it stays vector, and `isTemplate` is what lets the menu bar invert it
    /// for a light bar instead of leaving a black shape on black.
    private static func menuBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 17, height: 17)
        image.isTemplate = true
        image.accessibilityDescription = "Tilt"
        return image
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.menuBarIcon()
        statusItem.button?.imagePosition = .imageLeading
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        if statusItem.menu == nil {
            let built = NSMenu()
            built.autoenablesItems = false
            built.delegate = self
            statusItem.menu = built
        }
        populate(statusItem.menu!)
    }

    /// Rebuilt each time the menu opens rather than on every settings change:
    /// dragging a slider changes a setting on every mouse-moved event, and
    /// rebuilding underneath the drag would throw away the view being dragged.
    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Nothing to set up with until the permission is there: the switch, the
        // sliders and the glass all drive an overlay that cannot draw. Show what
        // finishes setup and nothing else.
        if needsScreenRecording {
            let note = NSMenuItem()
            note.view = NoteRow(
                "Tilt draws your desktop, so macOS counts that as screen "
                + "recording. Switch it on, then let macOS quit and reopen Tilt.")
            menu.addItem(note)
            let open = NSMenuItem(title: "Open Screen Recording settings…",
                                  action: #selector(openScreenRecordingSettings),
                                  keyEquivalent: "")
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
            addQuit(to: menu)
            return
        }

        let onOff = NSMenuItem()
        onOff.view = SwitchRow(title: "Enabled", isOn: enabled,
                               target: self, action: #selector(enabledSwitched(_:)))
        menu.addItem(onOff)

        if nsScreen == nil {
            let none = NSMenuItem(title: "Waiting for the built-in display",
                                  action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        if !sensor.isAvailable {
            let none = NSMenuItem(title: "No lid angle sensor on this Mac",
                                  action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }

        menu.addItem(.separator())
        add(SliderRow(title: "Engage below", range: 40...120, step: 5, value: threshold,
                      caption: { String(format: "%.0f°", $0) },
                      target: self, action: #selector(thresholdSlid(_:))), to: menu)
        add(SliderRow(title: "You sit about", range: 30...90, step: 5, value: distanceCm,
                      caption: { String(format: "%.0f cm away", $0) },
                      target: self, action: #selector(distanceSlid(_:))), to: menu)
        let glassRow = SegmentRow(title: "Glass effect",
                                  labels: ["Off", "Subtle", "Medium", "Strong"],
                                  values: [0, 0.35, 0.65, 1],
                                  current: glass,
                                  target: self, action: #selector(glassPicked(_:)))
        let glassItem = NSMenuItem()
        glassItem.view = glassRow
        menu.addItem(glassItem)

        let angleRow = NSMenuItem()
        angleRow.view = SwitchRow(title: "Show angle in menu bar", isOn: showsAngle,
                                  target: self, action: #selector(showsAngleSwitched(_:)))
        menu.addItem(angleRow)


        if let captureFailure {
            menu.addItem(.separator())
            let failure = NSMenuItem(
                title: "Capture failed: \(captureFailure.localizedDescription)",
                action: nil, keyEquivalent: "")
            failure.isEnabled = false
            menu.addItem(failure)
            let retry = NSMenuItem(title: "Try again", action: #selector(retryCapture),
                                   keyEquivalent: "")
            retry.target = self
            menu.addItem(retry)
        }

        menu.addItem(.separator())
        addQuit(to: menu)
    }

    private func addQuit(to menu: NSMenu) {
        // Our own selector rather than NSApplication.terminate on NSApp. Pointed
        // at the application object the row drew a symbol of its own in the
        // state column, which is where a checkmark goes, so the title sat a
        // glyph's width right of every other line in the menu.
        let quit = NSMenuItem(title: "Quit Tilt", action: #selector(quitTilt),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func quitTilt() {
        NSApp.terminate(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }




    private func add(_ row: SliderRow, to menu: NSMenu) {
        let item = NSMenuItem()
        item.view = row
        menu.addItem(item)
    }




    @objc private func enabledSwitched(_ sender: NSSwitch) {
        enabled = sender.state == .on
    }

    @objc private func showsAngleSwitched(_ sender: NSSwitch) {
        showsAngle = sender.state == .on
    }

    @objc private func thresholdSlid(_ sender: NSSlider) {
        threshold = sender.doubleValue.rounded()
        (sender.superview as? SliderRow)?.refresh()
    }

    @objc private func distanceSlid(_ sender: NSSlider) {
        distanceCm = sender.doubleValue.rounded()
        (sender.superview as? SliderRow)?.refresh()
    }


    @objc private func glassPicked(_ sender: NSSegmentedControl) {
        guard let row = sender.superview as? SegmentRow,
              row.values.indices.contains(sender.selectedSegment) else { return }
        glass = row.values[sender.selectedSegment]
    }

    @objc private func retryCapture() {
        captureFailure = nil
        suppression.remove(.capture)
        capture.invalidateFilter()
        rebuildMenu()
        Task { await capture.prepare(on: nsScreen, excludingWindow: window.windowNumber) }
    }

    // MARK: permission

    /// Settle screen recording before anything is drawn. The overlay sits above
    /// everything, so a refusal has to be known before the first fold rather
    /// than discovered as a black screen.
    ///
    /// No window of our own. macOS puts its own dialog up for this, and a second
    /// one beside it asking for the same permission is two windows for one
    /// answer. What the system does not say - why an app about a hinge wants the
    /// screen, and that the permission reaches a launch rather than a process -
    /// goes in the menu, which is where this app keeps the rest of its state and
    /// is one click from the icon that just appeared.
    private func hasScreenRecordingAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        // Asking is also what puts Tilt in the Screen Recording list; without it
        // there is no row for anyone to switch on.
        CGRequestScreenCaptureAccess()
        needsScreenRecording = true
        rebuildMenu()
        return false
    }

    @objc private func openScreenRecordingSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else { return }
        NSWorkspace.shared.open(url)
    }

}

// `Tilt --check` verifies the sensor decode without opening the GUI: the report
// layout is the one thing here that could silently differ on another machine.
if CommandLine.arguments.contains("--check") {
    let sensor = LidAngleSensor()
    guard let angle = sensor.read() else {
        FileHandle.standardError.write(Data(
            "no lid angle sensor answering feature report 1 on HID page 0x20 usage 0x8A\n".utf8))
        exit(1)
    }
    guard (0...180).contains(angle) else {
        FileHandle.standardError.write(Data(
            "lid angle \(angle) outside 0...180 - the report layout changed\n".utf8))
        exit(1)
    }
    print(String(format: "lid %.0f degrees", angle))

    // The filter is the only real algorithm here, and the two things it has to
    // do pull against each other: hide the sensor's 1 degree steps when the lid
    // creeps, without lagging when it swings. Both are asserted, because a
    // change that fixes one by breaking the other looks fine in a screenshot.
    let dt = 1.0 / 120
    func sweep(from: Double, to: Double, seconds: Double)
        -> (biggestStep: Double, lagAtEnd: Double) {
        var filter = OneEuroFilter()
        var biggest = 0.0
        var previous: Double?
        let frames = Int(seconds / dt)
        var truth = from
        for i in 0...frames {
            truth = from + (to - from) * Double(i) / Double(frames)
            let quantised = truth.rounded() // what the sensor actually reports
            let out = filter(quantised, dt: dt)
            if let previous { biggest = max(biggest, abs(out - previous)) }
            previous = out
        }
        return (biggest, abs((previous ?? truth) - truth))
    }

    let slow = sweep(from: 110, to: 100, seconds: 2) // 5 deg/s, the stepping case
    let fast = sweep(from: 110, to: 50, seconds: 0.5) // 120 deg/s, the lag case
    print(String(format: "slow sweep: biggest frame step %.3f deg, lag %.2f deg",
                 slow.biggestStep, slow.lagAtEnd))
    print(String(format: "fast sweep: biggest frame step %.3f deg, lag %.2f deg",
                 fast.biggestStep, fast.lagAtEnd))

    var failures: [String] = []
    if slow.biggestStep > 0.25 {
        failures.append("slow sweep steps \(slow.biggestStep) deg per frame - quantisation is showing")
    }
    if slow.lagAtEnd > 2 { failures.append("slow sweep lags \(slow.lagAtEnd) deg") }
    if fast.lagAtEnd > 2 { failures.append("fast sweep lags \(fast.lagAtEnd) deg") }
    guard failures.isEmpty else {
        FileHandle.standardError.write(Data((failures.joined(separator: "\n") + "\n").utf8))
        exit(1)
    }
    exit(0)
}

// Top-level code already runs on the main thread; the compiler just cannot see
// it from here.
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
