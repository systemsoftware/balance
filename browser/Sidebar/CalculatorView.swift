import SwiftUI

struct CalculatorView: View {
    @State private var display = "0"
    
    private let buttons: [[String]] = [
        ["AC", "+/-", "/"],
        ["7", "8", "9", "X"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["0", ".", "="]
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(display)
                .font(.system(size: 70, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 30)
            
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(buttons, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { button in
                            Button(action: {
                                handleTap(button)
                            }) {
                                Text(button)
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(buttonColor(button).textColor)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .background(buttonColor(button).bg)

                            .gridCellColumns(button == "0" || button == "AC" ? 2 : 1)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 16)
        }
    }
    
    private func handleTap(_ button: String) {
        if button == "AC" {
            display = "0"
        } else if display == "0" && button != "." {
            display = button
        } else if button == "=" {
            if let r = mathSuggestion(for: display.replacingOccurrences(of: "X", with: "*")) {
                display = r.result
            }
        } else if button == "+/-" {
            if display.first == "-" {
                display.removeFirst()
            } else {
                display = "-" + display
            }
        }
        else {
            display += button
        }
    }
    
    private func buttonColor(_ text: String) -> (bg: Color, textColor: Color) {
        if ["AC", "+/-", "%"].contains(text) {
            return (Color(.lightGray), .black)
        }
        if ["/", "X", "-", "+", "="].contains(text) {
            return (.orange, .white)
        }
        return (Color(.darkGray), .white)
    }
}
