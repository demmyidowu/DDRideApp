//
//  LoadingView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .theme.primary))
                .scaleEffect(1.5)

            Text(message)
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.opacity(0.9))
    }
}

#Preview {
    LoadingView()
}
