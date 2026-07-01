import AppKit
import Foundation

class MacCalendarManager {
    
    private let incomingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd:HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    func presentAddEventPopup(title: String, startDateString: String, endDateString: String, location: String, notes: String) {
        
        guard let startDate = incomingDateFormatter.date(from: normalizeDate(startDateString) ?? ""),
              let endDate = incomingDateFormatter.date(from: normalizeDate(endDateString) ?? "") else {
            print("Error: Date strings do not match the expected format (yyyy-MM-dd:HH:mm:ss)")
            return
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        
        let startStr = isoFormatter.string(from: startDate).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        let endStr = isoFormatter.string(from: endDate).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        
        let icsString = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//YourApp//MacCalendarManager//EN
        BEGIN:VEVENT
        SUMMARY:\(title)
        DTSTART:\(startStr)
        DTEND:\(endStr)
        LOCATION:\(location)
        DESCRIPTION:\(notes)
        END:VEVENT
        END:VCALENDAR
        """
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("event.ics")
        
        do {
            try icsString.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(fileURL)
        } catch {
            print("Error saving event file: \(error.localizedDescription)")
        }
    }
}

struct EventExtraction: Decodable {
    let events: [ExtractedEvent]
}

struct ExtractedEvent: Decodable {
    let name: String
    let start: String
    let end: String
    let location: String
    let notes: String
}

func showEventPicker(events: [ExtractedEvent], onSelect: @escaping (ExtractedEvent) -> Void) {
    let alert = NSAlert()
    alert.messageText = "Select Event"
    
    let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    popup.addItems(withTitles: events.map { "\($0.name) (\(readableDate($0.start) ?? "unknown"))" })

    alert.accessoryView = popup
    alert.addButton(withTitle: "Add")
    alert.addButton(withTitle: "Cancel")

    let response = alert.runModal()

    if response == .alertFirstButtonReturn {
        let index = popup.indexOfSelectedItem
        guard events.indices.contains(index) else { return }
        onSelect(events[index])
    }
}

func normalizeDate(_ input: String) -> String? {
    let formats = [
        "yyyy-MM-dd:HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd'T'HH:mm:ssZ",
    ]

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    for format in formats {
        formatter.dateFormat = format
        if let date = formatter.date(from: input) {
            formatter.dateFormat = "yyyy-MM-dd:HH:mm:ss"
            return formatter.string(from: date)
        }
    }

    return nil
}



func readableDate(_ input: String) -> String? {
    let normalized = normalizeDate(input) ?? input

    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd:HH:mm:ss"

    guard let date = parser.date(from: normalized) else { return nil }

    let output = DateFormatter()
    output.locale = Locale(identifier: "en_US")
    output.dateStyle = .medium
    output.timeStyle = .short
    return output.string(from: date)
}
func insertEventDelimiters(_ text: String) -> String {
    var result = text

    let months = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
    let days = "Mon|Tue|Wed|Thu|Fri|Sat|Sun"
    result = replace(result, pattern: "(?:\(months))\\d{1,2}(?:\(days))",
                      template: "\n--\n$0")

    result = replace(result, pattern: "(?:\(days))",
                      template: "$0 | ")

    result = replace(result, pattern: "(?:0?[1-9]|1[0-2]):[0-5]\\d\\s?(?:AM|PM)",
                      template: " | $0 | ")
    
    result = replace(result, pattern: "[A-Z][a-zA-Z .]+, [A-Z]{2}, US",
                      template: " | $0 | ")

    result = collapseImmediateDuplicates(result)

    return result
}

private func replace(_ text: String, pattern: String, template: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
}

/// Detects a substring immediately followed by an exact repeat of itself and removes the repeat.
/// Handles cases like "VenueNameVenueName" -> "VenueName"
private func collapseImmediateDuplicates(_ text: String) -> String {
    let chars = Array(text)
    var result = ""
    var i = 0
    while i < chars.count {
        var matched = false
        // check for repeats of length 8...80 chars (venue names are usually in this range)
        for len in stride(from: 80, through: 8, by: -1) {
            guard i + len * 2 <= chars.count else { continue }
            let first = String(chars[i..<i+len])
            let second = String(chars[i+len..<i+len*2])
            if first == second {
                result += first
                i += len * 2
                matched = true
                break
            }
        }
        if !matched {
            result.append(chars[i])
            i += 1
        }
    }
    return result
}
