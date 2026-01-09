# DD Ride App Theme Guide

This guide provides a comprehensive reference for the DD Ride app's design system, defined in `AppTheme.swift`.

## Overview

The `AppTheme` struct provides centralized access to:
- Colors (semantic and brand)
- Typography (system-based with custom weights)
- Spacing (consistent margins and padding)
- Corner Radius (rounded corners)
- Shadows (elevation effects)

All values automatically support **Dark Mode** and **Dynamic Type**.

---

## Colors

### Primary Brand Colors
```swift
AppTheme.Colors.primary      // Blue - Primary actions
AppTheme.Colors.secondary    // Gray - Secondary actions
AppTheme.Colors.accent       // Teal - Accent/highlights
```

### Semantic Colors
```swift
AppTheme.Colors.success      // Green - Success states
AppTheme.Colors.warning      // Orange - Warnings
AppTheme.Colors.danger       // Red - Errors/destructive actions
AppTheme.Colors.info         // Blue - Informational
```

### Background Colors
These automatically adapt to light/dark mode:
```swift
AppTheme.Colors.background             // Main background
AppTheme.Colors.secondaryBackground    // Secondary background
AppTheme.Colors.cardBackground         // Card/container backgrounds
```

### Text Colors
```swift
AppTheme.Colors.primaryText      // Main text color
AppTheme.Colors.secondaryText    // Secondary/subtle text
AppTheme.Colors.tertiaryText     // Tertiary/disabled text
```

### Ride Status Colors
```swift
AppTheme.Colors.rideQueued      // Orange - Ride in queue
AppTheme.Colors.rideAssigned    // Blue - Ride assigned
AppTheme.Colors.rideEnroute     // Green - DD en route
AppTheme.Colors.rideCompleted   // Gray - Completed ride
AppTheme.Colors.rideCancelled   // Red - Cancelled ride
```

### DD Status Colors
```swift
AppTheme.Colors.ddActive        // Green - DD is active
AppTheme.Colors.ddInactive      // Gray - DD is inactive
```

### Emergency Color
```swift
AppTheme.Colors.emergency       // Red - Emergency situations
```

---

## Typography

### Standard Text Styles
```swift
AppTheme.Typography.largeTitle   // Largest heading
AppTheme.Typography.title        // Page titles
AppTheme.Typography.title2       // Section titles
AppTheme.Typography.title3       // Subsection titles
AppTheme.Typography.headline     // List item titles
AppTheme.Typography.body         // Body text
AppTheme.Typography.callout      // Emphasized body text
AppTheme.Typography.subheadline  // Subtle text
AppTheme.Typography.footnote     // Small text
AppTheme.Typography.caption      // Captions
AppTheme.Typography.caption2     // Smallest text
```

### Custom Styles
```swift
AppTheme.Typography.button        // Button text (headline weight)
AppTheme.Typography.badge         // Badge text (caption2, semibold)
AppTheme.Typography.sectionHeader // Section headers (headline)
```

### Usage Examples
```swift
Text("Welcome")
    .font(AppTheme.Typography.title)

Text("Subtitle")
    .font(AppTheme.Typography.subheadline)
```

---

## Spacing

### Standard Spacing Scale
```swift
AppTheme.Spacing.xxs    // 4pt  - Minimal spacing
AppTheme.Spacing.xs     // 8pt  - Tight spacing
AppTheme.Spacing.sm     // 12pt - Small spacing
AppTheme.Spacing.md     // 16pt - Medium spacing
AppTheme.Spacing.lg     // 24pt - Large spacing
AppTheme.Spacing.xl     // 32pt - Extra large spacing
AppTheme.Spacing.xxl    // 48pt - Maximum spacing
```

### Context-Specific Spacing
```swift
AppTheme.Spacing.cardPadding      // 16pt - Padding inside cards
AppTheme.Spacing.sectionSpacing   // 24pt - Spacing between sections
AppTheme.Spacing.listItemSpacing  // 12pt - Spacing between list items
AppTheme.Spacing.buttonPadding    // 16pt - Padding inside buttons
```

### Usage Examples
```swift
VStack(spacing: AppTheme.Spacing.md) {
    // Content
}

Text("Hello")
    .padding(AppTheme.Spacing.cardPadding)
```

---

## Corner Radius

### Standard Radius Scale
```swift
AppTheme.CornerRadius.xs    // 4pt  - Minimal rounding
AppTheme.CornerRadius.sm    // 8pt  - Small rounding
AppTheme.CornerRadius.md    // 12pt - Medium rounding
AppTheme.CornerRadius.lg    // 16pt - Large rounding
AppTheme.CornerRadius.xl    // 20pt - Extra large rounding
```

### Context-Specific Radius
```swift
AppTheme.CornerRadius.button     // 12pt - Button corners
AppTheme.CornerRadius.card       // 12pt - Card corners
AppTheme.CornerRadius.badge      // 6pt  - Badge corners
AppTheme.CornerRadius.textField  // 12pt - Text field corners
```

### Usage Examples
```swift
RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)

VStack { }
    .cornerRadius(AppTheme.CornerRadius.button)
```

---

## Shadows

Three pre-defined shadow styles for elevation:

### Small Shadow
```swift
AppTheme.Shadow.sm
// color: Black 5% opacity
// radius: 2pt
// offset: (0, 1)
```
Use for: Subtle elevation, small cards

### Medium Shadow
```swift
AppTheme.Shadow.md
// color: Black 10% opacity
// radius: 5pt
// offset: (0, 2)
```
Use for: Standard cards, buttons

### Large Shadow
```swift
AppTheme.Shadow.lg
// color: Black 15% opacity
// radius: 10pt
// offset: (0, 4)
```
Use for: Floating elements, modals

### Usage Examples
```swift
VStack { }
    .shadow(
        color: AppTheme.Shadow.md.color,
        radius: AppTheme.Shadow.md.radius,
        x: AppTheme.Shadow.md.x,
        y: AppTheme.Shadow.md.y
    )
```

---

## View Modifiers

### Card Style
Applies consistent card styling (padding, background, corner radius, shadow):
```swift
VStack {
    // Content
}
.cardStyle()
```

### Primary Button Style
Applies primary button styling (font, colors, padding):
```swift
Text("Continue")
    .primaryButtonStyle()
```

### Section Header Style
Applies section header styling (font, color):
```swift
Text("Members")
    .sectionHeaderStyle()
```

---

## Design Patterns

### Consistent Cards
```swift
VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
    Text("Title")
        .font(AppTheme.Typography.headline)

    Text("Description")
        .font(AppTheme.Typography.subheadline)
        .foregroundColor(AppTheme.Colors.secondaryText)
}
.cardStyle()
```

### Stat Display
```swift
VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
    Text("42")
        .font(AppTheme.Typography.title)
        .foregroundColor(AppTheme.Colors.primaryText)

    Text("Total Rides")
        .font(AppTheme.Typography.caption)
        .foregroundColor(AppTheme.Colors.secondaryText)
}
.padding(AppTheme.Spacing.cardPadding)
.background(AppTheme.Colors.cardBackground)
.cornerRadius(AppTheme.CornerRadius.card)
```

### Status Badge
```swift
Text("Active")
    .font(AppTheme.Typography.badge)
    .foregroundColor(.white)
    .padding(.horizontal, AppTheme.Spacing.sm)
    .padding(.vertical, AppTheme.Spacing.xxs)
    .background(AppTheme.Colors.success)
    .cornerRadius(AppTheme.CornerRadius.badge)
```

### List Section
```swift
VStack(alignment: .leading, spacing: AppTheme.Spacing.listItemSpacing) {
    Text("Members")
        .sectionHeaderStyle()

    ForEach(members) { member in
        MemberRow(user: member)
    }
}
.padding(AppTheme.Spacing.md)
```

---

## Legacy Theme Support

For backward compatibility, the old `Color.theme` API still works:
```swift
// Legacy API (still works)
Color.theme.background
Color.theme.text
Color.theme.error

// New API (preferred)
AppTheme.Colors.background
AppTheme.Colors.primaryText
AppTheme.Colors.danger
```

---

## Best Practices

### DO:
✅ Use AppTheme constants for all styling
✅ Test in both Light and Dark modes
✅ Use semantic colors (`.primary`, `.secondary`)
✅ Let Dynamic Type scale text automatically
✅ Maintain consistent spacing throughout the app

### DON'T:
❌ Hardcode color values (`Color(red: 0.5, green: 0.5, blue: 0.5)`)
❌ Hardcode spacing values (`.padding(16)`)
❌ Use fixed font sizes (`.font(.system(size: 14))`)
❌ Ignore dark mode
❌ Create custom colors without adding to AppTheme

---

## Examples

### Complete Button
```swift
Button(action: action) {
    Text("Request Ride")
        .font(AppTheme.Typography.button)
        .foregroundColor(.white)
        .padding(AppTheme.Spacing.buttonPadding)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.primary)
        .cornerRadius(AppTheme.CornerRadius.button)
}
```

### Complete Card
```swift
VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
    HStack {
        Image(systemName: "car.fill")
            .foregroundColor(AppTheme.Colors.primary)

        Text("Active Ride")
            .font(AppTheme.Typography.headline)

        Spacer()

        Text("En Route")
            .font(AppTheme.Typography.badge)
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xxs)
            .background(AppTheme.Colors.rideEnroute)
            .cornerRadius(AppTheme.CornerRadius.badge)
    }

    Text("1234 College Ave")
        .font(AppTheme.Typography.body)
        .foregroundColor(AppTheme.Colors.secondaryText)
}
.padding(AppTheme.Spacing.cardPadding)
.background(AppTheme.Colors.cardBackground)
.cornerRadius(AppTheme.CornerRadius.card)
.shadow(
    color: AppTheme.Shadow.md.color,
    radius: AppTheme.Shadow.md.radius,
    x: AppTheme.Shadow.md.x,
    y: AppTheme.Shadow.md.y
)
```

---

## Adding New Theme Values

To add new values to the theme:

1. Add to the appropriate struct in `AppTheme.swift`
2. Document the value in this guide
3. Update components to use the new value
4. Test in light and dark modes

Example:
```swift
// In AppTheme.swift
struct Colors {
    // ... existing colors ...
    static let newColor = Color.purple  // Add new color
}

// In this guide
### New Color
```swift
AppTheme.Colors.newColor  // Purple - Description
```

// In components
.foregroundColor(AppTheme.Colors.newColor)
```
