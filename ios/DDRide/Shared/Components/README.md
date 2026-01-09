# Reusable SwiftUI Components

This directory contains all reusable SwiftUI components for the DD Ride app. All components support Dark Mode, Dynamic Type, and accessibility features (VoiceOver).

## Component List

### 1. PrimaryButton.swift
Reusable button with loading state, disabled state, and multiple styles.

**Features:**
- Three styles: primary (blue), secondary (gray), destructive (red)
- Loading state with ProgressView
- Disabled state with reduced opacity
- Optional icon support
- Full accessibility support
- Minimum 44pt touch target

**Usage:**
```swift
PrimaryButton(title: "Request Ride", action: requestRide)
PrimaryButton(title: "Loading...", isLoading: true) { }
PrimaryButton(title: "Cancel", style: .destructive, isDisabled: true) { }
CircularActionButton(icon: "car.fill", title: "Request Ride", action: {})
```

---

### 2. LoadingView.swift
Loading indicator with optional background overlay and message.

**Features:**
- Full-screen overlay or inline loading
- Optional background dimming
- Customizable message
- Accessibility labels

**Usage:**
```swift
LoadingView(message: "Loading rides...")
LoadingView(message: "Please wait...", showBackground: false)
LoadingOverlay(message: "Fetching data...")
```

---

### 3. ErrorView.swift
Comprehensive error display with retry functionality.

**Features:**
- Accepts Error or custom message
- Optional retry button
- Inline error banner variant
- Full accessibility support

**Usage:**
```swift
ErrorView(error: error, onRetry: { await viewModel.retry() })
ErrorView(message: "Custom error message", onRetry: retryAction)
ErrorBanner(message: "Failed to load data", onDismiss: {})
```

---

### 4. EmptyStateView.swift
Empty state view with icon, title, message, and optional action.

**Features:**
- Customizable SF Symbol icon
- Optional call-to-action button
- Center-aligned content
- Full accessibility

**Usage:**
```swift
EmptyStateView(
    icon: "car.fill",
    title: "No Active Rides",
    message: "Request a ride to get started"
)

EmptyStateView(
    icon: "checkmark.circle",
    title: "All Caught Up!",
    message: "No rides in queue",
    action: {},
    actionTitle: "Refresh"
)
```

---

### 5. MemberRow.swift
Member list row with profile photo/initials, role badge, and class year.

**Features:**
- Profile photo or initials circle
- Role badge (Admin/Member)
- Class year badge
- Optional tap action
- Full accessibility

**Components:**
- `MemberRow`: Main component
- `RoleBadge`: Admin/Member badge
- `ClassYearBadge`: Freshman/Sophomore/Junior/Senior badge

**Usage:**
```swift
MemberRow(user: user)
MemberRow(user: user, onTap: { selectedUser = user })

// Standalone badges
RoleBadge(role: .admin)
ClassYearBadge(classYear: 3)
```

---

### 6. RideCard.swift
Ride information card for lists with status, location, and DD info.

**Features:**
- Ride status badge with color coding
- Pickup/dropoff addresses
- DD assignment info with ETA
- Priority/emergency indicators
- Queue position display
- Optional tap action
- Full accessibility

**Components:**
- `RideCard`: Main component
- `RideStatusBadge`: Status badge with color

**Usage:**
```swift
RideCard(ride: ride)
RideCard(ride: ride, showDD: false, onTap: { selectedRide = ride })

// Standalone badge
RideStatusBadge(status: .enroute, isEmergency: false)
```

---

### 7. DDStatusBadge.swift
DD active/inactive status indicator.

**Features:**
- Animated pulse effect when active
- Compact and large variants
- Color-coded (green = active, gray = inactive)
- Full accessibility

**Components:**
- `DDStatusBadge`: Compact badge
- `DDStatusIndicator`: Large status card with description

**Usage:**
```swift
DDStatusBadge(isActive: true)
DDStatusBadge(isActive: false, showText: false)
DDStatusIndicator(isActive: true)
```

---

### 8. StatCard.swift
Metric display cards in various layouts.

**Features:**
- Vertical and horizontal layouts
- Optional icon with color
- Compact row variant for lists
- Full accessibility

**Components:**
- `StatCard`: Vertical card
- `HorizontalStatCard`: Horizontal card with icon
- `StatRow`: Compact row for lists

**Usage:**
```swift
StatCard(title: "Tonight", value: "12", icon: "car.fill", color: .blue)
HorizontalStatCard(title: "Active Rides", value: "8", icon: "car.fill", color: .blue)
StatRow(label: "Completed Today", value: "24", icon: "checkmark.circle.fill")
```

---

### 9. InfoCard.swift
Information cards for displaying important messages.

**Features:**
- Four types: info, success, warning, error
- Color-coded with icons
- Optional dismiss button
- Large variant with action button
- Queue position card variant
- Full accessibility

**Components:**
- `InfoCard`: Inline info card
- `LargeInfoCard`: Large card with title and action
- `QueuePositionCard`: Special card for queue position

**Usage:**
```swift
InfoCard(type: .info, message: "Ride assigned to you")
InfoCard(type: .warning, message: "Wait time increased", onDismiss: {})

LargeInfoCard(
    icon: "checkmark.circle.fill",
    title: "Ride Complete!",
    message: "Thank you for using DD Ride",
    color: .green,
    action: {},
    actionTitle: "Rate Ride"
)

QueuePositionCard(position: 3, estimatedWait: 8)
```

---

## Theme System

All components use the centralized `AppTheme` defined in `Shared/Styles/AppTheme.swift`.

### Colors
```swift
AppTheme.Colors.primary        // Blue
AppTheme.Colors.success        // Green
AppTheme.Colors.warning        // Orange
AppTheme.Colors.danger         // Red
AppTheme.Colors.background     // Adapts to dark mode
AppTheme.Colors.cardBackground // Card background
```

### Typography
```swift
AppTheme.Typography.title
AppTheme.Typography.headline
AppTheme.Typography.body
AppTheme.Typography.button
AppTheme.Typography.badge
```

### Spacing
```swift
AppTheme.Spacing.xs    // 8pt
AppTheme.Spacing.sm    // 12pt
AppTheme.Spacing.md    // 16pt
AppTheme.Spacing.lg    // 24pt
AppTheme.Spacing.xl    // 32pt
```

### Corner Radius
```swift
AppTheme.CornerRadius.button   // 12pt
AppTheme.CornerRadius.card     // 12pt
AppTheme.CornerRadius.badge    // 6pt
```

### View Modifiers
```swift
.cardStyle()              // Apply card styling
.primaryButtonStyle()     // Apply primary button styling
.sectionHeaderStyle()     // Apply section header styling
```

---

## Accessibility Guidelines

All components follow these accessibility best practices:

1. **VoiceOver Support**
   - Meaningful accessibility labels
   - Helpful accessibility hints for interactive elements
   - Proper trait assignments (.isButton, .isHeader, etc.)
   - Combined elements where appropriate

2. **Dynamic Type**
   - System font styles that scale
   - Fixed size with horizontal flexibility
   - Tested up to accessibility size xxxLarge

3. **Touch Targets**
   - Minimum 44x44 points for all interactive elements
   - Adequate spacing between tappable items

4. **Color Contrast**
   - Sufficient contrast ratios in light and dark modes
   - Icons supplement color-only information

5. **Semantic Colors**
   - Use system colors that adapt to dark mode
   - Avoid hardcoded colors except brand colors

---

## Dark Mode Support

All components automatically support Dark Mode through:

- Semantic system colors (`Color(.systemBackground)`)
- Theme colors that adapt automatically
- Tested in both light and dark appearances
- No manual dark mode handling required

---

## Testing

Each component includes:
- SwiftUI Preview with multiple variations
- Example usage in different states
- Accessibility preview in Xcode

To test a component:
1. Open the file in Xcode
2. Enable Canvas preview
3. Test with different Dynamic Type sizes
4. Test in Light and Dark modes
5. Test with VoiceOver in Simulator

---

## Best Practices

When using these components:

1. **Reuse over reinvention**: Always check if a component exists before creating new UI
2. **Consistent styling**: Use AppTheme constants instead of hardcoded values
3. **Accessibility first**: Test with VoiceOver and Dynamic Type
4. **Dark mode**: Always test in both modes
5. **Preview**: Add preview examples when modifying components
6. **Documentation**: Update this README when adding new components

---

## Examples

See the preview sections at the bottom of each component file for comprehensive examples of usage and variations.
