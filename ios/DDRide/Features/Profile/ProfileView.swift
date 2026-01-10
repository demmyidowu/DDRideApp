//
//  ProfileView.swift
//  DDRide
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ProfileView: View {
    let user: User

    @EnvironmentObject var authService: AuthService
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        // Profile photo or initials
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Text(user.initials)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .accessibilityLabel("Profile picture")

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(AppTheme.Typography.headline)

                            Text(user.email)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                RoleBadge(role: user.role)
                                ClassYearBadge(classYear: user.classYear)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Account Details Section
                Section("Account Details") {
                    InfoRow(label: "Phone", value: formatPhoneNumber(user.phoneNumber))
                    InfoRow(label: "Class Year", value: classYearName(user.classYear))
                    InfoRow(label: "Member Since", value: user.createdAt.formatted(date: .abbreviated, time: .omitted))

                    if user.isEmailVerified {
                        HStack {
                            Text("Email Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Verified")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // App Information Section
                Section("App Information") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    NavigationLink {
                        SupportView()
                    } label: {
                        Label("Support & Feedback", systemImage: "questionmark.circle.fill")
                    }

                    InfoRow(label: "App Version", value: appVersion)
                    InfoRow(label: "Build", value: buildNumber)
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive, action: { showSignOutConfirmation = true }) {
                        HStack {
                            if isSigningOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text("Sign Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func signOut() async {
        isSigningOut = true

        do {
            try authService.signOut()
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
        }

        isSigningOut = false
    }

    private func formatPhoneNumber(_ phone: String) -> String {
        // Format +15551234567 to (555) 123-4567
        guard phone.hasPrefix("+1"), phone.count == 12 else {
            return phone
        }

        let digits = String(phone.dropFirst(2))
        return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
    }

    private func classYearName(_ year: Int) -> String {
        switch year {
        case 1: return "Freshman"
        case 2: return "Sophomore"
        case 3: return "Junior"
        case 4: return "Senior"
        default: return "Unknown"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(AppTheme.Typography.title)
                    .padding(.bottom, 8)

                Group {
                    Text("Last Updated: January 2026")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)

                    Text("Information We Collect")
                        .font(AppTheme.Typography.title3)
                        .padding(.top, 8)

                    Text("""
                        DD Ride collects and uses your information to provide safe designated driver services for K-State fraternity and sorority chapters.

                        We collect:
                        • Name, email (@ksu.edu), and phone number
                        • Class year and chapter affiliation
                        • Location data (only when requesting or providing rides)
                        • Ride history and DD assignments
                        """)
                        .font(AppTheme.Typography.body)

                    Text("How We Use Your Information")
                        .font(AppTheme.Typography.title3)
                        .padding(.top, 8)

                    Text("""
                        • Match riders with designated drivers
                        • Send ride status notifications via SMS
                        • Ensure safety and accountability
                        • Generate ride logs for chapter records
                        • Improve app functionality and user experience
                        """)
                        .font(AppTheme.Typography.body)

                    Text("Data Security")
                        .font(AppTheme.Typography.title3)
                        .padding(.top, 8)

                    Text("""
                        We implement industry-standard security measures including:
                        • Encrypted data transmission (TLS/SSL)
                        • Secure Firebase authentication
                        • Role-based access controls
                        • Regular security audits
                        """)
                        .font(AppTheme.Typography.body)

                    Text("Your Rights")
                        .font(AppTheme.Typography.title3)
                        .padding(.top, 8)

                    Text("""
                        You have the right to:
                        • Access your personal data
                        • Request data deletion
                        • Opt out of notifications
                        • Update your information
                        """)
                        .font(AppTheme.Typography.body)

                    Text("Contact Us")
                        .font(AppTheme.Typography.title3)
                        .padding(.top, 8)

                    Text("For privacy-related questions or requests, contact us at privacy@ddride.app")
                        .font(AppTheme.Typography.body)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SupportView: View {
    var body: some View {
        List {
            Section("Contact Support") {
                Link(destination: URL(string: "mailto:support@ddride.app")!) {
                    HStack {
                        Label("Email Support", systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "sms:+15555551234")!) {
                    HStack {
                        Label("Text Support", systemImage: "message.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Help Center") {
                NavigationLink {
                    FAQView()
                } label: {
                    Label("Frequently Asked Questions", systemImage: "questionmark.circle.fill")
                }

                NavigationLink {
                    HowToUseView()
                } label: {
                    Label("How to Use DD Ride", systemImage: "book.fill")
                }
            }

            Section("Feedback") {
                Link(destination: URL(string: "https://forms.gle/ddride-feedback")!) {
                    HStack {
                        Label("Submit Feedback", systemImage: "text.bubble.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "https://forms.gle/ddride-bug-report")!) {
                    HStack {
                        Label("Report a Bug", systemImage: "ant.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Emergency") {
                Button {
                    if let url = URL(string: "tel://911") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Emergency: Call 911", systemImage: "phone.fill")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQView: View {
    var body: some View {
        List {
            Section("General Questions") {
                FAQItem(
                    question: "What is DD Ride?",
                    answer: "DD Ride is a designated driver management app for K-State fraternities and sororities. It helps chapters coordinate safe rides home for members during events."
                )

                FAQItem(
                    question: "Who can use DD Ride?",
                    answer: "DD Ride is available to members of participating K-State Greek chapters with a valid @ksu.edu email address."
                )
            }

            Section("Requesting Rides") {
                FAQItem(
                    question: "How do I request a ride?",
                    answer: "Tap 'Request Ride' on the home screen, enter your pickup location, and wait to be matched with a designated driver."
                )

                FAQItem(
                    question: "How long will I wait for a ride?",
                    answer: "Wait times vary based on DD availability. You'll see your queue position and estimated wait time after requesting."
                )

                FAQItem(
                    question: "What's the emergency button?",
                    answer: "The emergency button gives you immediate priority in the ride queue and alerts chapter admins. Use only for genuine emergencies."
                )
            }

            Section("Being a DD") {
                FAQItem(
                    question: "How do I become a DD?",
                    answer: "Your chapter admin assigns DD shifts. You'll receive a notification when you're scheduled."
                )

                FAQItem(
                    question: "Can I pause DD duties?",
                    answer: "Yes, you can toggle inactive temporarily. However, excessive toggling may alert your chapter admin."
                )
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQItem: View {
    let question: String
    let answer: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(answer)
                .font(AppTheme.Typography.body)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        } label: {
            Text(question)
                .font(AppTheme.Typography.headline)
        }
    }
}

struct HowToUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                InstructionSection(
                    title: "For Riders",
                    icon: "person.fill",
                    steps: [
                        "Open the app and go to the Rides tab",
                        "Tap 'Request Ride' and enter your pickup location",
                        "Wait to be matched with a designated driver",
                        "Track your DD's arrival in real-time",
                        "Rate your experience after completion"
                    ]
                )

                InstructionSection(
                    title: "For Designated Drivers",
                    icon: "car.fill",
                    steps: [
                        "Check your DD schedule in the app",
                        "Toggle 'Active' when you're ready to accept rides",
                        "Accept assigned rides and view pickup details",
                        "Navigate to the pickup location",
                        "Mark 'En Route' and then 'Complete' when done"
                    ]
                )

                InstructionSection(
                    title: "For Admins",
                    icon: "person.3.fill",
                    steps: [
                        "Create events from the Dashboard",
                        "Assign DDs to events",
                        "Monitor active rides and DD activity",
                        "Review ride logs and member statistics",
                        "Respond to alerts and emergency situations"
                    ]
                )
            }
            .padding()
        }
        .navigationTitle("How to Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InstructionSection: View {
    let title: String
    let icon: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.primary)
                Text(title)
                    .font(AppTheme.Typography.title3)
            }

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.primary)

                    Text(step)
                        .font(AppTheme.Typography.body)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.card)
    }
}

// MARK: - User Extension

extension User {
    var initials: String {
        let names = name.split(separator: " ")
        let initials = names.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
}

#Preview {
    NavigationStack {
        ProfileView(user: User(
            id: "123",
            name: "John Doe",
            email: "test@ksu.edu",
            phoneNumber: "+15551234567",
            chapterId: "sigma-chi",
            role: .member,
            classYear: 2,
            isEmailVerified: true,
            createdAt: Date(),
            updatedAt: Date()
        ))
        .environmentObject(AuthService.shared)
    }
}
