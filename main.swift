import Foundation
import CoreGraphics

@_silgen_name("CGVirtualDisplayCreate")
func CGVirtualDisplayCreate(_ properties: CFDictionary) -> Int32

func bootCustomEngine() {
    let displaySettings: [String: Any] = [
        "Width": 1920,
        "Height": 1080,
        "RefreshRate": 360,
        "IsVirtual": true,
        "MirrorMaster": true
    ]
    
    let resultStatus = CGVirtualDisplayCreate(displaySettings as CFDictionary)
    
    if resultStatus == 0 {
        RunLoop.main.run()
    } else {
        exit(1)
    }
}

bootCustomEngine()
