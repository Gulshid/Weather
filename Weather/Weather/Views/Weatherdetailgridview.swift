import SwiftUI

/// A grid of "Apple Weather"-style detail cards for the current conditions.
struct WeatherDetailGridView: View {
    let current: CurrentWeather
    let airQuality: AirQuality?
    let temperatureUnit: TemperatureUnit
    let windSpeedUnit: WindSpeedUnit

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conditions")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 12) {
                DetailCard(
                    icon: "thermometer.medium",
                    title: "Feels Like",
                    value: temperatureUnit.string(fromCelsius: current.feelsLike),
                    subtitle: feelsLikeNote
                )

                DetailCard(
                    icon: "humidity.fill",
                    title: "Humidity",
                    value: "\(current.humidity)%",
                    subtitle: humidityNote
                )

                DetailCard(
                    icon: "sun.max.trianglebadge.exclamationmark",
                    title: "UV Index",
                    value: "\(Int(current.uvIndex.rounded()))",
                    subtitle: current.uvIndexCategory
                )

                DetailCard(
                    icon: "wind",
                    title: "Wind",
                    value: windSpeedUnit.string(fromKmh: current.windSpeed),
                    subtitle: current.windDirectionLabel
                )

                DetailCard(
                    icon: "eye.fill",
                    title: "Visibility",
                    value: String(format: "%.1f km", current.visibility / 1000),
                    subtitle: current.visibilityDescription
                )

                DetailCard(
                    icon: "gauge.with.dots.needle.50percent",
                    title: "Pressure",
                    value: "\(Int(current.pressure.rounded())) hPa",
                    subtitle: pressureNote
                )

                if let airQuality {
                    DetailCard(
                        icon: "aqi.medium",
                        title: "Air Quality",
                        value: "\(airQuality.europeanAQI)",
                        subtitle: airQuality.category,
                        accentHex: airQuality.colorHex
                    )

                    DetailCard(
                        icon: "smoke.fill",
                        title: "PM2.5",
                        value: String(format: "%.1f µg/m³", airQuality.pm2_5),
                        subtitle: "Fine particulates"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var feelsLikeNote: String {
        current.feelsLike < current.temperature - 1 ? "Feels cooler" :
        current.feelsLike > current.temperature + 1 ? "Feels warmer" : "Similar to actual"
    }

    private var humidityNote: String {
        switch current.humidity {
        case ..<30: return "Dry"
        case 30..<60: return "Comfortable"
        default: return "Humid"
        }
    }

    private var pressureNote: String {
        switch current.pressure {
        case ..<1000: return "Low"
        case 1000..<1020: return "Normal"
        default: return "High"
        }
    }
}

private struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    var accentHex: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
            } icon: {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentHex.map { Color(hex: $0) } ?? .cyan)
            }

            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
