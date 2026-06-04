import SwiftUI
import Charts

/// The Capital centerpiece: an animated lime area+line chart of WB balance over
/// time, with drag-to-scrub showing the value on a given day.
struct EquityChart: View {
    let series: [BalancePoint]
    @State private var selectedDay: Date?
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: BalancePoint? {
        guard let selectedDay else { return nil }
        return series.min(by: {
            abs($0.date.timeIntervalSince(selectedDay)) < abs($1.date.timeIntervalSince(selectedDay))
        })
    }

    /// Green if the balance ended at/above where it started over the range, red if down.
    private var trend: Color {
        guard let first = series.first?.balanceCents, let last = series.last?.balanceCents else { return .good }
        return Money.direction(Double(first), Double(last))
    }

    var body: some View {
        if series.count < 2 {
            emptyState
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(series) { point in
                let value = Double(point.balanceCents) / 100
                LineMark(x: .value("Day", point.date), y: .value("Balance", value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(trend)
                AreaMark(x: .value("Day", point.date), y: .value("Balance", value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [trend.opacity(0.45), trend.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            if let sel = selected {
                RuleMark(x: .value("Day", sel.date))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(Money.wb(sel.balanceCents)).font(.caption.bold())
                            Text(sel.date, format: .dateTime.month().day()).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                PointMark(x: .value("Day", sel.date),
                          y: .value("Balance", Double(sel.balanceCents) / 100))
                    .foregroundStyle(trend)
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 200)
        // Draw the curve in left→right on first appear.
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle().frame(width: revealed ? geo.size.width : 0)
            }
        }
        .onAppear {
            guard !revealed else { return }
            if reduceMotion { revealed = true }
            else { withAnimation(.easeOut(duration: 0.7)) { revealed = true } }
        }
    }

    private var emptyState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
            VStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.title2).foregroundStyle(.secondary)
                Text("No balance history yet").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
    }
}
