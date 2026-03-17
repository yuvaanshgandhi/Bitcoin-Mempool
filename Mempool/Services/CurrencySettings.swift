import Foundation
import SwiftUI
import Combine

@MainActor
class CurrencySettings: ObservableObject {
    @AppStorage("selectedCurrency") var selectedCurrency: String = "USD" {
        didSet { objectWillChange.send() }
    }
    
    static let availableCurrencies = ["USD", "EUR", "GBP", "CAD", "CHF", "AUD", "JPY"]
    
    var currencySymbol: String {
        switch selectedCurrency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "CAD": return "CA$"
        case "CHF": return "CHF "
        case "AUD": return "A$"
        case "JPY": return "¥"
        default: return "$"
        }
    }
    
    /// Extracts the price in the selected currency from a BitcoinPrice object.
    /// Falls back to USD if the selected currency's value is nil.
    func price(from btcPrice: BitcoinPrice) -> Double {
        switch selectedCurrency {
        case "USD": return btcPrice.USD
        case "EUR": return btcPrice.EUR ?? btcPrice.USD
        case "GBP": return btcPrice.GBP ?? btcPrice.USD
        case "CAD": return btcPrice.CAD ?? btcPrice.USD
        case "CHF": return btcPrice.CHF ?? btcPrice.USD
        case "AUD": return btcPrice.AUD ?? btcPrice.USD
        case "JPY": return btcPrice.JPY ?? btcPrice.USD
        default: return btcPrice.USD
        }
    }
    
    /// Formats a fiat value with the correct currency symbol.
    func formatFiat(_ value: Double, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = selectedCurrency == "JPY" ? 0 : fractionDigits
        formatter.minimumFractionDigits = selectedCurrency == "JPY" ? 0 : fractionDigits
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(currencySymbol)\(formatted)"
    }
}
