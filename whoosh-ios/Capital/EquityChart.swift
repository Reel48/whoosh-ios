import SwiftUI
import Charts

/// The Capital centerpiece: an animated lime area+line chart of WB balance over
/// time, with drag-to-scrub showing the value on a given day.
struct EquityChart: View {
    let series: [BalancePoint]
    @State private var selectedDay: Date?

    private var selected: BalancePoint? {
        guard let selectedDay else { return nil }
        return series.min(by: {
            abs($0.date.timeIntervalSince(selectedDay)) < abs($1.date.timeIntervalSince(selectedDay))
        })
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
                    .foregroundStyle(Color.whooshGreen)
                AreaMark(x: .value("Day", point.date), y: .value("Balance", value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.whooshLime.opacity(0.55), Color.whooshLime.opacity(0.05)],
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
                    .foregroundStyle(Color.whooshGreen)
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 200)
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
