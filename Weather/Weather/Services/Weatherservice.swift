import Foundation
import CoreLocation

enum WeatherServiceError: LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed
    case cityNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL."
        case .requestFailed: return "Could not reach the weather service."
        case .decodingFailed: return "Could not read weather data."
        case .cityNotFound: return "City not found. Try a different search."
        }
    }
}

final class WeatherService {

    private let session = URLSession.shared
    private let isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        df.timeZone = TimeZone.current
        return df
    }()

    // MARK: - Public API

    /// Fetches full weather data for a coordinate pair, with an optional display name.
    func fetchWeather(latitude: Double, longitude: Double, cityName: String) async throws -> WeatherData {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,relative_humidity_2m,uv_index,visibility"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max,wind_speed_10m_max"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]

        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherServiceError.requestFailed
        }

        let decoder = JSONDecoder()
        let decoded: WeatherResponse
        do {
            decoded = try decoder.decode(WeatherResponse.self, from: data)
        } catch {
            print("WeatherService decode error: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("WeatherService raw response: \(raw)")
            }
            throw WeatherServiceError.decodingFailed
        }

        return mapToWeatherData(decoded, cityName: cityName)
    }

    /// Convenience for CLLocation-based lookups (uses reverse geocoding for the city name).
    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        let name = await reverseGeocode(location)
        return try await fetchWeather(latitude: location.coordinate.latitude,
                                       longitude: location.coordinate.longitude,
                                       cityName: name)
    }

    /// Fetches current air quality (European AQI + particulate matter) for a coordinate pair.
    func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQuality {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "current", value: "european_aqi,pm2_5,pm10")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherServiceError.requestFailed
        }

        struct AirQualityResponse: Codable {
            struct Current: Codable {
                let europeanAqi: Int
                let pm2_5: Double
                let pm10: Double

                enum CodingKeys: String, CodingKey {
                    case europeanAqi = "european_aqi"
                    case pm2_5
                    case pm10
                }
            }
            let current: Current
        }

        let decoded: AirQualityResponse
        do {
            decoded = try JSONDecoder().decode(AirQualityResponse.self, from: data)
        } catch {
            print("WeatherService air quality decode error: \(error)")
            throw WeatherServiceError.decodingFailed
        }

        return AirQuality(europeanAQI: decoded.current.europeanAqi,
                           pm2_5: decoded.current.pm2_5,
                           pm10: decoded.current.pm10)
    }

    /// Searches for a city name and returns matching results (name + coordinates).
    func searchCity(_ query: String) async throws -> [(name: String, latitude: Double, longitude: Double, country: String)] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherServiceError.requestFailed
        }

        struct GeoResponse: Codable {
            struct Result: Codable {
                let name: String
                let latitude: Double
                let longitude: Double
                let country: String?
                let admin1: String?
            }
            let results: [Result]?
        }

        guard let decoded = try? JSONDecoder().decode(GeoResponse.self, from: data),
              let results = decoded.results, !results.isEmpty else {
            throw WeatherServiceError.cityNotFound
        }

        return results.map { ($0.name, $0.latitude, $0.longitude, $0.country ?? "") }
    }

    // MARK: - Private helpers

    private func reverseGeocode(_ location: CLLocation) async -> String {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                let name = placemarks?.first?.locality
                    ?? placemarks?.first?.name
                    ?? "Current Location"
                continuation.resume(returning: name)
            }
        }
    }

    private func mapToWeatherData(_ response: WeatherResponse, cityName: String) -> WeatherData {
        let now = Date()

        let hourlyDates: [Date] = response.hourly.time.map { isoFormatter.date(from: $0) ?? .distantPast }

        // Find the hourly index closest to "now" to source current-hour-only fields
        // (UV index and visibility aren't available on the `current` endpoint).
        var currentHourIndex = 0
        var smallestDiff = Double.greatestFiniteMagnitude
        for (index, date) in hourlyDates.enumerated() {
            let diff = abs(date.timeIntervalSince(now))
            if diff < smallestDiff {
                smallestDiff = diff
                currentHourIndex = index
            }
        }

        let currentUV = response.hourly.uvIndex.indices.contains(currentHourIndex) ? response.hourly.uvIndex[currentHourIndex] : 0
        let currentVisibility = response.hourly.visibility.indices.contains(currentHourIndex) ? response.hourly.visibility[currentHourIndex] : 10000

        let current = CurrentWeather(
            temperature: response.current.temperature2m,
            feelsLike: response.current.apparentTemperature,
            humidity: response.current.relativeHumidity2m,
            windSpeed: response.current.windSpeed10m,
            windDirection: response.current.windDirection10m,
            pressure: response.current.surfacePressure,
            uvIndex: currentUV,
            visibility: currentVisibility,
            isDay: response.current.isDay == 1,
            condition: .from(code: response.current.weathercode)
        )

        var hourly: [HourlyForecast] = []
        for i in 0..<response.hourly.time.count {
            guard let date = isoFormatter.date(from: response.hourly.time[i]) else { continue }
            if date < now.addingTimeInterval(-3600) { continue }
            guard response.hourly.temperature2m.indices.contains(i),
                  response.hourly.weathercode.indices.contains(i),
                  response.hourly.precipitationProbability.indices.contains(i) else { continue }
            hourly.append(HourlyForecast(
                date: date,
                temperature: response.hourly.temperature2m[i],
                condition: .from(code: response.hourly.weathercode[i]),
                precipitationChance: response.hourly.precipitationProbability[i]
            ))
        }
        hourly = Array(hourly.prefix(24))

        var daily: [DailyForecast] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        for i in 0..<response.daily.time.count {
            guard let date = dayFormatter.date(from: response.daily.time[i]) else { continue }
            guard response.daily.temperatureMax.indices.contains(i),
                  response.daily.temperatureMin.indices.contains(i),
                  response.daily.weathercode.indices.contains(i),
                  response.daily.precipitationProbabilityMax.indices.contains(i) else { continue }
            let sunrise = i < response.daily.sunrise.count ? (isoFormatter.date(from: response.daily.sunrise[i]) ?? date) : date
            let sunset = i < response.daily.sunset.count ? (isoFormatter.date(from: response.daily.sunset[i]) ?? date) : date
            daily.append(DailyForecast(
                date: date,
                maxTemp: response.daily.temperatureMax[i],
                minTemp: response.daily.temperatureMin[i],
                condition: .from(code: response.daily.weathercode[i]),
                precipitationChance: response.daily.precipitationProbabilityMax[i],
                uvIndexMax: response.daily.uvIndexMax.indices.contains(i) ? response.daily.uvIndexMax[i] : 0,
                sunrise: sunrise,
                sunset: sunset
            ))
        }

        return WeatherData(cityName: cityName, latitude: response.latitude, longitude: response.longitude, current: current, hourly: hourly, daily: daily)
    }
}
