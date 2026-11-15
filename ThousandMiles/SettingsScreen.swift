import SwiftUI

struct SettingsScreen: View {
    @AppStorage(SettingsKeys.goalMiles) private var goalMiles = 1000
    @Environment(\.openURL) private var openURL

    private let presets = [500, 1000, 1500, 2000]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Quick pick", selection: $goalMiles) {
                        ForEach(presets, id: \.self) { miles in
                            Text("\(miles)").tag(miles)
                        }
                        if !presets.contains(goalMiles) {
                            Text("\(goalMiles)").tag(goalMiles)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $goalMiles, in: 100...5000, step: 50) {
                        HStack {
                            Text("Yearly goal")
                            Spacer()
                            Text("\(goalMiles) mi")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.trail)
                        }
                    }
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Your goal runs January 1 to December 31, so everyone's year lines up.")
                }

                Section {
                    Button("Open the Health app") {
                        if let url = URL(string: "x-apple-health://") { openURL(url) }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("1000 Miles reads Walking + Running Distance and Steps. Steps from devices like WHOOP count too: in the WHOOP app, turn on the Apple Health connection and allow Steps. To change access, open Health, tap your profile picture, then Apps > 1000 Miles.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Theme.paper
                    TopoBackground()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Settings")
        }
    }
}
