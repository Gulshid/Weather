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
            URLQueryItem(name: "current_weather", value: "true"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weathercode,precipitation_probability"),
            URLQueryItem(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "windspeed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]

        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherServiceError.requestFailed
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(WeatherResponse.self, from: data) else {
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
        let current = CurrentWeather(
            temperature: response.currentWeather.temperature,
            feelsLikeCode: response.currentWeather.weathercode,
            windSpeed: response.currentWeather.windspeed,
            isDay: response.currentWeather.isDay == 1,
            condition: .from(code: response.currentWeather.weathercode)
        )

        let now = Date()
        var hourly: [HourlyForecast] = []
        for i in 0..<response.hourly.time.count {
            guard let date = isoFormatter.date(from: response.hourly.time[i]) else { continue }
            if date < now.addingTimeInterval(-3600) { continue }
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
            daily.append(DailyForecast(
                date: date,
                maxTemp: response.daily.temperatureMax[i],
                minTemp: response.daily.temperatureMin[i],
                condition: .from(code: response.daily.weathercode[i]),
                precipitationChance: response.daily.precipitationProbabilityMax[i]
            ))
        }

        return WeatherData(cityName: cityName, latitude: response.latitude, longitude: response.longitude, current: current, hourly: hourly, daily: daily)
    }
}
