import SwiftUI
import EventKit
internal import Combine

class CalendarViewModel: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus
    let eventStore = EKEventStore()
    @AppStorage("calDays", store: Config.sharedDefaults) var days: Int = 2

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.fetchEvents() }
                }
            }
    }

    var isAuthorized: Bool {
            return authorizationStatus == .fullAccess
    }

    func fetchEvents() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else {
            events = []
            return
        }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        guard let end = Calendar.current.date(byAdding: .day, value: max(days, 1), to: start) else { return }
        let predicate = eventStore.predicateForEvents(
            withStart: start, end: end, calendars: eventStore.calendars(for: .event)
        )
        events = eventStore.events(matching: predicate)
            .filter { $0.endDate > now || $0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }
}

struct CalendarSidebarView: View {
    @StateObject private var viewModel = CalendarViewModel()

    private struct DayGroup: Identifiable {
        let date: Date
        let events: [EKEvent]
        var id: Date { date }
    }

    private var dayGroups: [DayGroup] {
        let today = Calendar.current.startOfDay(for: Date())
        let groups = Dictionary(grouping: viewModel.events) {
            max(today, Calendar.current.startOfDay(for: $0.startDate))
        }
        return groups.keys.sorted().map { DayGroup(date: $0, events: groups[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                if viewModel.isAuthorized {
                    if viewModel.events.isEmpty {
                        emptyState(
                            icon: "calendar.badge.checkmark",
                            title: "Nothing scheduled",
                            message: "No events in the next \(viewModel.days) days."
                        )
                    } else {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(dayGroups) { group in
                                VStack(alignment: .leading, spacing: 9) {
                                    dayHeading(group.date)
                                    VStack(spacing: 0) {
                                        ForEach(Array(group.events.enumerated()), id: \.offset) { index, event in
                                            CalendarRow(event: event)
                                            if index < group.events.count - 1 {
                                                Divider().padding(.leading, 22)
                                            }
                                        }
                                    }
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.primary.opacity(0.06))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                } else {
                    VStack(spacing: 12) {
                        emptyState(
                            icon: "calendar.badge.exclamationmark",
                            title: "Connect Calendar",
                            message: "Allow access to see your upcoming events here."
                        )
                        Button("Grant Access") { viewModel.requestAccess() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.primary.opacity(0.025))
        .onAppear { viewModel.fetchEvents() }
        .onChange(of: viewModel.days) { _, _ in viewModel.fetchEvents() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            viewModel.fetchEvents()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Calendar")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            Spacer(minLength: 0)
            Button { viewModel.fetchEvents() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh events")
            Menu {
                ForEach([2, 3, 7, 14, 30], id: \.self) { days in
                    Button {
                        viewModel.days = days
                    } label: {
                        if viewModel.days == days {
                            Label("Next \(days) days", systemImage: "checkmark")
                        } else {
                            Text("Next \(days) days")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.days)d")
                    }
                .font(.caption)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .tint(.primary)
            .help("Days to show")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func dayHeading(_ date: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(Calendar.current.isDateInToday(date) ? "Today" :
                    Calendar.current.isDateInTomorrow(date) ? "Tomorrow" :
                    date.formatted(.dateTime.weekday(.wide)))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 56)
    }
}

struct CalendarRow: View {
    let event: EKEvent

    private var eventColor: Color {
        guard let color = event.calendar?.cgColor else { return .appAccent }
        return Color(cgColor: color)
    }

    private var timeLabel: String {
        if event.isAllDay { return "All day" }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title ?? "Untitled event")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Label(timeLabel, systemImage: "clock")
                    .lineLimit(1)
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
    }
}
