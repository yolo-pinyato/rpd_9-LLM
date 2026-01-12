# Pulse Survey - Visual Guide

## What Users See:

### 1. Tasks Tab View
```
┌─────────────────────────────────────┐
│  📊 Weekly Check-In                 │
├─────────────────────────────────────┤
│  ╭───────────────────────────────╮  │
│  │ 💗 Weekly Pulse Survey        │  │
│  │ Rate your week and share      │  │
│  │ feedback                      │  │
│  │                        +500 → │  │
│  ╰───────────────────────────────╯  │
├─────────────────────────────────────┤
│  📚 Track Learning                  │
│  [Learning modules appear here]     │
└─────────────────────────────────────┘
```

### 2. Survey Modal (After Tapping)
```
┌─────────────────────────────────────┐
│  Weekly Pulse Check              ⨉  │
├─────────────────────────────────────┤
│  🩺 Weekly Pulse Check              │
│  Help us understand how you're      │
│  doing this week                    │
├─────────────────────────────────────┤
│                                     │
│  💗 How are you feeling so far     │
│     this week?                      │
│                                     │
│  1 ────────●──────────────── 10     │
│  Low          [5]            High   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ (Optional) In 1-2 sentences,│   │
│  │ why are you feeling this    │   │
│  │ way?                        │   │
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  🌟 How are you feeling so far     │
│     this week about the program?    │
│                                     │
│  1 ────────●──────────────── 10     │
│  Low          [5]            High   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ (Optional) In 1-2 sentences,│   │
│  │ why are you feeling this    │   │
│  │ way about the program?      │   │
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │   ✓ Submit Check-In         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⭐ Earn 500 points for completing  │
│     this check-in                   │
└─────────────────────────────────────┘
```

### 3. Success Screen
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│          ✅                         │
│       (80pt icon)                   │
│                                     │
│      Thank You!                     │
│                                     │
│  Your feedback helps us improve     │
│                                     │
│        +500 points                  │
│                                     │
│                                     │
│  (Auto-dismisses after 2 seconds)   │
│                                     │
└─────────────────────────────────────┘
```

## Technical Implementation:

### Component Hierarchy:
```
EnhancedTasksView
├── PulseSurveyCard (in Tasks list)
│   └── onTap → shows modal
│
└── .sheet(isPresented: $showPulseSurvey)
    └── PulseSurveyView
        ├── SliderQuestion (x2)
        │   ├── Current value display
        │   ├── Slider control
        │   └── Scale labels (Low/High)
        │
        ├── TextFieldQuestion (x2)
        │   └── TextEditor with placeholder
        │
        ├── Submit Button
        │   └── onTap → submitSurvey()
        │
        └── Success Overlay
            └── Auto-dismiss animation
```

### Data Flow:
```
User fills survey
     ↓
Tap "Submit Check-In"
     ↓
Create PulseSurvey object
     ↓
Save to database via DatabaseManagerEnhanced.savePulseSurvey()
     ↓
Award 500 points
     ↓
Save point allocation
     ↓
Update user's point balance
     ↓
Show success animation
     ↓
Auto-dismiss after 2 seconds
     ↓
Return to Tasks tab
```

## Key Features:

### ✅ User Experience:
- **Prominent Placement**: Always at top of Tasks tab
- **Clear Value Proposition**: Shows "+500 points" reward
- **Easy to Complete**: Just 4 questions (2 required, 2 optional)
- **Visual Feedback**: Sliders show value in real-time
- **Success Confirmation**: Animated success screen with haptic feedback

### ✅ Design:
- **Glassmorphic Cards**: Matches app's design language
- **Color-Coded**: Pink for personal, orange for program
- **Accessible**: Large touch targets, clear labels
- **Dark Mode**: Perfect contrast on dark gradient background

### ✅ Data Collection:
- **Structured**: 1-10 scale for quantitative analysis
- **Qualitative**: Optional text for deeper insights
- **Timestamped**: Track when surveys are completed
- **User-Linked**: Associated with user ID for personalization

### ✅ Analytics Potential:
- Track sentiment trends over time
- Identify when users struggle
- Correlate feelings with engagement
- Measure program effectiveness

## Example Usage Scenarios:

### Scenario 1: Weekly Check-in
**Monday morning:**
- User opens Tasks tab
- Sees pulse survey at top
- Completes in 30 seconds
- Earns 500 points
- Continues with learning tasks

### Scenario 2: Quick Feedback
**Mid-week:**
- User feeling stressed (rating: 3/10)
- Provides context: "Work overload this week"
- Program coordinators can reach out for support

### Scenario 3: Positive Progress
**Friday:**
- User feeling great (rating: 9/10)
- Reason: "Learned so much this week!"
- Validates program effectiveness

## Admin Benefits:

Admins can query the database to:
- View average weekly ratings
- Identify struggling users early
- Track program sentiment trends
- Make data-driven improvements
- Celebrate user successes

---

## Quick Integration Checklist:

- [x] Create PulseSurveyView component
- [x] Add PulseSurveyCard to Tasks tab
- [x] Implement database methods
- [x] Add point allocation tracking
- [x] Test survey submission
- [x] Verify data persistence
- [x] Confirm points are awarded
- [x] Check success animation

✅ **Ready to Use!**
