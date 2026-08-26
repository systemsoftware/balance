import SwiftUI

struct WeatherSidebarView: View {

    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345

    @AppStorage("homepageWeatherCity", store:Config.sharedDefaults) var weatherCity: String = ""

    @State private var location: String = ""

    @StateObject var vm = WeatherViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    SearchInputView(text: $location, placeholder:"Enter a location")

                    if vm.isLoading && vm.weather == nil {
                        ProgressView("Loading weather…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if let weather = vm.weather {
                        currentWeatherCard(weather)

                        if let hourly = weather.hourly, !hourly.isEmpty {
                            hourlyForecast(hourly)
                        }

                        detailsSection(weather)

                        astronomySection(weather)
                    } else {
                        ContentUnavailableView(
                            "Weather unavailable",
                            systemImage: "cloud.slash",
                            description: Text("Try searching for another city.")
                        )
                        .padding(.vertical, 32)
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: CGFloat(sidebarWidth))
        .background(Color.primary.opacity(0.025))
        .task(id: location) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if location.isEmpty {
                vm.fetch(city:weatherCity)
            } else {
               vm.fetch(city: location)
           }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Weather", systemImage: "cloud.sun.fill")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            Spacer()

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Current Weather

    @ViewBuilder
    private func currentWeatherCard(_ weather: WeatherInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weather.location)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(weather.temperature)
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .monospacedDigit()

                    Text(weather.condition)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                }

                Spacer()

                Image(systemName: weather.icon)
                    .font(.system(size: 44))
                    .symbolRenderingMode(.multicolor)
            }

            Divider()

            HStack(spacing: 10) {
                miniStat(
                    icon: "wind",
                    title: "Wind",
                    value: weather.wind
                )

                miniStat(
                    icon: "eye.fill",
                    title: "Visibility",
                    value: format(weather.visibility, suffix: " mi")
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06))
        }
    }

    // MARK: - Hourly

    @ViewBuilder
    private func hourlyForecast(_ hourly: [HourlyWeatherInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hourly Forecast", icon: "clock.fill")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(hourly) { hour in
                        VStack(spacing: 8) {
                            Text(displayTime(hour.time))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Image(systemName: hour.icon)
                                .font(.title2)
                                .symbolRenderingMode(.multicolor)
                                .frame(height: 28)

                            Text(hour.temperature)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .monospacedDigit()

                            if !hour.precip.isEmpty, hour.precip != "0.0" {
                                Label(format(hour.precip, suffix: " in"), systemImage: "drop.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 72)
                        .padding(.vertical, 12)
                        .background(
                            Color.primary.opacity(0.045),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Details

    @ViewBuilder
    private func detailsSection(_ weather: WeatherInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Conditions", icon: "gauge.with.dots.needle.50percent")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                detailCard(
                    icon: "drop.fill",
                    title: "Precipitation",
                    value: format(weather.precip, suffix: " in")
                )

                detailCard(
                    icon: "barometer",
                    title: "Pressure",
                    value: format(weather.pressure, suffix: " inHg")
                )

                detailCard(
                    icon: "eye.fill",
                    title: "Visibility",
                    value: format(weather.visibility, suffix: " mi")
                )

                detailCard(
                    icon: "wind",
                    title: "Wind",
                    value: weather.wind
                )
            }
        }
    }

    // MARK: - Astronomy

    @ViewBuilder
    private func astronomySection(_ weather: WeatherInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Sun & Moon", icon: "moon.stars.fill")

            VStack(spacing: 0) {
                astronomyRow(
                    icon: "sunrise.fill",
                    title: "Sunrise / Sunset",
                    value: weather.sun_rise_set
                )

                Divider()
                    .padding(.leading, 36)

                astronomyRow(
                    icon: "moonphase.waxing.crescent",
                    title: "Moon Phase",
                    value: weather.moon_phase
                )

                Divider()
                    .padding(.leading, 36)

                astronomyRow(
                    icon: "moonrise.fill",
                    title: "Moonrise / Moonset",
                    value: weather.moon_rise_set
                )
            }
            .padding(.horizontal, 12)
            .background(
                Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func miniStat(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value.isEmpty ? "—" : value)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func detailCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "—" : value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    @ViewBuilder
    private func astronomyRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: - Formatting

    private func format(_ value: String, suffix: String) -> String {
        guard !value.isEmpty else { return "—" }
        return value.hasSuffix(suffix.trimmingCharacters(in: .whitespaces))
            ? value
            : value + suffix
    }

    private func displayTime(_ raw: String) -> String {
        guard let number = Int(raw) else {
            return raw
        }

        let hour = number / 100

        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
}
