import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var showSearch = false
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            if let data = viewModel.weatherData, data.current.condition.isPrecipitating {
                WeatherParticlesView(kind: .rain)
                    .ignoresSafeArea()
            } else if let data = viewModel.weatherData, data.current.condition.isSnowy {
                WeatherParticlesView(kind: .snow)
                    .ignoresSafeArea()
            }

            if viewModel.isLoading && viewModel.weatherData == nil {
                loadingView
            } else if let data = viewModel.weatherData {
                mainContent(data)
            } else {
                emptyStateView
            }

            if showSearch {
                searchOverlay
            }
        }
        .task {
            if viewModel.weatherData == nil {
                viewModel.requestCurrentLocation()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private func mainContent(_ data: WeatherData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                topBar

                CurrentWeatherView(
                    data: data,
                    temperatureUnit: viewModel.temperatureUnit,
                    windSpeedUnit: viewModel.windSpeedUnit
                )
                .padding(.top, 8)

                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                HourlyForecastView(hourly: data.hourly, temperatureUnit: viewModel.temperatureUnit)

                DailyForecastView(daily: data.daily, temperatureUnit: viewModel.temperatureUnit)

                WeatherDetailGridView(
                    current: data.current,
                    airQuality: viewModel.airQuality,
                    temperatureUnit: viewModel.temperatureUnit,
                    windSpeedUnit: viewModel.windSpeedUnit
                )

                if let today = data.daily.first {
                    SunArcView(sunrise: today.sunrise, sunset: today.sunset)
                }

                savedCitiesSection
            }
            .padding(.bottom, 32)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                viewModel.requestCurrentLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: Circle())
            }

            Spacer()

            Button {
                Haptics.tap()
                viewModel.toggleSaveCurrentCity()
            } label: {
                Image(systemName: viewModel.isCurrentCitySaved ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .disabled(viewModel.weatherData == nil)

            Button {
                withAnimation(.spring(response: 0.3)) { showSearch = true }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: Circle())
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var savedCitiesSection: some View {
        Group {
            if !viewModel.savedCities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved Cities")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)

                    ForEach(viewModel.savedCities) { city in
                        SavedCityRow(city: city) {
                            Haptics.tap()
                            Task { await viewModel.loadSavedCity(city) }
                        } onDelete: {
                            viewModel.removeSavedCity(city)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Fetching weather…")
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.8))
            Text("No weather data yet")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Button {
                viewModel.requestCurrentLocation()
            } label: {
                Label("Use My Location", systemImage: "location.fill")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.25), in: Capsule())
                    .foregroundStyle(.white)
            }
            Button {
                withAnimation(.spring(response: 0.3)) { showSearch = true }
            } label: {
                Label("Search for a City", systemImage: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var backgroundGradient: LinearGradient {
        let colors = viewModel.weatherData?.current.condition.gradientColors(
            isDay: viewModel.weatherData?.current.isDay ?? true
        ) ?? ["4A90D9", "87CEEB"]

        return LinearGradient(
            colors: colors.map { Color(hex: $0) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search for a city", text: $viewModel.searchQuery)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showSearch = false
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    }
                } label: {
                    Text("Cancel")
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding()
            .padding(.top, 40)

            if viewModel.isSearching {
                ProgressView().padding()
            }

            List(viewModel.searchResults, id: \.name) { result in
                Button {
                    Task {
                        await viewModel.selectSearchResult(result)
                        withAnimation(.spring(response: 0.3)) { showSearch = false }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(result.name).font(.body.weight(.medium))
                        Text(result.country).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Spacer()
        }
        .background(.regularMaterial)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear { searchFocused = true }
    }
}

// MARK: - Saved City Row

private struct SavedCityRow: View {
    let city: WeatherViewModel.SavedCity
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.white.opacity(0.8))
                Text(city.name)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Hex Color Helper

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
