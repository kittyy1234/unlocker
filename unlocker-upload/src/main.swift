import AppKit

let argv = CommandLine.arguments

func argValue(_ flag: String) -> String? {
    guard let i = argv.firstIndex(of: flag), i + 1 < argv.count else { return nil }
    return argv[i + 1]
}

if argv.contains("--help") {
    print("""
    Usage: unlocker [options]

    Creates a high-refresh-rate virtual display and mirrors the main screen to it.
    Auto-starts when Roblox is detected (default). Unlocks FPS beyond display limits.

    Options:
      --rate <hz>    Target refresh rate (default: 500)
      --width <px>   Custom width
      --height <px>  Custom height
      --always       Keep display active even when Roblox is closed
      --no-menu      Run without menu bar icon
      --help         Show this help
    """)
    exit(0)
}

let rate = argValue("--rate").flatMap(Double.init) ?? 500.0
let customWidth = argValue("--width").flatMap(Int.init)
let customHeight = argValue("--height").flatMap(Int.init)
let alwaysOn = argv.contains("--always")
let showMenu = !argv.contains("--no-menu")

let app = NSApplication.shared
let delegate = AppDelegate(
    showMenu: showMenu,
    width: customWidth,
    height: customHeight,
    refreshRate: rate,
    watchRoblox: !alwaysOn
)
app.delegate = delegate
app.run()
