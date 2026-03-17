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
                
                // Explore Tab (Merged Dashboard + Mining)
                NavigationStack {
                    ExploreView()
                        .navigationDestination(for: ProjectedBlock.self) { block in
                             ProjectedBlockDetailView(block: block)
                        }
                }
                .tabItem {
                    Label("Explore", systemImage: "square.grid.2x2")
                }
                .tag(1)
                
                // Watchlist Tab
                WatchlistView()
                    .tabItem {
                        Label("Watchlist", systemImage: "eye")
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
