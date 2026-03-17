import SwiftUI
import Charts

struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @EnvironmentObject var currencySettings: CurrencySettings
    @State private var showAddSheet = false
    @State private var selectedValuePoint: PriceDataPoint?
    @State private var selectedBalancePoint: BalanceDataPoint?
    @State private var renameAddress: PortfolioAddress?
    @State private var renameText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                headerSection
                
                // MARK: - Portfolio Value Chart
                if !viewModel.portfolioValueHistory.isEmpty {
                    portfolioValueChartSection
                }
                
                // MARK: - Balance History Chart
                if !viewModel.balanceHistory.isEmpty {
                    balanceChartSection
                }
                
                // MARK: - Address List
                if viewModel.addresses.isEmpty {
                    emptyState
                } else {
                    addressListSection
                }
            }
            .padding(.bottom, 50)
        }
        .refreshable {
            await viewModel.loadPortfolio()
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .sheet(isPresented: $showAddSheet) {
            AddAddressSheet(viewModel: viewModel)
        }
        .alert("Rename Address", isPresented: Binding(
            get: { renameAddress != nil },
            set: { if !$0 { renameAddress = nil } }
        )) {
            TextField("Label", text: $renameText)
            Button("Save") {
                if let addr = renameAddress {
                    viewModel.renameAddress(id: addr.id, newLabel: renameText)
                }
                renameAddress = nil
            }
            Button("Cancel", role: .cancel) { renameAddress = nil }
        } message: {
            Text("Enter a new label for this address")
        }
        .task {
            await viewModel.loadPortfolio()
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
    
    // MARK: - Portfolio Value Chart (Interactive)
    
    private var portfolioValueChartSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Portfolio Value")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Spacer()
                    
                    if let selected = selectedValuePoint {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(currencySettings.formatFiat(selected.price))
                                .font(.subheadline.bold().monospaced())
                                .foregroundStyle(.green)
                            Text(formatChartDate(selected.date))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else if let price = viewModel.price {
                        let fiatBalance = viewModel.totalBalanceBTC * currencySettings.price(from: price)
                        Text(currencySettings.formatFiat(fiatBalance))
                            .font(.subheadline.bold().monospaced())
                            .foregroundStyle(.green)
                    }
                }
                
                Chart {
                    ForEach(viewModel.portfolioValueHistory) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("USD", point.price)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green.opacity(0.4), .green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("USD", point.price)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    if let selected = selectedValuePoint {
                        RuleMark(x: .value("Date", selected.date))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.15))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.15))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            let ts = date.timeIntervalSince1970
                                            if let closest = viewModel.portfolioValueHistory.min(by: {
                                                abs($0.date.timeIntervalSince1970 - ts) < abs($1.date.timeIntervalSince1970 - ts)
                                            }) {
                                                selectedValuePoint = closest
                                            }
                                        }
                                    }
                                    .onEnded { _ in selectedValuePoint = nil }
                            )
                    }
                }
                .frame(height: 200)
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Balance Chart (Interactive)
    
    private var balanceChartSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Balance History")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Spacer()
                    
                    if let selected = selectedBalancePoint {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatBTC(selected.balance))
                                .font(.subheadline.bold().monospaced())
                                .foregroundStyle(.orange)
                            Text(formatChartDate(selected.date))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                Chart {
                    ForEach(viewModel.balanceHistory) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("BTC", point.balance)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange.opacity(0.6), .purple.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("BTC", point.balance)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    if let selected = selectedBalancePoint {
                        RuleMark(x: .value("Date", selected.date))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.15))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.15))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            let ts = date.timeIntervalSince1970
                                            if let closest = viewModel.balanceHistory.min(by: {
                                                abs($0.date.timeIntervalSince1970 - ts) < abs($1.date.timeIntervalSince1970 - ts)
                                            }) {
                                                selectedBalancePoint = closest
                                            }
                                        }
                                    }
                                    .onEnded { _ in selectedBalancePoint = nil }
                            )
                    }
                }
                .frame(height: 200)
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Address List
    
    private var addressListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked Addresses")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal)
            
            ForEach(viewModel.addresses) { addr in
                NavigationLink(destination: AddressDetailView(address: addr.address)) {
                    addressCard(addr)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func addressCard(_ addr: PortfolioAddress) -> some View {
        let balance = viewModel.balances[addr.address]
        let totalSats = (balance?.confirmed ?? 0) + (balance?.mempool ?? 0)
        let btc = Double(totalSats) / 100_000_000
        let fiatValue = btc * (viewModel.price.map { currencySettings.price(from: $0) } ?? 0)
        
        return GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    if let label = addr.label, !label.isEmpty {
                        Text(label)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    
                    Text(addr.address)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if viewModel.isLoading && balance == nil {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(formatBTC(btc))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(.orange)
                        
                        if fiatValue > 0 {
                            Text(currencySettings.formatFiat(fiatValue))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
        }
        .padding(.horizontal)
        .contextMenu {
            Button {
                renameText = addr.label ?? ""
                renameAddress = addr
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button {
                UIPasteboard.general.string = addr.address
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive) {
                viewModel.removeAddress(id: addr.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
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
