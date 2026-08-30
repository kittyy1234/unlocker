import AppKit

let argv = CommandLine.arguments

func argValue(_ flag: String) -> String? {
    guard let i = argv.firstIndex(of: flag), i + 1 < argv.count else { return nil }
    return argv[i + 1]
}

if argv.contains("--help") {
    print("""
    Usage: virtualdisplay [options]

    Creates a virtual 240Hz display and mirrors the main screen to it.

    Options:
      --width <px>   Custom width for the virtual display (stretched resolution)
      --height <px>  Custom height for the virtual display (stretched resolution)
      --no-menu      Run without a menu bar icon (stop with SIGTERM or Ctrl-C)
      --help         Print this message and exit
    """)
    exit(0)
}

let customWidth  = argValue("--width").flatMap(Int.init)
let customHeight = argValue("--height").flatMap(Int.init)

let app = NSApplication.shared
let delegate = AppDelegate(
    showMenu: !argv.contains("--no-menu"),
    width: customWidth,
    height: customHeight
)
app.delegate = delegate
app.run()
