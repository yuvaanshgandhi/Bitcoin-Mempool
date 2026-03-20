import SwiftUI

struct AddAddressSheet: View {
    let viewModel: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var addressText = ""
    @State private var labelText = ""
    @State private var isValidating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Address icon
                    Image(systemName: "qrcode")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange.opacity(0.7))
                        .padding(.top, 20)
                    
                    Text("Add Bitcoin Address")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    // Address field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("bc1q... / 1... / 3...", text: $addressText)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal)
                    
                    // Label field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Label (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("e.g. Cold storage, Savings...", text: $labelText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Error
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    // Add button
                    Button {
                        Task {
                            await viewModel.addAddress(
                                address: addressText,
                                label: labelText.isEmpty ? nil : labelText
                            )
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isAddingAddress {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(viewModel.isAddingAddress ? "Validating..." : "Add Address")
                                .bold()
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(addressText.isEmpty ? Color.gray : Color.orange)
                        .clipShape(Capsule())
                    }
                    .disabled(addressText.isEmpty || viewModel.isAddingAddress)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.error = nil
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            viewModel.error = nil
        }
    }
}
