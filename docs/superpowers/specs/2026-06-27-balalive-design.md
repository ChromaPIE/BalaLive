# BalaLive Design

## Goal

BalaLive is a Steamodded Balatro mod that exposes a local OBS browser-source overlay. The overlay shows the current run's joker inventory, consumable inventory, and poker hand levels using the game's active localization.

## Scope

- Create a standalone Steamodded mod in `BalaLive`.
- Author metadata is `ChromaPIE`.
- Serve a pure frontend over `localhost` with a configurable default port.
- Show three rotating panels: jokers, consumables, and poker hand levels.
- Merge duplicate card names as `Name X2`, `Name X3`, etc.
- Reflect joker rarity by color, with two configurable styles: text color or rounded background.
- Allow OBS custom CSS to override the simple default presentation.

## Architecture

The mod runs a small nonblocking LuaSocket HTTP server inside `main.lua`. It serves static frontend assets and an event stream endpoint:

- `/` returns the HTML overlay.
- `/style.css` returns default CSS.
- `/app.js` returns frontend behavior.
- `/events` returns an SSE stream (`EventSource`) for state updates.
- `/state.json` returns the current snapshot for debugging and reconnect fallback.

The browser does not poll. The mod keeps a compact snapshot signature of all three data sets and only broadcasts an SSE update when that signature changes. This still catches updates in panels that are not currently visible in the rotation, because the signature is computed over jokers, consumables, and poker hand levels together.

## Data Sources

Jokers:

- Read from `G.jokers.cards` when `G.jokers` is available.
- Use `card.config.center.key` and `card.config.center.set` for identity and localization.
- Use `localize{type = 'name_text', set = center.set, key = center.key}` for the displayed name.
- Use `center.rarity` to derive rarity.
- Map vanilla numeric rarity through `G.C.RARITY[rarity]`.
- Map Steamodded custom rarity through `G.C.RARITY[rarity_key]`, which is populated from rarity badge colors.

Consumables:

- Read from `G.consumeables.cards` when `G.consumeables` is available.
- Use the same localized name flow as jokers.
- Consumable duplicates are merged by localized name and center key.

Poker hand levels:

- Read from `G.GAME.hands`.
- Show entries that match the run info view: visible hands from the current run state.
- Use `localize(hand_key, 'poker_hands')`.
- Display the current level as `Lv.N`.

## Performance

The server is nonblocking:

- All sockets use timeout `0`.
- The accept loop has a small per-frame budget.
- Open SSE clients are tracked and written to only when a state signature changes or a heartbeat is due.
- Full JSON serialization happens only after a signature change.
- The signature is built from stable lightweight fields: center keys, localized names, rarity keys, counts, and hand levels.

This avoids browser polling and avoids repeatedly serializing unchanged state. It also avoids hooking every possible inventory mutation path, which would be more invasive and less reliable across vanilla and Steamodded mods.

## Frontend Behavior

The frontend keeps the latest full state for all panels. Rotation timing is driven by the config values sent in each state update:

- `joker_seconds`
- `consumable_seconds`
- `hand_seconds`

Panel transitions use opacity and transform changes for fade/slide behavior. Within a visible panel, item changes are diffed by stable item keys:

- Removed items get a smooth exit animation before DOM removal.
- Added items get an enter animation.
- Changed counts or levels update in place with a brief pulse.

If a non-visible panel changes, the frontend stores the new data immediately. When that panel rotates into view, it enters with the newest content and item-level enter animations.

## OBS Styling

The default page is transparent and compact. CSS custom properties and simple class names make OBS custom CSS practical:

- `.balalive`
- `.balalive-panel`
- `.balalive-title`
- `.balalive-list`
- `.balalive-item`
- `.balalive-count`
- `.rarity-common`, `.rarity-uncommon`, `.rarity-rare`, `.rarity-legendary`

The default design is quiet and overlay-friendly: no large cards, no decorative background, no marketing layout.

## Config

`config.lua` returns defaults:

- `port`: default local port.
- `joker_seconds`: joker panel dwell time.
- `consumable_seconds`: consumable panel dwell time.
- `hand_seconds`: poker hand panel dwell time.
- `joker_rarity_style`: `text` or `background`.

`SMODS.current_mod.config_tab` exposes these through Steamodded UI. Config is stored with Steamodded's standard mod config system. Port changes apply after reload/restart because the listening socket is bound at startup.

## Nil Guard Strategy

Guards are placed at game boundary reads and socket operations:

- Treat missing `G`, `G.jokers`, `G.consumeables`, or `G.GAME.hands` as empty state.
- Skip malformed card entries that lack `config.center`.
- Use key/name fallback only for the specific missing localization or rarity field.
- Wrap socket accept/read/write/close paths so a stale OBS connection cannot crash the game.

The implementation should not wrap every local helper in broad `pcall`. Expected game-state absence is handled explicitly; unexpected programming errors should remain visible during development.

## Testing

Unit-level Lua tests cover:

- Duplicate merge behavior.
- Joker rarity color/style serialization.
- Poker hand visibility and level extraction.
- Snapshot signature changes for hidden panel data.
- Minimal HTTP route responses and SSE event formatting where practical.

Manual verification covers:

- OBS/browser opens `http://localhost:<port>/`.
- Overlay updates only when inventory or hand levels change.
- Visible item add/remove/count changes animate smoothly.
- Hidden panel changes appear on the next rotation.
- Config values persist through Steamodded config storage.
