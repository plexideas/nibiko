import AppKit
import CoreText
import MenuBarNotesCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let settingsStore: AppSettingsStore
    private let recordListStore: RecordListStore
    private let reminderNotificationStore: ReminderNotificationStore
    private let pomodoroTimer: PomodoroTimer
    private let calendarEventsStore: CalendarEventsStore
    private let captureService: QuickAddCaptureService
    private let localizer: Localizer
    private let showSettings: () -> Void
    private let requestQuit: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusIconView: StatusItemIconView
    private let popover = NSPopover()
    private let popoverWidth: CGFloat = 340
    private let maximumPopoverScreenHeightRatio: CGFloat = 0.85
    private let maximumBadgeCount = 99
    private let statusItemLength: CGFloat = 22
    private let pomodoroIndicatorSize = NSSize(width: 22, height: 22)
    private let baseIconDiameter: CGFloat = 17
    private let pomodoroRingDiameter: CGFloat = 20
    private let pomodoroRingLineWidth: CGFloat = 1.7
    private var hostingController: NSHostingController<PopoverRootView>?
    private var activeCount = 0
    private var pomodoroIndicator: PomodoroStatusIndicator?

    init(
        settingsStore: AppSettingsStore,
        recordListStore: RecordListStore,
        reminderNotificationStore: ReminderNotificationStore,
        pomodoroTimer: PomodoroTimer,
        calendarEventsStore: CalendarEventsStore,
        captureService: QuickAddCaptureService,
        localizer: Localizer,
        showSettings: @escaping () -> Void,
        requestQuit: @escaping () -> Void
    ) {
        self.statusIconView = StatusItemIconView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: statusItemLength,
                height: NSStatusBar.system.thickness
            )
        )
        self.settingsStore = settingsStore
        self.recordListStore = recordListStore
        self.reminderNotificationStore = reminderNotificationStore
        self.pomodoroTimer = pomodoroTimer
        self.calendarEventsStore = calendarEventsStore
        self.captureService = captureService
        self.localizer = localizer
        self.showSettings = showSettings
        self.requestQuit = requestQuit
    }

    func installStatusItem() {
        statusItem.length = statusItemLength
        statusIconView.image = statusImage()
        statusIconView.toolTip = statusItemToolTip()
        statusIconView.activate = { [weak self] in
            self?.togglePopover()
        }
        _ = statusItem.perform(NSSelectorFromString("setView:"), with: statusIconView)

        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(
            rootView: PopoverRootView(
                settingsStore: settingsStore,
                recordListStore: recordListStore,
                reminderNotificationStore: reminderNotificationStore,
                pomodoroTimer: pomodoroTimer,
                calendarEventsStore: calendarEventsStore,
                captureService: captureService,
                localizer: localizer,
                showSettings: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.showSettings()
                },
                requestQuit: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.requestQuit()
                },
                requestContentResize: { [weak self] in
                    self?.refreshPopoverSizeIfShown()
                }
            )
        )
        self.hostingController = hostingController
        popover.contentViewController = ScrollableTopAlignedContentViewController(
            hostingController: hostingController
        )
    }

    func updateActiveCount(_ count: Int) {
        activeCount = count
        refreshStatusItem()
    }

    func updatePomodoroStatus(state: PomodoroSessionState, remainingSeconds: Int, totalSeconds: Int) {
        switch state {
        case .running, .paused:
            pomodoroIndicator = PomodoroStatusIndicator(
                state: state,
                remainingSeconds: remainingSeconds,
                totalSeconds: totalSeconds
            )
        case .idle, .completed:
            pomodoroIndicator = nil
        }
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        statusItem.length = statusItemLength
        statusIconView.image = statusImage()
        statusIconView.toolTip = statusItemToolTip()
    }

    private func statusImage() -> NSImage? {
        let image = NSImage(size: pomodoroIndicatorSize, flipped: false) { [weak self] rect in
            guard let self else {
                return false
            }

            self.drawCircularStatusIcon(in: rect)
            if let indicator = self.pomodoroIndicator {
                self.drawPomodoroRing(indicator, in: rect)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private func statusItemToolTip() -> String {
        guard let pomodoroIndicator else {
            return localizer.string(.appName)
        }

        return "\(localizer.string(.pomodoroCardTitle)) \(formattedPomodoroRemaining(pomodoroIndicator.remainingSeconds))"
    }

    private func badgeText(for count: Int) -> String {
        count > maximumBadgeCount ? "\(maximumBadgeCount)+" : "\(count)"
    }

    private func formattedPomodoroRemaining(_ remainingSeconds: Int) -> String {
        let clampedSeconds = max(0, remainingSeconds)
        return String(format: "%02d:%02d", clampedSeconds / 60, clampedSeconds % 60)
    }

    private func drawCircularStatusIcon(in rect: NSRect) {
        let center = statusIconCenter(in: rect)
        let iconRect = NSRect(
            x: center.x - baseIconDiameter / 2,
            y: center.y - baseIconDiameter / 2,
            width: baseIconDiameter,
            height: baseIconDiameter
        )
        let iconPath = NSBezierPath(ovalIn: iconRect)

        (activeCount > 0 ? NSColor.systemRed : NSColor.white.withAlphaComponent(0.18)).setFill()
        iconPath.fill()
        NSColor.white.withAlphaComponent(0.78).setStroke()
        iconPath.lineWidth = 1.2
        iconPath.stroke()

        if activeCount > 0 {
            drawActiveCountText(badgeText(for: activeCount), in: iconRect)
            return
        }

        let glyphRect = iconRect.insetBy(dx: 4.6, dy: 4.2)
        let lineHeight = max(1, glyphRect.height / 4)
        let lineSpacing = lineHeight * 1.2
        let lineWidth = glyphRect.width
        let lineX = glyphRect.minX
        let topY = glyphRect.maxY - lineHeight
        let notePath = NSBezierPath()
        notePath.lineWidth = 1.15
        notePath.lineCapStyle = .round

        for index in 0..<3 {
            let y = topY - CGFloat(index) * lineSpacing
            notePath.move(to: NSPoint(x: lineX, y: y))
            notePath.line(to: NSPoint(x: lineX + lineWidth, y: y))
        }

        NSColor.white.withAlphaComponent(0.95).setStroke()
        notePath.stroke()
    }

    private func drawActiveCountText(_ text: String, in iconRect: NSRect) {
        let textRect = iconRect.insetBy(dx: 1.1, dy: 1.1)
        var fontSize: CGFloat
        switch text.count {
        case 1:
            fontSize = 10
        case 2:
            fontSize = 7.8
        default:
            fontSize = 5.6
        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        var textLine = activeCountTextLine(text, fontSize: fontSize)
        var textBounds = imageBounds(for: textLine, in: context)
        while (textBounds.width > textRect.width || textBounds.height > textRect.height), fontSize > 4.8 {
            fontSize -= 0.2
            textLine = activeCountTextLine(text, fontSize: fontSize)
            textBounds = imageBounds(for: textLine, in: context)
        }

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: textRect.midX - textBounds.midX,
            y: textRect.midY - textBounds.midY
        )
        CTLineDraw(textLine, context)
        context.restoreGState()
    }

    private func activeCountTextLine(_ text: String, fontSize: CGFloat) -> CTLine {
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    private func imageBounds(for textLine: CTLine, in context: CGContext) -> CGRect {
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = .zero
        let bounds = CTLineGetImageBounds(textLine, context)
        context.restoreGState()
        return bounds
    }

    private func drawPomodoroRing(_ indicator: PomodoroStatusIndicator, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let center = statusIconCenter(in: rect)
        let radius = pomodoroRingDiameter / 2
        let ringRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: pomodoroRingDiameter,
            height: pomodoroRingDiameter
        )
        let progress = indicator.elapsedProgress
        let progressColor: NSColor = indicator.state == .paused ? .systemYellow : .systemGreen

        context.saveGState()
        context.setLineWidth(pomodoroRingLineWidth)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
        context.strokeEllipse(in: ringRect)

        guard progress > 0 else {
            context.restoreGState()
            return
        }

        context.setStrokeColor(progressColor.cgColor)
        context.setLineCap(.round)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - (2 * .pi * progress),
            clockwise: true
        )
        context.strokePath()
        context.restoreGState()
    }

    private func statusIconCenter(in rect: NSRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    func refreshPopoverSizeIfShown() {
        guard popover.isShown else {
            return
        }

        updatePopoverContentSize(relativeTo: statusIconView)
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updatePopoverContentSize(relativeTo: statusIconView)
            popover.show(relativeTo: statusIconView.bounds, of: statusIconView, preferredEdge: .minY)
        }
    }

    private func updatePopoverContentSize(relativeTo view: NSView) {
        guard let hostingController else {
            return
        }

        let maximumHeight = maximumPopoverHeight(relativeTo: view)
        let fittingSize = hostingController.sizeThatFits(
            in: NSSize(width: popoverWidth, height: maximumHeight)
        )
        let height = min(max(fittingSize.height, 1), maximumHeight)
        let nextContentSize = NSSize(width: popoverWidth, height: ceil(height))
        guard abs(popover.contentSize.height - nextContentSize.height) > 0.5
            || abs(popover.contentSize.width - nextContentSize.width) > 0.5
        else {
            return
        }

        setPopoverContentSize(nextContentSize)
    }

    private func setPopoverContentSize(_ nextContentSize: NSSize) {
        guard popover.isShown, let window = popover.contentViewController?.view.window else {
            popover.contentSize = nextContentSize
            return
        }

        let currentFrame = window.frame
        popover.contentSize = nextContentSize
        let targetFrame = window.frame
        guard currentFrame.size != targetFrame.size || currentFrame.origin != targetFrame.origin else {
            return
        }

        window.setFrame(currentFrame, display: false)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }

    private func maximumPopoverHeight(relativeTo view: NSView) -> CGFloat {
        let screen = view.window?.screen ?? NSScreen.main
        return floor((screen?.visibleFrame.height ?? 720) * maximumPopoverScreenHeightRatio)
    }
}

private final class StatusItemIconView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }
    var activate: (() -> Void)?

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let image else {
            return
        }

        let targetRect = NSRect(
            x: round(bounds.midX - image.size.width / 2),
            y: round(bounds.midY - image.size.height / 2),
            width: image.size.width,
            height: image.size.height
        )
        image.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func mouseDown(with event: NSEvent) {
        activate?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct PomodoroStatusIndicator {
    var state: PomodoroSessionState
    var remainingSeconds: Int
    var totalSeconds: Int

    var elapsedProgress: CGFloat {
        let total = max(1, totalSeconds)
        let remaining = min(max(0, remainingSeconds), total)
        return CGFloat(total - remaining) / CGFloat(total)
    }
}

private final class ScrollableTopAlignedContentViewController<Content: View>: NSViewController {
    private let hostingController: NSHostingController<Content>
    private let scrollView = NSScrollView()
    private let documentView = FlippedView()

    init(hostingController: NSHostingController<Content>) {
        self.hostingController = hostingController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .allowed
        scrollView.documentView = documentView
        view = scrollView

        addChild(hostingController)
        documentView.addSubview(hostingController.view)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutDocument()
    }

    private func layoutDocument() {
        let width = scrollView.contentView.bounds.width
        guard width > 0 else {
            return
        }

        let fittingSize = hostingController.sizeThatFits(
            in: NSSize(width: width, height: .greatestFiniteMagnitude)
        )
        let contentHeight = ceil(max(fittingSize.height, 1))
        let documentHeight = max(contentHeight, scrollView.contentView.bounds.height)
        let nextDocumentFrame = NSRect(x: 0, y: 0, width: width, height: documentHeight)
        let shouldPinToTop = documentView.frame.size != nextDocumentFrame.size

        documentView.frame = nextDocumentFrame
        hostingController.view.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)

        if shouldPinToTop {
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
