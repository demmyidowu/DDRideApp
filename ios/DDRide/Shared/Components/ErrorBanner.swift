//
//  ErrorBanner.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Top banner for displaying error messages with auto-dismiss
///
/// Usage:
/// ```swift
/// .overlay(alignment: .top) {
///     if let error = viewModel.errorMessage {
///         ErrorBanner(message: error, isPresented: $viewModel.showError)
///     }
/// }
/// ```
struct ErrorBanner: View {
    let message: String
    @Binding var isPresented: Bool
    var autoDismiss: Bool = true
    var duration: TimeInterval = 5.0

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)

                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .accessibilityLabel("Dismiss error")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.red)
            .cornerRadius(12)
            .shadow(radius: 5)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(999)
        .onAppear {
            if autoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }
}

/// Simple error view for inline display
struct ErrorView: View {
    let error: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Error")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Try Again", action: retryAction)
                .buttonStyle(.bordered)
                .tint(.red)
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack {
        ErrorBanner(
            message: "Failed to load rides. Please check your connection.",
            isPresented: .constant(true)
        )

        Spacer()

        ErrorView(
            error: "Unable to connect to server",
            retryAction: {}
        )

        Spacer()
    }
}
