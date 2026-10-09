# Reign of Grelok — Ruby implementation reference

> Purpose: a precise, agent-oriented description of how `src-ruby/grelok.rb` works, written as the
> spec for the TypeScript rewrite in `src/`. Line numbers refer to `src-ruby/grelok.rb` (702 lines).
> When the Ruby behaviour looks like a bug, it is flagged **[QUIRK]** with a porting recommendation —
> decide per case whether to replicate or fix, but do it deliberately.

## 1. File map

| File | Role |
|---|---|
| `src-ruby/grelok.rb` | Entire engine: classes `Message`, `Thing`, `Location`, `Game`, `Player` + main REPL loop. |
| `src-ruby/game_data.rb` | **Generated.** `class GameData` with constants `CUSTOM_ACTIONS`, `CONSTRAINTS`, `COMMANDS`, `THINGS`, `LOCATIONS`, `MESSAGES` (YAML files dumped as Ruby hash literals). Do not edit by hand. |
| `src-ruby/wrap_yaml_files.rb` | Build script that produced `game_data.rb` from the `*.yml` files (so the game could ship as a single exe without YAML files). |
| `game-data/*.yml` | Source of truth for all content. The TS port should load these (or a JSON/TS conversion of them) instead of `game_data.rb`. |
| `src-ruby/console_log.txt` | Runtime file: command log of the current session (basis for save games). |
| `src-ruby/saved_games/` | Runtime dir: `*.sav` files. |
| `walkthrough.txt` | Shortest winning command sequence — use as an end-to-end test. |
| *(deleted)* `src-ruby/core_extensions.rb` | Defined `Array#to_sentence` and `String#chop_to_lines`. Already ported to `src/utils.ts` as `toSentence()` / `chopToLines()` (with tests). `grelok.rb` still calls them, so it no longer runs as-is. |

Runtime target: the code is Ruby **1.8-era** (it relies on `String#each`, removed in 1.9; and `File.exists?`, removed in 3.2). It will not run on modern Ruby without changes — treat this document, not execution, as the reference.

## 2. Architecture overview

```
main loop (L684-702)
  └─ Player                      ← owns ALL mutable state + all command handlers + parser
       ├─ @game : Game           ← world container, rebuilt on every start()/load
       │     ├─ locations : Hash<alias, Location>
       │     ├─ things    : Hash<alias, Thing>
       │     ├─ custom_actions : Hash<command_alias, string[]>   (script DSL, §6)
       │     └─ console_log : File (command log for saves)
       ├─ @constraints : { 'boolean' => Hash<string,"true"|"false">, 'locations' => Hash<"loc-dir", message> }
       ├─ @current_location / @previous_location : location alias
       ├─ @active_objects / @active_objects_shortcuts : string[] (names w/ spaces)
       └─ @switches : { extended_prompt: bool, load_mode?: true }
  Message (class-level static store over GameData::MESSAGES; mutable!)
```

There is no separation between engine, parser, and I/O: `Player#say` prints directly with `puts`. For the TS port, a natural split is **Parser → CommandDispatcher → World state → Output sink** (an output sink makes load-mode muting and testing trivial).

## 3. Data model

### 3.1 Thing (L25-54)
Attributes: `alias` (id, snake_case), `description`, `location`, `visible`, `pickable`. Constructed from a hash; only whitelisted keys are copied (`allowed_attr_names`).

- `name` = alias with `_` → space (`rusty_sword` → `rusty sword`). `Thing.alias_to_name` is the static equivalent.
- `location` semantics:
  - a location alias (`'plain'`, `'mountain'`, …) → lying in that location
  - `'i'` → in the player's inventory
  - `nil` → not in the world (not yet spawned, or destroyed)
- `visible` defaults to `true` when missing from YAML (L111). `visible: no` is used for hidden items (gemstone, gemstone_shards) revealed by scripts.
- YAML `yes`/`no` parse as booleans.

### 3.2 Location (L58-73) — subclass of Thing
Attributes: `alias`, `name` (explicit, overrides Thing#name), `description`, `directions` (`{ 'n'|'s'|'e'|'w' => location_alias }`). Locations do **not** hold things — a thing's position lives only on `thing.location`.

- `formatted_directions` → `"You can go north and east"` (uses `to_sentence`, `on_empty: 'nowhere'`).
- Inheriting from Thing is incidental; in TS use a separate `Location` type.

### 3.3 Message (L12-22)
Static lookup `find_by_alias(key)` over `messages.yml`; `replace(old, new)` copies the text of `new` under key `old` (used to make NPC dialogue progress).

**[QUIRK]** The store is class-level and shares the `GameData::MESSAGES` hash object, so replacements survive `start()` and `load_game`. Same for `@constraints = GameData::CONSTRAINTS` (L155) — mutated in place, never reset. → **Port:** deep-clone all mutable data on every new game/load.

### 3.4 Game (L76-124)
Builds `locations` and `things` from data, loads `custom_actions`, opens `console_log.txt` for writing (truncates), creates `saved_games/`. `log_command` appends a line unless it is `''`, `exit`, `quit`.

### 3.5 Constraints (`constraints.yml`)
```yaml
locations: { "chapel-e": "Chapel door is blocked by zombie." }   # key = "<location>-<direction letter>", value = message shown when blocked
boolean:                                                          # story flags; values are STRINGS "true"/"false"
  given_quest_holy_water: "false"
  zombie_blocks_chapel_door: "true"
  chapel_door_locked: "true"
  jug_contains_holy_water: "false"
```
**[QUIRK]** Booleans are strings. Comparisons with an explicit value (`verify boolean x false`) work; a bare truthiness check would treat `"false"` as true. → **Port:** either keep string compare or normalise to real booleans at load time *and* in `set constraint-boolean`.

## 4. Main loop (L684-702)

```
player = Player.new            # start(): new Game, location 'plain'
loop until line in [quit, exit]:
  player.look_around()          # prints room only if location changed; rebuilds active objects
  set Readline tab-completion to player.autocompletion_array (prefix grep)
  line = readline(prompt, history=true); drop empty lines from history
  player.process_line(line)
```
- `trap('INT','SIG_IGN')` — Ctrl+C is ignored.
- Prompt (L186): extended → `\n[plain: n, s, e, w] > ` (location name lowercased + direction letters); otherwise `\n> `.
- Note the loop exits on the raw line `quit`/`exit`, *after* `process_line` has already printed "See ya!" via `quit_game`.

### look_around (L195-212)
If `current_location != previous_location`: print blank line, name, description, `formatted_directions`, `things_in_location` (`"There is X, Y and Z"` / `"There is nothing"`), then set `previous_location`. Always recompute:
- `active_objects` = inventory names + names of visible things in current location
- `active_objects_shortcuts` = last word of each multi-word name (`rusty sword` → `sword`), used only for tab completion.

`look` with no argument forces a redescription by setting `previous_location = nil`.

## 5. Command processing pipeline — `process_line` (L532-679)

Steps, in order (this is the heart of the port):

1. **Empty line** → return.
2. **`h` / `help`** → print file `README` line by line until a line `Development notes:` (wrapped with `chop_to_lines`). Not logged. *(The file it expects doesn't exist in the repo any more; README.md is the new equivalent.)*
3. **`extended prompt on|off`** → toggle switch, print confirmation. Not logged.
4. **Tokenise**: `line.split(/\s+/)`.
5. **Resolve verb** via `COMMANDS` (§5.1): first entry (hash order) whose alias list contains token 0 → canonical command; else token 0 is used verbatim (enables data-only verbs like `drink`, `push`, `move`). Remove token 0.
6. **Drop one leading preposition** if next token ∈ `at up to with on` (`look at`, `pick up`, `talk to`).
7. **Parameter grouping**:
   - if command is a two-parameter command (`give use attack ask`): join tokens with `_`, split once on the first of `_to_`, `_on_`, `_with_`, `_about_` (checked in that priority order, not by position) → `[par1, par2]`.
   - otherwise all remaining tokens are one parameter joined by `_` (`rusty sword` → `rusty_sword`).
   - **[QUIRK]** L580 uses `%{ give use attack ask }` — a *string*, so `include?` is a substring test (`"k"`, `"us"`, `"e u"` all match). → **Port:** use a proper `Set`.
8. **`attack`** → rewritten to `use` with params reversed: `attack zombie with rusty sword` ≡ `use rusty_sword on zombie`.
9. **Directions**: canonical `go_north` → command `go`, param `north`.
10. **Unwrap**: a single-element param array becomes a plain string (the code juggles string-vs-array throughout; **port:** always use `string[]`).
11. **Two-token rejoin** (L614): if two params joined by space form an active object name, treat as one.
12. **Partial-name resolution** (L618-640): for each param not exactly an active-object name, match it against the part of each active object *after its first word* (`sword` matches `rusty sword`). One match → replaced by that object's alias. Two or more → print `Which sword do you mean: rusty sword, shining sword or something else?` and **abort** the command (not logged). No match → left unchanged.
    - Note: exact multi-word matches compare `rusty_sword` against `rusty sword`, so they never hit the "exact" branch — harmless, they just fall through unchanged.
    - Suffix rule is "everything after the first word", whereas tab-completion shortcuts use "last word". They differ only for 3+-word names (none exist today).
13. **Build `command_alias`** — the key used for all data lookups:
    - 0/1 param: `"<command>_<par>"` → `look_at_rubble`, `go_north`, `display_inventory_` (trailing `_` when no param)
    - 2 params with a conjunction (`use→on`, `give→to`, `ask→about`): `use_jug_on_basin`, `give_gemstone_to_wizard`, `ask_blacksmith_about_grelok`
    - 2 params otherwise: joined with `_`.
14. **Log** `command_alias` with `_`→space to `console_log.txt` — unless the raw line starts with `save`/`load`. Logged *before* execution, regardless of success.
15. **Dispatch** (first hit wins):
    1. `perform_custom_action(command_alias, …)` — scripted interaction (§6).
    2. `Message.find_by_alias(command_alias)` — pure flavour text (`talk_to_wizard`, `push_zombie`, `ask_blacksmith_about_grelok`).
       **[QUIRK]** No presence check: `talk to wizard` prints the wizard's line from any location. → **Port:** consider requiring the referenced things to be active objects.
    3. `Player` method named `command` (Ruby `respond_to?` + `send`) — built-in handler (§5.2).
    4. otherwise → gibberish message.

### 5.1 Verb table (`commands.yml`)
| canonical | aliases |
|---|---|
| go_north / go_south / go_east / go_west | n, north / s, south / e, east / w, west |
| look_at | l, look, e, examine |
| display_inventory | i, inv, inventory |
| pick_up | p, pick, t, take |
| drop | d, drop |
| save_game | save |
| load_game | load, restore |
| give | g, give |
| use | u, use |
| attack | a, attack, slay |
| talk_to | tt, talk, talk to |
| ask | ask |
| quit_game | quit, exit |

**[QUIRK]** `e` is listed for both `go_east` and `look_at`; first match wins and `go_east` comes first, so `e` always means east (README's "e(xamine)" is wrong). `talk to` as a single alias never matches (tokens are single words); `talk` + dropped preposition `to` covers it.

### 5.2 Built-in handlers (Player methods)
All receive the param (string or array). Output strings are exact and worth keeping in tests.

| Method | Behaviour |
|---|---|
| `look_at(x)` | no x → re-describe room. Else if thing exists, is visible and is here or in inventory → `It's <description>.`; else `You can't see any <name> here.` |
| `pick_up(x)` | visible + pickable + here → location = `'i'`, `You picked up <name>.`; already carried → `You already carry <name>.`; else `You can't pick up <name>.` / `Pick up what?` |
| `drop(x)` | carried → location = current, `You dropped <name>.`; else `You don't carry <name>.` / `Drop what?` |
| `go(dir)` | uses first letter of dir. Allowed if `directions[d]` exists **and** no `constraints.locations["<loc>-<d>"]`. Blocked → constraint message or `You can't go that way.` |
| `talk_to(x)` | fallback only (real dialogue is messages/custom actions): >1 param → gibberish; active object → `You can't chat with that.`; else `Talk to whom? I don't see any <name> around here.` |
| `ask(x, about)` | active object → message `ask_<x>_about_anything` or `You can't chat with that.`; else `Ask whom? …` |
| `give(what, whom)` | checks: what given, carried, whom given, whom active → message `give_anything_to_<whom>` or `That doesn't make sense.` |
| `use(a, b?)` | a carried; b (optional) active → `That doesn't make sense.` (all meaningful uses are custom actions) |
| `display_inventory` | `You carry X and Y` / `You don't have anything.` |
| `quit_game` | `See ya!` (loop then exits) |
| `save_game(name?)` | §7 |
| `load_game(name?)` | §7 |

### 5.3 Output — `say` (L134-140)
- Symbol argument → looked up in messages; string → printed as-is; `sym_only: true` → print only if the symbol resolves (missing keys are silently ignored).
- `:what_a_gibberish` → `gibberish#{rand(1)+1}` — **[QUIRK]** `rand(1)` is always 0, so it is always `gibberish1` (commented as deliberate for debugging). Three variants exist in data.
- Suppressed entirely while `@switches[:load_mode]`.
- Text is word-wrapped with `chop_to_lines(70)`.

## 6. Custom actions — the scripting DSL (L422-529)

`custom_actions.yml` maps a `command_alias` to an ordered list of instruction strings. This is where all puzzle logic lives.

### 6.1 Entry: `perform_custom_action(command_alias, command, pars)`
1. No entry for `command_alias` → return `false` (dispatcher continues to messages/methods).
2. Generic preconditions (print error, **skip script**, still return `true`):
   - `use`/`give`: par1 must be in inventory → `You don't carry <par1>.`; par2 must be a visible thing **in the current location** (inventory doesn't count) → `There's no <par2> nearby.`
   - `look_at`/`talk_to`/`ask`: par1 must be visible in the current location → `There's no <par1> nearby.`
   - other verbs (e.g. `drink`): no checks. **[QUIRK]** `drink from jug` runs without verifying you carry the jug.
   - **[QUIRK]** `things[par1].location` crashes (nil) if par1 isn't a thing alias — unreachable with current data because the alias must already match a custom action.
3. Run instructions in order; stop at the first returning false.
4. If every instruction returned true → print message with key `command_alias` (if one exists).
5. Return `true`.

### 6.2 Instructions (`perform_custom_action_internal`)
Format: `<cmd> <args…>` (space-separated).

| Instruction | Effect | Returns |
|---|---|---|
| `verify location <thing> <loc> [msg]` | `things[thing].location == loc` (`i` = inventory). On failure, say `msg` if given. | result |
| `verify boolean <flag> [value] [msg]` | with value: string equality; without: truthiness. On failure, say `msg`. | result |
| `say <msg_key>` | print message | true |
| `remove <thing>` | location = nil | true |
| `add <thing>` | location = `'i'` | true |
| `visible <thing>` | visible = true | true |
| `set message <key> <new_key>` | `Message.replace` — key now shows new_key's text | true |
| `set description-thing <thing> <msg_key>` | thing.description = message text | true |
| `set description-location <loc> <msg_key>` | location.description = message text | true |
| `set constraint-boolean <flag> <value>` | flag = value (string) | true |
| `set constraint-location <loc-dir> <msg_key\|nil>` | set blocking message, or `nil` → delete (unblock) | true |
| `quiet` | nothing — used as last step to suppress the automatic `command_alias` message (after an explicit `say`) | **false** |
| `exit` | terminates the process immediately (`Kernel#exit`) | — |

Anything else in `set` raises; unknown `verify` type raises; unknown commands are silently ignored.

Idioms used in data:
- **One-shot with follow-up dialogue**: `verify` flag → change state → `say X` → `set message X X_2` → `quiet`. Next time the verify fails and prints `X` — which now holds the `_2` text.
- **Reveal**: `say look_at_rubble` → `verify location gemstone mountain` (stop if already taken) → `visible gemstone` → `say look_at_rubble_hidden` → `quiet`.

**[QUIRK — likely bug]** `use_shining_sword_on_grelok: [exit]` exits before step 4, so the victory text (`messages.use_shining_sword_on_grelok`, ending "THE END") is never printed. → **Port:** print the message, then end the game (and don't hard-exit the process; return a `gameOver` signal).

### 6.3 Current scripts, summarised
| command_alias | Logic |
|---|---|
| `look_at_rubble` | reveals hidden `gemstone` on the mountain (once) |
| `give_gemstone_to_wizard` | gemstone removed; hidden `gemstone_shards` (already in swamp) become visible |
| `give_gemstone_shards_to_blacksmith` | requires `rusty_sword` in inventory (`error_no_rusty_sword`); removes shards + rusty sword, adds `shining_sword` |
| `use_shining_sword_on_grelok` | win → exit |
| `talk_to_priest` | first time: flag `given_quest_holy_water`, add `jug` + `chapel_key`; dialogue advances to `_2` |
| `use_rusty_sword_on_zombie` (also `attack zombie with rusty sword`) | zombie falls in grave; `chapel-e` block message becomes "locked"; updates chapel/zombie/grave descriptions |
| `use_chapel_key_on_chapel_door` | requires zombie gone; unlocks `chapel-e`, key consumed, door description changes |
| `use_jug_on_basin` | fills jug (flag + description), errors if already full |
| `drink_from_jug` | "empty" or "you don't want to drink holy water" |
| `give_jug_to_priest` | requires full jug (else re-says priest's current line); removes jug; priest dialogue → `_3` |

## 7. Save / load — command-log replay (L358-419)

There is **no state serialisation**. A save is a copy of `console_log.txt`: the normalised command aliases (spaces instead of `_`, e.g. `go north`, `look at rubble`, `use jug on basin`) of every command entered since the game started. Loading replays them.

- `save [name]`: no name → first free `saveNNN` (001, 002, …); purely numeric name → `saveNNN`. Writes `saved_games/<name>.sav`. Prints `Game was saved as <name>.sav`.
- `load` (no name): lists `[name]` for each `.sav`, or `No saved games are available.`
- `load <name>` (`.sav` optional): missing → `This saved game doesn't exist.`; else `start()` (fresh game — but see the Message/constraints quirk in §3.3), set `load_mode` (mutes output), `process_line` each line, unset `load_mode`, rewrite `console_log.txt` with the save's contents, print `Loaded save game: <file>`.
- Replay works because normalised aliases re-parse to the same aliases (e.g. `go north` → unknown verb `go` → method `go('north')`), and the game is deterministic.
- Invalid/failed commands are logged and replayed too (harmless, just muted).
- **[QUIRK]** A replayed command that hits the `exit` instruction would terminate the process during load.
- **Port options:** keep replay (simple, deterministic, matches original), or serialise state (things' location/visible/description, location descriptions, constraints, message overrides, current location) as JSON. Replay requires the port to keep `command_alias` normalisation stable.

## 8. World content (for orientation)

```
            mountain  (grelok, rubble, [gemstone hidden])
               |
swamp ——— plain ——— chapel ——e——> chapel_interior (basin)
(wizard,   (standing_stone,  (zombie, open_grave, chapel_door)
 tower,     pebble)          chapel-e blocked: zombie → locked → open
 [shards        |
  hidden])    town (blacksmith, priest)
```
Start: `plain`, inventory `rusty_sword`. Off-world at start: `shining_sword`, `jug`, `chapel_key`.

Main quest (`walkthrough.txt`): north → look at rubble → take gemstone → south, west → give gemstone to wizard → take gemstone shards → east, south → give gemstone shards to blacksmith → north, north → use shining sword on grelok. The priest / zombie / holy-water chain is an optional side quest with no effect on the ending.
