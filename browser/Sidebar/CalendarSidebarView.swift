import SwiftUI
import EventKit
internal import Combine

class CalendarViewModel: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus
    
    let eventStore = EKEventStore()
    
    @AppStorage("calDays", store:Config.sharedDefaults) var days: Int = 2
    
    init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() {
        if #available(macOS 14.0, iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted {
                        self?.fetchEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted {
                        self?.fetchEvents()
                    }
                }
            }
        }
    }
    
    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess || status == .writeOnly
        } else {
            return status == .authorized
        }
    }

    func fetchEvents() {
        guard isAuthorized else { return }
        
        let calendars = eventStore.calendars(for: .event)
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        var components = DateComponents()
        components.day = days
        components.second = -1
        let endOfTomorrow = Calendar.current.date(byAdding: components, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfTomorrow, calendars: calendars)
        let fetchedEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        self.events = fetchedEvents
    }
}

struct CalendarSidebarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Calendar")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button(action: {
                    viewModel.fetchEvents()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                
                
                    Picker("Days",selection: $viewModel.days) {
                        ForEach(2...30, id: \.self) {
                            Text("\($0)")
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                    
                
            }
            .padding()
            

            ScrollView {
                if viewModel.isAuthorized {
                    if viewModel.events.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 40))
                                .opacity(0.4)
                            Text("No events found")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.events, id: \.eventIdentifier) { event in
                                CalendarRow(event: event, timeString: timeString(for: event))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .opacity(0.4)
                        
                        Text("Calendar Access Required")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                        
                        Text("Please grant access to view your upcoming events.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Button("Grant Access") {
                            viewModel.requestAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.black.opacity(0.02))
        .onAppear {
            if viewModel.isAuthorized {
                viewModel.fetchEvents()
            }
        }
    }
    
    private func timeString(for event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = event.isAllDay ? .none : .medium
        
        if event.isAllDay {
            return "\(formatter.string(from: event.startDate)) - All Day"
        } else {
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            return "\(start) - \(end)"
        }
    }
}

struct CalendarRow: View {
    let event: EKEvent
    let timeString: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Circular Icon
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(timeString)
                        .lineLimit(1)
                    if let location = event.location, !location.isEmpty {
                        Text("•")
                        Text(location)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
