# Cross-Chapter Priority Calculation Update

## Overview
Updated the ride queue priority calculation to differentiate between same-chapter and cross-chapter rides.

## Business Rule

### Priority Formula

1. **Emergency rides**: `priority = 9999` (always highest, regardless of chapter)
2. **Same chapter rides**: `priority = (classYear × 10) + (waitMinutes × 0.5)`
3. **Cross-chapter rides**: `priority = (waitMinutes × 0.5)` only (class year doesn't matter)

### Rationale

- **Same chapter**: DDs know their own chapter's members and respect the class year hierarchy (seniors > juniors > sophomores > freshmen)
- **Cross-chapter**: DDs don't know other chapters' hierarchies, so only wait time determines priority
- **Emergency**: Always highest priority to ensure immediate response, regardless of chapter relationship

## Files Modified

### 1. `/ios/DDRide/Core/Services/RideQueueService.swift`

#### Changes:
- Updated `calculatePriority()` method signature to include `isSameChapter: Bool` parameter
- Added logic to skip class year calculation for cross-chapter rides
- Added helper method `isSameChapterRide(ride:event:)` to determine chapter relationship
- Added new method `calculatePriorityForRide(ride:event:classYear:)` for full context calculation
- Updated `updateRidePriority()` to accept `event` parameter
- Updated `updateAllPriorities()` to fetch event and pass to priority calculation
- Updated documentation and examples

#### New API:
```swift
func calculatePriority(
    classYear: Int,
    waitMinutes: Double,
    isEmergency: Bool,
    isSameChapter: Bool
) -> Double

func isSameChapterRide(ride: Ride, event: Event) -> Bool

func calculatePriorityForRide(ride: Ride, event: Event, classYear: Int) -> Double

func updateRidePriority(_ ride: inout Ride, classYear: Int, event: Event)
```

### 2. `/ios/DDRide/Core/Services/RideRequestService.swift`

#### Changes:
- Added event fetching in `requestRide()` method
- Determines `isSameChapter` by comparing user's chapter with event's chapter
- Passes `isSameChapter` parameter to `calculatePriority()`

### 3. `/ios/DDRide/Core/Services/EmergencyService.swift`

#### Changes:
- Updated documentation to clarify that emergency rides bypass cross-chapter logic
- No code changes needed (emergency rides already hardcode priority to 9999)

### 4. `/ios/DDRide/Tests/RideQueueServiceTests.swift` (NEW)

#### Added comprehensive unit tests:
- Same-chapter priority tests (all class years)
- Cross-chapter priority tests (verifying class year is ignored)
- Emergency priority tests (both same and cross-chapter)
- Comparison tests (same vs cross-chapter)
- Edge cases (zero wait, negative wait, high wait)
- Helper method tests (`isSameChapterRide`)

## Test Cases

### Same Chapter Examples

| Class Year | Wait Time | Calculation | Priority |
|------------|-----------|-------------|----------|
| Senior (4) | 5 min | (4×10) + (5×0.5) | 42.5 |
| Junior (3) | 10 min | (3×10) + (10×0.5) | 35.0 |
| Sophomore (2) | 20 min | (2×10) + (20×0.5) | 30.0 |
| Freshman (1) | 15 min | (1×10) + (15×0.5) | 17.5 |

### Cross-Chapter Examples

| Class Year | Wait Time | Calculation | Priority |
|------------|-----------|-------------|----------|
| Senior (4) | 5 min | 5×0.5 | 2.5 |
| Junior (3) | 10 min | 10×0.5 | 5.0 |
| Sophomore (2) | 20 min | 20×0.5 | 10.0 |
| Freshman (1) | 15 min | 15×0.5 | 7.5 |

### Emergency Examples

| Class Year | Wait Time | Chapter | Priority |
|------------|-----------|---------|----------|
| Any | Any | Same | 9999 |
| Any | Any | Cross | 9999 |

## Scenarios

### Scenario 1: Same-Chapter Senior vs Cross-Chapter Senior (Same Wait Time)
- **Same-chapter senior**: (4×10) + (5×0.5) = **42.5**
- **Cross-chapter senior**: 5×0.5 = **2.5**
- **Result**: Same-chapter senior gets higher priority ✓

### Scenario 2: Cross-Chapter Rider Waiting Long Enough
- **Cross-chapter waiting 40 min**: 40×0.5 = **20.0**
- **Same-chapter freshman waiting 5 min**: (1×10) + (5×0.5) = **12.5**
- **Result**: Cross-chapter rider can overtake same-chapter freshman if they wait long enough ✓

### Scenario 3: Multiple Emergencies
- Both emergencies have priority = **9999**
- Queue position determined by `requestedAt` timestamp (FIFO)
- First emergency → Position 1
- Second emergency → Position 2

## Impact on Existing Features

### Affected Services:
1. **RideQueueService**: Core priority calculation updated
2. **RideRequestService**: Now fetches event to determine chapter relationship
3. **DDAssignmentService**: No changes needed (uses priority from rides)
4. **EmergencyService**: No changes needed (already bypasses priority calculation)

### Database Changes:
- **None**: Existing schema already has `chapterId` on both `Ride` and `Event` models

### Backward Compatibility:
- Old `calculatePriority()` signature is deprecated but not removed
- New code should use `calculatePriorityForRide()` for full context
- `calculateCurrentPriority()` defaults to `isSameChapter: true` for backward compatibility

## Migration Notes

### For Existing Rides:
1. No data migration needed
2. Next call to `updateAllPriorities()` will recalculate with new logic
3. Rides created before this update will be recalculated correctly on next priority update cycle

### For New Rides:
- RideRequestService automatically handles chapter relationship detection
- No changes needed in UI or request flow

## Testing Checklist

- [x] Unit tests added for all priority calculation scenarios
- [x] Same-chapter priority calculations verified
- [x] Cross-chapter priority calculations verified
- [x] Emergency priority always 9999
- [x] Helper method `isSameChapterRide()` tested
- [ ] Integration tests with real event/ride data
- [ ] UI testing to verify queue position updates correctly
- [ ] Load testing with mixed same/cross-chapter rides

## Future Enhancements

### Potential Improvements:
1. **Configurable Weights**: Allow chapters to customize `classYearWeight` and `waitTimeWeight`
2. **Cross-Chapter Discounts**: Apply a multiplier to cross-chapter priorities (e.g., 0.8x)
3. **Chapter Affinity**: Track historical ride patterns and adjust priorities based on partner chapters
4. **Admin Overrides**: Allow admins to manually adjust priority for specific rides

## Documentation Updates

### Updated Files:
- `/ios/DDRide/Core/Services/RideQueueService.swift` - Full documentation with examples
- `/ios/DDRide/Core/Services/RideRequestService.swift` - Added event fetching step
- `/ios/DDRide/Core/Services/EmergencyService.swift` - Clarified emergency bypass logic
- `CLAUDE.md` - Core business rules documentation (should be updated)

### Recommended Updates:
- Update `CLAUDE.md` with new cross-chapter priority formula
- Add examples to Firebase Functions documentation
- Update admin dashboard documentation to explain priority logic
- Create user-facing FAQ about cross-chapter rides

---

## Contact

For questions or clarifications about this update, contact the development team.

**Last Updated**: 2026-01-09
