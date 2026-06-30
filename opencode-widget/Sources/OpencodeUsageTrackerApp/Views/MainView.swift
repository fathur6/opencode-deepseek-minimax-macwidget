import SwiftUI

struct MainView: View {
    @State var viewModel: UsageViewModel

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            UsageView(viewModel: viewModel)
                .tabItem {
                    Label("Usage", systemImage: "square.grid.2x2.fill")
                }

            HistoryView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}
