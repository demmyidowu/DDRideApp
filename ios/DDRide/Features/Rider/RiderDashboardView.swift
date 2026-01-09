//
//  RiderDashboardView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct RiderDashboardView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Rider Dashboard")
                    .font(.largeTitle)
                Text("Under Construction")
                    .foregroundColor(.theme.textSecondary)
            }
            .navigationTitle("Request Ride")
        }
    }
}

#Preview {
    RiderDashboardView()
}
