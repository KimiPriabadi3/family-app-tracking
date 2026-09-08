---
version: 1
slug: "lib-screens-home-screen-dart"
primary_target: "lib/screens/home_screen.dart"
related_targets: ["lib/screens/status_screen.dart","lib/screens/calendar_screen.dart","lib/screens/announcement_screen.dart","lib/screens/tasks_screen.dart","lib/screens/errand_list_screen.dart","lib/screens/job_list_screen.dart","lib/screens/map_screen.dart","lib/screens/admin_screen.dart","lib/screens/profile_select_screen.dart"]
---

Scope: the whole Android app shell and its five destinations. Visitor mode: Operate.

Audience: Bunda, Mas, Adek on their own phones, all day. Task: read the household's
current record without asking anyone, and update your own row in two taps.
Constraint: no auth, no push, map ships keyless and stays.

## Direction contract

THESIS: The household as an official register — every member a numbered row, every
fact a stamped field. Refuses the pastel card-and-avatar family organizer.

OWN-WORLD: Guilloche safety-tint ground. Registry green #0E5C4A owns whole fields;
stamp red #D62828 marks cancelled and overdue; garuda gold #E8B004 marks whose turn
it is. Hairline ruled tables, flat planes, hard edges — no rounded cards, gradients,
or soft shadows. Each member owns one ink. Tracked uppercase field labels over a
workhorse sans; casual Indonesian in the values.

STORY: Opens, reads the record, learns where everyone is and whose turn it is,
stamps their own row, closes. Never composes a message.

FIRST VIEWPORT: A ruled register header (NO. / NAMA / KEADAAN / PUKUL) over three
numbered member rows banded in their own inks, each status a stamped field carrying
its time and visibly ageing toward stale. Today's entries run beneath as register
lines. One stamped primary action, bottom right.

FORM: Kartu Keluarga, candidate 7 of 7 grounded, seed key 2c719192.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Raises

- Color is data, never decoration (from Peta Orienteering).
- Flat planes, hard edges, zero gradients (from Pelat Presisionis).
- Every zone names itself in words, never icon-only (from Streetwear Industri).
- Freshness is visible; standing state ages toward stale (from Tambang Awan).
- States unmistakable at a glance, never a tint apart (from Desktop Satu-Bit).

## Unresolved

Maps API key absent — Peta renders its register and an empty map field until a key
lands. Push notifications not built.
