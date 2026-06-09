# Implementation Task: Fix iOS Camera Preview "One Camera Rule" Bug

## Objective
Resolve the black screen/frozen camera issue when transitioning between the full-screen (expanded) and circle (minimized) camera views. 

## Context
iOS restricts apps to a single active `CameraPreview` feed. Currently, `RecordingPage` attempts to spawn a second camera to draw the circle, hijacking the feed from `HomePage`. The solution is to lift the layout state (`isFocusModeExpanded`) up to `HomePage` so it can handle the circle transition using its existing, active camera.

---

### Task 1: Add Focus State to `HomePage`
**File:** `HomePage.swift`
**Action:** Add a state variable to track the focus mode (circle state).
**Code to insert:**
```swift
    /// false = home card; true = full-screen session. Drives the enlarge transition.
    @State private var sessionActive = false

    // NEW: Tracks if the recording session is in the "minimized circle" focus mode
    @State private var isFocusModeExpanded = false 
```

---

### Task 2: Refactor `HomePage` Camera Preview
**File:** `HomePage.swift`
**Action:** Update the `CameraPreview` implementation to animate into a circle when `isFocusModeExpanded` is triggered.
**Code to replace:** Find `// 2. The single, persistent camera.` and replace the block with:
```swift
            // 2. The single, persistent camera.
            GeometryReader { geo in
                let circleSize: CGFloat = 164
                let isCircle = sessionActive && isFocusModeExpanded
                
                let camW = isCircle ? circleSize : geo.size.width
                let camH = isCircle ? circleSize : geo.size.height
                
                let camCenterY: CGFloat = isCircle
                    ? geo.safeAreaInsets.top + 168
                    : geo.size.height / 2
                
                CameraPreview(session: sessionRecording.captureSession)
                    .frame(width: camW, height: camH)
                    .clipShape(RoundedRectangle(cornerRadius: isCircle ? circleSize / 2 : (sessionActive ? 30 : 34), style: .continuous))
                    .overlay {
                        if !isCircle {
                            RoundedRectangle(cornerRadius: sessionActive ? 30 : 34, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.5), lineWidth: 3)
                        }
                    }
                    .position(x: geo.size.width / 2, y: camCenterY)
                    // Apply your existing padding ONLY if it's the home card state
                    .padding(.top, !sessionActive ? safeTop + 120 : 0)
                    .padding(.bottom, !sessionActive ? safeBottom + 122 : 0)
                    .padding(.horizontal, !sessionActive ? 16 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isFocusModeExpanded)
                    .animation(transition, value: sessionActive)
            }
            .ignoresSafeArea()
```

---

### Task 3: Pass State Binding to `RecordingPage`
**File:** `HomePage.swift`
**Action:** Inject the `$isFocusModeExpanded` binding into the `RecordingPage` instance and handle state reset on exit.
**Code to replace:** Update the `if sessionActive` block:
```swift
            // 4. Recording controls, hosted in place over the now-full-screen camera.
            if sessionActive {
                RecordingPage(
                    autoStart: true, 
                    embedded: true, 
                    isExpanded: $isFocusModeExpanded, // New binding passed here
                    onExit: {
                        isFocusModeExpanded = false // Reset state when session ends
                        endSession()
                    }
                )
                .hidesFloatingTabBar()
                .transition(.opacity)
            }
```

---

### Task 4: Convert State to Binding in `RecordingPage`
**File:** `RecordingPage.swift`
**Action:** Update the local variable to accept the binding from `HomePage`.
**Code to replace:**
```swift
    // Replace this:
    // @State private var isExpanded = false
    
    // With this:
    @Binding var isExpanded: Bool
```

---

### Task 5: Remove Hijacking Camera Feed
**File:** `RecordingPage.swift`
**Action:** Delete the local `CameraPreview` that is stealing the hardware feed.
**Code to delete:** Inside the main `ZStack`, completely remove this entire block:
```swift
            // Camera preview — morphs between full-screen fill and small circle.
            // We always build it (even embedded) so full-focus has its camera circle...
            GeometryReader { geo in
                let circleSize: CGFloat = 164
                // ... [delete everything down to] ...
            }
            .ignoresSafeArea()
            // Embedded + minimized → HomePage's shared camera shows through; standalone,
            // or once expanded into the circle, → show this one.
            .opacity(embedded && !isExpanded ? 0 : 1)
```
