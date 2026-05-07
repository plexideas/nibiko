import Foundation
import Testing
@testable import MenuBarNotesCore

@MainActor
@Suite("Pomodoro timer")
struct PomodoroTimerTests {
    @Test("start uses the selected template duration")
    func startUsesSelectedTemplateDuration() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_000))
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 1_500)
        let timer = PomodoroTimer(clock: { clock.now })

        timer.start(template: template)

        #expect(timer.session.state == .running)
        #expect(timer.session.templateID == "deep")
        #expect(timer.remainingSeconds == 1_500)
    }

    @Test("pause freezes remaining time")
    func pauseFreezesRemainingTime() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_000))
        let timer = PomodoroTimer(clock: { clock.now })

        timer.start(template: .defaultFocus)
        clock.advance(by: 300)
        timer.pause()
        clock.advance(by: 300)

        #expect(timer.session.state == .paused)
        #expect(timer.remainingSeconds == 1_200)
    }

    @Test("resume continues from the paused remaining time")
    func resumeContinuesFromPausedRemainingTime() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_000))
        let timer = PomodoroTimer(clock: { clock.now })

        timer.start(template: .defaultFocus)
        clock.advance(by: 300)
        timer.pause()
        clock.advance(by: 600)
        timer.resume()
        clock.advance(by: 60)
        timer.refresh()

        #expect(timer.session.state == .running)
        #expect(timer.remainingSeconds == 1_140)
    }

    @Test("stop returns the timer to idle")
    func stopReturnsTimerToIdle() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_000))
        let timer = PomodoroTimer(clock: { clock.now })

        timer.start(template: .defaultFocus)
        clock.advance(by: 120)
        timer.stop()

        #expect(timer.session.state == .idle)
        #expect(timer.remainingSeconds == PomodoroTemplate.defaultFocus.focusDurationSeconds)
    }

    @Test("refresh completes an elapsed running session")
    func refreshCompletesElapsedRunningSession() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_000))
        let template = PomodoroTemplate(id: "short", name: "Short", focusDurationSeconds: 60)
        let timer = PomodoroTimer(clock: { clock.now })

        timer.start(template: template)
        clock.advance(by: 61)
        timer.refresh()

        #expect(timer.session.state == .completed)
        #expect(timer.remainingSeconds == 0)
    }

    @Test("template switching while idle changes the next session duration")
    func templateSwitchingChangesNextSessionDuration() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_000))
        let short = PomodoroTemplate(id: "short", name: "Short", focusDurationSeconds: 300)
        let long = PomodoroTemplate(id: "long", name: "Long", focusDurationSeconds: 2_700)
        let timer = PomodoroTimer(clock: { clock.now })

        timer.selectTemplate(short)
        #expect(timer.remainingSeconds == 300)

        timer.selectTemplate(long)
        timer.start(template: long)

        #expect(timer.session.templateID == "long")
        #expect(timer.remainingSeconds == 2_700)
    }

    @Test("initial session restores a paused Pomodoro")
    func initialSessionRestoresPausedPomodoro() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 12_000))
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 1_500)
        let session = PomodoroSession(
            state: .paused,
            templateID: template.id,
            startedAt: Date(timeIntervalSince1970: 10_000),
            pausedRemainingSeconds: 780
        )

        let timer = PomodoroTimer(
            selectedTemplate: template,
            currentSession: session,
            clock: { clock.now }
        )

        #expect(timer.session == session)
        #expect(timer.remainingSeconds == 780)
        #expect(timer.canResume)
    }

    @Test("initial session restores an in-progress Pomodoro")
    func initialSessionRestoresRunningPomodoro() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 10_300))
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 1_500)
        let session = PomodoroSession(
            state: .running,
            templateID: template.id,
            startedAt: Date(timeIntervalSince1970: 10_000),
            endsAt: Date(timeIntervalSince1970: 11_500)
        )

        let timer = PomodoroTimer(
            selectedTemplate: template,
            currentSession: session,
            clock: { clock.now }
        )

        #expect(timer.session == session)
        #expect(timer.remainingSeconds == 1_200)
        #expect(timer.canPause)
    }

    @Test("initial session completes an elapsed running Pomodoro")
    func initialSessionCompletesElapsedRunningPomodoro() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 12_000))
        let template = PomodoroTemplate(id: "short", name: "Short", focusDurationSeconds: 60)
        let session = PomodoroSession(
            state: .running,
            templateID: template.id,
            startedAt: Date(timeIntervalSince1970: 10_000),
            endsAt: Date(timeIntervalSince1970: 10_060)
        )

        let timer = PomodoroTimer(
            selectedTemplate: template,
            currentSession: session,
            clock: { clock.now }
        )

        #expect(timer.session.state == .completed)
        #expect(timer.session.templateID == template.id)
        #expect(timer.remainingSeconds == 0)
    }

    @Test("initial session restores completed and idle Pomodoros")
    func initialSessionRestoresCompletedAndIdlePomodoros() {
        let clock = ManualClock(now: Date(timeIntervalSince1970: 12_000))
        let template = PomodoroTemplate(id: "deep", name: "Deep Work", focusDurationSeconds: 1_500)
        let completedSession = PomodoroSession(
            state: .completed,
            templateID: template.id,
            startedAt: Date(timeIntervalSince1970: 10_000),
            completedAt: Date(timeIntervalSince1970: 11_500)
        )
        let idleSession = PomodoroSession(state: .idle, templateID: template.id)

        let completedTimer = PomodoroTimer(
            selectedTemplate: template,
            currentSession: completedSession,
            clock: { clock.now }
        )
        let idleTimer = PomodoroTimer(
            selectedTemplate: template,
            currentSession: idleSession,
            clock: { clock.now }
        )

        #expect(completedTimer.session == completedSession)
        #expect(completedTimer.remainingSeconds == 0)
        #expect(idleTimer.session == idleSession)
        #expect(idleTimer.remainingSeconds == 1_500)
    }
}

private final class ManualClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
