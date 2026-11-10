# CommonGround iOS (SwiftUI)

Native iOS client that talks to the same Spring backend as Android and the Next.js web app.

## Requirements

- macOS with Xcode 15+ (iOS 17 deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Open in Xcode

`CommonGround.xcodeproj` is already generated — open it directly:

```bash
cd ios
open CommonGround.xcodeproj
```

Only re-run XcodeGen if you change `project.yml`:

```bash
xcodegen generate
```

### Canvas preview (no Run)

Open `ContentView.swift` → Canvas (⌥⌘↩). If Canvas still errors, Product → Clean Build Folder, then reopen the file.

In Xcode to run on a simulator:

1. Select the **CommonGround** scheme and an iPhone simulator (or device).
2. Set your **Team** under Signing & Capabilities if you run on a physical device.
3. Press **Run** (⌘R).

## Backend URL

Default base URL is `https://volunteer-backend-7m4w.onrender.com` (same Render service as Android).

Override per build in `project.yml`:

```yaml
API_BASE_URL: "https://your-host.example.com"
```

Then re-run `xcodegen generate`. The value is injected into `Info.plist` as `API_BASE_URL` and read by `APIConfig`.

## What’s included

| Area | Status |
|------|--------|
| Splash + login (JWT) | Done |
| Tabs: Home / Events / Hours / Tasks / Profile | Done |
| Home summary, badges preview, notifications | Done |
| Events list + register / cancel | Done |
| Hours list + submit log | Done |
| Tasks list + status updates | Done |
| Check-in by event code | Done (Home + Profile) |
| Badges & notifications | Done |
| Letters / certificates | Placeholder |
| Appearance: System / Light / Dark | Done |
| Gemini chat FAB | Done |
| iPhone Duo adaptive shell | Done — tabs when compact; sidebar split when unfolded / wide |
| Events list + detail dual-pane | Done on Duo / iPad width |
| Multi-scene / landscape | Enabled |

## Demo sign-in

Use the same volunteer / leader / organiser accounts you use on web or Android against the Render backend.

## Push notifications (device token)

After login, CommonGround requests notification permission, registers for APNs, and posts the device token to `POST /api/me/devices` (`platform: "IOS"`).

**Credentials required for real delivery (not checked in):**

1. Enable Push Notifications for the App ID / signing team in Apple Developer.
2. Create an APNs key (or certificate) and add it to Firebase Cloud Messaging (or your backend sender).
3. Re-run `xcodegen generate` after changing `project.yml` so the `aps-environment` entitlement is applied.
4. For release builds, set `aps-environment` to `production`.

Without those steps, you should still see the registration API call when signed in on a physical device; remote pushes will not arrive.
