//
//  ErrorView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.theme.error)

            Text("Error")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Retry")
                        .fontWeight(.semibold)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 64)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
}

#Preview {
    ErrorView(message: "Something went wrong. Please try again.") {
        print("Retry tapped")
    }
}
