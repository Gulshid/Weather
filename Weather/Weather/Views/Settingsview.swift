import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Temperature", selection: $viewModel.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .onChange(of: viewModel.temperatureUnit) { _, _ in Haptics.selectionChanged() }

                    Picker("Wind Speed", selection: $viewModel.windSpeedUnit) {
                        ForEach(WindSpeedUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .onChange(of: viewModel.windSpeedUnit) { _, _ in Haptics.selectionChanged() }
                }

                Section("Saved Cities") {
                    if viewModel.savedCities.isEmpty {
                        Text("No saved cities yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.savedCities) { city in
                            Text(city.name)
                        }
                        .onDelete { offsets in
                            offsets.forEach { index in
                                viewModel.removeSavedCity(viewModel.savedCities[index])
                            }
                        }
                        .onMove(perform: viewModel.moveSavedCity)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.1")
                    LabeledContent("Weather Data", value: "Open-Meteo")
                    LabeledContent("Air Quality Data", value: "Open-Meteo")
                    Text("Forecasts and air quality are provided by the free Open-Meteo API. Data updates roughly every hour.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
