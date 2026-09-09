# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Three members of one household, each on their own Android phone:

- **Bunda** — the mother.
- **Mas** — the eldest child; also the developer and the app's only admin.
- **Adek** — the younger sibling.

All three are comfortable with everyday Android apps, so no member needs
enlarged type or a simplified variant. There is no fourth user and no plan to
distribute beyond the family.

They open the app across the whole day rather than at one dominant moment:
in the morning before leaving (today's schedule, whose turn the chores are),
midday while apart (where everyone is, adding a shopping request), and in the
evening together (filling in tomorrow, setting next week's rotation, posting a
notice). No single scenario outranks the others.

## Product Purpose

Remove the need to ask. Routine household questions — "where are you?",
"what time are you home?", "is the electricity token out?", "whose turn is it
to mop?", "can you buy milk on the way?" — currently each cost a WhatsApp
message and a wait for a reply. This app makes those answers already visible,
so WhatsApp is left for conversations that genuinely need two people talking.

Success is measured by absence: fewer check-in messages in the family chat.

## Positioning

Deliberately not a chat app. WhatsApp already wins at conversation and is not
being replaced. What it is bad at is standing information — a status that is
simply true right now, a chore rotation, a shared list — which sinks under new
messages and has to be re-asked. This app holds only that standing state, for
one specific household of three known people.

That premise is also why it has no accounts: with three trusted members on
three known phones, identity is a choice on first launch, not a login.

## Operating Context

- Each phone picks its member once on first launch; the choice is remembered
  locally. There is no password, no account, and no way to be logged out.
- Chores rotate weekly. Assignments are set per week rather than repeating
  automatically, so the rotation can bend around a busy week.
- Location is shared only by members who switch it on, and only while the app
  is open — there is no background tracking.
- The app is installed by downloading an APK from its GitHub releases page,
  not from the Play Store.

## Capabilities and Constraints

Confirmed capabilities: shared calendar of per-member commitments; presence
status (home / campus / office / asleep) with an optional short note; an
announcement board; a weekly chore rotation; a shared shopping list; a map of
members currently sharing location; an admin who can cancel others' calendar
entries and edit the chore list and rotation.

Constraints:

- Flutter on Android only. Cloud Firestore for storage, with no
  authentication — security rules can check the shape of a write, never who
  made it.
- Because there is no auth, permissions such as "only the author may delete"
  are honest UI affordances among trusted family, not enforced boundaries.
- Free Firebase (Spark) plan. Push notifications are not built yet; everything
  updates live in-app instead.
- The map uses OpenStreetMap tiles rather than Google Maps, a decision made to
  avoid attaching a payment card: Google requires a billing account even inside
  its free tier, and the published APK would then carry a key worth stealing.
  OSM's tile policy covers this volume, and its attribution is displayed on the
  map as that policy requires.

Undecided: whether push notifications are ever added.

## Brand Commitments

The name is **Family App Tracking**. Interface language is Indonesian, in the
casual register a family actually uses with each other — not the formal
Indonesian of institutional software.

Members are labelled **Bunda**, **Mas**, and **Adek**. These are family terms
of address, not usernames, and "Mas" is deliberately used instead of "Aku" so
the label reads correctly on someone else's phone.

## Evidence on Hand

The app is real and in use by exactly three people; there are no customers,
testimonials, metrics, or press, and none may be invented. The repository is
public at github.com/KimiPriabadi3/family-app-tracking as a portfolio piece,
so the code is read by strangers even though the app is not used by them.

## Product Principles

1. **Answer before it is asked.** Anything a member would otherwise message
   about should already be on screen. A feature that requires a follow-up
   question has failed.
2. **Standing state, not conversation.** Hold what is currently true. Resist
   every pull toward threads, replies, and chat.
3. **Writing must cost almost nothing.** Information only stays accurate if
   updating it is trivial, so entry is always short, optional, and a couple of
   taps at most.
4. **Trust is the security model.** Three known people on three known phones.
   Design for clarity and honest labelling, never for defending against a
   hostile user.
5. **It belongs to this family.** Warmth and familiarity beat neutrality; this
   is a home tool, not enterprise software.

## Accessibility & Inclusion

No member-specific requirement was established — all three read standard
Android type comfortably. Ordinary platform accessibility still applies:
adequate contrast, touch targets, and support for the system font scale.
