import Foundation

// MARK: - API Response Models (Open-Meteo)

struct WeatherResponse: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let currentWeather: CurrentWeatherAPI
    let hourly: HourlyAPI
    let daily: DailyAPI

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone
        case currentWeather = "current_weather"
        case hourly, daily
    }
}

struct CurrentWeatherAPI: Codable {
    let temperature: Double
    let windspeed: Double
    let winddirection: Double
    let weathercode: Int
    let time: String
    let isDay: Int

    enum CodingKeys: String, CodingKey {
        case temperature, windspeed, winddirection, weathercode, time
        case isDay = "is_day"
    }
}

struct HourlyAPI: Codable {
    let time: [String]
    let temperature2m: [Double]
    let weathercode: [Int]
    let precipitationProbability: [Int]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weathercode
        case precipitationProbability = "precipitation_probability"
    }
}

struct DailyAPI: Codable {
    let time: [String]
    let weathercode: [Int]
    let temperatureMax: [Double]
    let temperatureMin: [Double]
    let precipitationProbabilityMax: [Int]
    let sunrise: [String]
    let sunset: [String]

    enum CodingKeys: String, CodingKey {
        case time, weathercode
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case sunrise, sunset
    }
}

// MARK: - App-facing Models

struct CurrentWeather {
    let temperature: Double
    let feelsLikeCode: Int
    let windSpeed: Double
    let isDay: Bool
    let condition: WeatherCondition
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let condition: WeatherCondition
    let precipitationChance: Int
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let minTemp: Double
    let condition: WeatherCondition
    let precipitationChance: Int
}

struct WeatherData {
    let cityName: String
    let latitude: Double
    let longitude: Double
    let current: CurrentWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

// MARK: - Weather Condition Mapping (WMO codes)

enum WeatherCondition {
    case clearSky
    case mainlyClear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case rain
    case freezingRain
    case snow
    case snowGrains
    case rainShowers
    case snowShowers
    case thunderstorm
    case thunderstormHail
    case unknown

    static func from(code: Int) -> WeatherCondition {
        switch code {
        case 0: return .clearSky
        case 1: return .mainlyClear
        case 2: return .partlyCloudy
        case 3: return .overcast
        case 45, 48: return .fog
        case 51, 53, 55: return .drizzle
        case 56, 57: return .freezingRain
        case 61, 63, 65: return .rain
        case 66, 67: return .freezingRain
        case 71, 73, 75: return .snow
        case 77: return .snowGrains
        case 80, 81, 82: return .rainShowers
        case 85, 86: return .snowShowers
        case 95: return .thunderstorm
        case 96, 99: return .thunderstormHail
        default: return .unknown
        }
    }

    var systemImageName: String {
        switch self {
        case .clearSky: return "sun.max.fill"
        case .mainlyClear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .overcast: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .freezingRain: return "cloud.sleet.fill"
        case .snow: return "cloud.snow.fill"
        case .snowGrains: return "cloud.snow.fill"
        case .rainShowers: return "cloud.heavyrain.fill"
        case .snowShowers: return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.fill"
        case .thunderstormHail: return "cloud.bolt.rain.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var description: String {
        switch self {
        case .clearSky: return "Clear Sky"
        case .mainlyClear: return "Mainly Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .overcast: return "Overcast"
        case .fog: return "Foggy"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .freezingRain: return "Freezing Rain"
        case .snow: return "Snow"
        case .snowGrains: return "Snow Grains"
        case .rainShowers: return "Rain Showers"
        case .snowShowers: return "Snow Showers"
        case .thunderstorm: return "Thunderstorm"
        case .thunderstormHail: return "Thunderstorm with Hail"
        case .unknown: return "Unknown"
        }
    }

    /// Gradient colors used as the background depending on condition & day/night
    func gradientColors(isDay: Bool) -> [String] {
        if !isDay {
            return ["0F1C3F", "26315F"]
        }
        switch self {
        case .clearSky, .mainlyClear:
            return ["4A90D9", "87CEEB"]
        case .partlyCloudy:
            return ["6B93C1", "A8C5E0"]
        case .overcast, .fog:
            return ["768A96", "A9B7C0"]
        case .drizzle, .rain, .rainShowers, .freezingRain:
            return ["4B5D67", "7B93A0"]
        case .snow, .snowGrains, .snowShowers:
            return ["8DA5C4", "C9D6E3"]
        case .thunderstorm, .thunderstormHail:
            return ["2C3E50", "4C5F70"]
        case .unknown:
            return ["4A90D9", "87CEEB"]
        }
    }
}
