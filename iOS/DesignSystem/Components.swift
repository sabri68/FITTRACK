import SwiftUI

/// Circular progress ring.
struct RingView: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var gradient: AnyShapeStyle = AnyShapeStyle(Theme.accentGradient)
    var track: Color = Theme.subtleFill

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            if progress > 1 {
                // Overflow indicator when the target is exceeded.
                Circle()
                    .trim(from: 0, to: min(progress - 1, 1))
                    .stroke(Theme.warning, style: StrokeStyle(lineWidth: lineWidth * 0.45, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

/// Horizontal macro progress bar with label.
struct MacroBar: View {
    var title: String
    var value: Double
    var target: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(FTFormat.integer(value)) / \(FTFormat.grams(target))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(1, target > 0 ? value / target : 0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var subtitle: String? = nil
    var symbol: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.12)))
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    var title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(.subheadline.weight(.semibold))
            }
        }
        .padding(.top, 6)
    }
}

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Theme.accent.opacity(0.8))
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
    }
}

struct HalalBadge: View {
    var status: HalalStatus
    var compact = false

    var color: Color {
        switch status {
        case .declaredHalal, .naturallyHalal, .plantBased: return Theme.positive
        case .dependsOnOrigin, .unknown: return .secondary
        case .potentiallyNonHalal: return .red
        }
    }

    var body: some View {
        Label(compact ? shortLabel : status.label, systemImage: status.symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
            .accessibilityLabel(status.label)
    }

    private var shortLabel: String {
        switch status {
        case .declaredHalal: return "Halal déclaré"
        case .naturallyHalal: return "Brut"
        case .plantBased: return "Végétal"
        case .dependsOnOrigin: return "Selon provenance"
        case .unknown: return "Halal ?"
        case .potentiallyNonHalal: return "Non halal ?"
        }
    }
}

/// Numeric text field that accepts French decimal input ("12,5"). Zero is shown as an empty field.
struct DecimalField: View {
    var title: String
    @Binding var value: Double
    var suffix: String? = nil
    var width: CGFloat? = nil
    var identifier: String? = nil
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .frame(width: width)
                .accessibilityIdentifier(identifier ?? title)
                .onChange(of: text) { _, newValue in
                    if let v = FTFormat.parseDecimal(newValue) {
                        value = v
                    } else if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        value = 0
                    }
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { text = Self.display(value) }
                }
            if let suffix { Text(suffix).foregroundStyle(.secondary) }
        }
        .onAppear { text = Self.display(value) }
        .onChange(of: value) { _, newValue in
            if !focused { text = Self.display(newValue) }
        }
        .toolbar {
            if focused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { focused = false }
                }
            }
        }
    }

    private static func display(_ value: Double) -> String {
        value == 0 ? "" : FTFormat.number(value, maxFractionDigits: 2)
    }
}
