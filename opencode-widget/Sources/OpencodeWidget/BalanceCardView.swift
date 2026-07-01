import SwiftUI

struct BalanceCardView: View {
    let title: String
    let balance: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let balance {
                Text(String(format: "$%.2f", balance))
                    .font(.title3)
                    .fontWeight(.bold)
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.thin)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(8)
    }
}
