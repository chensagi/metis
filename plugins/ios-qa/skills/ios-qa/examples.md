# ios-qa Examples

Three worked examples below: **Spec Mode**, **PR Mode**, and **General Mode**. Screen names and app specifics shown are from a real run — adapt the patterns to your own app.

## Example 1: Spec Mode Run

```
/ios-qa 130

## Loading Spec

Task 130: Weekly Tournament — Game Flow & UI
Status: done
Criteria: 13 items

## Verification Plan

Total criteria: 13
  UI-verifiable: 8
  Behavior: 3
  Code-only: 1
  Non-verifiable: 1

## Phase 1: Verify

--- Lobby Screen ---

SCREEN: Lobby
OBSERVED: Lobby with era cards, "Personal Bests" section, leaderboard button.
  Tournament entry point: Gold "Weekly Tournament" card at top with trophy icon.
STRUCTURAL: 22 elements. tournament-card present.
SPEC CHECK:
  [1] "Tournament screen accessible from lobby" → PASS (card visible, tappable)
BLOCKERS: none
ISSUES: none
ACTION: tap tournament card

--- Tournament Screen ---

SCREEN: Tournament Lobby
OBSERVED: Header "Weekly Tournament". Era: "The Pandemic Era (2020)".
  Countdown: "0d 0h 0m". Leaderboard section with 8 entries.
  "Enter Tournament" button at bottom.
STRUCTURAL: 34 elements. countdown-timer present. enter-tournament-button present.
SPEC CHECK:
  [2] "Shows tournament details (era, dates, duration, cash)" → PASS
  [3] "Countdown timer to tournament end" → FAIL — shows "0d 0h 0m", not updating
  [7] "Live leaderboard with pull-to-refresh" → PARTIAL — list visible, can't verify pull-to-refresh yet
BLOCKERS:
  1. CRITICAL: Countdown shows "0d 0h 0m" — user sees stale/wrong data
ACTION: investigate and fix the countdown blocker

--- Fixing Blocker ---

Read src/components/TournamentCard.tsx
Found: countdown calculates diff from tournament.ends_at but uses wrong timezone offset.

Fix applied: src/components/TournamentCard.tsx:45 — corrected timezone calculation.

sleep 2

SCREEN: Tournament Lobby (post-fix)
OBSERVED: Countdown now shows "3d 14h 22m" — updating correctly
SPEC CHECK:
  [3] "Countdown timer" → PASS (after fix)
BLOCKERS: none
ACTION: proceed to behavior checks

[... continues for remaining criteria ...]

## Final Report

# QA Report: Task 130 — Weekly Tournament Game Flow & UI

## Spec Verification

| # | Criterion | Type | Result | Notes |
|---|-----------|------|--------|-------|
| 1 | Tournament accessible from lobby | UI | PASS | Gold card at top of lobby |
| 2 | Shows tournament details | UI | PASS | All fields present |
| 3 | Countdown timer | UI | PASS* | Fixed timezone bug during QA |
| 4 | Career gate for level < 5 | Behavior | SKIP | Player is level 8 |
| 5 | Enter starts game with fixed params | Behavior | PASS | Correct era, date, cash |
| 6 | Boosts hidden, HUD shown | UI | PASS | HUD present, boost toolbar absent |
| 7 | Live leaderboard with refresh | Behavior | PASS | Pull-to-refresh works |
| 8 | Player entry highlighted | UI | SKIP | No entry submitted |
| 9 | Auto-submit on endGame | Behavior | SKIP | Would need full game completion |
| 10 | Past tournaments shown | UI | PASS | 3 past results visible |
| 11 | Already entered shows rank | UI | SKIP | No prior entry |
| 12 | Offline graceful degradation | Behavior | SKIP | Can't test offline in sim |
| 13 | Types pass tsc | Code | SKIP | Run typecheck separately |

**Result: 7/13 PASS, 0 FAIL, 1 FIXED, 5 SKIP**

## Blockers Fixed

1. **Countdown timezone bug** — Was showing "0d 0h 0m" due to wrong timezone offset.
   Fixed in TournamentCard.tsx:45
```

## Example 2: PR Mode Run

```
/ios-qa --from-pr 188

## Checkout

PR #188: "feat: achievement rewards + NEW badges on unseen unlocks"
Branch: claude/achievement-rewards-and-new-badges
Original branch: main

git fetch origin claude/achievement-rewards-and-new-badges
git checkout -b claude/achievement-rewards-and-new-badges-qa origin/claude/achievement-rewards-and-new-badges
Waiting for bundler... (poll http://localhost:8081/status, marker "packager-status:running")

## Scope

Changed files (from gh pr diff):
  src/components/AchievementCard.tsx
  src/components/profile/BadgeGrid.tsx
  src/stores/gameStore.ts
  src/screens/ProfileScreen.tsx
  src/constants/achievements.ts

Mapped via fileToScreenMap: Profile, Lobby (badge notification dot)
Task number: none found in PR title/branch
Mode: general-targeted (Profile, Lobby)

## QA Scan

SCREEN: Lobby
OBSERVED: Era cards, tournament card, personal bests.
  Red notification dot visible on profile avatar in header.
STRUCTURAL: 24 elements. profile-avatar present with notification-dot overlay.
BLOCKERS: none
ISSUES: none
ACTION: tap profile avatar

SCREEN: Profile
OBSERVED: Player stats section.
  Badge grid showing 12 badges — 3 with "NEW" label overlay in gold.
  Tapping a NEW badge shows achievement detail modal with reward description.
STRUCTURAL: 38 elements. badge-grid present. 12 badge-items. 3 with new-label.
BLOCKERS: none
ISSUES:
  1. Badge grid row 3 third badge shifted ~2px right (Tier 3)
ACTION: scroll

SCREEN: Profile (below fold)
OBSERVED: "Recent Achievements" section with 4 entries.
STRUCTURAL: recent-achievements-section present. 4 achievement-card items.
BLOCKERS: none
ISSUES: none
ACTION: done scanning

## QA Report (posted to PR #188)

<!-- ios-qa-bot -->
## QA Report

**Branch:** `claude/achievement-rewards-and-new-badges`
**Screens tested:** Lobby, Profile
**Mode:** general-targeted

### Results

| Screen | Status | Notes |
|--------|--------|-------|
| Lobby | PASS | Notification dot visible on profile avatar |
| Profile (above fold) | PASS | Badge grid with NEW labels works |
| Profile (below fold) | PASS | Recent achievements section looks clean |

### Blockers

None found.

### Issues (non-blocking)

1. Badge grid row 3 has ~2px misalignment — minor visual nit

### Summary

**Result:** 3/3 screens PASS
**Screens scanned:** 3
**Fixes applied:** 0
**Escalated:** 0

---
*Automated QA by ios-qa*
```

## Example 3: General Mode Run

```
/ios-qa

Phase 0: Prerequisites — OK

Phase 1: Scan (8 screens from smokeScreens + fileToScreenMap)

SCREEN: Lobby
OBSERVED: Era cards in vertical list, 6 eras, "Weekly Tournament" card at top.
STRUCTURAL: 26 elements. All era cards present.
BLOCKERS: none
ISSUES: none
ACTION: proceed

SCREEN: Game Home
OBSERVED: Net worth "$10,000.00", date "January 2, 2020",
  speed controls, skip button.
STRUCTURAL: 20 elements. net-worth-label present.
BLOCKERS: none
ISSUES: none
ACTION: proceed

SCREEN: Market
OBSERVED: Stock list, 15 stocks visible.
STRUCTURAL: 38 elements. stock-card-AAPL present.
BLOCKERS:
  1. HIGH: Third stock card "NovaChem" shows price "$0.00" and change "NaN%"
     — User sees broken data. Unacceptable.
ACTION: investigate NovaChem price issue before continuing

[... fixes blocker, continues scanning ...]

RESULT:
  Screens scanned: 8
  Blockers found: 1
  Blockers fixed: 1
  Issues found: 2
  Issues fixed: 2
  Remaining: 0
```
