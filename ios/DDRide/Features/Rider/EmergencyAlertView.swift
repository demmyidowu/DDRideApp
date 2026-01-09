//
//  EmergencyAlertView.swift
//  DDRide
//
//  Created on 2026-01-09.
//

import SwiftUI

/// Emergency ride request sheet with predefined reasons
///
/// This sheet presents four emergency options:
/// 1. Safety Concern
/// 2. Medical Emergency
/// 3. Stranded Alone
/// 4. Other (with text field)
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showEmergencyAlert) {
///     EmergencyAlertView { reason in
///         await requestEmergencyRide(reason: reason)
///     }
/// }
/// ```
struct EmergencyAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: EmergencyReason?
    @State private var customReason: String = ""

    let onSubmit: (String) -> Void

    enum EmergencyReason: String, CaseIterable {
        case safety = "Safety Concern"
        case medical = "Medical Emergency"
        case stranded = "Stranded Alone"
        case other = "Other"

        var icon: String {
            switch self {
            case .safety:
                return "shield.fill"
            case .medical:
                return "cross.fill"
            case .stranded:
                return "person.fill.questionmark"
            case .other:
                return "ellipsis.circle.fill"
            }
        }

        var description: String {
            switch self {
            case .safety:
                return "I feel unsafe or threatened"
            case .medical:
                return "Medical assistance needed"
            case .stranded:
                return "I'm alone and stranded"
            case .other:
                return "Specify your emergency"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text("Emergency Request")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This will alert the Risk Manager and prioritize your ride")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)

                // Reason options
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(EmergencyReason.allCases, id: \.self) { reason in
                            EmergencyReasonButton(
                                reason: reason,
                                isSelected: selectedReason == reason,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedReason = reason
                                    }
                                }
                            )
                        }

                        // Custom reason text field (shown when "Other" is selected)
                        if selectedReason == .other {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Please describe your emergency:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextField("Describe emergency...", text: $customReason, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...5)
                                    .accessibilityLabel("Emergency description")
                            }
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                }

                // Submit button
                VStack(spacing: 12) {
                    Button {
                        submitEmergency()
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Submit Emergency Request")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedReason == nil || (selectedReason == .other && customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .opacity(selectedReason == nil || (selectedReason == .other && customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1.0)
                    .padding(.horizontal)
                    .accessibilityLabel("Submit emergency request")
                    .accessibilityHint(selectedReason == nil ? "Select an emergency reason first" : "")

                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                }
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submitEmergency() {
        guard let reason = selectedReason else { return }

        let finalReason: String
        if reason == .other {
            finalReason = customReason.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            finalReason = reason.rawValue
        }

        onSubmit(finalReason)
        dismiss()
    }
}

/// Individual emergency reason button
struct EmergencyReasonButton: View {
    let reason: EmergencyAlertView.EmergencyReason
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: reason.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .red)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(reason.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(reason.rawValue): \(reason.description)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    EmergencyAlertView { reason in
        print("Emergency reason: \(reason)")
    }
}
