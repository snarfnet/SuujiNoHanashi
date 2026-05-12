import Foundation

enum NumberCategory: String, CaseIterable, Identifiable {
    case trivia = "trivia"
    case math = "math"
    case year = "year"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .trivia: return "トリビア"
        case .math: return "数学"
        case .year: return "歴史"
        }
    }
    var icon: String {
        switch self {
        case .trivia: return "sparkles"
        case .math: return "function"
        case .year: return "calendar"
        }
    }
}

struct NumberFact {
    let number: Int
    let category: NumberCategory
    let english: String
}

func fetchNumberFact(number: Int, category: NumberCategory) async throws -> NumberFact {
    let url = URL(string: "http://numbersapi.com/\(number)/\(category.rawValue)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let text = String(data: data, encoding: .utf8) ?? "No fact found."
    return NumberFact(number: number, category: category, english: text)
}
