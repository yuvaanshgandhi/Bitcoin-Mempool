import SwiftUI

struct SettingsView: View {
    @Environment(CurrencySettings.self) var currencySettings
    
    var body: some View {
        NavigationStack {
            List {
                // Currency Section
                Section {
                    ForEach(CurrencySettings.availableCurrencies, id: \.self) { currency in
                        Button {
                            withAnimation {
                                currencySettings.selectedCurrency = currency
                            }
                        } label: {
                            HStack {
                                Text(symbolFor(currency))
                                    .font(.title2)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currency)
                                        .font(.body.bold())
                                        .foregroundStyle(.white)
                                    Text(nameFor(currency))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                if currencySettings.selectedCurrency == currency {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(white: 0.08))
                    }
                } header: {
                    Text("Currency")
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(.white)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .listRowBackground(Color(white: 0.08))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Providers")
                            .foregroundStyle(.white)
                        
                        HStack {
                            Text("Core Data")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("mempool.space")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                        
                        HStack {
                            Text("Fee Multiple")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("Bull Bitcoin API")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(white: 0.08))
                } header: {
                    Text("About")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func symbolFor(_ currency: String) -> String {
        switch currency {
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        case "GBP": return "🇬🇧"
        case "CAD": return "🇨🇦"
        case "CHF": return "🇨🇭"
        case "AUD": return "🇦🇺"
        case "JPY": return "🇯🇵"
        default: return "💱"
        }
    }
    
    private func nameFor(_ currency: String) -> String {
        switch currency {
        case "USD": return "US Dollar"
        case "EUR": return "Euro"
        case "GBP": return "British Pound"
        case "CAD": return "Canadian Dollar"
        case "CHF": return "Swiss Franc"
        case "AUD": return "Australian Dollar"
        case "JPY": return "Japanese Yen"
        default: return currency
        }
    }
}
