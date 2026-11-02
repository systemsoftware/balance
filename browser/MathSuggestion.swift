
import Foundation
import Expression

struct MathSuggestion {
    let expression: String
    let result: String
}

func mathSuggestion(for input: String) -> MathSuggestion? {
    let text = input
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "×", with: "*")
        .replacingOccurrences(of: "÷", with: "/")
        .replacingOccurrences(of: "−", with: "-")

    guard !text.isEmpty, text.count <= 100 else {
        return nil
    }

    let allowed = CharacterSet(
        charactersIn: "0123456789+-*/%.() "
    )

    guard text.unicodeScalars.allSatisfy({
        allowed.contains($0)
    }) else {
        return nil
    }

    guard text.contains(where: {
        "+-*/%".contains($0)
    }) else {
        return nil
    }

    do {
        let value = try NumericExpression(text).evaluate()

        guard value.isFinite else { return nil }

        let result = value.formatted(
            .number.precision(.significantDigits(1...12))
                .grouping(.never)
        )

        return MathSuggestion(
            expression: input,
            result: result
        )
    } catch {
        return nil
    }
}
