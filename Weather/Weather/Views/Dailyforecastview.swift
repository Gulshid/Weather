import SwiftUI

struct DailyForecastView: View {
    let daily: [DailyForecast]
    let temperatureUnit: TemperatureUnit

    private var overallMin: Double { daily.map(\.minTemp).min() ?? 0 }
    private var overallMax: Double { daily.map(\.maxTemp).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Forecast")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(daily.enumerated()), id: \.element.id) { index, day in
                    dayRow(day, isFirst: index == 0)
                    if index < daily.count - 1 {
                        Divider().background(.white.opacity(0.2))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func dayRow(_ day: DailyForecast, isFirst: Bool) -> some View {
        HStack {
            Text(isFirst ? "Today" : weekdayLabel(day.date))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 70, alignment: .leading)

            Image(systemName: day.condition.systemImageName)
                .symbolRenderingMode(.multicolor)
                .frame(width: 30)

            if day.precipitationChance > 0 {
                Text("\(day.precipitationChance)%")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                    .frame(width: 34)
            } else {
                Spacer().frame(width: 34)
            }

            Text(temperatureUnit.string(fromCelsius: day.minTemp))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 34, alignment: .trailing)

            TemperatureRangeBar(
                low: day.minTemp, high: day.maxTemp,
                overallLow: overallMin, overallHigh: overallMax
            )
            .frame(height: 4)

            Text(temperatureUnit.string(fromCelsius: day.maxTemp))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }

    private func weekdayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

private struct TemperatureRangeBar: View {
    let low: Double
    let high: Double
    let overallLow: Double
    let overallHigh: Double

    var body: some View {
        GeometryReader { geo in
            let totalRange = max(overallHigh - overallLow, 1)
            let startFraction = (low - overallLow) / totalRange
            let endFraction = (high - overallLow) / totalRange
            let width = geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))

                Capsule()
                    .fill(
                        LinearGradient(colors: [.cyan, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max((endFraction - startFraction) * width, 4))
                    .offset(x: startFraction * width)
            }
        }
    }
}
