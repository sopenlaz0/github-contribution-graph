// Sources/State/AppState.swift
// Observable app state that drives the entire UI.
// Uses `gh` CLI for auth, supports year selection for contributions.
// RELEVANT FILES: Sources/Services/GitHubAuth.swift, Sources/Services/GitHubService.swift

import SwiftUI
import UserNotifications

// MARK: - Auth Status

enum AuthStatus: Equatable {
    case checking
    case loggedIn
    case needsGH
    case needsLogin
    case error(String)
}

// MARK: - Contribution Range

enum ContributionRange: Hashable, Codable {
    case last12Months
    case thisMonth
    case year(Int)

    private enum CodingKeys: String, CodingKey {
        case kind
        case year
    }

    private enum Kind: String, Codable {
        case last12Months
        case thisMonth
        case year
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .last12Months:
            self = .last12Months
        case .thisMonth:
            self = .thisMonth
        case .year:
            self = .year(try container.decode(Int.self, forKey: .year))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .last12Months:
            try container.encode(Kind.last12Months, forKey: .kind)
        case .thisMonth:
            try container.encode(Kind.thisMonth, forKey: .kind)
        case .year(let year):
            try container.encode(Kind.year, forKey: .kind)
            try container.encode(year, forKey: .year)
        }
    }

    func dateBounds(referenceDate: Date = Date()) -> ClosedRange<Date>? {
        let calendar = Calendar(identifier: .gregorian)

        switch self {
        case .last12Months:
            return nil
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: referenceDate)
            guard let start = calendar.date(from: components) else { return nil }
            return start...referenceDate
        case .year(let year):
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = 1
            startComponents.day = 1
            startComponents.hour = 0
            startComponents.minute = 0
            startComponents.second = 0

            var endComponents = DateComponents()
            endComponents.year = year
            endComponents.month = 12
            endComponents.day = 31
            endComponents.hour = 23
            endComponents.minute = 59
            endComponents.second = 59

            guard
                let start = calendar.date(from: startComponents),
                let end = calendar.date(from: endComponents)
            else {
                return nil
            }

            return start...end
        }
    }

    var dayCount: Int? {
        guard let bounds = dateBounds() else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents([.day], from: bounds.lowerBound, to: bounds.upperBound).day.map { $0 + 1 }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Codable {
    case iconOnly
    case todayCount
    case currentStreak

    var title: String {
        switch self {
        case .iconOnly:
            return "Icon only"
        case .todayCount:
            return "Today's count"
        case .currentStreak:
            return "Current streak"
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    private static let staleRefreshInterval: TimeInterval = 60 * 15
    private static let automaticRefreshInterval: TimeInterval = 60 * 15
    private static let dailyReminderHour = 18
    private static let dailyReminderMinute = 0
    private static let dailyReminderIdentifier = "dailyContributionReminder"

    private struct CachedContributionState: Codable {
        let username: String
        let selectedRange: ContributionRange
        let calendar: ContributionCalendar
        let lastUpdated: Date
    }

    private enum PersistenceKeys {
        static let selectedRange = "selectedContributionRange"
        static let cachedState = "cachedContributionState"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let automaticRefreshEnabled = "automaticRefreshEnabled"
        static let dailyReminderEnabled = "dailyReminderEnabled"
    }

    // MARK: - Published State

    @Published var authStatus: AuthStatus = .checking
    @Published var username: String = ""
    @Published var calendar: ContributionCalendar?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    @Published var selectedRange: ContributionRange = .last12Months
    @Published var menuBarDisplayMode: MenuBarDisplayMode = .todayCount
    @Published var automaticRefreshEnabled = true
    @Published var dailyReminderEnabled = false

    // MARK: - Private

    private let auth = GitHubAuth()
    private let service = GitHubService()
    private var token: String = ""
    private var authTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var backgroundRefreshTask: Task<Void, Never>?

    // MARK: - Computed

    var isLoggedIn: Bool {
        authStatus == .loggedIn && !token.isEmpty
    }

    var availableYears: [Int] {
        let current = Foundation.Calendar.current.component(.year, from: Date())
        return Array((current - 4)...current).reversed()
    }

    var contributionPeriodLabel: String {
        switch selectedRange {
        case .last12Months:
            return "in the last year"
        case .thisMonth:
            return "this month"
        case .year(let year):
            return "in \(year)"
        }
    }

    var selectedRangeTitle: String {
        switch selectedRange {
        case .last12Months:
            return "Last 12 months"
        case .thisMonth:
            return "This month"
        case .year(let year):
            return String(year)
        }
    }

    var contributionSummary: ContributionSummary? {
        guard let calendar else { return nil }
        let visibleDays = calendar.allDays.filter { $0.isVisible }
        guard !visibleDays.isEmpty else { return nil }
        return calendar.summary(dayCount: selectedRange.dayCount ?? visibleDays.count)
    }

    var menuBarValueText: String? {
        switch menuBarDisplayMode {
        case .iconOnly:
            return nil
        case .todayCount:
            return todayContributions.map(String.init)
        case .currentStreak:
            return contributionSummary.map { "\($0.currentStreak)" }
        }
    }

    var syncStatusLabel: String? {
        guard let lastUpdated else { return nil }
        return "Updated \(lastUpdated.formatted(.relative(presentation: .named))) · \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }

    var shouldRefreshOnOpen: Bool {
        guard let lastUpdated else { return calendar == nil }
        return Date().timeIntervalSince(lastUpdated) >= Self.staleRefreshInterval
    }

    /// Today's date as "yyyy-MM-dd" for matching against contribution days.
    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    var todayDateString: String {
        Self.todayFormatter.string(from: Date())
    }

    /// Today's contribution count, extracted from the loaded calendar.
    var todayContributions: Int? {
        guard let cal = calendar else { return nil }
        let today = todayDateString
        for week in cal.weeks {
            if let day = week.contributionDays.first(where: { $0.date == today && $0.isVisible }) {
                return day.contributionCount
            }
        }
        return nil
    }

    init() {
        restorePersistedSelection()
        restoreMenuBarDisplayMode()
        restoreAutomaticRefreshPreference()
        restoreDailyReminderPreference()
        configureAutomaticRefreshLoop()
    }

    // MARK: - Auth

    func checkAuth() {
        authTask?.cancel()
        authTask = Task { await performAuthCheck() }
    }

    func logout() {
        authTask?.cancel()
        refreshTask?.cancel()
        token = ""
        username = ""
        calendar = nil
        lastUpdated = nil
        errorMessage = nil
        selectedRange = .last12Months
        isLoading = false
        authStatus = .needsLogin
        clearPersistedState()
        Task { await removeDailyReminderNotification() }
    }

    // MARK: - Range Selection

    func selectRange(_ range: ContributionRange) {
        guard selectedRange != range else { return }
        selectedRange = range
        persistSelectedRange()
        fetchContributions()
    }

    func refreshContributions() {
        fetchContributions()
    }

    func refreshContributionsIfNeeded() {
        guard shouldRefreshOnOpen else { return }
        fetchContributions()
    }

    func selectMenuBarDisplayMode(_ mode: MenuBarDisplayMode) {
        guard menuBarDisplayMode != mode else { return }
        menuBarDisplayMode = mode
        persistMenuBarDisplayMode()
    }

    func setAutomaticRefreshEnabled(_ isEnabled: Bool) {
        guard automaticRefreshEnabled != isEnabled else { return }
        automaticRefreshEnabled = isEnabled
        persistAutomaticRefreshPreference()
        configureAutomaticRefreshLoop()
    }

    func setDailyReminderEnabled(_ isEnabled: Bool) {
        guard dailyReminderEnabled != isEnabled else { return }
        dailyReminderEnabled = isEnabled
        persistDailyReminderPreference()

        Task {
            await updateDailyReminderSchedule(requestAuthorizationIfNeeded: isEnabled)
        }
    }

    // MARK: - Fetch Contributions

    func fetchContributions() {
        errorMessage = nil
        refreshTask?.cancel()
        refreshTask = Task { await performFetch() }
    }

    // MARK: - Private: Auth Check

    private func performAuthCheck() async {
        authStatus = .checking

        guard auth.isInstalled() else {
            authStatus = .needsGH
            return
        }

        do {
            let fetchedToken = try await auth.getToken()
            guard !Task.isCancelled else { return }
            token = fetchedToken

            let fetchedUsername = try await service.fetchUsername(token: fetchedToken)
            guard !Task.isCancelled else { return }
            username = fetchedUsername
            authStatus = .loggedIn

            restoreCachedStateIfAvailable(for: fetchedUsername)
            await updateDailyReminderSchedule(requestAuthorizationIfNeeded: false)
            fetchContributions()
        } catch let error as AuthError {
            guard !Task.isCancelled else { return }
            switch error {
            case .ghNotInstalled: authStatus = .needsGH
            case .notAuthenticated: authStatus = .needsLogin
            }
        } catch {
            guard !Task.isCancelled else { return }
            authStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Private: Fetch

    private func performFetch() async {
        guard isLoggedIn else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await service.fetchContributions(
                username: username, token: token, range: selectedRange
            )
            guard !Task.isCancelled else { return }

            calendar = result
            lastUpdated = Date()
            persistCachedState()
            Task { [weak self] in
                await self?.updateDailyReminderSchedule(requestAuthorizationIfNeeded: false)
            }
        } catch {
            guard !Task.isCancelled else { return }

            if let ghError = error as? GitHubError, case .httpError(401) = ghError {
                errorMessage = "Token expired. Click Refresh to re-authenticate."
                token = ""
                authStatus = .needsLogin
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restorePersistedSelection() {
        guard
            let data = UserDefaults.standard.data(forKey: PersistenceKeys.selectedRange),
            let range = try? JSONDecoder().decode(ContributionRange.self, from: data)
        else {
            return
        }

        selectedRange = range
    }

    private func persistSelectedRange() {
        guard let data = try? JSONEncoder().encode(selectedRange) else { return }
        UserDefaults.standard.set(data, forKey: PersistenceKeys.selectedRange)
    }

    private func restoreCachedStateIfAvailable(for username: String) {
        guard
            let data = UserDefaults.standard.data(forKey: PersistenceKeys.cachedState),
            let cached = try? JSONDecoder().decode(CachedContributionState.self, from: data),
            cached.username == username,
            cached.selectedRange == selectedRange
        else {
            return
        }

        calendar = cached.calendar
        lastUpdated = cached.lastUpdated
    }

    private func restoreMenuBarDisplayMode() {
        guard
            let rawValue = UserDefaults.standard.string(forKey: PersistenceKeys.menuBarDisplayMode),
            let mode = MenuBarDisplayMode(rawValue: rawValue)
        else {
            return
        }

        menuBarDisplayMode = mode
    }

    private func restoreAutomaticRefreshPreference() {
        guard UserDefaults.standard.object(forKey: PersistenceKeys.automaticRefreshEnabled) != nil else {
            return
        }

        automaticRefreshEnabled = UserDefaults.standard.bool(forKey: PersistenceKeys.automaticRefreshEnabled)
    }

    private func restoreDailyReminderPreference() {
        guard UserDefaults.standard.object(forKey: PersistenceKeys.dailyReminderEnabled) != nil else {
            return
        }

        dailyReminderEnabled = UserDefaults.standard.bool(forKey: PersistenceKeys.dailyReminderEnabled)
    }

    private func persistCachedState() {
        guard let calendar, let lastUpdated else { return }

        let cached = CachedContributionState(
            username: username,
            selectedRange: selectedRange,
            calendar: calendar,
            lastUpdated: lastUpdated
        )

        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: PersistenceKeys.cachedState)
        persistSelectedRange()
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.cachedState)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.selectedRange)
    }

    private func persistMenuBarDisplayMode() {
        UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: PersistenceKeys.menuBarDisplayMode)
    }

    private func persistAutomaticRefreshPreference() {
        UserDefaults.standard.set(automaticRefreshEnabled, forKey: PersistenceKeys.automaticRefreshEnabled)
    }

    private func persistDailyReminderPreference() {
        UserDefaults.standard.set(dailyReminderEnabled, forKey: PersistenceKeys.dailyReminderEnabled)
    }

    private func configureAutomaticRefreshLoop() {
        backgroundRefreshTask?.cancel()

        guard automaticRefreshEnabled else { return }

        backgroundRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = UInt64(Self.automaticRefreshInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { break }
                await self?.performAutomaticRefreshIfNeeded()
            }
        }
    }

    private func performAutomaticRefreshIfNeeded() async {
        guard automaticRefreshEnabled, isLoggedIn, !isLoading else { return }
        await performFetch()
    }

    private func updateDailyReminderSchedule(requestAuthorizationIfNeeded: Bool) async {
        guard dailyReminderEnabled, isLoggedIn else {
            await removeDailyReminderNotification()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined, requestAuthorizationIfNeeded {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else {
                dailyReminderEnabled = false
                persistDailyReminderPreference()
                await removeDailyReminderNotification()
                return
            }
        } else if settings.authorizationStatus != .authorized, settings.authorizationStatus != .provisional {
            await removeDailyReminderNotification()
            return
        }

        let todayCount = await resolveTodayContributionCount()
        guard let todayCount, todayCount == 0 else {
            await removeDailyReminderNotification()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "No contributions yet today"
        content.body = "Open GitHub Contributions and keep your streak moving."
        content.sound = .default

        var components = DateComponents()
        components.hour = Self.dailyReminderHour
        components.minute = Self.dailyReminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func resolveTodayContributionCount() async -> Int? {
        if let todayContributions {
            return todayContributions
        }

        return try? await service.fetchTodayContributionCount(username: username, token: token)
    }

    private func removeDailyReminderNotification() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
    }
}
