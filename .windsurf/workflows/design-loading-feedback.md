---
description: Non-negotiable loading feedback design rule
---

# Loading Feedback Design Rule

Every user-triggered button and link across `website/`, `admin/`, and `app/` must provide immediate visual feedback.

## Non-negotiable requirements

1. All buttons that submit, mutate, fetch, save, upload, delete, authenticate, or navigate must be stateful.
2. All buttons must show a spinner or clear loading indicator while work is in progress.
3. All links that navigate must show a spinner/loading indicator while navigation is pending.
4. Loading buttons and links must prevent repeat activation while loading.
5. Loading controls must expose accessible state with `disabled`, `aria-disabled`, or `aria-busy` where appropriate.
6. Never add plain clickable `<button>`, `<a>`, or framework link controls for user-triggered actions unless they are wrapped in the shared loading primitives or an equivalent platform-specific implementation.

## Required implementation patterns

- In `website/`, use `LoadingButton`, `LoadingLink`, and `useLoadingAction`.
- In `admin/`, use `LoadingButton`, `LoadingLink`, and `useLoadingAction`.
- In `app/`, implement the Flutter equivalent: disabled loading state plus progress indicator for every interactive button/link/tap target.

## Why this matters

Most Obroh users may be on very poor networks. These visual cues tell users that something is happening, prevent repeated clicks, and reduce confusion during slow requests.
