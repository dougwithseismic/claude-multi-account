import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import ClaudeNotch
@testable import UsageCore

@Suite struct CopiesTests {
    @Test func linksGoToTheCopyUsedLast() {
        #expect(Links.target(lastUsed: "B", running: ["A", "B", "C"]) == "B")
        // B was quit: the first running copy.
        #expect(Links.target(lastUsed: "B", running: ["C", "A"]) == "A")
        #expect(Links.target(lastUsed: nil, running: ["C"]) == "C")
        #expect(Links.target(lastUsed: "B", running: []) == nil)
    }

    @Test func hotkeys() {
        #expect(Hotkeys.keyCode(for: "1") == kVK_ANSI_1)
        #expect(Hotkeys.keyCode(for: "d") == kVK_ANSI_D)
        #expect(Hotkeys.keyCode(for: "!") == nil)
        #expect(Hotkeys.keyCode(for: "12") == nil)
    }

    @Test func theOutlineFollowsTheWindow() {
        // A 1512×982 main screen: a window 100pt from the top is 100pt below its top in AppKit too.
        let window = CGRect(x: 40, y: 100, width: 800, height: 600)
        #expect(Outline.flip(window, primaryHeight: 982) == CGRect(x: 40, y: 282, width: 800, height: 600))
        #expect(Outline.flip(Outline.flip(window, primaryHeight: 982), primaryHeight: 982) == window)

        let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: -200, width: 2560, height: 1440)]
        #expect(Outline.isFullScreen(CGRect(x: 1512, y: -200, width: 2560, height: 1440), screens: screens))
        #expect(!Outline.isFullScreen(CGRect(x: 0, y: 38, width: 1512, height: 944), screens: screens))
    }
}

@MainActor @Test func theDemoShowsEveryState() {
    let model = AccountsModel(reader: nil)
    Demo.fill(model)
    #expect(model.isSettled)
    #expect(model.keychainProblem != nil)
    let errors = model.accounts.map(\.error)
    #expect(errors.contains(nil))
    #expect(errors.contains { if case .rateLimited = $0 { true } else { false } })
    #expect(errors.contains { if case .tokenExpired = $0 { true } else { false } })
    #expect(errors.contains(.notSignedIn))
    #expect(errors.contains(.unexpectedResponse))
    #expect(errors.contains(.noLogin))
    #expect(model.accounts.contains { $0.report?.windows.isEmpty == true })
    #expect(model.accounts.contains { $0.report?.weeklyPeak?.percentUsed == 100 })
    #expect(model.copies.contains { !$0.others.isEmpty })
}
