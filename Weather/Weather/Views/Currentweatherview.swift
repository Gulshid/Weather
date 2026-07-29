import SwiftUI

struct CurrentWeatherView: View {
    let data: WeatherData
    let temperatureUnit: TemperatureUnit
    let windSpeedUnit: WindSpeedUnit

    var body: some View {
        VStack(spacing: 8) {
            Text(data.cityName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)

            Text(Date(), style: .date)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Image(systemName: data.current.condition.systemImageName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 90))
                .padding(.vertical, 8)

            Text(temperatureUnit.string(fromCelsius: data.current.temperature))
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.white)

            Text(data.current.condition.description)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))

            Text("Feels like \(temperatureUnit.string(fromCelsius: data.current.feelsLike))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))

            if let today = data.daily.first {
                Text("H:\(temperatureUnit.string(fromCelsius: today.maxTemp))  L:\(temperatureUnit.string(fromCelsius: today.minTemp))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 24) {
                WeatherStatChip(icon: "wind", label: "Wind", value: windSpeedUnit.string(fromKmh: data.current.windSpeed))
                if let today = data.daily.first {
                    WeatherStatChip(icon: "umbrella.fill", label: "Rain", value: "\(today.precipitationChance)%")
                }
                WeatherStatChip(icon: "humidity.fill", label: "Humidity", value: "\(data.current.humidity)%")
            }
            .padding(.top, 12)
        }
        .padding(.horizontal)
    }
}

private struct WeatherStatChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(minWidth: 70)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }
}
