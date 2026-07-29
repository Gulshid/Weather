import Foundation
import CoreLocation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {

    @Published var weatherData: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var searchQuery = ""
    @Published var searchResults: [(name: String, latitude: Double, longitude: Double, country: String)] = []
    @Published var isSearching = false

    /// Simple saved-city list, keyed by "lat,lon"
    @Published var savedCities: [SavedCity] = []

    private let service = WeatherService()
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()

    struct SavedCity: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let latitude: Double
        let longitude: Double
    }

    init() {
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
            weatherData = try await service.fetchWeather(for: location)
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
            weatherData = try await service.fetchWeather(latitude: latitude, longitude: longitude, cityName: cityName)
        } catch is CancellationError {
            // Refresh was interrupted (e.g. user let go of pull-to-refresh early) — not a real error.
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Same as above, surfaced via URLSession instead of Swift's CancellationError.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        guard let data = weatherData else { return }
        await loadWeather(latitude: data.latitude, longitude: data.longitude, cityName: data.cityName)
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

    func saveCurrentCity() {
        guard let data = weatherData else { return }
        guard !savedCities.contains(where: { $0.name == data.cityName }) else { return }
        savedCities.append(SavedCity(name: data.cityName, latitude: data.latitude, longitude: data.longitude))
    }

    func removeSavedCity(_ city: SavedCity) {
        savedCities.removeAll { $0.id == city.id }
    }

    func loadSavedCity(_ city: SavedCity) async {
        await loadWeather(latitude: city.latitude, longitude: city.longitude, cityName: city.name)
    }
}
