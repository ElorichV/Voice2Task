import Foundation

struct TaskDraft: Equatable {
    let title: String
    let priority: Priority
    let dueDate: Date?
}

struct LocalTaskExtractor {
    var now: Date = .now
    var calendar: Calendar = .current

    func extract(from text: String) -> [TaskDraft] {
        let clauses = splitIntoClauses(text)
        var drafts: [TaskDraft] = []
        var seenTitles = Set<String>()

        for clause in clauses {
            let trimmedClause = clause.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedClause.isEmpty else { continue }

            let draft = TaskDraft(
                title: cleanTitle(from: trimmedClause),
                priority: priority(in: trimmedClause),
                dueDate: dueDate(in: trimmedClause)
            )
            guard draft.title.split(whereSeparator: \.isWhitespace).count >= 2 else { continue }

            let deduplicationKey = draft.title.lowercased()
            guard seenTitles.insert(deduplicationKey).inserted else { continue }
            drafts.append(draft)
            if drafts.count == 10 { break }
        }

        return drafts
    }

    private func splitIntoClauses(_ text: String) -> [String] {
        let punctuation = CharacterSet(charactersIn: ".!?;").union(.newlines)
        let clauses = text.components(separatedBy: punctuation)
        let connectors = [" y luego ", " además ", " también ", " después "]

        return clauses.flatMap { clause in
            connectors.reduce([clause]) { parts, connector in
                parts.flatMap { split($0, on: connector) }
            }
        }
    }

    private func split(_ text: String, on connector: String) -> [String] {
        var remainder = text
        var parts: [String] = []

        while let range = remainder.range(
            of: connector,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "es_ES")
        ) {
            parts.append(String(remainder[..<range.lowerBound]))
            remainder = String(remainder[range.upperBound...])
        }
        parts.append(remainder)
        return parts
    }

    private func priority(in text: String) -> Priority {
        let lowPriorityPhrases = [
            "cuando haya tiempo", "cuando pueda", "cuando puedas", "algún día",
            "sin prisa", "no es urgente", "prioridad baja", "si da tiempo",
        ]
        if lowPriorityPhrases.contains(where: { containsPhrase($0, in: text) }) {
            return .baja
        }

        let highPriorityPhrases = [
            "urgente", "urge", "importante", "cuanto antes", "lo antes posible",
            "asap", "prioridad alta", "hoy mismo", "hoy",
        ]
        if highPriorityPhrases.contains(where: { containsPhrase($0, in: text) }) {
            return .alta
        }
        return .media
    }

    private func dueDate(in text: String) -> Date? {
        let today = calendar.startOfDay(for: now)

        if containsPhrase("pasado mañana", in: text) {
            return calendar.date(byAdding: .day, value: 2, to: today)
        }
        if containsTomorrow(in: text) {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        if containsPhrase("hoy", in: text) {
            return today
        }
        if containsPhrase("esta semana", in: text) {
            return comingFriday(from: today)
        }
        if containsPhrase("la próxima semana", in: text)
            || containsPhrase("la semana que viene", in: text) {
            return nextMonday(from: today)
        }
        if containsPhrase("fin de semana", in: text) {
            return nextSaturday(from: today)
        }

        let weekdays = [
            ("lunes", 2), ("martes", 3), ("miércoles", 4), ("jueves", 5),
            ("viernes", 6), ("sábado", 7), ("domingo", 1),
        ]
        for (name, weekday) in weekdays where containsPhrase(name, in: text) {
            return nextOccurrence(of: weekday, from: today)
        }
        return nil
    }

    private func containsTomorrow(in text: String) -> Bool {
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(
                of: "mañana",
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: Locale(identifier: "es_ES")
              ) {
            if hasWordBoundaries(around: range, in: text) {
                let prefix = String(text[..<range.lowerBound])
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !["por la", "en la", "de la", "pasado"].contains(where: { prefix.hasSuffix($0) }) {
                    return true
                }
            }
            searchStart = range.upperBound
        }
        return false
    }

    private func comingFriday(from today: Date) -> Date? {
        let weekday = calendar.component(.weekday, from: today)
        guard weekday != 6, weekday != 7, weekday != 1 else { return today }
        return calendar.date(byAdding: .day, value: 6 - weekday, to: today)
    }

    private func nextMonday(from today: Date) -> Date? {
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (2 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: today)
    }

    private func nextSaturday(from today: Date) -> Date? {
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday, to: today)
    }

    private func nextOccurrence(of weekday: Int, from today: Date) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: today)
        let difference = (weekday - currentWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: difference == 0 ? 7 : difference, to: today)
    }

    private func cleanTitle(from clause: String) -> String {
        var title = clause
        let leadingFillers = [
            "pasado mañana", "la próxima semana", "esta semana", "cuando haya tiempo",
            "tengo que", "tenemos que", "acuérdate de", "no olvides", "recuérdame",
            "cuando puedas", "cuando pueda", "algún día", "si da tiempo", "sin prisa",
            "prioridad baja", "prioridad alta", "debería", "necesitamos", "necesito",
            "debemos", "debo", "me falta", "no olvidar", "recordar", "además",
            "después", "entonces", "también", "mañana", "hoy", "luego", "quiero",
            "vamos a", "voy a", "por favor", "hay que", "y", "e", "pero",
        ]

        while true {
            title = trimLeadingSeparators(title)
            guard let filler = leadingFillers.first(where: { startsWithPhrase($0, in: title) }),
                  let range = title.range(
                    of: filler,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: title.startIndex..<title.endIndex,
                    locale: Locale(identifier: "es_ES")
                  ) else {
                break
            }
            title = String(title[range.upperBound...])
        }

        let removablePhrases = Self.priorityPhrases
            + Self.datePhrases
        for phrase in removablePhrases {
            title = removingPhrase(phrase, from: title)
        }

        title = title
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard let firstCharacter = title.first else { return "" }
        return firstCharacter.uppercased() + title.dropFirst()
    }

    private func trimLeadingSeparators(_ text: String) -> String {
        var result = text
        while let first = result.first, first.isWhitespace || first == "," {
            result.removeFirst()
        }
        return result
    }

    private func startsWithPhrase(_ phrase: String, in text: String) -> Bool {
        guard let range = text.range(
            of: phrase,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: text.startIndex..<text.endIndex,
            locale: Locale(identifier: "es_ES"),
            ),
            range.lowerBound == text.startIndex else {
            return false
        }
        return range.upperBound == text.endIndex || text[range.upperBound].isWhitespace || text[range.upperBound] == ","
    }

    private func containsPhrase(_ phrase: String, in text: String) -> Bool {
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(
                of: phrase,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: Locale(identifier: "es_ES")
              ) {
            if hasWordBoundaries(around: range, in: text) { return true }
            searchStart = range.upperBound
        }
        return false
    }

    private func removingPhrase(_ phrase: String, from text: String) -> String {
        var result = text
        var searchStart = result.startIndex
        while searchStart < result.endIndex,
              let range = result.range(
                of: phrase,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<result.endIndex,
                locale: Locale(identifier: "es_ES")
              ) {
            if hasWordBoundaries(around: range, in: result) {
                result.replaceSubrange(range, with: " ")
                searchStart = result.index(range.lowerBound, offsetBy: 1, limitedBy: result.endIndex) ?? result.endIndex
            } else {
                searchStart = range.upperBound
            }
        }
        return result
    }

    private func hasWordBoundaries(around range: Range<String.Index>, in text: String) -> Bool {
        let previous = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : nil
        let next = range.upperBound < text.endIndex ? text[range.upperBound] : nil
        return previous.map { !isWordCharacter($0) } ?? true
            && (next.map { !isWordCharacter($0) } ?? true)
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    private static let priorityPhrases = [
        "no es urgente", "prioridad baja", "prioridad alta", "cuando haya tiempo",
        "cuando puedas", "cuando pueda", "algún día", "sin prisa", "si da tiempo",
        "lo antes posible", "cuanto antes", "hoy mismo", "es urgente", "es importante",
        "urgente", "importante", "urge", "asap", "hoy",
    ]

    private static let datePhrases = [
        "para pasado mañana", "pasado mañana", "para mañana", "por la mañana",
        "en la mañana", "de la mañana", "mañana", "para esta semana", "esta semana",
        "para la próxima semana", "la próxima semana", "para la semana que viene",
        "la semana que viene", "este fin de semana", "el fin de semana",
        "para el fin de semana", "para fin de semana", "fin de semana", "para hoy", "hoy",
        "para el lunes", "para lunes", "el lunes", "lunes", "para el martes", "para martes",
        "el martes", "martes", "para el miércoles", "para miércoles", "el miércoles", "miércoles",
        "para el jueves", "para jueves", "el jueves", "jueves", "para el viernes", "para viernes",
        "el viernes", "viernes", "para el sábado", "para sábado", "el sábado", "sábado",
        "para el domingo", "para domingo", "el domingo", "domingo",
    ]
}
