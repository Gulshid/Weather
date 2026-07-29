import SwiftUI

struct HourlyForecastView: View {
    let hourly: [HourlyForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Forecast")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(hourly) { hour in
                        VStack(spacing: 10) {
                            Text(hourLabel(hour.date))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))

                            Image(systemName: hour.condition.systemImageName)
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)

                            Text("\(Int(hour.temperature.rounded()))°")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            if hour.precipitationChance > 0 {
                                Text("\(hour.precipitationChance)%")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .frame(width: 56)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func hourLabel(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .hour) {
            return "Now"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
}
