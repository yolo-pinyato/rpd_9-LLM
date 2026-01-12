# Test Account Switcher Feature

## Overview
The Test Account Switcher is a development/testing feature added to the Profile tab that allows you to quickly switch between 5 dummy test accounts. This enables easy testing of different user scenarios, tracks, and data states without needing to manually create new accounts or reset the database.

## Location
**Profile Tab → Test Account Switcher Card** (orange card at the bottom, tap to expand)

## Features

### 5 Pre-Configured Test Accounts

| Account ID | Name | Email | Description | Special Features |
|------------|------|-------|-------------|------------------|
| `test_user_001` | Alex Johnson | alex.johnson@test.com | HVAC Track, High Engagement | **Admin Access** |
| `test_user_002` | Maria Garcia | maria.garcia@test.com | Nursing Track, New User | Random data |
| `test_user_003` | James Smith | james.smith@test.com | Spiritual Track, Regular User | Random data |
| `test_user_004` | Sarah Lee | sarah.lee@test.com | Mental Health Track, Power User | Random data |
| `test_user_005` | David Chen | david.chen@test.com | HVAC Track, Returning User | Random data |

### Automatic Data Generation

When you switch to a test account for the first time, the system automatically creates:

1. **User Profile**:
   - Random track assignment (HVAC, Nursing, Spiritual, Mental Health)
   - Random points balance (500-3,000 points)
   - Random current streak (0-15 days)
   - Random tasks completed (5-50 tasks)
   - Default goals: "Personal Development", "Career Growth", "Financial Stability"

2. **Sample Check-Ins**:
   - 3-10 random historical check-ins
   - Distributed across recent days
   - 100 points per check-in
   - Stored with QR code: `TEST_QR_[day_offset]`

3. **User Level**:
   - Automatically calculated from points (1 level per 500 points)
   - Max level: 20

## Usage

### Switching Accounts

1. Navigate to the **Profile** tab
2. Scroll to the bottom to find the **Test Account Switcher** card (orange border)
3. Tap the card header to expand it
4. You'll see 5 test accounts listed with:
   - Profile icon with first letter of name
   - Name and email
   - Description of the account type
   - Green checkmark if it's the current account
5. Tap any account to switch to it
6. The app will reload data for that account immediately

### Visual Indicators

- **Current Account**: Green checkmark icon, highlighted background, bold name
- **Other Accounts**: Gray profile icons, plain background, arrow icon on right
- **Collapsed State**: Shows header with chevron down icon
- **Expanded State**: Shows all accounts with chevron up icon

## Technical Details

### Code Structure

#### Main Components
- `TestAccountSwitcherCard` - Main card view with expand/collapse
- `TestAccountRow` - Individual account row with profile info
- Database methods in `DatabaseManagerEnhanced`:
  - `getUser(id:)` - Load existing user
  - `saveUser(_:)` - Save new user
  - `saveCheckIn(_:)` - Save check-in event
  - `getTasks(forTrack:)` - Load user's tasks
  - `getCheckIns(forUser:)` - Load user's check-ins

#### Data Flow
```
1. User taps account row
   ↓
2. switchToAccount() called
   ↓
3. Check if user exists in database
   ├─ Yes: Load existing user
   └─ No: Create new user with random data
   ↓
4. Update viewModel.user
   ↓
5. Call viewModel.loadData()
   ↓
6. UI refreshes with new user's data
```

### Database Tables Used

- **users** - Stores user profiles
- **check_ins** - Stores check-in events
- **tasks** - Stores completed tasks
- **events** - Logs account switches

### Persistence

- All test accounts are persisted in the SQLite database
- Switching accounts doesn't delete data
- You can switch back to previous accounts and see all their data
- Data persists across app launches

## Use Cases

### 1. Testing Different Tracks
Switch between accounts to test HVAC, Nursing, Spiritual, and Mental Health content paths.

### 2. Testing User Levels
Test accounts have different point balances (500-3,000), giving you levels 1-7 to test UI at different progression stages.

### 3. Testing Admin Features
`test_user_001` (Alex Johnson) has admin privileges, allowing you to test the Admin Dashboard tab.

### 4. Testing Check-In History
Each account has 3-10 historical check-ins, perfect for testing charts and history views.

### 5. Testing Onboarding vs Returning Users
- New accounts show full onboarding state
- Existing accounts skip onboarding
- Different streak counts test engagement metrics

### 6. SQL Database Testing
All accounts write to the same `workforce_dev.sqlite` database, perfect for:
- Testing multi-user queries
- Verifying data isolation
- Testing database schema changes
- Exporting data for analysis

## Developer Notes

### Customizing Test Accounts

To customize the test accounts, edit the `testAccounts` array in `TestAccountSwitcherCard`:

```swift
let testAccounts: [(id: String, name: String, email: String, description: String)] = [
    ("test_user_001", "Your Name", "email@test.com", "Your Description"),
    // ... more accounts
]
```

### Adjusting Random Data Ranges

In the `switchToAccount()` method, modify these lines:

```swift
pointsBalance: Int.random(in: 500...3000),      // Change point range
currentStreak: Int.random(in: 0...15),          // Change streak range
totalTasksCompleted: Int.random(in: 5...50),    // Change task count
for dayOffset in 0..<Int.random(in: 3...10) {   // Change check-in count
```

### Making All Accounts Admin

Change this line to make all test accounts admins:

```swift
isAdmin: true  // Instead of: account.id == "test_user_001"
```

### Adding More Test Accounts

Simply add more tuples to the `testAccounts` array:

```swift
("test_user_006", "Jane Doe", "jane.doe@test.com", "Custom Track, Description")
```

## Security Considerations

⚠️ **Important**: This feature is for development/testing only!

- Should be **removed** or **disabled** in production builds
- Test account IDs follow pattern `test_user_###`
- Consider adding `#if DEBUG` guards:

```swift
#if DEBUG
TestAccountSwitcherCard(viewModel: viewModel)
    .padding(.horizontal)
#endif
```

## Future Enhancements

Potential improvements for this feature:

1. **Reset Account Data**: Button to clear all data for a test account
2. **Duplicate Account**: Clone an account with all its data
3. **Export Account Data**: Export test account data as JSON
4. **Import Account Data**: Load test scenarios from JSON files
5. **Account Presets**: Pre-configured scenarios (e.g., "High Performer", "Struggling User")
6. **Time Travel**: Set account to different dates to test time-based features
7. **Bulk Operations**: Switch multiple accounts at once for stress testing

## Troubleshooting

### Account Won't Switch
- Check console logs for database errors
- Verify database file isn't corrupted
- Try restarting the app

### Data Not Showing
- Verify `viewModel.loadData()` is being called
- Check if `getTasks()` and `getCheckIns()` return data
- Look for SQL errors in console

### App Crashes on Switch
- Check for force-unwrapping nil values
- Verify all database columns exist
- Ensure CheckInEvent initializer matches struct definition

### Can't See Switcher Card
- Scroll to bottom of Profile tab
- Tap the orange bordered card to expand
- Verify code isn't wrapped in `#if DEBUG` on release build

## Database Query Examples

### View All Test Users
```sql
SELECT user_id, race, points_balance, current_streak, selected_track 
FROM users 
WHERE user_id LIKE 'test_user_%';
```

### View Test User Check-Ins
```sql
SELECT u.user_id, u.race, COUNT(c.id) as check_in_count
FROM users u
LEFT JOIN check_ins c ON u.user_id = c.user_id
WHERE u.user_id LIKE 'test_user_%'
GROUP BY u.user_id;
```

### Clear All Test User Data
```sql
DELETE FROM users WHERE user_id LIKE 'test_user_%';
DELETE FROM check_ins WHERE user_id LIKE 'test_user_%';
DELETE FROM tasks WHERE user_id LIKE 'test_user_%';
DELETE FROM events WHERE user_id LIKE 'test_user_%';
```

## Related Files

- `/repo/rpd_9_LLMApp.swift` - Main app file with TestAccountSwitcherCard
- `/repo/DatabaseManagerEnhanced.swift` - Database methods for user management
- `/repo/PERFORMANCE_OPTIMIZATIONS.md` - Related performance improvements

## Changelog

### v1.0 (January 8, 2026)
- Initial implementation
- 5 test accounts with random data generation
- Admin access for test_user_001
- Sample check-in generation
- Profile tab integration
- Database persistence

---

**Note**: Remember to remove or disable this feature before production deployment!
