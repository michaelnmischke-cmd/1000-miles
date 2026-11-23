# Connecting Fitbit

Most trackers (WHOOP, Garmin, Oura, Polar, COROS, Withings, Strava and others) send steps to Apple Health, and 1000 Miles already reads those. Fitbit is the exception: it doesn't write to Apple Health. So the app reads Fitbit steps directly.

Fitbit's own Web API was switched off in fall 2026 (support ended September 30). Fitbit data now comes from the **Google Health API**, and users sign in with the Google account their Fitbit is linked to. That needs a free Google Cloud project, set up once by you (the developer), not by each user.

Until a client ID is filled in, the Fitbit option in **Settings > Step sources** says "Coming soon" and everything else works as before.

## One-time setup (about 15 minutes)

1. Go to [console.cloud.google.com](https://console.cloud.google.com) and create a project named `1000 Miles`.
2. Open **APIs & Services > Library**, search for **Google Health API**, and click **Enable**.
3. Open **Google Auth Platform** (the OAuth consent screen). Choose **External**, fill in the app name and your email, and leave it in **Testing**.
4. Under **Audience > Test users**, add your own Google account and those of anyone testing with you (up to 100).
5. Under **Data Access**, add the scope `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly`.
6. Under **Clients**, click **Create client**, choose **iOS**, and enter the app's bundle ID (`app.thousandmiles.ios`, or the one you picked in Xcode). Copy the **Client ID**.
7. In Xcode, open `ThousandMiles/StepSources/GoogleHealthConfig.swift` and paste the client ID between the quotes of `clientID`.
8. Run the app, open **Settings > Step sources**, and tap **Connect Fitbit**.

Your Fitbit account must already be moved to a Google account (the Fitbit app walks you through it). If it isn't, the app says so.

## Good to know

- **Testing mode signs you out weekly.** While the Google project is in Testing, Google ends the sign-in after 7 days. The app keeps the last Fitbit steps it saw and asks you to connect again.
- **Going public needs Google's review.** Health scopes are "restricted". Before more than 100 people can connect, Google requires app verification and a yearly third-party security assessment (CASA), which takes a few weeks and costs roughly $500 to $4,500 a year. Worth doing only if lots of users ask for Fitbit.
- **Not tested against Google yet.** Google's Health API guide shows a "Web server" client with a secret. The app uses the standard iOS client with PKCE instead, which Google supports for its other APIs and which keeps secrets off the phone. If Google refuses the iOS client for this API, the fallback is a small sign-in helper on the Firebase backend planned for the social stage.
- **Widgets show Apple Health miles only** for now. Sharing Fitbit miles with the widget needs an App Group, which comes with the paid Apple Developer account in stage 3.
- **Privacy.** Only daily step counts are read. They and the sign-in are kept on the iPhone (the sign-in in the Keychain). Disconnecting revokes access with Google.

## How double counting is avoided

A walk can be recorded by your iPhone, your watch and your Fitbit at the same time, so sources are never added together.

- Inside Apple Health, Health already merges overlapping devices (iPhone, Apple Watch, WHOOP...) using its own source priority.
- Between Apple Health and Fitbit, the app takes the **larger** of the two for each day. Fitbit steps are turned into miles with your stride, learned from days your iPhone recorded both steps and distance (about 2,250 steps per mile until it has enough days).
