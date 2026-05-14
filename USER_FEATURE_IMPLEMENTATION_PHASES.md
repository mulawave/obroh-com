# Obroh Auth Member Platform — Phased Implementation Plan

This document converts the requested authenticated member platform into actionable, trackable phases. It is a planning document only and does not implement any application code.

## Scope

Build the authenticated family-member experience end to end across backend, website, admin, and database layers, including:

- Authenticated user dashboard with global family timeline feed.
- User-managed profile, portfolio, biography, lineage, resume, and legal declaration areas.
- Public portfolio and biography versions controlled by user privacy toggles.
- Internal email-style messaging system.
- Admin approval, moderation, badge, notification, and family-tree workflows.
- Replacement of placeholder backend feature routes with real implementations.

## Non-Scope For This Planning Step

- No code implementation.
- No database schema changes yet.
- No UI files created yet.
- No route handlers created yet.
- No dependency installation.

## Global Delivery Principles

- **Premium UI/UX**: All authenticated pages must keep the Obroh obsidian-and-gold luxury visual system, smooth motion, refined empty states, responsive layouts, and polished loading states.
- **Family-first visibility**: Logged-in approved members can see the shared family feed by default.
- **Privacy toggles**: Public exposure must always be opt-in at the user level.
- **Admin governance**: Sensitive records, children added to lineage, badges, custodial roles, and legal declarations require admin visibility or approval where appropriate.
- **Internal-first communication**: Messaging behaves like email but remains inside the Obroh platform, with optional external email/push alerts only as notifications.
- **Auditability**: Legal declarations, lineage changes, profile privacy changes, and public page exposure should be timestamped and traceable.

## Phase Tracking Summary

| Phase | Name | Status | Primary Apps | Priority |
|---|---|---:|---|---|
| 0 | Product Architecture & Data Model Finalization | Not Started | Backend, Website, Admin | Critical |
| 1 | Authenticated App Shell & Navigation | Not Started | Website | Critical |
| 2 | User Profile System | Not Started | Backend, Website, Admin | Critical |
| 3 | Family Timeline Feed | Not Started | Backend, Website | Critical |
| 4 | Internal Messaging System | Not Started | Backend, Website | Critical |
| 5 | Portfolio Builder & Public Portfolio | Not Started | Backend, Website | Critical |
| 6 | Biography Builder & Public Biography | Not Started | Backend, Website | High |
| 7 | Resume Generation & Export | Not Started | Backend, Website | High |
| 8 | My Lineage & Child Registration Workflow | Not Started | Backend, Website, Admin | Critical |
| 9 | Legal Declaration System | Not Started | Backend, Website, Admin | Critical |
| 10 | Admin Governance, Badges, Moderation & Notifications | Not Started | Backend, Admin, Website | Critical |
| 11 | Placeholder Route Completion | Not Started | Backend, Website, Admin | Critical |
| 12 | Security, Privacy, Uploads & Compliance Hardening | Not Started | Backend, Website, Admin | Critical |
| 13 | QA, Testing, Migration & Production Release | Not Started | All | Critical |

---

# Phase 0 — Product Architecture & Data Model Finalization

## Objective

Define the full domain model, permission model, and API boundaries before implementation begins.

## Tasks

- [ ] Confirm whether production database will be PostgreSQL before feature implementation.
- [ ] Define final Prisma models for all requested features.
- [ ] Define upload storage strategy for images, PDFs, affidavits, gallery items, resumes, and profile marks.
- [ ] Define public slug strategy for portfolio and biography URLs.
- [ ] Define privacy visibility levels:
  - [ ] Private to user only.
  - [ ] Visible to logged-in family members.
  - [ ] Public via share link.
  - [ ] Admin-only.
- [ ] Define notification channels:
  - [ ] In-app notification.
  - [ ] Email alert.
  - [ ] Push notification placeholder/future mobile support.
- [ ] Define moderation rules for posts, comments, public messages, and legal declarations.
- [ ] Define audit log requirements for sensitive actions.

## Proposed Core Data Models

- [ ] `UserProfile`
- [ ] `UserProfileFieldVisibility`
- [ ] `UserBadge`
- [ ] `TimelinePost`
- [ ] `TimelinePostMedia`
- [ ] `TimelinePostLike`
- [ ] `TimelinePostComment`
- [ ] `Portfolio`
- [ ] `PortfolioGalleryImage`
- [ ] `PortfolioProject`
- [ ] `PortfolioProjectImage`
- [ ] `PortfolioSkill`
- [ ] `PortfolioExperience`
- [ ] `PortfolioEducation`
- [ ] `PortfolioProduct`
- [ ] `PortfolioPublicMessage`
- [ ] `Biography`
- [ ] `BiographyMedia`
- [ ] `InternalMessageThread`
- [ ] `InternalMessage`
- [ ] `InternalMessageRecipient`
- [ ] `InternalMessageAttachment`
- [ ] `MessageDraft`
- [ ] `LineageRelationship`
- [ ] `ChildRegistrationRequest`
- [ ] `LegalDeclaration`
- [ ] `LegalDeclarationDocument`
- [ ] `Notification`
- [ ] `AuditLog`

## Acceptance Criteria

- [ ] A final schema design is approved before coding.
- [ ] Entity relationships are clear and mapped to user stories.
- [ ] Public/private visibility rules are unambiguous.
- [ ] Upload and file access rules are defined.

---

# Phase 1 — Authenticated App Shell & Navigation

## Objective

Create the authenticated member area foundation that all feature pages use.

## Tasks

- [ ] Create authenticated layout for logged-in users.
- [ ] Add member sidebar/top navigation.
- [ ] Add responsive mobile navigation.
- [ ] Add protected route guard for approved members.
- [ ] Add premium dashboard shell with obsidian/gold theme.
- [ ] Add shared components:
  - [ ] Member avatar.
  - [ ] Badge display.
  - [ ] User summary card.
  - [ ] Feed card.
  - [ ] Empty state.
  - [ ] Loading skeleton.
  - [ ] Privacy toggle.
  - [ ] Upload dropzone.
  - [ ] Captcha widget reuse.
- [ ] Add routes:
  - [ ] `/dashboard`
  - [ ] `/dashboard/profile`
  - [ ] `/dashboard/portfolio`
  - [ ] `/dashboard/biography`
  - [ ] `/dashboard/lineage`
  - [ ] `/dashboard/legal`
  - [ ] `/dashboard/messages`
  - [ ] `/dashboard/resume`

## Acceptance Criteria

- [ ] Approved members can enter `/dashboard` after login.
- [ ] Non-authenticated users are redirected to login.
- [ ] Pending/rejected users cannot access member pages.
- [ ] Navigation exposes all planned sections.
- [ ] UI is responsive and visually consistent.

---

# Phase 2 — User Profile System

## Objective

Build the robust multi-dimensional user profile where complete member data is recorded, edited, displayed, and selectively exposed publicly.

## Backend Tasks

- [ ] Create profile data model linked to `User`.
- [ ] Add detailed profile fields:
  - [ ] Full legal name.
  - [ ] Preferred name.
  - [ ] Gender.
  - [ ] Date of birth.
  - [ ] Place of birth.
  - [ ] Current location.
  - [ ] Nationality.
  - [ ] State/local government.
  - [ ] Religion.
  - [ ] Marital status.
  - [ ] Height.
  - [ ] Last checked weight.
  - [ ] Skin tone.
  - [ ] Blood group.
  - [ ] Genotype.
  - [ ] Scars with images.
  - [ ] Tattoos with images.
  - [ ] Birthmarks with images.
  - [ ] Waist size.
  - [ ] Trouser length.
  - [ ] Shoe size.
  - [ ] Shirt size.
  - [ ] Drink preference.
  - [ ] Smoking preference.
  - [ ] Best meals.
  - [ ] Languages.
  - [ ] Emergency contacts.
  - [ ] Social links.
  - [ ] Custom user-defined fields.
- [ ] Add profile visibility toggles per field.
- [ ] Add upload endpoints for profile images and identifying mark images.
- [ ] Add profile update API.
- [ ] Add profile fetch API for self.
- [ ] Add profile fetch API for logged-in family members.
- [ ] Add sanitized public profile projection for portfolio/biography.

## Frontend Tasks

- [ ] Create profile overview page.
- [ ] Create editable profile form sections.
- [ ] Create field visibility controls.
- [ ] Create profile image/gallery manager.
- [ ] Create identifying marks manager.
- [ ] Display badges next to name wherever user appears.
- [ ] Add profile completion progress.
- [ ] Add premium summary cards.

## Admin Tasks

- [ ] Allow admin to view complete member profile.
- [ ] Allow admin to assign official badges/positions.
- [ ] Allow admin to review sensitive profile change history.

## Acceptance Criteria

- [ ] User can edit and save detailed profile info.
- [ ] User can add custom fields.
- [ ] User can choose fields shown publicly.
- [ ] Logged-in members can see family-visible fields.
- [ ] Public visitors only see explicitly public fields.
- [ ] User badges appear consistently across dashboard, posts, comments, and messages.

---

# Phase 3 — Family Timeline Feed

## Objective

Create a smooth mini social-media style timeline where all approved logged-in family members can post updates, memories, and comments.

## Backend Tasks

- [ ] Create timeline post model.
- [ ] Add post categories/tags:
  - [ ] Event.
  - [ ] Work.
  - [ ] Household.
  - [ ] Nuclear Family.
  - [ ] Biography.
  - [ ] Fun.
  - [ ] Community.
  - [ ] Legal.
  - [ ] Memory.
  - [ ] Announcement.
- [ ] Add media attachments for posts.
- [ ] Add like endpoint.
- [ ] Add unlike endpoint.
- [ ] Add comment endpoint.
- [ ] Add comment edit/delete rules.
- [ ] Add pagination/infinite feed endpoint.
- [ ] Add feed filtering by category/tag.
- [ ] Add auto-post integration hooks for legal declarations and biography/portfolio milestones.
- [ ] Add moderation flags for admin.

## Frontend Tasks

- [ ] Add timeline feed to dashboard home.
- [ ] Add post composer.
- [ ] Add category/tag picker.
- [ ] Add rich post cards with author avatar and badge.
- [ ] Add likes.
- [ ] Add comments.
- [ ] Add smooth optimistic UI for likes/comments.
- [ ] Add infinite scroll or load-more.
- [ ] Add media preview grid.
- [ ] Add elegant empty state.

## Admin Tasks

- [ ] Add admin feed moderation page or section.
- [ ] Allow admin to hide/remove inappropriate content.
- [ ] Allow admin to pin official announcements.

## Acceptance Criteria

- [ ] All approved logged-in members see the same family feed.
- [ ] Members can create posts with category tags.
- [ ] Members can like and comment.
- [ ] There is no sharing, following, or friend request functionality.
- [ ] Legal declarations can auto-publish to feed.
- [ ] Feed remains performant with pagination.

---

# Phase 4 — Internal Messaging System

## Objective

Build a full internal email-style messaging system for member-to-member private communication and inbound public portfolio messages.

## Backend Tasks

- [ ] Create message thread model.
- [ ] Create message model.
- [ ] Create recipient model supporting multiple recipients.
- [ ] Create message attachment model.
- [ ] Create draft model.
- [ ] Add inbox endpoint.
- [ ] Add sentbox endpoint.
- [ ] Add draft endpoint.
- [ ] Add spambox endpoint.
- [ ] Add read/unread endpoint.
- [ ] Add archive endpoint.
- [ ] Add spam endpoint.
- [ ] Add delete/trash behavior.
- [ ] Add compose/send endpoint.
- [ ] Add save draft endpoint.
- [ ] Add recipient autocomplete endpoint:
  - [ ] Search first name.
  - [ ] Search last name.
  - [ ] Search full name.
  - [ ] Search email.
  - [ ] Return top 10 approved members.
- [ ] Add guest public portfolio message ingestion.
- [ ] Add notification event for new message.
- [ ] Add email alert placeholder/integration point.

## Frontend Tasks

- [ ] Create `/dashboard/messages` layout.
- [ ] Add folders:
  - [ ] Inbox.
  - [ ] Sent.
  - [ ] Drafts.
  - [ ] Spam.
  - [ ] Trash/archive if desired.
- [ ] Create Gmail-like message list.
- [ ] Create message reading pane.
- [ ] Create compose modal/page.
- [ ] Create recipient autocomplete field.
- [ ] Support multiple recipients.
- [ ] Save drafts automatically.
- [ ] Add attachments.
- [ ] Add unread badge counts.
- [ ] Add search and filters.
- [ ] Add guest message indicator for public portfolio messages.

## Acceptance Criteria

- [ ] Members can send private messages to one or more members.
- [ ] Recipient field auto-suggests top 10 matching members.
- [ ] Drafts are preserved.
- [ ] Sentbox, inbox, drafts, and spambox work.
- [ ] Public portfolio contact messages arrive in the user's internal inbox.
- [ ] New messages trigger in-app notifications and optional external alerts.

---

# Phase 5 — Portfolio Builder & Public Portfolio

## Objective

Create a user-managed premium portfolio page with galleries, projects, skills, jobs, products, public sharing, and visitor contact form.

## Backend Tasks

- [ ] Create portfolio model.
- [ ] Add public/private toggle.
- [ ] Add public slug.
- [ ] Add portfolio hero data.
- [ ] Add portfolio gallery model.
- [ ] Add work/product/project gallery model.
- [ ] Add project model with images.
- [ ] Add skills model with years of experience.
- [ ] Add jobs/workplaces/companies model.
- [ ] Add education/certification model.
- [ ] Add services/products model.
- [ ] Add testimonials or achievements model if approved.
- [ ] Add public portfolio fetch endpoint by slug.
- [ ] Add private portfolio CRUD endpoints.
- [ ] Add public contact form endpoint with internal captcha validation.
- [ ] Route public messages to internal messaging inbox.
- [ ] Add link to public biography when biography public toggle is enabled.

## Frontend Tasks

- [ ] Create portfolio dashboard page.
- [ ] Create portfolio editor.
- [ ] Create picture gallery with autoslide toggle.
- [ ] Create work/product gallery manager.
- [ ] Create project upload and image manager.
- [ ] Create skills editor.
- [ ] Create job/workplace/company editor.
- [ ] Create public toggle.
- [ ] Create public share link display/copy action.
- [ ] Create public portfolio route.
- [ ] Create public contact form gated by internal captcha.
- [ ] Display public biography link only when biography is public.

## Acceptance Criteria

- [ ] User can manage portfolio content.
- [ ] User can upload and organize images.
- [ ] Portfolio can be made public or private.
- [ ] Public link renders the same portfolio data in a public-safe view.
- [ ] Visitors can submit contact messages only after captcha verification.
- [ ] Visitor messages appear in the user's internal inbox.

---

# Phase 6 — Biography Builder & Public Biography

## Objective

Create a user-managed biography page with text, images, privacy toggle, and public sharing.

## Backend Tasks

- [ ] Create biography model linked to user.
- [ ] Add sections:
  - [ ] Early life.
  - [ ] Family background.
  - [ ] Education.
  - [ ] Career.
  - [ ] Achievements.
  - [ ] Faith/values.
  - [ ] Memories.
  - [ ] Legacy statement.
  - [ ] Custom sections.
- [ ] Add biography media uploads.
- [ ] Add public/private toggle.
- [ ] Add public slug.
- [ ] Add public biography fetch endpoint.
- [ ] Add private biography CRUD endpoint.
- [ ] Add optional feed publication when biography is updated.
- [ ] Add link to public portfolio when portfolio is public.

## Frontend Tasks

- [ ] Create biography dashboard editor.
- [ ] Create rich biography preview.
- [ ] Create image manager.
- [ ] Create section reorder controls.
- [ ] Create public toggle.
- [ ] Create public share link display/copy action.
- [ ] Create public biography route.
- [ ] Display public portfolio link only when portfolio is public.

## Acceptance Criteria

- [ ] User can create and edit biography sections.
- [ ] User can upload biography images.
- [ ] Public biography is only visible when enabled.
- [ ] Public biography links back to public portfolio only when portfolio is public.
- [ ] Public portfolio links to public biography only when biography is public.

---

# Phase 7 — Resume Generation & Export

## Objective

Generate a modern obsidian-and-gold resume using user profile and portfolio data, downloadable as HTML or PDF.

## Backend Tasks

- [ ] Define resume data projection from profile and portfolio.
- [ ] Add resume settings model if customization is needed.
- [ ] Add resume HTML generation endpoint.
- [ ] Add PDF generation strategy.
- [ ] Add download endpoints for HTML and PDF.
- [ ] Add default avatar fallback.

## Frontend Tasks

- [ ] Add resume preview page.
- [ ] Add section inclusion controls.
- [ ] Add resume theme preview using Obroh obsidian/gold.
- [ ] Add download as HTML.
- [ ] Add download as PDF.
- [ ] Add regenerate resume action.

## Acceptance Criteria

- [ ] Resume pulls from user profile and portfolio data.
- [ ] Resume uses default avatar when no image exists.
- [ ] User can download HTML version.
- [ ] User can download PDF version.
- [ ] Resume visual design matches the premium Obroh theme.

---

# Phase 8 — My Lineage & Child Registration Workflow

## Objective

Allow users to view their family branch down to the root and add children into an admin-approved lineage workflow.

## Backend Tasks

- [ ] Replace placeholder family-tree route with real lineage endpoints.
- [ ] Create relationship model for parent/child/spouse/branch links.
- [ ] Create lineage fetch endpoint for current user.
- [ ] Create branch-to-root endpoint.
- [ ] Create child registration request model.
- [ ] Add child creation request endpoint.
- [ ] Add admin approval endpoint.
- [ ] On approval, add child to appropriate branch/family tree location.
- [ ] Add lineage update audit log.
- [ ] Add notifications to admin on child registration.

## Frontend Tasks

- [ ] Create `/dashboard/lineage` page.
- [ ] Show branch tree from user to root.
- [ ] Show descendants/children section.
- [ ] Add child registration form.
- [ ] Show approval status for submitted children.
- [ ] Add elegant tree visualization.

## Admin Tasks

- [ ] Add child registration review page/section.
- [ ] Approve/reject child additions.
- [ ] Correct branch placement before approval.
- [ ] Notify user of approval/rejection.

## Acceptance Criteria

- [ ] User can view lineage branch down to root.
- [ ] User can submit child records.
- [ ] Submitted children do not alter official tree until approved.
- [ ] Admin can approve and place child records.
- [ ] Approved children appear in lineage/family tree.

---

# Phase 9 — Legal Declaration System

## Objective

Create a legal declaration area where users publish important legal updates, upload supporting documents, notify admin, and update the community feed.

## Backend Tasks

- [ ] Create legal declaration model.
- [ ] Add declaration types:
  - [ ] Change of name.
  - [ ] Court affidavit.
  - [ ] Marital/legal status update.
  - [ ] Custodial/legal family update.
  - [ ] Other legal issue.
- [ ] Add document upload model.
- [ ] Accept PDF and PNG formats.
- [ ] Add legal declaration CRUD endpoint.
- [ ] Add publish endpoint.
- [ ] On publish, create timeline feed post.
- [ ] On publish, notify admin.
- [ ] Add admin review/status fields.
- [ ] Add audit log for every legal declaration action.

## Frontend Tasks

- [ ] Create `/dashboard/legal` page.
- [ ] Create legal declaration form.
- [ ] Add document upload control.
- [ ] Add declaration status timeline.
- [ ] Add published declarations list.
- [ ] Add feed preview before publishing.

## Admin Tasks

- [ ] Add legal declarations admin review page/section.
- [ ] Allow admin to mark reviewed/resolved/needs attention.
- [ ] Allow admin notes.
- [ ] Notify declaring user of admin action.

## Acceptance Criteria

- [ ] User can submit legal declaration with documents.
- [ ] Supported documents include PDF and PNG.
- [ ] Published declarations appear in the global family feed.
- [ ] Admin receives notification.
- [ ] Declaration actions are auditable.

---

# Phase 10 — Admin Governance, Badges, Moderation & Notifications

## Objective

Extend the admin panel to govern member-facing features safely.

## Backend Tasks

- [ ] Create badge/position model.
- [ ] Add badge assignment endpoint.
- [ ] Add notification model.
- [ ] Add notification read/unread endpoints.
- [ ] Add moderation endpoints for posts/comments/public messages.
- [ ] Add admin dashboard counts for:
  - [ ] Pending child registrations.
  - [ ] Legal declarations.
  - [ ] Public portfolio messages.
  - [ ] Flagged posts/comments.
  - [ ] New member activity.
- [ ] Add audit logs for admin actions.

## Admin Tasks

- [ ] Add member badge assignment UI.
- [ ] Add feed moderation UI.
- [ ] Add legal declaration review UI.
- [ ] Add child registration approval UI.
- [ ] Add message/contact oversight where appropriate.
- [ ] Add notification management indicators.

## Website Tasks

- [ ] Display notifications in member dashboard.
- [ ] Display user badges anywhere user appears:
  - [ ] Profile names.
  - [ ] Feed posts.
  - [ ] Comments.
  - [ ] Messaging sender/recipient labels.
  - [ ] Portfolio/biography author section where appropriate.

## Acceptance Criteria

- [ ] Admin can assign official user badges/positions.
- [ ] Badges appear consistently across authenticated pages.
- [ ] Admin can review sensitive workflows.
- [ ] Users receive notifications for relevant actions.

---

# Phase 11 — Placeholder Route Completion

## Objective

Replace all current placeholder backend implementations with real feature endpoints or deliberately remove unused placeholders.

## Existing Placeholder Areas To Resolve

- [ ] `/api/family-tree`
- [ ] `/api/knowledge-base`
- [ ] `/api/legacy`

## Tasks

- [ ] Map `/api/family-tree` to lineage and approved family tree data.
- [ ] Decide if `/api/knowledge-base` remains separate from member dashboard features.
- [ ] If retained, define knowledge-base models and routes.
- [ ] Decide if `/api/legacy` maps to biography/legal declarations/ancestry records or remains a separate module.
- [ ] If retained, define legacy models and routes.
- [ ] Update frontend pages to use real endpoints.
- [ ] Remove or hide any UI links to unfinished routes until implemented.
- [ ] Add integration tests for all formerly placeholder routes.

## Acceptance Criteria

- [ ] No production route returns placeholder `501` unless intentionally documented and hidden.
- [ ] Family tree route returns real lineage/tree data.
- [ ] Knowledge-base and legacy routes are either implemented or removed from production navigation.

---

# Phase 12 — Security, Privacy, Uploads & Compliance Hardening

## Objective

Secure the expanded platform before production release.

## Tasks

- [ ] Add schema validation for every new endpoint.
- [ ] Add authorization checks for every private resource.
- [ ] Add ownership checks for profile, portfolio, biography, resume, messages, and legal declarations.
- [ ] Add file validation:
  - [ ] MIME type.
  - [ ] File extension.
  - [ ] File size.
  - [ ] Image dimensions where needed.
- [ ] Add malware scanning strategy if using external storage.
- [ ] Add signed/private file URL strategy for sensitive documents.
- [ ] Add rate limiting for:
  - [ ] Timeline posting.
  - [ ] Comments.
  - [ ] Messages.
  - [ ] Public portfolio contact form.
  - [ ] Uploads.
- [ ] Add spam detection for guest public messages.
- [ ] Add audit logs for sensitive actions.
- [ ] Ensure public pages expose only allowed fields.
- [ ] Ensure legal documents are never public unless explicitly designed and approved.
- [ ] Review localStorage token security and consider HTTP-only cookie migration.

## Acceptance Criteria

- [ ] Users cannot access or mutate other users' private resources.
- [ ] Public portfolio/biography data respects privacy toggles.
- [ ] Uploads are constrained and safe.
- [ ] Sensitive legal files are protected.
- [ ] Public contact forms are captcha-gated and rate-limited.

---

# Phase 13 — QA, Testing, Migration & Production Release

## Objective

Validate the entire authenticated member platform end to end and prepare it for production deployment.

## Backend Testing Tasks

- [ ] Add route tests for profile APIs.
- [ ] Add route tests for timeline APIs.
- [ ] Add route tests for messaging APIs.
- [ ] Add route tests for portfolio APIs.
- [ ] Add route tests for biography APIs.
- [ ] Add route tests for lineage APIs.
- [ ] Add route tests for legal declaration APIs.
- [ ] Add route tests for public portfolio/biography access rules.
- [ ] Add route tests for admin approvals and moderation.

## Frontend Testing Tasks

- [ ] Test dashboard auth gating.
- [ ] Test profile editing.
- [ ] Test feed posting/commenting/liking.
- [ ] Test message compose/draft/send/inbox flows.
- [ ] Test portfolio management.
- [ ] Test public portfolio contact form.
- [ ] Test biography management and public sharing.
- [ ] Test lineage child registration.
- [ ] Test legal declaration publishing.
- [ ] Test responsive layouts.

## Production Readiness Tasks

- [ ] Migrate from SQLite to PostgreSQL for production.
- [ ] Update `.env.example`.
- [ ] Add production environment variable documentation.
- [ ] Add deployment scripts or CI workflow.
- [ ] Add database migration workflow.
- [ ] Add backup/restore procedure for user data and files.
- [ ] Add seed strategy that does not expose default admin credentials.
- [ ] Run backend build.
- [ ] Run website lint/build.
- [ ] Run admin lint/build.
- [ ] Run integration test suite.

## Acceptance Criteria

- [ ] All feature flows pass manual QA.
- [ ] Automated tests cover critical behavior.
- [ ] No placeholder feature route remains exposed in production.
- [ ] Production database and file storage are ready.
- [ ] The platform is ready for staging deployment and user acceptance testing.

---

# Recommended Implementation Order

1. **Phase 0**: Finalize architecture and schema.
2. **Phase 1**: Build authenticated member shell.
3. **Phase 2**: Build profile system because all other features depend on user data.
4. **Phase 3**: Build timeline feed.
5. **Phase 4**: Build messaging system.
6. **Phase 5**: Build portfolio and public portfolio.
7. **Phase 6**: Build biography and public biography.
8. **Phase 7**: Build resume generation.
9. **Phase 8**: Build lineage and child approval workflow.
10. **Phase 9**: Build legal declarations.
11. **Phase 10**: Build admin governance, badges, moderation, and notifications.
12. **Phase 11**: Complete or remove placeholder routes.
13. **Phase 12**: Harden security and privacy.
14. **Phase 13**: QA, migration, and production release.

# Cross-Feature Dependencies

- **Profile system** is required before portfolio, biography, resume, badges, and public pages.
- **Messaging system** is required before public portfolio contact messages can be delivered internally.
- **Notification system** is required for messages, legal declarations, admin approvals, and child registration updates.
- **Upload system** is required for profile marks, portfolio galleries, biography media, resume avatar, project images, and legal documents.
- **Admin governance** is required for badges, lineage approval, legal review, and content moderation.
- **Public privacy engine** is required before public portfolio and biography can be safely launched.

# Open Product Decisions

- [ ] Should all timeline posts be editable after publication?
- [ ] Should comments be editable/deletable by authors only, or also moderated by admins?
- [ ] Should public portfolio messages allow attachments?
- [ ] Should public biography include a visitor contact form or only portfolio?
- [ ] Should legal declarations be visible to all members immediately or after admin review?
- [ ] Should child records create full user accounts immediately or pending child profile records first?
- [ ] Should minors have restricted visibility defaults?
- [ ] Should public portfolio and biography slugs use username, generated IDs, or custom slugs?
- [ ] Should resume PDF generation happen server-side or client-side?
- [ ] Should messages support threaded replies or email-like separate messages?

# Definition Of Done For Entire Epic

- [ ] Authenticated users have a complete dashboard experience.
- [ ] Dashboard includes global family timeline feed.
- [ ] Users can manage detailed profiles with privacy controls.
- [ ] Users can manage portfolios and publish public portfolio links.
- [ ] Users can receive public portfolio visitor messages internally.
- [ ] Users can send and receive internal email-style messages.
- [ ] Users can manage biographies and publish public biography links.
- [ ] Users can generate and download resumes.
- [ ] Users can view lineage and submit children for admin approval.
- [ ] Users can publish legal declarations with documents.
- [ ] Admin can govern badges, approvals, moderation, and legal updates.
- [ ] All placeholder routes are completed or intentionally removed.
- [ ] Security, privacy, uploads, and authorization are production-hardened.
- [ ] All builds, lint checks, and critical tests pass.
