import Foundation
import Darwin
import UIKit

enum AdRuntime {
    static var allowsAds: Bool {
        hardwareFamily == .iPhone
    }

    private enum HardwareFamily {
        case iPhone
        case iPad
        case other
    }

    private static var hardwareFamily: HardwareFamily {
        if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return family(for: simulatorModel)
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
            }
        }
        return family(for: identifier)
    }

    private static func family(for identifier: String) -> HardwareFamily {
        if identifier.hasPrefix("iPhone") || identifier.hasPrefix("iPod") {
            return .iPhone
        }
        if identifier.hasPrefix("iPad") {
            return .iPad
        }
        return .other
    }
}
