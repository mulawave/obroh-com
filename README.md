# Obroh — Ancestry Datacenter

The official Obroh Chronicles heritage platform. A premium digital archive for managing the Obroh family tree, ancestral records, knowledge base, and individual autobiographies.

## Project Structure

```
obroh.com/
├── website/    → Public-facing Next.js website (port 3000)
├── admin/      → Admin panel - Next.js dashboard (port 3001)
├── backend/    → Node.js/Express API server (port 5000)
└── app/        → Flutter mobile application
```

## Quick Start

### Website (Public)
```bash
cd website
npm install
npm run dev        # → http://localhost:3000
```

### Admin Panel
```bash
cd admin
npm install
npm run dev        # → http://localhost:3001
```

### Backend API
```bash
cd backend
cp .env.example .env    # Configure environment variables
npm install
npm run dev             # → http://localhost:5000
```

### Mobile App
```bash
cd app
flutter create --platforms=android .   # Android-only; do not generate ios/
flutter run
```

## Production Deployment Standard (Locked)

Only one deployment entrypoint is approved for this repository:

```bash
npm run deploy:prod
```

This command runs `scripts/deploy/deploy.ps1`, which is now the single source of truth pipeline.

- Direct execution of service scripts under `scripts/deploy/services/` is blocked.
- The deploy pipeline is integrity-checked against `scripts/deploy/pipeline-manifest.json` before any deployment can run.
- Any pipeline file drift is rejected unless explicit owner approval is provided via `OBROH_DEPLOY_PIPELINE_CHANGE_APPROVED=true`.

## Tech Stack

| Layer      | Technology                                |
|------------|-------------------------------------------|
| Website    | Next.js 16, TailwindCSS v4, Framer Motion |
| Admin      | Next.js 16, TailwindCSS v4, Lucide Icons  |
| Backend    | Node.js, Express, MongoDB, JWT             |
| Mobile     | Flutter (Dart), Android only               |

## Theme

Obsidian + Gold gradient — a premium, sophisticated dark theme with gold accents.

## Design Must Rule: Loading Feedback

All user-triggered buttons and links across the website, admin panel, and mobile app must be stateful and show loading feedback.

- **Buttons**: must disable repeat activation and show a spinner while submitting, saving, uploading, deleting, authenticating, fetching, or navigating.
- **Links**: must show a spinner or equivalent loading indicator while navigation is pending.
- **Poor-network support**: this is non-negotiable because most users may be on unreliable connections and need clear visual cues that the system is working.
- **Implementation**: use the shared `LoadingButton`, `LoadingLink`, and `useLoadingAction` patterns in web apps; implement equivalent disabled loading states and progress indicators in Flutter.

## Contact

- **Email:** info@obroh.com
- **Location:** Obroh Ancestral Home, Delta State, Nigeria
