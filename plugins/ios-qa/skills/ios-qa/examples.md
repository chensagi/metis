# ios-qa Examples

Three worked examples below: **Spec Mode**, **PR Mode**, and **General Mode**.

## Example 1: Spec Mode Run

```
/ios-qa 130

## Loading Spec

Task 130: Feed Screen — Pagination & Pull-to-Refresh
Status: done
Criteria: 13 items

## Verification Plan

Total criteria: 13
  UI-verifiable: 8
  Behavior: 3
  Code-only: 1
  Non-verifiable: 1

## Phase 1: Verify

--- Home Screen ---

SCREEN: Home
OBSERVED: Home with bottom tab bar (Feed, Search, Profile, Settings).
  Feed entry point: highlighted tab icon.
STRUCTURAL: 22 elements. feed-tab present.
SPEC CHECK:
  [1] "Feed accessible from home tabs" → PASS (tab visible, tappable)
BLOCKERS: none
ISSUES: none
ACTION: tap feed tab

--- Feed Screen ---

SCREEN: Feed
OBSERVED: Header "Feed". Sticky filter chip row ("All", "Following", "Trending").
  List with 10 post cards. "Last updated 0m ago" stamp at top.
  Floating compose button bottom-right.
STRUCTURAL: 34 elements. last-updated-stamp present. compose-fab present.
SPEC CHECK:
  [2] "Shows feed metadata (filter, last updated, count)" → PASS
  [3] "Last-updated stamp refreshes on pull" → FAIL — stays "0m ago" after pull
  [7] "Pull-to-refresh re-fetches the page" → PARTIAL — spinner appears, list doesn't update
BLOCKERS:
  1. CRITICAL: Last-updated stamp shows "0m ago" stale — user sees wrong freshness
ACTION: investigate and fix the stamp blocker

--- Fixing Blocker ---

Read src/components/FeedHeader.tsx
Found: stamp formats diff from feed.fetched_at but compares to a stale
       prop instead of Date.now() — refetches don't propagate.

Fix applied: src/components/FeedHeader.tsx:45 — read Date.now() on each render.

sleep 2

SCREEN: Feed (post-fix)
OBSERVED: Stamp now shows "3m ago" — updating correctly after pull-to-refresh
SPEC CHECK:
  [3] "Last-updated stamp" → PASS (after fix)
BLOCKERS: none
ACTION: proceed to behavior checks

[... continues for remaining criteria ...]

## Final Report

# QA Report: Task 130 — Feed Screen Pagination & Pull-to-Refresh

## Spec Verification

| # | Criterion | Type | Result | Notes |
|---|-----------|------|--------|-------|
| 1 | Feed accessible from home tabs | UI | PASS | Tab visible and tappable |
| 2 | Shows feed metadata | UI | PASS | All fields present |
| 3 | Last-updated stamp | UI | PASS* | Fixed stale-prop bug during QA |
| 4 | Empty state for new user | Behavior | SKIP | Test account has history |
| 5 | Compose opens new-post sheet | Behavior | PASS | Sheet animates in correctly |
| 6 | Filter chips toggle visible posts | UI | PASS | All three chips switch the list |
| 7 | Pull-to-refresh re-fetches | Behavior | PASS | List updates after pull |
| 8 | Infinite scroll loads page 2 | UI | PASS | Loader → 10 more cards appended |
| 9 | Optimistic post insertion | Behavior | SKIP | Would need full compose flow |
| 10 | Cached posts shown offline | UI | SKIP | Can't test offline in sim |
| 11 | Reaction tap updates count | UI | PASS | Counter increments + animates |
| 12 | Long-press shows action menu | Behavior | PASS | Menu appears with 4 items |
| 13 | Types pass tsc | Code | SKIP | Run typecheck separately |

**Result: 8/13 PASS, 0 FAIL, 1 FIXED, 4 SKIP**

## Blockers Fixed

1. **Stale last-updated stamp** — Was showing "0m ago" because the formatter
   compared against a prop that never refreshed.
   Fixed in FeedHeader.tsx:45
```

## Example 2: PR Mode Run

```
/ios-qa --from-pr 188

## Checkout

PR #188: "feat: profile cards + NEW badges on unseen activity"
Branch: claude/profile-cards-and-new-badges
Original branch: main

git fetch origin claude/profile-cards-and-new-badges
git checkout -b claude/profile-cards-and-new-badges-qa origin/claude/profile-cards-and-new-badges
Waiting for bundler... (poll http://localhost:8081/status, marker "packager-status:running")

## Scope

Changed files (from gh pr diff):
  src/components/ProfileCard.tsx
  src/components/profile/BadgeGrid.tsx
  src/stores/activityStore.ts
  src/screens/ProfileScreen.tsx
  src/constants/badges.ts

Mapped via fileToScreenMap: Profile, Home (badge notification dot)
Task number: none found in PR title/branch
Mode: general-targeted (Profile, Home)

## QA Scan

SCREEN: Home
OBSERVED: Feed list, filter chips, compose button.
  Red notification dot visible on profile avatar in header.
STRUCTURAL: 24 elements. profile-avatar present with notification-dot overlay.
BLOCKERS: none
ISSUES: none
ACTION: tap profile avatar

SCREEN: Profile
OBSERVED: User header with avatar and stats.
  Badge grid showing 12 badges — 3 with "NEW" label overlay in gold.
  Tapping a NEW badge shows a detail modal with description.
STRUCTURAL: 38 elements. badge-grid present. 12 badge-items. 3 with new-label.
BLOCKERS: none
ISSUES:
  1. Badge grid row 3 third badge shifted ~2px right (Tier 3)
ACTION: scroll

SCREEN: Profile (below fold)
OBSERVED: "Recent Activity" section with 4 entries.
STRUCTURAL: recent-activity-section present. 4 activity-card items.
BLOCKERS: none
ISSUES: none
ACTION: done scanning

## QA Report (posted to PR #188)

<!-- ios-qa-bot -->
## QA Report

**Branch:** `claude/profile-cards-and-new-badges`
**Screens tested:** Home, Profile
**Mode:** general-targeted

### Results

| Screen | Status | Notes |
|--------|--------|-------|
| Home | PASS | Notification dot visible on profile avatar |
| Profile (above fold) | PASS | Badge grid with NEW labels works |
| Profile (below fold) | PASS | Recent activity section looks clean |

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

SCREEN: Home
OBSERVED: Feed with 10 post cards, sticky filter chips, compose FAB.
STRUCTURAL: 26 elements. All cards present.
BLOCKERS: none
ISSUES: none
ACTION: proceed

SCREEN: Search
OBSERVED: Empty search field with "Try 'recipes' or '@username'" hint,
  trending tags row, recent searches list.
STRUCTURAL: 20 elements. search-input present.
BLOCKERS: none
ISSUES: none
ACTION: proceed

SCREEN: Notifications
OBSERVED: Notification list, 15 items visible.
STRUCTURAL: 38 elements. notification-row present.
BLOCKERS:
  1. HIGH: Third notification row shows title "undefined" and body "NaN reactions"
     — User sees broken data. Unacceptable.
ACTION: investigate undefined notification before continuing

[... fixes blocker, continues scanning ...]

RESULT:
  Screens scanned: 8
  Blockers found: 1
  Blockers fixed: 1
  Issues found: 2
  Issues fixed: 2
  Remaining: 0
```
