import Foundation
import SwiftUI

extension Date {
    func startOfMonth(using calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }
    
    func daysInMonth(using calendar: Calendar = .current) -> Int {
        calendar.range(of: .day, in: .month, for: self)?.count ?? 0
    }
    
    func weekdayOfStart(using calendar: Calendar = .current) -> Int {
        // 1 = Sunday, 2 = Monday, etc.
        calendar.component(.weekday, from: self.startOfMonth(using: calendar))
    }
    
    func generateMonthDates(using calendar: Calendar = .current) -> [Date?] {
        let startOfCurrentMonth = self.startOfMonth(using: calendar)
        let totalDays = startOfCurrentMonth.daysInMonth(using: calendar)
        let leadingEmptySlots = startOfCurrentMonth.weekdayOfStart(using: calendar) - 1
        
        var days: [Date?] = Array(repeating: nil, count: leadingEmptySlots)
        
        for day in 0..<totalDays {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfCurrentMonth) {
                days.append(date)
            }
        }
        
        return days
    }
}


struct FullCalendarView: View {
    @Binding var selectedDate: Date
    @State private var visibleDate: Date = Date()
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let calendar = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with Month/Year Display and Controls
            HStack {
                Text(visibleDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Today") {
                        visibleDate = Date()
                        selectedDate = Date()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            
            // Weekday Row
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(visibleDate.generateMonthDates().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 35)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: visibleDate) {
            visibleDate = newDate
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.body)
            .frame(maxWidth: .infinity)
            .frame(height: 35)
            .background(cellBackground)
            .foregroundStyle(cellTextForegroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    @ViewBuilder
    private var cellBackground: some View {
        if isSelected {
            Color.accentColor
        } else if isToday {
            Color.accentColor.opacity(0.15)
        } else {
            Color(nsColor: .controlBackgroundColor)
        }
    }
    
    private var cellTextForegroundColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
}
