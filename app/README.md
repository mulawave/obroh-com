# Obroh Mobile App

A Flutter mobile application placeholder for the Obroh Ancestry Datacenter.

## Design Must Rule: Loading Feedback

Every user-triggered button, link, and tap target must be stateful and show a loading indicator while work is in progress. This is non-negotiable because most users may be on poor networks and need clear visual feedback to avoid repeated taps.

- Disable repeat activation while loading.
- Show a progress indicator/spinner for submit, save, upload, delete, auth, fetch, and navigation actions.
- Preserve accessibility semantics for disabled/loading controls.

## Setup

1. Install [Flutter](https://flutter.dev/docs/get-started/install)
2. Run `flutter create .` in this directory to initialize the project
3. Run `flutter run` to start the app

## Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** Riverpod / Bloc (TBD)
- **Backend:** Connects to the Obroh API at `/api`

## Features (Planned)

- Family tree visualization (interactive, zoomable)
- Member profiles and autobiographies
- Knowledge base browser
- Push notifications for family events
- Offline access to saved records
- Photo galleries and document uploads
- Council of Elders directory
