# Whoosh iOS — agent briefing

Native SwiftUI client for **Whoosh** (a sports/fantasy/finance app with a
simulated currency, *Whoosh Bucks*). This repo is the iOS app only; it talks to a
separate Next.js + Supabase backend over a versioned JSON API. There is **no
shared code** with the backend — the contract is the OpenAPI spec vendored here.

## How it connects
- **Backend base URL:** `https://whoosh.business` (production). Set in `Config.swift`.
- **API contract:** `openapi/whoosh-v1.yaml` (vendored copy of the backend's spec —
  the source of truth for every endpoint, request, and response shape). When the
  backend changes, re-copy this file.
- **Auth:** Supabase GoTrue email auth, hand-rolled in `Auth/SupabaseAuth.swift`
  (no SDK). Session (access/refresh tokens) persists in the Keychain
  (`Auth/TokenStore.swift`). Email confirmation is ON, so sign-up shows
  "check your email, then sign in."
- **Networking:** all requests go through `Networking/WhooshAPI.swift`, which adds
  `Authorization: Bearer <jwt>` + `X-Client: ios` and unwraps the `{ ok, data }` /
  `{ ok, error }` envelope. Models in `Networking/Models.swift` are **partial**
  Codable mirrors of the spec (decoder ignores unmodeled keys). Switch on the
  stable `APIError.code` (e.g. `conflict`, `unauthorized`, `insufficient_funds`).

## App structure
- `whoosh_iosApp.swift` → `RootView` driven by `AppModel` (an `ObservableObject`,
  `@MainActor`). State machine: `loading → unauthenticated → onboarding → home`.
  **No marketing/landing screen** — signed-out users go straight to account
  creation; first-run users must create a profile (handle + avatar).
- `SplashView` (lime `#cef932` + black bolt, ~2s) → `AccountCreationView` →
  `OnboardingView` → `HomeView` (a `TabView`: Home · Capital · Account).
- **Capital** (`Capital/`) is the most built-out section: `CapitalView` (balance
  hero, Swift Charts `EquityChart`, allocation, holdings, auto-scrolling
  `TickerStrip`), wallet actions (`BuyWBSheet` Stripe link-out, `TransferSheet`,
  daily bonus, `ActivityView`), investing (`InvestView`/`SymbolView`), and house
  bets (`BetsView`/`PlaceWagerView`).

## Brand
- Lime `#cef932` (`Color.whooshLime`), pigment-green `#009640` (`Color.whooshGreen`),
  black ink (`Color.whooshInk`) — all in `Brand.swift`.
- Money is formatted via the `Money` helper (`Money.swift`): cents → `$1,234.56`,
  signed/colored. Use it everywhere for consistency.
- The lightning bolt asset is `Assets.xcassets/WhooshBolt` (template image).

## Conventions / gotchas
- **Xcode 16 synchronized folders** (`objectVersion = 77`): any `.swift`/asset file
  added inside `whoosh-ios/` is auto-compiled — no need to edit the `.xcodeproj`.
- Keep money formatting + brand colors centralized (don't hardcode hex/strings).
- Layout: views inside the vertical `ScrollView` must not report a width wider than
  the screen. (A doubled-HStack marquee once blew out the page width — the
  `TickerStrip` now bounds itself with a fixed-height `GeometryReader` + `.clipped()`.
  Watch for the same trap with any horizontally-wide content.)
- Payments are **web Stripe link-out** (open a hosted URL), not in-app IAP — see the
  backend's `docs/ios-payments.md`. The balance is intentionally **always visible**
  (no hide/Face-ID toggle).

## Build / run
- Open `whoosh-ios.xcodeproj` in Xcode → ⌘R (iPhone simulator). Sign in to reach
  the Home/Capital tabs.
- CLI build: `xcodebuild -project whoosh-ios.xcodeproj -scheme whoosh-ios \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build`.
