# VIP app: ideas list

Ideas we may build later. Not committed scope.

## Added to the prototype (13 Nov 2026, built but not yet run)

"My past" covers past events and orders only. Album links and hand-added events from idea 1 are still to do.

| Feature | Where in the app | Source on vipsite.nl | Notes |
|---|---|---|---|
| My past (past events + orders) | Me → My past | `/my-vip/profile/events` (past section), `/my-vip/profile/orders` | First version of idea 1. |
| My committees (groups) | Me → My committees | `/my-vip/profile/groups` | About who you are now, so kept apart from "My past". |
| My invoices | Me → Invoices | `/my-vip/profile/invoices` | Separate: about money you owe, with status. Paying happens on the website. |
| End membership / become alumnus | Me → Membership | `/my-vip/finished-your-studies/*` | The site only says to email vip.gmw@rug.nl, so the app shows that info plus an email button. |
| First-year student guide | More → First year | `/first-year-student/*` (5 public pages) | Public content pages, the same viewer as trust persons. Useful during the introduction period. |

## Feedback from testing on iPhone (13 Nov 2026)

Being built now:
- Share and save-to-Photos buttons in the photo viewer.
- Stalking Guide: tap a member to open their page, including their profile photo.
- Links in page text open directly (no copy and paste).
- A Settings screen that holds the preferences (moved out of Me).
- My events shows only upcoming events; My past shows past events (they were duplicated).
- Events tab: switch between list, calendar and photo gallery.

To keep in mind:
- Event disclaimers (location access, noise, crowds, lights) as tags/buttons, so you can filter events by them.
- Maybe move "Email the board" out of Membership to a more general place.
- Maybe keep Photos as a main tab (it is one now; decide whether it stays).
- "Add to calendar" button on each event (the calendar subscription already covers your own sign-ups).
- Colour themes and dark mode, or follow the phone's setting.
- Dutch version and other languages.

## Ideas

### 1. My past
A personal timeline of what you did at VIP:
- Every event you took part in, plus your orders.
- Each past event links to its photo album.
- Paid events come in automatically from your sign-ups (`/my-vip/profile/events`).
- Free events without a sign-up can be added to your history by hand.
- Photo albums are only shown for events in your history.

Open questions:
- **Linking albums to events:** the website doesn't link them, so the app has to match album and event by date and title. That will sometimes miss or mismatch; allow a manual "this is the album" fix.
- **Where manual additions live:** without a backend they stay on the phone only, and are lost on reinstall. With the Congressus API later, could they become real attendance records?
- **Photo access rule:** every member can already see all albums on the website, so the "only your events" rule is about the app's design, not about privacy.
- **Attendance vs sign-up:** a sign-up doesn't prove you went. Loyalty-point QR check-ins would, if that data ever becomes available.

### 2. Yearbook (later project)
- The yearbooks are downloadable files (2022-23 "VIP Rewind", 2023-24 "The Mythical Tales of VIP"); see `/my-vip/yearbook-2022-2023`.
- Quick version: open the files in an in-app reader.
- Proper version: reformat them for a phone screen (pages, photos, swipe). That depends on how the files were made; ask the Yearbook committee for the source files.

### 3. Committees & groups: what members need
Already on the website (any logged-in member, not only committee members):
- Idea Fund request form (`/association/committees-structures/idea-fund`): text fields, descriptions and a file upload.
- Committee expense claims (`/association/committees-structures/declaration-form-committee-expenses`): instructions plus a link.

Still to find out:
- **What the website shows a committee member.** The account used for testing isn't in any group, so we can't see this yet. Ask someone in a committee to show you, or check again once you've joined one.

Brainstorm for the app:
- Chat with your committee or between groups.
- Shared group calendar and to-dos.
- Submit Idea Fund requests and expense claims from the phone, with a camera photo of the receipt.
- Notifications when a request is approved or paid out.

Constraint: Congressus has no chat. A chat function needs its own backend, which is a board-level decision. WhatsApp groups are what it would compete with.

### 4. Committees, structures & board
- Browse all committees and structures, each with its description (`/association/committees-structures/*`, about 30 public pages).
- "Become active" and committee applications in one place, with application periods surfaced as events or notifications.
- Board: the current board, plus the archive back to 2004-05, and "Joining the VIP Board".

### 5. Remaining nice-to-haves (from Documents onward in the feature inventory)
| Feature | Source | Access |
|---|---|---|
| General Members Meeting documents | `/association/documents/documents-general-members-meeting` | Members |
| Recommendation lists (books, films, podcasts by area of psychology) | `/study-career/recommendation-lists` | Public |
| Tutoring / exam training sign-up (TentamenTrainingen discount) | `/study-career/study/tutoring/sign-up-tutoring` | Members |
| Vacancies (students, graduates, volunteer work) | `/study-career/none-vacancies` | Public |
| Book shop (ACCO discount link) | `/books/vip-book-shop` | Members |
| Anonymous feedback form | `/contact/feedback` | Public |

(Contact details are already in the prototype under More → Contact VIP.)
