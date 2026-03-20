import SwiftUI
import Charts

struct PortfolioView: View {
    @State private var viewModel = PortfolioViewModel()
    @Environment(CurrencySettings.self) var currencySettings
    @State private var showAddSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                headerSection
                
                // MARK: - Portfolio Value Chart
                if !viewModel.portfolioValueHistory.isEmpty {
                    PortfolioValueChartView(viewModel: viewModel)
                }
                
                // MARK: - Balance History Chart
                if !viewModel.balanceHistory.isEmpty {
                    BalanceHistoryChartView(viewModel: viewModel)
                }
                
                // MARK: - Address List
                if viewModel.addresses.isEmpty {
                    emptyState
                } else {
                    AddressListView(viewModel: viewModel)
                }
            }
            .padding(.bottom, 50)
        }
        .refreshable {
            await viewModel.loadPortfolio(currency: currencySettings.selectedCurrency)
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .sheet(isPresented: $showAddSheet) {
            AddAddressSheet(viewModel: viewModel)
        }
        .task(id: currencySettings.selectedCurrency) {
            await viewModel.loadPortfolio(currency: currencySettings.selectedCurrency)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Portfolio")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !viewModel.addresses.isEmpty {
                VStack(spacing: 4) {
                    Text(formatBTC(viewModel.totalBalanceBTC))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        
                    Text("\(viewModel.totalBalanceSats) SATS")
                        .font(.title3.monospaced().weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.9))
                        .padding(.bottom, 2)
                    
                    if let price = viewModel.price {
                        let fiatBalance = viewModel.totalBalanceBTC * currencySettings.price(from: price)
                        Text("≈ \(currencySettings.formatFiat(fiatBalance))")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bitcoinsign.circle")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.6))
            
            Text("No Addresses Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Tap + to add a Bitcoin address\nand start tracking your portfolio")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.orange)
                .clipShape(Circle())
                .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Formatters
    
    private func formatBTC(_ value: Double) -> String {
        if value == 0 { return "0 BTC" }
        return "\(value.formatted(.number.precision(.fractionLength(2...8)))) BTC"
    }
    
    private func formatFiat(_ value: Double) -> String {
        return currencySettings.formatFiat(value)
    }
    
    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
