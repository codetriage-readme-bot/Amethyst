//
//  Layout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol WindowActivityCache {
    func windowIsActive(_ window: SIWindow) -> Bool
}

struct FrameAssignment {
    let frame: CGRect
    let window: SIWindow
    let focused: Bool
    let screenFrame: CGRect

    fileprivate func perform() {
        var padding = UserConfiguration.shared.windowMarginSize()
        let windowMinimumWidth = UserConfiguration.shared.windowMinimumWidth()
        let windowMinimumHeight = UserConfiguration.shared.windowMinimumHeight()
        var finalFrame = frame

        if UserConfiguration.shared.windowMargins() {
            padding = floor(padding / 2)

            finalFrame.origin.x += padding
            finalFrame.origin.y += padding
            finalFrame.size.width -= 2 * padding
            finalFrame.size.height -= 2 * padding
        }

        if focused {
            if windowMinimumWidth > finalFrame.size.width {
                finalFrame.origin.x -= ((windowMinimumWidth - finalFrame.size.width) / 2)
                finalFrame.size.width = windowMinimumWidth
            }

            if windowMinimumHeight > finalFrame.size.height {
                finalFrame.origin.y -= ((windowMinimumHeight - finalFrame.size.height) / 2)
                finalFrame.size.height = windowMinimumHeight
            }
        }

        var finalPosition = finalFrame.origin

        // Just resize the window
        finalFrame.origin = window.frame().origin
        window.setFrame(finalFrame)

        if focused {
            finalFrame.size = CGSize(width: max(window.frame().size.width, finalFrame.size.width), height: max(window.frame().size.height, finalFrame.size.height))

            // Update origin to determine if position should be adjusted
            finalFrame.origin = finalPosition
            if !screenFrame.contains(finalFrame) {
                finalPosition.x = max(0, min(finalPosition.x, screenFrame.maxX - finalFrame.size.width))
                finalPosition.y = max(0, min(finalPosition.y, screenFrame.maxY - finalFrame.size.height))
            }
        }

        // Move the window to its final frame
        finalFrame.origin = finalPosition
        window.setFrame(finalFrame)
    }
}

class ReflowOperation: Operation {
    let screen: NSScreen
    let windows: [SIWindow]
    let frameAssigner: FrameAssigner

    init(screen: NSScreen, windows: [SIWindow], frameAssigner: FrameAssigner) {
        self.screen = screen
        self.windows = windows
        self.frameAssigner = frameAssigner
        super.init()
    }
}

protocol FrameAssigner: WindowActivityCache {
    func performFrameAssignments(_ frameAssignments: [FrameAssignment])
}

extension FrameAssigner {
    func performFrameAssignments(_ frameAssignments: [FrameAssignment]) {
        for frameAssignment in frameAssignments {
            if !windowIsActive(frameAssignment.window) {
                return
            }
        }

        for frameAssignment in frameAssignments {
            LogManager.log?.debug("Frame Assignment: \(frameAssignment)")
            frameAssignment.perform()
        }
    }
}

extension FrameAssigner where Self: Layout {
    func windowIsActive(_ window: SIWindow) -> Bool {
        return windowActivityCache.windowIsActive(window)
    }
}

extension NSScreen {
    func adjustedFrame() -> CGRect {
        var frame = UserConfiguration.shared.ignoreMenuBar() ? frameIncludingDockAndMenu() : frameWithoutDockOrMenu()

        if UserConfiguration.shared.windowMargins() {
            /* Inset for producing half of the full padding around screen as collapse only adds half of it to all windows */
            let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

            frame.origin.x += padding
            frame.origin.y += padding
            frame.size.width -= 2 * padding
            frame.size.height -= 2 * padding
        }

        let windowMinimumWidth = UserConfiguration.shared.windowMinimumWidth()
        let windowMinimumHeight = UserConfiguration.shared.windowMinimumHeight()

        if windowMinimumWidth > frame.size.width {
            frame.origin.x -= (windowMinimumWidth - frame.size.width) / 2
            frame.size.width = windowMinimumWidth
        }

        if windowMinimumHeight > frame.size.height {
            frame.origin.y -= (windowMinimumHeight - frame.size.height) / 2
            frame.size.height = windowMinimumHeight
        }

        return frame
    }
}

protocol Layout {
    static var layoutName: String { get }
    static var layoutKey: String { get }

    var windowActivityCache: WindowActivityCache { get }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation
}

protocol PanedLayout {
    func shrinkMainPane()
    func expandMainPane()
    func increaseMainPaneCount()
    func decreaseMainPaneCount()
}

protocol StatefulLayout {
    func updateWithChange(_ windowChange: WindowChange)
    func nextWindowIDCounterClockwise() -> CGWindowID?
    func nextWindowIDClockwise() -> CGWindowID?
}
