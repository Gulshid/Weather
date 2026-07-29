import Foundation

// MARK: - API Response Models (Open-Meteo)

struct WeatherResponse: Codable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let current: CurrentAPI
    let hourly: HourlyAPI
    let daily: DailyAPI

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone, current, hourly, daily
    }
}

struct CurrentAPI: Codable {
    let time: String
    let temperature2m: Double
    let relativeHumidity2m: Int
    let apparentTemperature: Double
    let isDay: Int
    let precipitation: Double
    let weathercode: Int
    let surfacePressure: Double
    let windSpeed10m: Double
    let windDirection10m: Double

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case isDay = "is_day"
        case precipitation
        case weathercode = "weather_code"
        case surfacePressure = "surface_pressure"
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
    }
}

/// Decodes a numeric array leniently: Open-Meteo can return `null` entries in
/// arrays like `uv_index` or `visibility` for certain locations/models. A plain
/// `[Double]`/`[Int]` fails to decode entirely if even one element is null, which
/// previously caused the whole response to be rejected. Nulls are mapped to `fallback`.
private func decodeLenientArray<T: LosslessStringConvertible & Decodable>(
    _ container: KeyedDecodingContainer<HourlyAPI.CodingKeys>,
    key: HourlyAPI.CodingKeys,
    fallback: T
) throws -> [T] {
    guard container.contains(key) else { return [] }
    let optionalValues = try container.decode([T?].self, forKey: key)
    return optionalValues.map { $0 ?? fallback }
}

private func decodeLenientArray<T: LosslessStringConvertible & Decodable>(
    _ container: KeyedDecodingContainer<DailyAPI.CodingKeys>,
    key: DailyAPI.CodingKeys,
    fallback: T
) throws -> [T] {
    guard container.contains(key) else { return [] }
    let optionalValues = try container.decode([T?].self, forKey: key)
    return optionalValues.map { $0 ?? fallback }
}

struct HourlyAPI: Codable {
    let time: [String]
    let temperature2m: [Double]
    let weathercode: [Int]
    let precipitationProbability: [Int]
    let relativeHumidity2m: [Int]
    let uvIndex: [Double]
    let visibility: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weathercode = "weather_code"
        case precipitationProbability = "precipitation_probability"
        case relativeHumidity2m = "relative_humidity_2m"
        case uvIndex = "uv_index"
        case visibility
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode([String].self, forKey: .time)
        temperature2m = try decodeLenientArray(container, key: .temperature2m, fallback: 0)
        weathercode = try decodeLenientArray(container, key: .weathercode, fallback: 0)
        precipitationProbability = try decodeLenientArray(container, key: .precipitationProbability, fallback: 0)
        relativeHumidity2m = try decodeLenientArray(container, key: .relativeHumidity2m, fallback: 0)
        uvIndex = try decodeLenientArray(container, key: .uvIndex, fallback: 0)
        visibility = try decodeLenientArray(container, key: .visibility, fallback: 10000)
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
    let uvIndexMax: [Double]
    let windSpeed10mMax: [Double]

    enum CodingKeys: String, CodingKey {
        case time, weathercode
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case sunrise, sunset
        case uvIndexMax = "uv_index_max"
        case windSpeed10mMax = "wind_speed_10m_max"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode([String].self, forKey: .time)
        weathercode = try decodeLenientArray(container, key: .weathercode, fallback: 0)
        temperatureMax = try decodeLenientArray(container, key: .temperatureMax, fallback: 0)
        temperatureMin = try decodeLenientArray(container, key: .temperatureMin, fallback: 0)
        precipitationProbabilityMax = try decodeLenientArray(container, key: .precipitationProbabilityMax, fallback: 0)
        sunrise = try decodeLenientArray(container, key: .sunrise, fallback: "")
        sunset = try decodeLenientArray(container, key: .sunset, fallback: "")
        uvIndexMax = try decodeLenientArray(container, key: .uvIndexMax, fallback: 0)
        windSpeed10mMax = try decodeLenientArray(container, key: .windSpeed10mMax, fallback: 0)
    }
}

// MARK: - Air Quality (Open-Meteo Air Quality API)

struct AirQuality {
    let europeanAQI: Int
    let pm2_5: Double
    let pm10: Double

    var category: String {
        switch europeanAQI {
        case ..<20: return "Good"
        case 20..<40: return "Fair"
        case 40..<60: return "Moderate"
        case 60..<80: return "Poor"
        case 80..<100: return "Very Poor"
        default: return "Extremely Poor"
        }
    }

    var colorHex: String {
        switch europeanAQI {
        case ..<20: return "4CAF50"
        case 20..<40: return "8BC34A"
        case 40..<60: return "FFC107"
        case 60..<80: return "FF9800"
        case 80..<100: return "F44336"
        default: return "9C27B0"
        }
    }
}

// MARK: - Units

enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius, fahrenheit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .celsius: return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }

    var symbol: String { self == .celsius ? "°C" : "°F" }

    func convert(fromCelsius celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return celsius * 9 / 5 + 32
        }
    }

    func string(fromCelsius celsius: Double) -> String {
        "\(Int(convert(fromCelsius: celsius).rounded()))°"
    }
}

enum WindSpeedUnit: String, CaseIterable, Identifiable, Codable {
    case kmh, mph

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kmh: return "Kilometers/hour (km/h)"
        case .mph: return "Miles/hour (mph)"
        }
    }

    var shortLabel: String { self == .kmh ? "km/h" : "mph" }

    func convert(fromKmh kmh: Double) -> Double {
        self == .kmh ? kmh : kmh * 0.621371
    }

    func string(fromKmh kmh: Double) -> String {
        "\(Int(convert(fromKmh: kmh).rounded())) \(shortLabel)"
    }
}

// MARK: - App-facing Models

struct CurrentWeather {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Double
    let pressure: Double
    let uvIndex: Double
    let visibility: Double
    let isDay: Bool
    let condition: WeatherCondition

    /// 16-point compass label for the current wind direction.
    var windDirectionLabel: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                           "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((windDirection.truncatingRemainder(dividingBy: 360) / 22.5).rounded()) % 16
        return directions[index]
    }

    var uvIndexCategory: String {
        switch uvIndex {
        case ..<3: return "Low"
        case 3..<6: return "Moderate"
        case 6..<8: return "High"
        case 8..<11: return "Very High"
        default: return "Extreme"
        }
    }

    var visibilityDescription: String {
        let km = visibility / 1000
        if km >= 10 { return "Excellent" }
        if km >= 4 { return "Good" }
        if km >= 1 { return "Moderate" }
        return "Poor"
    }
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
    let uvIndexMax: Double
    let sunrise: Date
    let sunset: Date
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

    /// Whether this condition should trigger the animated precipitation overlay.
    var isPrecipitating: Bool {
        switch self {
        case .drizzle, .rain, .freezingRain, .rainShowers, .thunderstorm, .thunderstormHail:
            return true
        default:
            return false
        }
    }

    var isSnowy: Bool {
        switch self {
        case .snow, .snowGrains, .snowShowers:
            return true
        default:
            return false
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
