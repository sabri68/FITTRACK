import Foundation

/// French formatting helpers used across iPhone and Apple Watch.
enum FTFormat {
    static let locale = Locale(identifier: "fr_FR")

    static func number(_ value: Double, maxFractionDigits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...maxFractionDigits)).locale(locale))
    }

    static func integer(_ value: Double) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    /// "77,5 kg"
    static func weight(_ kg: Double) -> String { "\(number(kg)) kg" }

    /// "2 450 kcal"
    static func kcal(_ value: Double) -> String { "\(integer(value)) kcal" }

    /// "154 g"
    static func grams(_ value: Double) -> String { "\(integer(value)) g" }

    /// "177 cm"
    static func centimeters(_ value: Double) -> String { "\(integer(value)) cm" }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// "1:05:12" or "12:34"
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "1 h 05 min" or "45 min"
    static func durationLong(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds)) / 60
        let h = total / 60, m = total % 60
        return h > 0 ? String(format: "%d h %02d min", h, m) : "\(m) min"
    }

    /// "lundi 3 mars"
    static func dayLong(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    /// "3 mars 2025"
    static func dayMedium(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }

    /// "03/03"
    static func dayShort(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale))
    }

    /// "14:05"
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
    }

    /// Parses a decimal typed with a comma or a dot.
    static func parseDecimal(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let v = Double(cleaned), v.isFinite else { return nil }
        return v
    }
}
