import Foundation
import SwiftUI

let args = CommandLine.arguments
if args.contains("--help") || args.contains("-h") {
    print("KiwiBar 1.2.0: Bandwagon Host menu bar monitor")
    print("Usage: KiwiBar [--settings | --probe | --render PATH --sample [--dark]]")
    print("Enter VEID and API key in KiwiBar Settings. Credentials are stored in macOS Keychain.")
} else if args.contains("--version") {
    print("1.2.0")
} else if args.contains("--env") {
    print("File-based credentials are no longer supported. Open KiwiBar Settings.")
    exit(1)
} else if args.contains("--probe") || args.contains("--render") {
    do { try await Diagnostics.run(args) }
    catch { print("Diagnostic failed (error \((error as NSError).code))."); exit(1) }
} else {
    KiwiBarApplication.main()
}
