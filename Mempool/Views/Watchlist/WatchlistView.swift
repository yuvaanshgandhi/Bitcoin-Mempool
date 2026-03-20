import SwiftUI

struct WatchlistView: View {
    @StateObject private var viewModel = WatchlistViewModel()
    @Environment(CurrencySettings.self) var currencySettings
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Type Picker
                    Picker("Tracking Type", selection: $viewModel.selectedType) {
                        Text("Transactions").tag(WatchlistType.transaction)
                        Text("Addresses").tag(WatchlistType.address)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color.black)
                    
                    let filteredItems = viewModel.watchedItems.filter { $0.type == viewModel.selectedType }
                    
                    if filteredItems.isEmpty && !viewModel.isAddingItem {
                        emptyStateView
                    } else {
                        itemListView(filteredItems)
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            viewModel.isAddingItem.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isAddingItem ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshStatuses()
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: viewModel.selectedType == .transaction ? "point.topleft.down.curvedto.point.bottomright.up" : "link")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Watched \(viewModel.selectedType == .transaction ? "Transactions" : "Addresses")")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Add \(viewModel.selectedType == .transaction ? "transactions" : "addresses") to track their\nstatus in real-time")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Button {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.isAddingItem = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add \(viewModel.selectedType == .transaction ? "Transaction" : "Address")")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .background(
                    LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(14)
            }
            Spacer()
        }
    }
    
    // MARK: - Item List
    
    private func itemListView(_ items: [WatchlistItem]) -> some View {
        List {
            // Add Item Section
            if viewModel.isAddingItem {
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "text.cursor")
                                .foregroundStyle(.orange)
                            TextField("\(viewModel.selectedType == .transaction ? "Transaction ID" : "Address")", text: $viewModel.newItemInput)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(Color(white: 0.12))
                        .cornerRadius(10)
                        
                        HStack {
                            Image(systemName: "tag")
                                .foregroundStyle(.orange.opacity(0.7))
                            TextField("Label (optional)", text: $viewModel.newLabelInput)
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .background(Color(white: 0.12))
                        .cornerRadius(10)
                        
                        HStack(spacing: 12) {
                            Button {
                                if let clipboardText = UIPasteboard.general.string {
                                    viewModel.newItemInput = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color(white: 0.15))
                                .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            Button {
                                viewModel.addItem(
                                    type: viewModel.selectedType,
                                    identifier: viewModel.newItemInput,
                                    label: viewModel.newLabelInput
                                )
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(
                                    viewModel.newItemInput.isEmpty ? Color.gray : Color.orange
                                )
                                .cornerRadius(8)
                            }
                            .disabled(viewModel.newItemInput.isEmpty)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color(white: 0.06))
                } header: {
                    Text("Track New \(viewModel.selectedType == .transaction ? "Transaction" : "Address")")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // Pending/Confirmed Sections for Transactions
            if viewModel.selectedType == .transaction {
                let unconfirmed = items.filter { !$0.isConfirmed }
                if !unconfirmed.isEmpty {
                    Section {
                        ForEach(unconfirmed) { tx in watchlistRow(item: tx) }
                        .onDelete { offsets in
                            offsets.map { unconfirmed[$0] }.forEach { viewModel.removeItem(id: $0.id) }
                        }
                    } header: {
                        HStack {
                            Text("Pending").foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(unconfirmed.count)")
                                .font(.caption.bold()).foregroundStyle(.orange)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2)).cornerRadius(6)
                        }
                    }
                }
                
                let confirmed = items.filter { $0.isConfirmed }
                if !confirmed.isEmpty {
                    Section {
                        ForEach(confirmed) { tx in watchlistRow(item: tx) }
                        .onDelete { offsets in
                            offsets.map { confirmed[$0] }.forEach { viewModel.removeItem(id: $0.id) }
                        }
                    } header: {
                        HStack {
                            Text("Confirmed").foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(confirmed.count)")
                                .font(.caption.bold()).foregroundStyle(.green)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.green.opacity(0.2)).cornerRadius(6)
                        }
                    }
                }
            } else {
                // Address Section
                if !items.isEmpty {
                    Section {
                        ForEach(items) { addr in watchlistRow(item: addr) }
                        .onDelete { offsets in
                            offsets.map { items[$0] }.forEach { viewModel.removeItem(id: $0.id) }
                        }
                    } header: {
                        HStack {
                            Text("Tracked Addresses").foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(items.count)")
                                .font(.caption.bold()).foregroundStyle(.blue)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2)).cornerRadius(6)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Row
    
    @ViewBuilder
    private func watchlistRow(item: WatchlistItem) -> some View {
        let isRecentlyConfirmed = viewModel.recentlyConfirmedTxid == item.identifier
        
        NavigationLink(destination: destinationView(for: item)) {
            HStack(spacing: 14) {
                // Status/Type Icon
                ZStack {
                    if item.type == .transaction {
                        Circle()
                            .fill(item.isConfirmed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: item.isConfirmed ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(item.isConfirmed ? .green : .orange)
                            .symbolEffect(.bounce, value: isRecentlyConfirmed)
                    } else {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "link")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let label = item.label {
                        Text(label)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    
                    Text(item.identifier.prefix(12) + "...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 8) {
                        if item.type == .transaction {
                            if item.isConfirmed, let height = item.blockHeight {
                                Text("Block #\(height)")
                                    .font(.caption2)
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                            if let confirmedAt = item.confirmedAt {
                                Text("Confirmed \(timeAgo(confirmedAt))")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                            } else {
                                Text("Added \(timeAgo(item.addedAt))")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                            }
                        } else {
                            if let txCount = item.txCount {
                                Text("\(txCount) Txs")
                                    .font(.caption2).foregroundStyle(.blue.opacity(0.8))
                            }
                            if let funded = item.fundedTxoSum, let spent = item.spentTxoSum {
                                let balance = Double(funded - spent) / 100_000_000
                                Text("\(balance.formatted(.number.precision(.fractionLength(4)))) BTC")
                                    .font(.caption2.bold()).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
                
                Spacer()
                
                if item.type == .transaction && !item.isConfirmed {
                    ProgressView()
                        .tint(.orange)
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.type == .transaction ? (item.isConfirmed ? Color.green.opacity(isRecentlyConfirmed ? 0.15 : 0.05) : Color(white: 0.08)) : Color(white: 0.08))
                .animation(.easeInOut(duration: 0.8).repeatCount(isRecentlyConfirmed ? 3 : 0, autoreverses: true), value: isRecentlyConfirmed)
        )
    }
    
    @ViewBuilder
    private func destinationView(for item: WatchlistItem) -> some View {
        if item.type == .transaction {
            TransactionDetailView(txid: item.identifier)
        } else {
            AddressDetailView(address: item.identifier)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
