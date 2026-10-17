import AppKit
import SwiftUI

/// `--snapshot <file.png>`: once every account has been read (or after 30 seconds),
/// renders the rings and the open panel with the live numbers to a PNG and quits.
/// For checking the rows without screen-recording permission.
@MainActor
enum Snapshot {
    nonisolated static func path(in arguments: [String]) -> String? {
        guard let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static func write(
        _ model: AccountsModel, to path: String, hasNotch: Bool = true, deadline: Date = Date().addingTimeInterval(30)
    ) {
        guard model.isSettled || Date() > deadline else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                write(model, to: path, hasNotch: hasNotch, deadline: deadline)
            }
            return
        }
        let height = hasNotch ? 38 : NotchLayout.pillSize.height
        let rings = RingsView(model: model, hasNotch: hasNotch)
        let view = VStack(alignment: .trailing, spacing: 16) {
            if hasNotch {
                rings.frame(height: height).fixedSize()
            } else {
                rings.frame(width: NotchLayout.pillSize.width, height: height)
            }
            PanelView(model: model, topInset: height, open: { _ in }, quit: {}, footerExtras: AnyView(LoginItemToggle()))
        }
        .padding(16)
        .background(Color(white: 0.85))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("ClaudeNotch: couldn't render the snapshot\n".utf8))
            exit(1)
        }
        do { try png.write(to: URL(filePath: path)) } catch {
            FileHandle.standardError.write(Data("ClaudeNotch: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        exit(0)
    }
}
