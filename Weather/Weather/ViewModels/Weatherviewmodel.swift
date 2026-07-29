import Foundation
import CoreLocation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {

    @Published var weatherData: WeatherData?
    @Published var airQuality: AirQuality?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    @Published var searchQuery = ""
    @Published var searchResults: [(name: String, latitude: Double, longitude: Double, country: String)] = []
    @Published var isSearching = false

    /// Simple saved-city list, keyed by "lat,lon" and persisted to UserDefaults.
    @Published var savedCities: [SavedCity] = [] {
        didSet { persistSavedCities() }
    }

    /// Display units, persisted to UserDefaults so they survive relaunches.
    @Published var temperatureUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }
    @Published var windSpeedUnit: WindSpeedUnit {
        didSet { UserDefaults.standard.set(windSpeedUnit.rawValue, forKey: Keys.windSpeedUnit) }
    }

    private let service = WeatherService()
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let savedCities = "savedCitiesData"
        static let temperatureUnit = "temperatureUnit"
        static let windSpeedUnit = "windSpeedUnit"
    }

    struct SavedCity: Identifiable, Equatable, Codable {
        var id = UUID()
        let name: String
        let latitude: Double
        let longitude: Double
    }

    var isCurrentCitySaved: Bool {
        guard let data = weatherData else { return false }
        return savedCities.contains { $0.name == data.cityName }
    }

    init() {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: Keys.temperatureUnit), let unit = TemperatureUnit(rawValue: raw) {
            temperatureUnit = unit
        } else {
            temperatureUnit = .celsius
        }

        if let raw = defaults.string(forKey: Keys.windSpeedUnit), let unit = WindSpeedUnit(rawValue: raw) {
            windSpeedUnit = unit
        } else {
            windSpeedUnit = .kmh
        }

        if let storedData = defaults.data(forKey: Keys.savedCities),
           let decoded = try? JSONDecoder().decode([SavedCity].self, from: storedData) {
            savedCities = decoded
        }

        locationManager.$location
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] location in
                Task { await self?.loadWeather(for: location) }
            }
            .store(in: &cancellables)

        locationManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.errorMessage = message
                self?.isLoading = false
            }
            .store(in: &cancellables)

        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { await self?.performSearch(query) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Loading

    func requestCurrentLocation() {
        isLoading = true
        errorMessage = nil
        locationManager.requestLocation()
    }

    func loadWeather(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        do {
            let data = try await service.fetchWeather(for: location)
            weatherData = data
            lastUpdated = Date()
            await loadAirQuality(latitude: data.latitude, longitude: data.longitude)
        } catch is CancellationError {
            // Refresh was interrupted (e.g. user let go of pull-to-refresh early) — not a real error.
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Same as above, surfaced via URLSession instead of Swift's CancellationError.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadWeather(latitude: Double, longitude: Double, cityName: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let data = try await service.fetchWeather(latitude: latitude, longitude: longitude, cityName: cityName)
            weatherData = data
            lastUpdated = Date()
            await loadAirQuality(latitude: data.latitude, longitude: data.longitude)
        } catch is CancellationError {
            // Refresh was interrupted (e.g. user let go of pull-to-refresh early) — not a real error.
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Same as above, surfaced via URLSession instead of Swift's CancellationError.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadAirQuality(latitude: Double, longitude: Double) async {
        airQuality = try? await service.fetchAirQuality(latitude: latitude, longitude: longitude)
    }

    func refresh() async {
        guard let data = weatherData else { return }
        await loadWeather(latitude: data.latitude, longitude: data.longitude, cityName: data.cityName)
        Haptics.selectionChanged()
    }

    // MARK: - Search

    private func performSearch(_ query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            searchResults = try await service.searchCity(query)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func selectSearchResult(_ result: (name: String, latitude: Double, longitude: Double, country: String)) async {
        searchQuery = ""
        searchResults = []
        await loadWeather(latitude: result.latitude, longitude: result.longitude, cityName: result.name)
    }

    // MARK: - Saved Cities

    /// Adds or removes the currently displayed city from the saved list.
    func toggleSaveCurrentCity() {
        guard let data = weatherData else { return }
        if let existingIndex = savedCities.firstIndex(where: { $0.name == data.cityName }) {
            savedCities.remove(at: existingIndex)
        } else {
            savedCities.append(SavedCity(name: data.cityName, latitude: data.latitude, longitude: data.longitude))
            Haptics.success()
        }
    }

    func removeSavedCity(_ city: SavedCity) {
        savedCities.removeAll { $0.id == city.id }
    }

    func moveSavedCity(fromOffsets source: IndexSet, toOffset destination: Int) {
        savedCities.move(fromOffsets: source, toOffset: destination)
    }

    func loadSavedCity(_ city: SavedCity) async {
        await loadWeather(latitude: city.latitude, longitude: city.longitude, cityName: city.name)
    }

    private func persistSavedCities() {
        guard let encoded = try? JSONEncoder().encode(savedCities) else { return }
        UserDefaults.standard.set(encoded, forKey: Keys.savedCities)
    }
}
