//
//  DDDashboardView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct DDDashboardView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("DD Dashboard")
                    .font(.largeTitle)
                Text("Under Construction")
                    .foregroundColor(.theme.textSecondary)
            }
            .navigationTitle("DD Dashboard")
        }
    }
}

#Preview {
    DDDashboardView()
}
