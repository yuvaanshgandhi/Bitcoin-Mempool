import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        GlassEffectContainer {
            TabView(selection: $selectedTab) {
                // Portfolio Tab (Main)
                NavigationStack {
                    PortfolioView()
                }
                .tabItem {
                    Label("Portfolio", systemImage: "bitcoinsign.circle")
                }
                .tag(0)
                
                // Dashboard Tab
                NavigationStack {
                    DashboardView()
                        .navigationDestination(for: ProjectedBlock.self) { block in
                             Text("Detailed view for projected block logic needed")
                        }
                }
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(1)
                
                // Mining Tab
                NavigationStack {
                    MiningView()
                }
                .tabItem {
                    Label("Mining", systemImage: "hammer")
                }
                .tag(2)
                
                // Search Tab
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(3)
                
                // Settings Tab
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(4)
            }
            .tint(.orange)
        }
    }
}
