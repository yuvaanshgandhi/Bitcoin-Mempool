import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea() // Explicit Deep Dark Background
                
                VStack(spacing: 30) {
                    Text("Search Mempool")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    // Dark Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Block, Transaction, Address...", text: $viewModel.query)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .onSubmit {
                                Task { await viewModel.performSearch() }
                            }
                        
                        if viewModel.isSearching {
                            ProgressView().tint(.white)
                        }
                    }
                    .padding()
                    .background(Color(white: 0.1)) // Dark Card
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding()
                    }
                    
                    if let result = viewModel.searchResult {
                        // Result Found Card
                        VStack {
                            Text("Result Found")
                                .font(.headline).foregroundStyle(.green)
                            Text(result.key)
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button {
                                navigateToResult(result)
                            } label: {
                                Text("View Details")
                                    .bold()
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.1)) // Dark Card
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationDestination(for: SearchResult.self) { result in
                destinationView(for: result)
            }
        }
    }
    
    func navigateToResult(_ result: SearchResult) {
        navigationPath.append(result)
    }
    
    @ViewBuilder
    func destinationView(for result: SearchResult) -> some View {
        switch result.type {
        case .block:
            BlockDetailView(identifier: result.key)
        case .transaction:
            TransactionDetailView(txid: result.key)
        case .address:
            AddressDetailView(address: result.key)
        case .unknown:
            Text("Unknown Entity")
        }
    }
}
