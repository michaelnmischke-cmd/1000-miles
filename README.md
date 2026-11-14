# 1000 Miles

An iPhone app that tracks the miles you walk and run each year, with the goal of reaching 1000.

Stage 1 (this version): reads walking + running distance from Apple Health and shows your yearly progress ring, daily pace, weekly chart, milestones, and a goal setting. Friends, leaderboards, widgets and the song button come in later stages.

## Run it on your iPhone

You need: a Mac with Xcode, your iPhone, and a USB cable. A free Apple ID is enough for now.

### 1. Get the code onto your Mac

1. Install [GitHub Desktop](https://desktop.github.com) and sign in with your GitHub account.
2. Choose **File > Clone Repository**, pick `1000-miles`, and clone it (the default folder is fine).
3. Later, when there's new code, open GitHub Desktop and click **Fetch origin**, then **Pull origin**.

### 2. Open the project

1. In GitHub Desktop, choose **Repository > Show in Finder**.
2. Double-click `ThousandMiles.xcodeproj`. Xcode opens.

### 3. Sign the app (one time)

1. In Xcode's left sidebar, click the blue **ThousandMiles** project icon at the top.
2. Under **Targets**, click **ThousandMiles**, then the **Signing & Capabilities** tab.
3. Next to **Team**, choose **Add an Account…** and sign in with your Apple ID. Then pick **(Your Name) (Personal Team)**.
4. If Xcode says the bundle identifier is not available, change **Bundle Identifier** to something unique, such as `app.thousandmiles.yourname`.

### 4. Get your iPhone ready (one time)

1. Plug your iPhone into the Mac and tap **Trust** on the phone.
2. On the iPhone, open **Settings > Privacy & Security > Developer Mode**, turn it on, and restart when asked.

### 5. Run it

1. At the top of Xcode, click the device menu (next to "ThousandMiles") and pick your iPhone.
2. Press the **Play** button (or Command-R).
3. The first time, your iPhone may say "Untrusted Developer". Open **Settings > General > VPN & Device Management**, tap your Apple ID, and tap **Trust**. Then press Play again.
4. In the app, tap **Connect Apple Health** and allow **Walking + Running Distance**.

With a free Apple ID, the app stops opening after 7 days. Just plug in and press Play again. This goes away once you join the Apple Developer Program.

### Try it without your phone

Pick any iPhone simulator from the device menu and press Play. Make sure a Team is selected (step 3) first, because Apple Health only works when the app is signed. The Simulator has no real steps, so the app shows sample miles.

## Project layout

| Path | What it is |
| --- | --- |
| `ThousandMiles/ThousandMilesApp.swift` | App start, tabs, refreshing when the app opens |
| `ThousandMiles/HealthStore.swift` | Reads miles from Apple Health |
| `ThousandMiles/YearProgress.swift` | Pace, miles left, weekly totals, milestones |
| `ThousandMiles/ProgressScreen.swift` | The main progress screen |
| `ThousandMiles/SettingsScreen.swift` | Goal setting |
| `ThousandMiles/OnboardingView.swift` | Welcome screen and Health permission |
| `ThousandMiles/Theme.swift` | Colors, fonts and card style |
| `Config/ThousandMiles.entitlements` | Turns on HealthKit |
