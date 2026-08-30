import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private let showMenu: Bool
    private let customWidth: Int?
    private let customHeight: Int?
    private let refreshRate: Double
    private let watchRoblox: Bool
    private var virtualDisplay: CGVirtualDisplay?
    private var statusItem: NSStatusItem?
    private var nativeMode: CGDisplayMode?
    private var physicalDisplayID: CGDirectDisplayID = 0
    private var signalSources: [DispatchSourceSignal] = []
    private var isStopping = false
    private var pollTimer: Timer?
    private var robloxTimer: Timer?
    private var displayActive = false

    init(showMenu: Bool, width: Int? = nil, height: Int? = nil, refreshRate: Double = 500, watchRoblox: Bool = true) {
        self.showMenu = showMenu
        self.customWidth = width
        self.customHeight = height
        self.refreshRate = refreshRate
        self.watchRoblox = watchRoblox
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in self?.stop() }
            src.resume()
            signalSources.append(src)
        }
        if watchRoblox {
            startRobloxWatcher()
        } else {
            createDisplay()
        }
        if showMenu { setupStatusBar() }
    }

    private func isRobloxRunning() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-ix", "Roblox"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty && task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func startRobloxWatcher() {
        robloxTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let running = self.isRobloxRunning()
            if running && !self.displayActive {
                self.createDisplay()
            } else if !running && self.displayActive {
                self.teardownDisplay()
            }
        }
        if isRobloxRunning() {
            createDisplay()
        }
    }

    private func createDisplay() {
        guard !displayActive else { return }
        guard let screen = NSScreen.main else { return }
        physicalDisplayID = CGMainDisplayID()

        let nativeScale = Int(screen.backingScaleFactor)
        let w = customWidth ?? Int(screen.frame.width)
        let h = customHeight ?? Int(screen.frame.height)
        let isNative = customWidth == nil && customHeight == nil
        let scale = isNative ? nativeScale : 1
        let hz = refreshRate

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(.main)
        descriptor.name = "Unlocker \(Int(hz))Hz"
        descriptor.maxPixelsWide = UInt32(w * scale)
        descriptor.maxPixelsHigh = UInt32(h * scale)
        descriptor.sizeInMillimeters = screen.physicalSizeInMillimeters
        descriptor.productID = 0x1234
        descriptor.vendorID = 0x3456
        descriptor.serialNum = 0x0002
        descriptor.terminationHandler = { [weak self] _, _ in
            self?.virtualDisplay = nil
            self?.displayActive = false
        }

        let display = CGVirtualDisplay(descriptor: descriptor)
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = isNative && scale > 1 ? 1 : 0
        settings.modes = [
            CGVirtualDisplayMode(width: UInt(w), height: UInt(h), refreshRate: hz),
            CGVirtualDisplayMode(width: UInt(w), height: UInt(h), refreshRate: 360),
            CGVirtualDisplayMode(width: UInt(w), height: UInt(h), refreshRate: 240),
            CGVirtualDisplayMode(width: UInt(w), height: UInt(h), refreshRate: 120),
            CGVirtualDisplayMode(width: UInt(w), height: UInt(h), refreshRate: 60),
        ]
        display.apply(settings)
        virtualDisplay = display
        displayActive = true

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.pollForMirroring()
        }
        updateMenuTitle()
    }

    private func pollForMirroring() {
        guard let vd = virtualDisplay else {
            pollTimer?.invalidate()
            return
        }
        var count: CGDisplayCount = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        guard ids.contains(vd.displayID) else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        enableMirroring()
    }

    private func enableMirroring() {
        guard let vd = virtualDisplay else { return }
        nativeMode = CGDisplayCopyDisplayMode(physicalDisplayID)
        if CGDisplayIsInMirrorSet(physicalDisplayID) != 0 {
            var cfg: CGDisplayConfigRef?
            CGBeginDisplayConfiguration(&cfg)
            CGConfigureDisplayMirrorOfDisplay(cfg, physicalDisplayID, kCGNullDirectDisplay)
            CGCompleteDisplayConfiguration(cfg, CGConfigureOption(rawValue: 0))
        }
        var cfg: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cfg)
        CGConfigureDisplayMirrorOfDisplay(cfg, physicalDisplayID, vd.displayID)
        CGCompleteDisplayConfiguration(cfg, CGConfigureOption(rawValue: 0))
    }

    private func disableMirroring() {
        guard CGDisplayIsInMirrorSet(physicalDisplayID) != 0 else { return }
        var cfg: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cfg)
        CGConfigureDisplayMirrorOfDisplay(cfg, physicalDisplayID, kCGNullDirectDisplay)
        if let mode = nativeMode {
            CGConfigureDisplayWithDisplayMode(cfg, physicalDisplayID, mode, nil)
        }
        CGCompleteDisplayConfiguration(cfg, CGConfigureOption(rawValue: 0))
        nativeMode = nil
    }

    private func teardownDisplay() {
        pollTimer?.invalidate()
        pollTimer = nil
        disableMirroring()
        virtualDisplay = nil
        displayActive = false
        updateMenuTitle()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)
        let menu = NSMenu()
        let title = menu.addItem(withTitle: "Unlocker", action: nil, keyEquivalent: "")
        title.isEnabled = false
        title.tag = 100
        menu.addItem(.separator())
        menu.addItem(withTitle: "Force On", action: #selector(forceOn), keyEquivalent: "o")
        menu.addItem(withTitle: "Force Off", action: #selector(forceOff), keyEquivalent: "f")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(stop), keyEquivalent: "q")
        statusItem?.menu = menu
        updateMenuTitle()
    }

    private func updateMenuTitle() {
        guard let menu = statusItem?.menu else { return }
        if let item = menu.item(withTag: 100) {
            let state = displayActive ? "ON \(Int(refreshRate))Hz" : "Waiting for Roblox"
            item.title = "Unlocker — \(state)"
        }
    }

    @objc func forceOn() {
        if !displayActive { createDisplay() }
    }

    @objc func forceOff() {
        if displayActive { teardownDisplay() }
    }

    @objc func stop() {
        guard !isStopping else { return }
        isStopping = true
        robloxTimer?.invalidate()
        robloxTimer = nil
        pollTimer?.invalidate()
        pollTimer = nil
        disableMirroring()
        virtualDisplay = nil
        displayActive = false
        NSApp.terminate(nil)
    }
}

private extension NSScreen {
    var physicalSizeInMillimeters: CGSize {
        guard let dpi = deviceDescription[NSDeviceDescriptionKey("NSDeviceResolution")] as? NSValue else {
            return CGSize(width: 600, height: 340)
        }
        let d = dpi.sizeValue
        guard d.width > 0, d.height > 0 else { return CGSize(width: 600, height: 340) }
        return CGSize(width: frame.width / d.width * 25.4, height: frame.height / d.height * 25.4)
    }
}
