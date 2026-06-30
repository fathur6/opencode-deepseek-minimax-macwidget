import SwiftUI

@main
struct OpencodeUsageTrackerApp: App {
    @State private var viewModel = UsageViewModel()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView { Task { await handleOnboardingComplete() } }
                } else {
                    MainView(viewModel: viewModel)
                        .frame(minWidth: 300, minHeight: 400)
                }
            }
            .task {
                await viewModel.load()
                if viewModel.state == .onboarding {
                    showOnboarding = true
                }
            }
        }
        .windowResizability(.contentSize)
    }

    private func handleOnboardingComplete() async {
        showOnboarding = false
        await viewModel.load()
    }
}
