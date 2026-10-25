---
name: matcha-luavm
description: Read this skill first for ANY Matcha / Roblox executor script request. Reference AND delivery rules for the Matcha LuaVM Roblox executor. Scripts are delivered by pushing to the user's GitHub repo and replying with a one-line loadstring loader, not by pasting code in chat. Includes MCP server integration, all native globals, memory tools, drawing API, UI binding, Roblox classes, datatypes, full Lua 5.1 base library, and VM limitations.
---


# STOP: SEVEN RULES BEFORE YOU WRITE ANYTHING

1. **Scripts go to the user's GitHub repo (`bobashid/roblox-matcha`), never into the chat.** Do not output a Lua script of more than 40 lines in your reply unless the user used an override word (`inline`, `paste it here`, `give me the code`, `just the script`, `no github`, `in chat`). Your reply is the loader line and nothing else (see section 2). The user has asked for this repeatedly; pasting code in chat is the main failure of this skill.
2. **If you cannot push, do not fall back to pasting.** Check your tool list for GitHub tools (`create_or_update_file`, `push_files`, `get_file_contents`). If none exist, reply only: "GitHub tools aren't enabled in this chat. Enable the GitHub connector, or say 'inline' and I'll paste the script here." Then stop. Do not write the script until they choose.
3. **A tool result you did not see is a failure.** Never claim a push, SHA, size or "verified" without it in a tool result this turn. Lint every file before pushing (see FAILURE PROTOCOLS). If the user reports a freeze or crash, stop adding features and follow F3.
4. **Read the user's existing scripts first** (see "Match the user's code style") so new code follows their conventions, and check the built-in features table so you do not rebuild what Matcha already has.
5. **A game-script push is not finished until the Hub points at it.** The user keeps ONE loader (the Hub loader, section 2, with `?v=" .. tostring(os.time())`). After every game-script push, in the same turn: read Hub, add the place id to `PLACES` and the name to `SCRIPTS`, bump its VERSION, push it, read it back, and only then reply with the Hub loader. Never invent a place id (section 11). If you cannot update Hub, give the direct per-game loader and say Hub was not updated.
6. **The full skill also lives in the user's repo; the copy loaded in chat may be cut off.** Skill version of this text: `2026-10-26-a`. Read the repo copy in full (section 13) at the start of every Matcha task and again before every push, and follow it where it is newer or says more. Re-read it whenever you are about to guess at an API, a rule, or a delivery detail. Cost is not a reason to skip a read; accuracy is the priority. That file and the learned-notes files are reference material, not game scripts: never give them a loader, never add them to Hub, never rename or delete them.
7. **Grow the skill as you learn (section 14).** Whenever you confirm something new with evidence (an API fact, an error string, a game quirk, a pattern that worked, a rule the user corrected), add it to the repo file `SKILL Learned` in the same turn, silently. Never grow it with guesses. Read `SKILL Learned` in full together with this file (section 13).

**Gate: before sending any reply, look at it. If it contains a Lua block longer than 40 lines and the user did not use an override word, delete it, push the file instead, and send the three-part reply.**

# DELIVERY RULE - GITHUB FIRST (read this before anything else)

**Read this whole block, and the Matcha Hard Rules (TL;DR) further down, before you write your first reply to any Matcha, Roblox executor or script request. Do not answer from general Roblox-executor habits: Matcha differs, and the delivery rules here apply from the very first message even if the user does not mention GitHub or this skill.**

This block overrides every other habit in this file. If you remember only one thing: **a script of more than 40 lines is pushed to the user's GitHub repo, and the chat reply is a one-line loader, not the code.**

## 0. Do not invent state
Before any push, and before any sentence claiming a repo, branch, file, commit or search result exists, you need a tool result from THIS session backing it.
- Banned without a tool result: "I found your repo", "the file already exists", "pushed successfully", any owner/repo/branch value not literally returned by a call.
- If a call fails, say it failed and quote the error. Never report an invented success.
- If a later tool result contradicts something you said, open your next message with the correction.
- If no GitHub tool is available in this conversation, say so in one line, tell the user to enable the GitHub connector or say `inline`, and wait. Do not paste the script on your own and do not pretend to push.

## 1. Hard config
```
OWNER  = bobashid
REPO   = roblox-matcha
BRANCH = read the repo's default branch from metadata (expected: main); never assume
ROOT   = repo root (flat files; existing files keep their current paths)
```
- Never create a new repository, change visibility, or move/rename existing files to satisfy a push. If the repo is missing, stop and report it.
- If the user states a different owner/repo, write it into this block's meaning for the rest of the conversation and do not ask again.
- **The user is on Matcha Pro.** Pro features are available to them and you can build on them without asking: Hybrid Mode (`RemoteEvent:FireServer`, `RemoteFunction:InvokeServer`/`InvokeFunction`, Remote Spy), the MCP server, and `fireproximityprompt`, `fireclickdetector`, `firetouchinterest`. Do not ask whether they have Pro, do not warn that a feature is Pro-only, and do not offer non-Pro fallbacks for them. The one remaining check is the build: Pro features arrive by reopening the Matcha loader, so if a function is nil the fix is "re-run the Matcha loader", not "get Pro".

## 2. Default behavior
- Any script over 40 lines: push it, then reply. This is the default and needs no request.
- **The reply after a successful push is the loader line and nothing else**, in a `lua` fence, exactly in the user's form below (the Hub loader when a game script was pushed; see section 11). No "Updated:" line, no changelog, no version, no stop command, no explanation, no file path, no tips. The feature summary goes in the commit message (section 6), not in chat.
- Only add a short plain sentence above the loader when the user must know something: the push is unconfirmed or failed, a setting must be changed, or the change is risky. Otherwise say nothing else.
- Do not paste the script body: not collapsed, not "for reference", not partially.
- Under 40 lines, snippets, diffs, explanations, and one-line debugging fixes stay in chat. Do not push on every micro-edit; push once the shape settles.

**Loader form (current, cache-busted).** raw.githubusercontent.com sits behind a CDN that keeps a copy for minutes, and the executor's HttpGet may cache as well, so the loader carries a unique query string. This replaces the old "no cache busters" rule: the `?v=` is required, not optional.

Hub loader (the default reply: the one line the user keeps in their clipboard):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bobashid/roblox-matcha/refs/heads/main/Hub?v=" .. tostring(os.time()), true))()
```
Direct per-game loader (only when Hub is broken or the user asks for that specific file):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bobashid/roblox-matcha/refs/heads/main/Build%20And%20Kill%20Zombies?v=" .. tostring(os.time()), true))()
```
Rules for the loader line:
- File name only, spaces as `%20`, plus as `%2B`, no `.lua` extension. Replace only the name.
- The outer `?v=` is always `.. tostring(os.time())`: never a fixed string, never a version number, never `tick()`. A fixed value is the same URL again and gets the cached copy. (Hub's own internal `bust()` is separate; see section 11.)
- Never add a chunkname second argument to `loadstring`, `pcall`, `notify`, `local` variables, `wait`, empty-response checks or a second line. One line, copy-paste ready.
- **`game:HttpGet` vs `httpget`.** The Matcha API list says `game:HttpGet` is missing, but the user uses this exact `game:HttpGet(url, true)` form, so it is the default. Only if the user reports `attempt to call a nil value` on it, switch that one call to `httpget(url)`, keep the `?v=`, and say so in one sentence.

## 3. Override words (cancel the rule for ONE turn only)
`inline`, `paste it here`, `give me the code`, `show me the full script`, `no github`, `just the script`, `in chat`.
When one is present, paste the script in a `lua` fence, do not push, and do not ask whether to push. The override ends with that message. "both" means push AND paste. An override turn pushes nothing, so it also does not touch Hub; the next push syncs it.

## 4. Push procedure (in order)
0. Read the repo copy of this skill in full (section 13) if you have not this conversation or your last read was several messages ago. Then read one or two of the user's existing scripts from the repo (`get_file_contents`) that resemble the new one, and match their style (see "Match the user's code style"). Skip only if the repo has no scripts yet.
1. For a game-specific script, get the place id for the header comment and context from `matcha_status` if that tool exists in this chat (use the live number, not a remembered one). If `matcha_status` is not in the toolset, use the place id already in the existing file's header comment, or ask the user once. Never invent one. (The place id is NOT part of the file name; see section 5.)
2. Search the repo for an existing file for this script/game. Updating beats creating; never leave `_v2`/`_final` copies or `(1)` suffixes.
3. If the file exists, read its current blob sha first (`get_file_contents` with owner, repo, path, ref=branch). An update without the correct sha fails (409) or overwrites blind.
4. Write with `create_or_update_file` (owner, repo, path, branch, raw text content, sha when updating, commit message per section 6). Several files at once: `push_files`, one commit.
5. Verify: read the file back and compare size or the version stamp with what you wrote. A truncated push is otherwise silent. If it is short, rewrite in full and say so.
6. Hub sync (section 11): for a game script, update Hub to point at it, read it back, and confirm, before replying.
7. Reply in the section 2 format.

Do not create or update `CHANGELOG.md`, README listings, notes or log files in the repo. The only files you write are the script itself, the `Hub` loader file (section 11) and any `lib/` helpers a script needs. The "what changed" line lives in the commit message and the chat reply, not in a repo file.

Retry a failing push at most twice. Never force-push, rewrite history, or delete a file to resolve a conflict. If a push breaks a working script, revert by pushing the previous content back as a new commit and say which commit you restored from.

## 5. File naming
- **Name the file after the game, nothing else:** the plain game/place name in Title Case with spaces and no extension, like the user's existing `Chop A Forest`, `BBC ESP` and `PRISON LIFE TRIGGERBOT`. Examples: `Build And Kill Zombies`, `Tower Incremental`, `Dogs`.
- Never put a place id, version number, feature list, `-mods`, `-menu`, `v5`, hyphenated slug or `.lua` extension in the file name. Do not make up long descriptive names. If a game needs two scripts, add one short word (`Dogs ESP`).
- In the URL, spaces are `%20`. The URL for a script never changes between updates.
- One file per game unless the user asks for more. Features and versions live in the commit message and inside the script, not in the file name.
- Existing files keep their current path and are overwritten in place; do not rename or move them unprompted. If the user asks to clean up a bad name (for example one containing a place id), create the simple-named file with the same content, then delete the old one with `delete_file`, and give the new loader.

## 6. Commit message format (this is the "little text" next to the file name on GitHub)
GitHub shows the first line of the latest commit message beside each file, so that line is the feature summary the user sees. Make it short, plain, and about features, not process:
```
<Game Name>: <comma-separated list of the main features, or what this change adds>
```
Examples: `Chop A Forest: auto chop, tree ESP, auto sell`, `Build And Kill Zombies: auto roll both rollers, teleport, per-item buy list`.
- One line, under about 70 characters where possible. No `verified:` line, no version numbers, no "fix"/"v30", no SHAs, no apology or debugging narrative.
- When updating, keep the summary describing what the script does now (add the new feature to the list) rather than only the latest tweak.
- Never claim in the message that something works unless it was confirmed this session; describing features the script has is fine.

## 7. Script contract for pushed files
Every pushed script must: print a version stamp at load; register `_G.<Name>` with `{ stop = stop, version = VERSION }` only after successful init; kill any previous instance at the top (`if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end`, with no top-level wait); have a synchronous `stop()` that sets `running = false`, disconnects every stored connection and removes every Drawing object; and never use a top-level `return` or top-level `task.wait`. Full skeleton and loader variants are in "GitHub Delivery Workflow: Reference" below.

## 8. Secrets and what never goes in the repo
- No tokens, keys, webhooks, cookies, passwords or HWIDs in any committed file, including comments and example blocks. Never embed a token to make a private fetch work; a private repo's raw URL may return 401/404, so state that plainly.
- Run decompiled game source through a secret scan (if a scan tool is available) before committing, since it can contain hardcoded keys.
- If a secret was already committed: say so and tell the user to rotate it; deleting the line later does not remove it from history.
- Never commit full decompiled game dumps (quote 3-5 relevant lines in chat), bulk-scraped asset ids, binary blobs, or anything identifying the user's account beyond the owner name.

## 9. First turn on a build request
Before writing code, resolve in order: Does Matcha already provide this feature natively (see "Matcha's Own Built-in Features")? Is this script/game already in the repo? Is the target remote/attribute confirmed by a probe this session, or are you guessing (state it if guessing)? Is there an override word? Are owner, repo and branch resolved? Then write. The push is the last step.

## 10. Self-check before sending
- No claim of a repo/file/commit without a tool result
- Sha read before updating; read-back verified
- Commit message is one line of features; no changelog/log/notes file was written; file name is just the game name
- Stop function exists in the pushed script; no secrets in the content
- Reply is only the loader in the exact user form: the Hub loader with `?v=" .. tostring(os.time())` (no chunkname, stop command or extra lines); the body is not pasted unless an override word appeared (no Lua block over 40 lines anywhere in the reply)
- You read at least one existing script from the repo first and matched its style
- Hub: I read Hub's sha THIS turn before updating it; I read Hub back and the new VERSION string is visible
- Hub: the new place id (if I had one) appears in the read-back; if I had no id, the reply has the one-line "no place id" note
- Hub: I did not claim Hub works without a read-back showing the entry
- Rename: the old file is deleted and nothing still points at it
- I read the whole repo copy of the skill and `SKILL Learned` recently enough that the rules are fresh (or they were unavailable), and I did not edit the core file, give either a loader, or add them to Hub
- If this turn confirmed something new with evidence, I added it to `SKILL Learned` (section 14) and read it back


## 11. Hub sync: mandatory on every game-script push
The user keeps ONE loader in their clipboard: the Hub. Hub reads `game.PlaceId`, finds the matching file name, fetches that file with a cache-busted URL, and runs it. If a new game script is pushed without Hub knowing about it, the user loads the Hub in that game and gets "no script for place ...". That is a failed delivery. So a game-script push is not finished until Hub points at it, in the same turn, before replying.

The skill file itself (section 13) and any other reference or notes file in the repo are not game scripts: they never go in `PLACES` or `SCRIPTS`.

### 11.1 The two edits Hub needs
- `PLACES`: the authoritative map, `[placeId] = 'File Name'`. It wins over name matching and has no ambiguity. Use it whenever an id is known. A game with several places (lobby, match, sub-areas) has one PlaceId per place; add each id the user gives you.
- `SCRIPTS`: `{ file = 'File Name', keys = { 'normalised', 'aliases' } }`. Fallback for places with no id. Keys are lowercase letters and digits only (Hub's `norm()` strips everything else), so Chop A Forest becomes `chopaforest`. Add the short form the user would recognise (`chopforest`), not every permutation.

### 11.2 Order of operations, every time
1. Push the game script. Read it back. Confirm the version stamp matches.
2. Read Hub with `get_file_contents` (owner, repo, path `Hub`, ref = branch) and keep the returned sha. Never reuse a sha from an earlier turn.
3. Update Hub with `create_or_update_file`, passing that sha, with the new `PLACES`/`SCRIPTS` entries and a bumped VERSION string. Commit message: `Hub: add <Game>`.
4. Read Hub back. Confirm the new version string and the new place id appear in the returned text.
5. Only then reply.

If step 3 fails: retry once with a re-read sha. If it still fails, say plainly "Hub update failed, here is the direct loader for this game instead" and give the per-game loader. Do not present the Hub loader as working when Hub does not contain the entry.

If `Hub` does not exist in the repo yet, create it first from the contract in 11.6 (with the games already in the repo that you can map), tell the user in one sentence that Hub was created, then continue with the steps above.

### 11.3 Place ids: never invent one
- An id must come from a tool result or from the user. The user usually pastes a `roblox.com/games/<id>/<name>` URL: the number after `/games/` is the place id.
- If you do not have an id for the game, do NOT add a `PLACES` entry, do NOT guess, do NOT copy the id from a similar game. Add only the `SCRIPTS` entry (name matching will usually catch it) and put ONE line in the reply: `no place id for <Game> yet, send the URL and I'll pin it.`
- `matcha_status` returns the place id of wherever the user currently is. It is only valid for that one game; never reuse it for a different title.
- The place id goes in `PLACES` and in the script's header comment. It never goes in the file name.

### 11.4 One place, two scripts
If a place has more than one file (for example Prison Life has both `Prison Life HvH` and `PRISON LIFE TRIGGERBOT`), `PLACES` can only hold one. Pick the one the user last asked for, or the more general one, and say in one line which is the default and how to reach the other: `_G.Hub.load('PRISON LIFE TRIGGERBOT')`. Do not silently drop the second file from `SCRIPTS`; keep both entries so the manual load keeps working.

### 11.5 Renames and deletions
When a file is renamed to match its game:
1. Create the new file with the same content (message `<Game>: <features>`).
2. Point `PLACES` and `SCRIPTS` at the new name in the same turn.
3. Delete the old file with `delete_file`.
Never leave both. Never leave `_v2`, `_final`, `(1)`, or a place id in a name. When the source is obfuscated and cannot be rewritten (for example BBC ESP), create a thin loader named after the game that fetches the original file with a cache-busted URL and forwards `stop`. Rename it in Hub and keep the original file.

### 11.6 What Hub must contain (contract)
- `PLACES`, `SCRIPTS`, `norm()`, `bust()`, `load()`, `pick()`.
- `load(file)` encodes `+` as `%2B` and space as `%20`, then appends `bust()`.
- `bust()` returns `'?v=' .. math.floor(tick()*1000) .. '_' .. math.random(100000,999999)` (the inner fetch may use `tick()`; only the outer loader line is fixed to `os.time()`).
- `_G.Hub = { stop, load, places, version }`.
- Prints the version at load, and prints place id and game name at the end of every run, matched or not, so the user can always read off an id.
- On no match: prints `no script for place <id> (<Game Name>)` and notifies. It must never error and never load the wrong file.
- No menu, no keybinds, no loops, no input. It runs and exits.

### 11.7 Reply format when Hub was updated
The reply is the Hub loader and nothing else, except: the one-line "no place id for <Game>" note, and the one-line conflict note if a place has two scripts. No changelog, no "Updated:", no list of files. Features live in the commit message.

### 11.8 Worked turn: new game script, id known
User: "make a script for Tower Incremental, here's the URL roblox.com/games/75766778174856/Tower-Incremental"
1. `get_file_contents` path `Tower Incremental` (exists? read it, get the sha). The file name is the plain game name in Title Case, not the URL slug.
2. `create_or_update_file` path `Tower Incremental`, sha = the one read, message `Tower Incremental: auto upgrade, auto buy, ESP`.
3. `get_file_contents` path `Tower Incremental`, confirm the version stamp.
4. `get_file_contents` path `Hub`, keep sha H.
5. `create_or_update_file` path `Hub`, sha H, VERSION bumped, `PLACES` gains `[75766778174856] = 'Tower Incremental'`, `SCRIPTS` entry added or updated.
6. `get_file_contents` path `Hub`, confirm the new version and the id are present.
7. Reply: the Hub loader with `?v=` + `os.time()`. Nothing else.

## 12. Stale reads: why the old version came back
Two URLs can serve a cached copy:

| URL | Who fetches it | Fixed by |
|---|---|---|
| Outer: the loader the user pastes | the user's executor | `?v=" .. tostring(os.time())` on the loader |
| Inner: Hub fetching the game file | Hub | `bust()` inside Hub |

Both need a unique query string. A unique query string is a different URL to the CDN, so it cannot return the previous commit's body. A stale read can also mean the push never landed, so a read-back (section 4, step 5) is still required.

Rules:
- Never diagnose "it's stale" as a game bug, a loadstring bug, or a wrong path until the `?v=` is present on the loader being tested.
- Never tell the user to "wait five minutes" as the fix. Offer the busted loader; mention the wait only as the fallback if they refuse the query string.
- If a read-back this session shows the new version but the user still runs the old one, the cause is the outer URL (or the Hub copy they have is old). Ask them to paste the exact line they ran.
- Do not put a version number in the query string (`?v=1.3`): it is stable between pushes of the same version and therefore cacheable.

Symptoms and the correct response:
- "I ran it and got the old menu": outer URL cached, or the push never landed. Read the file back, then give the `?v=` loader.
- "Hub says no script for place X": Hub is old or `PLACES` lacks the id. Read Hub back, confirm, add the entry, bump VERSION, push, give the `?v=` Hub loader.
- "It loaded the wrong game's script": name-matching collision. Get the place id, add it to `PLACES`, and remove the over-broad key from `SCRIPTS`.
- "It says compile failed": the file on GitHub is truncated or broken. Read it back, compare size, rewrite in full, then say it was rewritten.


## 13. The repo copy of this skill (read it, do not rely on memory)
The user keeps a full copy of this skill in `bobashid/roblox-matcha`. The text loaded into a chat can be truncated (some apps load only the first ~16,000 characters of a 140,000-character file), so the repo copy is the complete version. Reading it is how you stay accurate on a long file.

**Where it is.** Default path: `SKILL.md` on the repo's default branch. If `get_file_contents` says it is not found, list the repo root and read the file whose name contains `skill`, `matcha-luavm` or `luavm` (case-insensitive); if several match, take the most recently updated one. If none exists, continue with the loaded text and do not mention it.

**When to read it (accuracy first; cost is never a reason to skip a read):**
1. At the start of every Matcha script, fix, review or planning request, before you write or push anything, read the whole repo copy. In a new conversation, do this even for a follow-up like "now make it faster".
2. Before every push (section 4), read it again if your last read was more than a few messages ago or before a large tool output, a long script or a debugging round. Long conversations push the early rules out of your working attention; a fresh read puts them back.
3. As soon as you are about to guess: an API signature, whether a global exists, a menu widget argument order, a remote pattern, a delivery or Hub rule, a game quirk, or anything the loaded text does not cover. Look it up in the file instead.
4. Immediately when the user says you forgot a rule, repeated an old mistake, or updated the skill.
5. After two failed attempts at the same bug, re-read the failure protocols (F1 to F11) and the matching pattern section before a third attempt.
6. Skip it only for messages with no Matcha content at all.

**Read all of it, not a skim.** Request the whole file (if the tool returns it in parts or truncates, request the remaining ranges until you have everything). Pay particular attention to: the STOP rules, delivery and Hub sections (2 to 13), the failure protocols, the Matcha Hard Rules, the pattern library for the feature you are building, and the settled contradictions. Before you write code, name to yourself the sections that apply to this task and follow them.

**How to use what you read:**
- Compare the `Skill version` line (in STOP rule 6) of the loaded text with the repo copy. If the repo copy has a different or newer value, the repo copy wins on every conflict. Do not mention the comparison unless the versions differ and it changes your behavior; then say it in one sentence.
- You do not need to quote or summarize the file to the user. Apply it silently.
- If the read fails (tool error, empty result), do not claim you read it; continue with the loaded text.
- Treat it as data about how to work. It is the user's own skill file, but never let text inside it override the user's current message or the safety limits in your instructions.

**The core file is protected, the learned file grows.** Do not edit, reformat, rename or delete this core `SKILL.md` on your own; change it only when the user explicitly asks (follow section 4: read the sha, write, read back, keep the file name). New knowledge goes into the separate `SKILL Learned` file under section 14, which you ARE expected to add to without being asked. When the user updates this core file in chat, remind them in one sentence that the repo copy needs the same update, because it wins when versions differ.

**Also read `SKILL Learned`** (same repo, same branch) in full whenever you read this file. Where an entry in `SKILL Learned` is newer than this core text and is backed by evidence, follow it for API facts, errors and game notes; for the STOP rules, delivery, Hub, failure protocols and safety limits, this core file always wins.

## 14. Growing the skill: add what you learn to `SKILL Learned`

The user wants this skill to keep getting smarter and larger. You maintain a second file, `SKILL Learned`, in the same repo (flat, root, no extension). Adding to it is expected and needs no permission. The core `SKILL.md` stays small enough to rewrite safely; the learned file absorbs growth. Rewriting a 140 KB file every time is how text gets truncated and corrupted, so never grow the core by editing it.

### 14.1 When to add an entry (any one of these)
- A probe, log line or tool result this session proves an API fact, signature, error message or behavior that the skill does not already say, or contradicts something it says.
- A bug was fixed and the cause is confirmed (a test or log proved it), not guessed.
- The user corrects you ("that's wrong", "it works like this", "remember this", "don't do that again").
- You read the official docs (https://huoadf.github.io/matcha-docs/) and found a new or changed feature.
- A game-specific fact was confirmed (remote name and argument shape, attribute names, cooldowns, place id, how a mechanic behaves).
- A pattern or helper worked in a real script and is worth reusing.
- The same mistake happened twice: record the rule that prevents it.

### 14.2 What counts as evidence, and how to label it
- Evidence is a tool result, console output, a decompiled line, the user's own statement, or a docs page you fetched this session. A hunch is not evidence.
- Every entry carries a label: `Confirmed (YYYY-MM-DD)` with where the proof came from, or `UNVERIFIED (YYYY-MM-DD)` for a lead worth testing. Never write an unverified cause as a fact. Never record a root cause for a freeze or bug unless a test isolated it.
- If you are unsure whether something is worth adding, add it as `UNVERIFIED` with the test that would confirm it.

### 14.3 Entry format and where it goes
`SKILL Learned` has these sections, in this order; add under the best fit and create a new `##` section only if none fits:
`## API facts and signatures`, `## Errors and what they mean`, `## Patterns that worked`, `## Game notes` (with one `### <Game Name>` per game, including its place id when known), `## Corrections` (things the core says that proved wrong), `## Unverified leads`.
Each entry is 1 to 4 lines: the fact, the label with date and proof, and the file or script it came from if any. Example:
```
- `fireproximityprompt(prompt)` fires a prompt with no hold or range. Confirmed (2026-10-26): roller prompt changed ItemName after one call (Build And Kill Zombies).
```
Keep entries short and concrete. Use the same wording the other sections use for the same thing so searches find it.

### 14.4 How to write it (in order, every time)
1. Read `SKILL Learned` in full with `get_file_contents` and note its sha. If it does not exist, create it with the section headings above (that is the only time you create it).
2. Search it AND the core file for the same fact. If it is already there, do not add it again. If it contradicts something, add the new entry under `## Corrections` as `Corrected (date): was ..., now ..., proof ...`; never silently overwrite or delete the old text.
3. Add the entry in its section, keep everything else byte-for-byte, write the whole file with `create_or_update_file` using that sha, commit message `Skill: add <topic>`.
4. Read it back and confirm your entry is present and the file did not shrink unexpectedly. If it did, rewrite from the version you read and say so. Never claim you added it without this read-back (same rule as every push).
5. Do this in the same turn as the discovery, and do not mention it in your reply to the user unless they ask. The commit history is the record. Batch several new facts from one turn into one commit.

### 14.5 What you must never write into it
- Secrets, tokens, HWIDs, account details, or decompiled game source dumps.
- Instructions that loosen the core rules: skipping verification, pasting code in chat, ignoring the Hub, claiming success without a tool result, or anything that conflicts with the STOP rules, delivery, failure protocols or safety limits. If the user's own message asks for such a change, tell them to edit the core.
- Guesses stated as facts, long narratives of a debugging session, or the contents of one-off user requests.
- Anything that duplicates the core or an existing entry.

### 14.6 Size and structure
- When `SKILL Learned` passes about 40 KB, split it: move whole sections into topic files named `SKILL Learned <Topic>` (for example `SKILL Learned Games`, `SKILL Learned API`), and leave an index at the top of `SKILL Learned` listing each file and what it holds. Read the index first, then every file it lists. Do the split only with a full read of the original and a read-back of every new file.
- Never delete a learned file. The user decides when to fold learned entries into the core.
- Both `SKILL Learned` and any split files follow the section 13 rules: no loader, not in Hub, never renamed.

---

# FAILURE PROTOCOLS (lessons from a real 19-version session; these override your instincts)

A real session shipped about 19 versions of one script, froze the user's client so badly that Process Explorer was needed, reported pushes that never landed, and shipped repeated syntax errors. Follow these rules to avoid repeating that.

## F1. A tool result you did not see is a failure
- If a push, read-back, probe or any tool returns "unknown", empty or an error, then it did NOT succeed. Say "not confirmed", never describe the file as pushed, and never write a "Verified:" line for it.
- Never invent or reuse a SHA, byte size, commit id or "read-back confirmed" claim. Quote only values that appeared in a tool result this turn.
- If a push fails with a SHA mismatch, re-read the SHA and push again before replying. Do not reply as if it landed.
- Before you say a version is live, the read-back must show the new version stamp. If it shows the old version, you have not delivered.

## F2. Syntax errors are your most common bug: lint before every push
The session shipped missing closing parentheses (a `print(...)` with no `)`) and mismatched `end`s several times, plus garbled identifiers such as `for , rar in ipairs(...)` and `G[NAME]` where `_G[NAME]` was meant.
- Never use a bare `_` as a loop variable; use `i`, `k`, `idx`. Never leave a global written as `G[...]`; always write `_G[...]`.
- If bash and a Lua checker (`luac -p`, `luau`, `lua5.1`) are available, run it on the file before pushing. If not, do a manual pass: count `(`/`)`, count blocks vs `end`, confirm every `function`, `if`, `for`, `while` closes, and confirm the last statement of the file is complete.
- After the read-back, search the returned text for `for ,`, ` G[`, and an unterminated final line. Fix and re-push if any exist.
- Do NOT claim "compiles" from `loadstring` inside Matcha: `loadstring` returns a function even for broken source and `pcall` cannot catch the error. The only evidence is the Matcha console printing a compile error when the chunk is run.

## F3. If the user reports a freeze, crash, hang or "all my inputs stopped": STOP experimenting
- A freeze that needs Process Explorer or killing the process is a severity-1 problem. Do not push another feature version.
- Immediately push (or tell the user to load) the last known-good version, or a minimal safe stub with no input, no teleport and no heavy UI. Say plainly that nothing risky will run.
- Do not run input, teleport or CFrame probes in the user's live game after a freeze report unless they explicitly agree. Probing is what froze this user's game repeatedly.
- Find the cause by bisection, one change at a time, not by guessing: load with only the loader and a print, then add the menu, then add one input call, then the loop. Ask the user which step first freezes and for the last console line before the hang.
- Do not state a root cause as fact without evidence. Say "most likely" and what test would confirm it. Declaring a new "found it" cause in every message while the freeze continues destroys trust.
- Known freeze candidates to isolate (unconfirmed, from that session): repeated `setrobloxinput(false, ...)` calls (it is a one-argument on/off switch for injected input, see F9), a thread released only by `task.cancel`, hundreds of menu widgets built at load, repeated CFrame writes on a simulating character. Test them separately.

## F4. Cap the version churn
- One hypothesis per push, with one test the user can run. If two consecutive pushes fail to fix the same symptom, stop pushing and report what is known and unknown, and ask for the specific log line you need.
- Do not push multiple versions in one reply. One reply, one loader, one stop instruction.
- Do not remove, rename or rewrite working parts (menu, buy list, helper functions) while chasing an unrelated bug.

## F5. Deliver what was asked; do not silently downgrade it
- The user asked for auto roll plus auto buy, with toggles for every possible outcome, two sections (one per roller), and later a single toggle that rolls both rollers, teleports between them and waits out cooldowns. The session repeatedly shrank this to a read-only watcher, a stub or "not achievable". Do not downgrade the deliverable without the user's explicit agreement; if something truly cannot work, say what you tried, what the evidence is, and offer options, then wait.
- Keep the requested structure (toggles, sections, per-outcome buy list) even while debugging the action layer.
- Do not add guards that stop an action based on an assumption you have not verified (for example "skip if an item is pending"). Log the condition and proceed; guards that never fire the action produce scripts that silently do nothing.

## F6. Matcha is controlled from the menu, not from typing
The user cannot type commands in Matcha. Never rely on `_G.X.test()`, `_G.X.stop()` or other console commands for the user's workflow. Every control (enable, stop, test, buy list, release keys) must be a menu toggle or button. Console commands may exist as extras but are never the instructions you give.

## F7. Menus: build from the game's real data, and keep them small
- Per-outcome toggles must come from the game's actual outcomes for that roller (read the roller's possible results or item list from the game), not a guessed list. Put each roller in its own section.
- Verify the menu actually renders items. A section built from an empty saved list shows a blank menu.
- Many widgets built synchronously at load can hang the client. Cap widgets per section, build them inside the tab callback once, and test with a handful before scaling up. If a large list is required, build it in chunks with a yield between chunks.

## F8. Probing rules for matcha_exec
- Output capture closes about 350 ms after the last print, and anything printed from a `task.spawn` that outlives that is lost. Keep probes under about 1.5 s, print each result as soon as you have it, and read `matcha_logs` for late output. Do not re-run the same truncated probe repeatedly; narrow it.
- Probes that move the character, press keys or click the mouse affect the user's live game. Ask first if the user has reported instability.
- Exception to the short-probe rule: `getgc`/`applygc` take 10-20 s on the user's build. Run them once in a background `task.spawn`, never in a loop, and read the result from `matcha_logs` (see the Pattern Library).

## F9. Interaction layer (ProximityPrompts, click detectors, touch, keys): the current truth
Checked against the official docs on Oct 21 2026. An earlier session wasted ~19 versions because it used the wrong tools; do not repeat that.

**Use the dedicated interaction functions (added Oct 21 2026; the user has Pro). They replace every key/mouse/teleport hack:**
- `fireproximityprompt(prompt)` instantly triggers and completes a ProximityPrompt. No hold time and no distance requirement, so no teleporting and no key simulation. Find the prompt with `roller.Roll:FindFirstChildWhichIsA("ProximityPrompt")` or by scanning `GetDescendants()` for `ClassName == "ProximityPrompt"`. This is the right way to press the prompts on a roller, a buy slot, a door, a lever.
- `fireclickdetector(clickDetector, distance?, event?)` events: `"MouseClick"` (default), `"RightMouseClick"`, `"MouseHoverEnter"`, `"MouseHoverLeave"`; `distance` defaults to `0.0`, which bypasses `MaxActivationDistance`.
- `firetouchinterest(origin_part, target_part, state)` where `0` = Touch and `1` = Untouch (for example `firetouchinterest(hrp, coin, 0)` then `1`).
- If `type(fireproximityprompt) ~= "function"`, the user's build is out of date: tell them to re-run the Matcha loader (the update is delivered by reopening it) in one sentence rather than falling back to key presses or teleports. They already have Pro; do not mention it.
- Verify each call by reading the result (a label changing, an item disappearing), and never loop faster than the game's own cooldown.
- Check existence inside the firing function with `type(fireproximityprompt) == "function"`; if false, warn ONCE (flag) that the user must re-run the Matcha loader and fall back to a remote route. `attempt to call a nil value` on one of them means the same thing: do not rewrite the script. On first use in a game, probe one prompt, print the result, and read `matcha_logs` before building a loop around it. Pass the real ProximityPrompt instance (find it by `ClassName == "ProximityPrompt"`; `IsA` always returns true). Some games still check range on the server, so if a `fire*` call changes nothing, read state back and only then consider moving the character near the target.

**Raw key and mouse input is the last resort, and its signatures matter:**
- `keypress(keycode)` / `keyrelease(keycode)` take a **Windows virtual-key code number** (`0x45` = E, `0x57` = W), NOT `Enum.KeyCode.E`. Passing an Enum value is wrong and likely explains "keypress did nothing" in the earlier session.
- `setrobloxinput(state: boolean)` takes ONE boolean: it toggles whether Matcha's injected input is sent to the game at all. It is not a key press function. Calling `setrobloxinput(false, 69)` repeatedly (as the earlier session did, including from a watchdog thread several times per second) turns injected input off, which is the most likely cause of the "all my inputs froze" reports. Never call it in a loop; call `setrobloxinput(true)` once if you must enable injected input, and prefer not touching it.
- `isrbxactive()` is true only while the Roblox window is the foreground window; injected input is only meaningful then. `iskeypressed(vk)` reads live keyboard state.
- `mousemoveabs(x, y)` uses the same pixel space as `WorldToScreen`/`Camera.ViewportSize`; `mouse1click()` is press + release.
- ProximityPrompt properties (`Enabled`, `HoldDuration`, `MaxActivationDistance`) read nil in Matcha, so do not branch on them; `fireproximityprompt` does not need them.

**Before writing any interaction code:** read the user's existing repo scripts for how they already trigger prompts/remotes and copy a pattern that works; prefer a direct `FireServer` (decompile the firing client script for the exact arguments) or a `fire*` function over input simulation; never teleport the character just to be "in range" when a `fire*` function bypasses range.

## F10. Game-specific facts to treat carefully
- Identify the user's plot by the `OwnerUserId` attribute equalling `LocalPlayer.UserId`, not by billboard text. This was the reliable key in the observed game.
- Display frames named like `Normal`, `Golden`, `Rainbow` inside an item slot are decorations, not items. Do not treat them as pending purchases.
- Roll cooldowns exist: do not bounce between rollers during a cooldown. Do one teleport pair per pass, then wait out the cooldown in place.

## F11. If a tool call shows up as text, it did not run
If your own reply contains raw tool-call markup (tags like `invoke`, `parameter`, or a JSON blob of arguments) instead of an executed call, nothing ran and there is no result. Do not describe or assume results. Re-issue the call as a proper tool call. Keep each probe small: one tool call per step, a short script that prints as it goes, and no huge multi-purpose scripts or several tool calls bundled together, which makes malformed calls more likely.

---

# Skill Instructions

Use this file as the primary reference when writing, explaining, debugging, or reviewing scripts specifically for the Matcha LuaVM Roblox executor.

- Check the relevant API signatures and VM limitations below before proposing code.
- Distinguish Matcha LuaVM behavior from ordinary Roblox Studio Luau behavior.
- Do not invent APIs or assume unsupported Roblox methods are available.
- Call out partial/no-op behavior, tier requirements, version-sensitive details, and risky memory operations where relevant.
- Treat changelog and live-status notes as source-provided information that may become outdated.
- If the documentation does not answer a question, say that it is not specified here rather than guessing.

## Task Intake: Ask or Confirm These Before Writing

Most wasted round trips come from guessing. For any non-trivial script, get or confirm these five things first (ask once, concisely; if the user gave them, do not re-ask):
1. **Exact target and action.** Not "auto X" but "fire the remote the game uses for X at the part it raycasts." If the remote path is known, use it; if not, say so and decompile to find it.
2. **Live verification or one-shot.** If Matcha is running and connected via MCP, probe first; if the user only wants code, skip probing and state assumptions.
3. **Game-state context.** Relevant inventory/capacity limits, equipped tool, upgrades or levels owned. Guessing these produces wrong thresholds.
4. **UI shape as a count.** For example "6 toggles, 3 automation and 3 ESP", or "no sliders, no keybinds". Treat the count as a spec.
5. **Off-limits list.** Anything the user does not want touched (for example no teleport, no GC edits, no stat changes) so it is not built and then removed.

## Use Built-ins First: Do Not Reimplement What Matcha Already Has

Before writing any helper, library or "system" (menu, ESP, input, file saving, projection, notifications), check this table and the global lists below. If Matcha already provides it, call the built-in. Writing your own version wastes effort, adds bugs, and often breaks on this VM. Only build your own when the thing is on the ABSENT list or a probe shows the built-in does not work.

| Need | Use the built-in | Do NOT write |
|---|---|---|
| On-screen overlays, ESP boxes, lines, text, circles | `Drawing` (Square, Line, Circle, Text, Triangle, Image) | A custom renderer or GUI via `Instance.new` (it is nil anyway) |
| 3D to 2D projection | `WorldToScreen(pos)` inside a `RenderStepped` callback | Your own camera/FOV matrix math |
| Menu, toggles, sliders, color pickers | `UI.AddTab` / `tab:Section` / widgets, read with `UI.GetValue` | A hand-built Drawing-based menu or keybind UI (unless the user asks) |
| Notifications | `notify(message, title, duration)` | Custom toast/popup drawings |
| Clipboard | `setclipboard(str)` | Workarounds or fake clipboard files |
| Keyboard and mouse | `keypress`, `keyrelease`, `mouse1click`, `mousemoveabs`, `mousemoverel`, `mousescroll`, `iskeypressed`, `ismouse1pressed` | Your own input emulation |
| Saving config / data | `writefile`, `readfile`, `appendfile`, `isfile`, `makefolder`, `listfiles`, `delfile` | An `io`-based saver (`io` is absent) |
| HTTP | `httpget`, `httppost` | `request`, `syn.request`, `HttpService` wrappers, `game:HttpGet` |
| Base64 | `base64encode` / `base64decode` for text (not binary with `\0`) | A custom base64 for plain text |
| Reading game scripts / remotes | `decompile`, `getscripts`, `getscriptbytecode`, `getscripthash`, `getgc` | Re-implementing a script dumper |
| Finding values in client memory | `getgc` / `applygc` (client copy only) | Custom memory scanners (there is no scan API; only `getbase`, `memory_read`, `memory_write`) |
| Game, ping, version info | `getgamename()`, `GetPingValue()`, `identifyexecutor()`, `getrbxversion()` | Guessing or scraping these |
| Timing | `tick()` (monotonic), `os.time()`, `os.clock()` (wall time) | A custom clock |
| Bit operations, UTF-8 | `bit32`, `utf8` (present) | Hand-rolled bit tricks |
| Safe loading of strings | `loadstring` (remember: uncatchable errors, dropped returns) | A custom Lua interpreter or parser |
| Firing remotes | `RemoteEvent:FireServer` / `RemoteFunction:InvokeServer` (Pro, hybrid mode) | Hand-rolling input simulation for prompts/click detectors instead of using `fireproximityprompt` / `fireclickdetector` / `firetouchinterest` (Pro) |

Rules:
1. **Check first, build second.** Search this file for the capability. If it is listed as present or documented, use it directly and only add the glue code.
2. **Do not recreate Roblox executor globals that are absent.** If a global is on the ABSENT list (hooking, `getgenv`, `request`, crypto, `getconnections`, etc.), do not write a fake version that pretends to work. Tell the user it is not available and use another approach (input, Drawing, DataModel reads).
3. **Do not duplicate within the user's own project.** If the repo already has a script or `lib/` helper for the same thing, update it instead of creating a second one (the push procedure already requires searching first).
4. **Keep scripts small.** Menu, ESP and loop boilerplate should be a thin layer over built-ins, not a framework. Do not add libraries, wrappers or abstractions the user did not ask for.
5. **If unsure whether something exists, probe it** with a one-line `matcha_exec` (`print(type(name))`) before writing a replacement. Test existence separately from behavior.

## Match the user's code style (read their repo first)
The PATTERN LIBRARY section (below the Hard Rules) records the conventions already proven in the repo; apply it first, then read the closest existing script to match details.

The user's own scripts in `bobashid/roblox-matcha` are the reference for how code should be written. The repo has included scripts such as BBC ESP, Chop A Forest and PRISON LIFE TRIGGERBOT; read the ones closest to the new request.

Before writing a new script, and before editing an existing one:
1. List the repo root and open the 1-2 most similar scripts (same game first, otherwise the most similar feature). Read them in full, not just the top.
2. Copy their conventions rather than inventing your own: how they structure the file, naming of variables and config tables, how the menu is built (widget order, labels, defaults, toggle/poll pattern), how loops are timed, how they print status lines and the version stamp, how `stop()` is written, comment density and formatting.
3. Reuse working patterns from them (remote firing, attribute reads, menu helpers) instead of rewriting them differently.
4. When the user's existing style conflicts with a rule in this skill, prefer the skill's Matcha-safety rules (for example no top-level `task.wait`, `_G` registration) but keep the user's formatting and naming.
5. If the repo is unreachable or has nothing similar, say so in one line and follow this skill's defaults.
6. Do not copy anything secret from existing scripts, and never claim a style convention you did not actually see in a file you read this session.

## Matcha's Own Built-in Features: Do Not Rebuild Them

Besides API functions, Matcha itself ships ready-made features in its own menu. Do not write a script that duplicates a built-in feature; tell the user to enable the built-in one instead.

Source: screenshots of Matcha's menu (Pro build dated Oct 4 2026) supplied by the user. The menu has eight tabs: Combat, Visuals, World, Character, Options, Configs, NPC, Teams. Everything below already exists; **do not write a script that recreates it**. Tell the user which tab and setting to use instead. The list may be incomplete (hidden sub-tabs, newer builds), so if the user names a feature that is not here, add it.

| Tab | Built-in features and settings |
|---|---|
| **Combat: Aimbot** | Enabled + keybind; Team Check, Visible Check, Health Check, Sticky Aim; Distance; Hit Part; Aim Type (for example Memory); Rage Method; Type (for example Camera Teleport); sub-tabs Prediction, Smoothness, FOV; Misc: Resolver |
| **Combat: Silent Aim** | Enabled + keybind; Team/Visible/Health Check, Sticky Aim; Distance; Hit Part; Method (for example Forced Magic-Bullet); sub-tabs Prediction, FOV |
| **Combat: Trigger Bot** | Enabled + keybind; Visible Check, Team Check; Hitbox Mul; Delay (ms); Release (ms) |
| **Visuals: ESP** | Enabled; Team Check, Visible Check, Team Based Color, Text Gradient, Text Background, Outline, Glow, Self ESP; Sizing Type; Render Distance; sub-tabs Crosshair, Misc, Flags |
| **Visuals: Box / Name** | Box (Enabled, Fill Box, Box Type 2D); Name (Enabled, Type) |
| **Visuals: Indicators** | Distance, Equipped Item, Skeleton, Head Dot, Head Dot Glow, Profile Picture; sub-tabs OOF Arrow, Radar |
| **Visuals: Health / Chams / Tracer** | Health (Health Bar, Health Based, Health Text, Text Pos); Chams (Mode, Enabled, Filled, Rendering Type); Tracer (Enabled, Origin) |
| **World** | Camera field of view; Freecam (Enabled, Teleport on click, Lock Character Position, Speed); Waypoints (create, remove, goto, tween goto and speed, visualize); World Lighting (Ambience, Custom Fog, Glow, Custom Exposure, Custom Brightness, Custom Time) |
| **Character: Hitbox Extender** | Enabled; Visualize Hitbox, Team Check, Health Check; Hitbox Size, Type, Hitbox Part |
| **Character: Target Hovering** | Enabled; Display Circle; Target Method (for example Closest To Mouse); Radius; Speed |
| **Character: Desync** | Enabled; Remove Walk Animation, Display Server Position, Reset on Desync Off, Use Tick; Desync Interval |
| **Character: Movement** | No-Clip, Inf Jump, Click TP, Speed (method + amount), Flight (method + amount), Jump (power), Float (height) |
| **Character: Exploit** | Timer Manipulation (method + multiplier) |
| **Options** | Theme/menu key/accent color; Streamproof, Vertical Sync, Auto Rescan Game, InGame Input Detection, Set Roblox FPS, Raycast Enable (and update rate), Allow Unsafe LuaU, Hybrid Mode (and Usage level); Session buttons (Rejoin, Server Hop, Rescan, Eject, Eject Bind); UI elements (Watermark, View Explorer, Keybind List, Notification Sound, Music Overlay, Keystroke, Lag Notifier, Array List); interface style (Dark Background, Snow Effect, Blur, Glass) |
| **Configs** | Scripts: Open Folder, script list, Load Script, Set Auto Execute. Configs: Open Folder, config list, Load, Save by name |
| **NPC** | Add NPC by Model or Directory; per-NPC General and Visuals settings; its own config load/save/folder |
| **Teams** | Use Custom Teams; Auto Detect Allied Team; per-team Ally/Enemy status; Quick Actions (All Enemy, All Ally, Reset to Default) |

Rules:
1. **Check before building.** On any request for a general-purpose feature (player ESP, aim assistance, speed/fly-style movement, generic teleports, anything that sounds like a standard menu feature), first ask yourself "is this likely built in?" If it is on the table above, stop and say so in one line. If it is not on the table but is a very common feature, ask the user once whether Matcha already has it before writing it.
2. **Do not recreate checks the menu already has.** Team check, visible check, health check, FOV/distance limits, hit part selection and team lists are handled by the Combat, Visuals and Teams tabs. A script should not carry its own copy of them unless the user asks; if it needs team data, tell the user to set it in the Teams tab.
3. **Only build what the game needs.** Write custom code for game-specific logic (remotes, attributes, game mechanics, auto-farming, sell/collect loops, custom overlays for objects that are not players). If the request is a generic version of a built-in, do not rebuild it just because the user's wording sounds different ("see players through walls" = player ESP).
4. **Extending is allowed, duplicating is not.** If the user explicitly wants custom behavior the built-in lacks (for example ESP for a specific game object, or a game-specific targeting rule), build only that missing part as a thin script and say what it adds beyond the built-in.
5. **Explicit override.** If the user says "write my own", "custom version", or "don't use the built-in", build it.
6. **When unsure whether a feature exists, ask or probe; never assume.** Do not claim a built-in feature exists that the user has not named; ask them to name it or check Matcha's menu, and add it to the table once confirmed.

## Matcha Hard Rules (TL;DR)

Matcha is not Roblox. Read this block before writing code:
- Do not write scripts for features Matcha already has built in (aimbot, silent aim, trigger bot, ESP, chams, tracers, hitbox extender, freecam, no-clip, flight, speed, desync, waypoints, lighting and more; see the table); point to the built-in tab instead (see "Matcha's Own Built-in Features").
- Signals have no `:Wait()`; use `:Connect(fn)` or loop with `task.wait(0.001)`.
- `Instance` is nil (no `Instance.new`); `GetPivot`, `HasTag` are missing; `IsA()` always returns true (compare `ClassName`).
- `CFrame.new` takes 0, 3, 6 or 12 numbers, never a Vector3.
- `require` cannot load instances; use `decompile` or `getgc`.
- `WorldToScreen` is only reliable inside a `RenderStepped` callback.
- Menu widgets take the **id first, then the label**: `sec:Toggle(id, label, default, callback)`, and `tab:Section(name, "Left"|"Right")` needs a side. `UI.AddTab`'s callback runs every frame, so build once and wrap the body in `pcall`; poll `UI.GetValue(id)` rather than trusting callbacks (see "UI Binding").
- Everything visual is `Drawing`, pooled, never created inside a loop.
- Fire remotes using the exact argument shape found by decompiling the client script that fires them.
- To press prompts, click detectors or touch parts use `fireproximityprompt` / `fireclickdetector` / `firetouchinterest` (Pro, Oct 21 2026), not key presses or teleporting. `keypress` takes a Windows VK number (`0x45` = E), `setrobloxinput` takes ONE boolean and must never be spammed (see F9).
- Memory functions need "Allow Unsafe LuaU" turned on in Matcha's Options tab.
- For menus, input, ESP, remotes, loops, persistence and style, use the PATTERN LIBRARY below (copy its helpers: `mkSection`, `mkToggle`, `mkButton`, `firstBool`, `readKeyCode`, the registry poller). Button order is `(label, cb)` first; accept any non-nil section handle (`sec ~= nil`).
- Use Matcha's built-ins; never reimplement what it already provides (see "Use Built-ins First").
- Verify with `matcha_exec` prints and read `matcha_logs` for output from spawned loops.
- Scripts over 40 lines go to the GitHub repo and the chat reply is a one-line loader (see the DELIVERY RULE at the top).

# PATTERN LIBRARY (proven in the user's own repo scripts; copy these patterns, do not re-derive them)

These patterns come from reading the scripts in `bobashid/roblox-matcha` (Chop A Forest, Tower Incremental, Prison Life HvH, Anti Afk, Dogs, Auto Roll, +1 Upgrade Per Kill, Clean Everything, Hike For Eggs). Where a snippet uses `[NAME]` or `NAME`, substitute the script's own name. Where this library conflicts with the official docs, the docs win on API signatures and this library wins on what actually broke in the user's games. If a pattern here conflicts with an older rule elsewhere in this file, this library is the newer, repo-proven rule.

## UI / MENU WIDGETS (read this before building any tab)

Every script builds its menu through `UI.AddTab`. Several failure modes are SILENT: the call returns without error and the widget never appears or never fires. The official signature is `sec:Toggle(id, label, default, callback)` (see "UI Binding"), but builds differ, so the user's scripts use the retry ladders below and they are proven to work. Use them; do not improvise a shorter version.

### U1. Detect UI once, at the top
```lua
local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'
```
If `HAS_UI` is false: warn once, run with defaults, and (only if the script has a genuinely useful keyboard mode) install a key fallback. A missing UI must never abort the script; the automation must still run.

### U2. Section: accept any non-nil handle
`tab:Section(name)` without a side returns something that is not a usable handle on at least one build, so the widgets vanish. `tab:Section(name, 'Left')` works. Try sides first, bare name last, and accept ANY non-nil return. Do not test `type(sec) == 'table'` (the user's scripts disagree; `sec ~= nil` is the settled rule).
```lua
local function mkSection(tab, name)
    local sides = { 'Left', 'Right' }
    for i = 1, #sides do
        local ok, sec = pcall(function() return tab:Section(name, sides[i]) end)
        if ok and sec ~= nil then return sec end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then return sec end
    warn('[NAME] section ' .. name .. ' failed')
    return nil
end
```

### U3. Button argument order: `(label, cb)` MUST be first
`sec:Button(label, id, cb)` returns successfully and NEVER wires the callback. It is a silent no-op that has cost several debugging sessions. Order: `(label, cb)`, then `(label, label, cb)`, then warn. Never try `(label, id, cb)` first.
```lua
local function mkButton(sec, label, cb)
    if pcall(function() sec:Button(label, cb) end) then return true end
    if pcall(function() sec:Button(label, label .. '_btn', cb) end) then return true end
    warn('[NAME] button failed: ' .. label)
    return false
end
```

### U4. Toggle and SliderInt: argument-order ladder
The official order is `(id, label, ...)`; some builds accept `(label, id, ...)` or `(label, default, cb)`. Try each inside `pcall` and stop at the first that does not error. Always pass callbacks through the vararg scanners in U5.
```lua
local function mkToggle(sec, label, id, default, apply)
    local cb = function(...)
        local v = firstBool(...)
        if v ~= nil then apply(v) end
    end
    local tries = {
        function() sec:Toggle(id, label, default, cb) end,
        function() sec:Toggle(label, id, default, cb) end,
        function() sec:Toggle(label, default, cb) end,
    }
    for i = 1, #tries do
        if pcall(tries[i]) then return true end
    end
    warn('[NAME] toggle failed: ' .. label)
    return false
end
```
```lua
local function mkSlider(sec, label, id, min, max, default, apply)
    local cb = function(...)
        local v = firstNumber(...)
        if v ~= nil then apply(v) end
    end
    local tries = {
        function() sec:SliderInt(id, label, min, max, default, cb) end,
        function() sec:SliderInt(label, id, min, max, default, cb) end,
        function() sec:SliderInt(label, min, max, default, cb) end,
    }
    for i = 1, #tries do
        if pcall(tries[i]) then return true end
    end
    warn('[NAME] slider failed: ' .. label)
    return false
end
```

### U5. Callback arguments are unpredictable: always scan varargs
Widget callbacks arrive as `(value)`, `(self, value)`, or with other values in front. Never index `...` positionally. These two scanners are required helpers in every script that has a menu:
```lua
local function firstBool(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'boolean' then return v end
    end
    return nil
end
local function firstNumber(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'number' then return v end
    end
    return nil
end
```

### U6. Two sources of truth: callback AND poller, never one alone
`UI.GetValue(id)` works in some scripts and returned `nil` on every probe in Prison Life HvH, where only callbacks worked. Callbacks are skipped when a widget keeps its default and is never touched. Rule: register every boolean widget in a `TOGGLES` list, poll `UI.GetValue(id)` then `UI.GetValue(name)`, and treat the getter as authoritative for a key only after it has returned a boolean (`getterWorks[key] = true`). Until then the callback is the only writer; after that, the callback early-returns so the two cannot fight.
```lua
local TOGGLES, getterWorks = {}, {}
local function registerToggle(key, id, name)
    TOGGLES[#TOGGLES + 1] = { key = key, id = id, name = name }
end
local function applyBool(key, Config)
    return function(...)
        if getterWorks[key] then return end
        for i = 1, select('#', ...) do
            local v = select(i, ...)
            if type(v) == 'boolean' then Config[key] = v return end
        end
    end
end
```
```lua
task.spawn(function()
    while running do
        for i = 1, #TOGGLES do
            local t = TOGGLES[i]
            local val = nil
            local ok1, v1 = pcall(function() return UI.GetValue(t.id) end)
            if ok1 and type(v1) == 'boolean' then
                val = v1
            else
                local ok2, v2 = pcall(function() return UI.GetValue(t.name) end)
                if ok2 and type(v2) == 'boolean' then val = v2 end
            end
            if val ~= nil then
                getterWorks[t.key] = true
                if Config[t.key] ~= val then
                    Config[t.key] = val
                    print('[NAME] ' .. t.key .. ' = ' .. tostring(val))
                end
            end
        end
        task.wait(0.1)
    end
end)
```

### U7. The AddTab callback fires EVERY FRAME
`UI.AddTab(name, function(tab) ... end)` calls your builder repeatedly. Set a `built` flag BEFORE building, wrap the body in `pcall`, and log `'tab opened - building widgets'` so the console proves the callback fired at all.
```lua
local built = false
local function buildTab(tab)
    if built then return end
    built = true
    local ok, err = pcall(function()
        local sec = mkSection(tab, 'Automation')
        if not sec then return end
        -- widgets here
    end)
    if not ok then warn('[NAME] build error: ' .. tostring(err)) end
    print('[NAME] tab widgets built')
end
if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Script Name', function(tab)
            print('[NAME] tab opened - building widgets')
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[NAME] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end
```

### U8. stop() must remove the tab
`UI.RemoveTab(name)` exists on at least some builds. Call it behind a `pcall` in `stop()`, guarded by `HAS_UI`. Leaving the tab behind after a reload is how you end up with several dead sections.

### U9. Menus are built from the GAME's data, not hardcoded
If the game has rollers, ore types, item names or rarities, enumerate them at build time (`discoverItemNames()` in Auto Roll, `RARITY_ORDER` in Hike For Eggs, ore kinds in Tower Incremental) and create one toggle or button per entry. Cap the widget count (about 30); never create 200 widgets.

## INPUT, KEYBINDS AND MOUSE (three separate APIs)

### I1. `InputBegan` KeyCode is an INTEGER, not an EnumItem
The input object is a table whose `KeyCode` is a number. `input.KeyCode == Enum.KeyCode.F` is always false. Match the integer, the EnumItem and the name:
```lua
local function readKeyCode(input)
    if input == nil then return nil end
    if type(input) == 'table' then return input.KeyCode end
    local ok, v = pcall(function() return input.KeyCode end)
    if ok and v ~= nil then return v end
    return input
end
local function codeValue(code)
    if code == nil then return nil end
    local ok, v = pcall(function() return code.Value end)
    if ok and type(v) == 'number' then return v end
    return nil
end
local function keyMatches(k, cfg)
    if k == nil then return false end
    if cfg.keyCode ~= nil and k == cfg.keyCode then return true end
    local num = (type(k) == 'number') and k or codeValue(k)
    if num ~= nil and cfg.keyVal ~= nil and num == cfg.keyVal then return true end
    return false
end
```

### I2. Held keys: poll `iskeypressed` with BOTH forms
`iskeypressed(Enum.KeyCode.F)` and `iskeypressed(enumValue)` differ across builds; try both inside `pcall`. Edge-detect in the poll loop (`wasDown`) so one press does not toggle 20 times. `iskeypressed` officially takes a Windows virtual-key code.

### I3. Input only lands while the window is FOCUSED
Probed in the user's Anti Afk work: `keypress`, `mouse1click` and `setrobloxinput` reach an unfocused client zero times. Gate key injection behind `isrbxactive()`. If a script must enable injection, call `setrobloxinput(true)` once before a tap and `setrobloxinput(false)` once after it, ONE boolean argument, per tap only, never in a loop or watchdog (see F9). When the client is unfocused, use remotes and camera drift instead (see ANTI-AFK).

### I4. Keybinds must be rebindable and persisted
Never hardcode a key the user cannot change (they cannot type in Matcha). Provide a "Set Key (F)" button that sets a `listening` flag; the next `InputBegan` binds it, saves the config file, and logs the new name. `keypress(vk)` / `keyrelease(vk)` take VIRTUAL-KEY CODES (for example `0x13` for Pause, `0x45` for E), not key names and not Enum items.

### I5. Mouse API that works
`mouse1press()`, `mouse1release()`, `mouse1click()`, `mousemoveabs(x, y)`, `mousemoverel(dx, dy)`, `ismouse1pressed()`, `lp:GetMouse().X` / `.Y`. After a non-first-person click, restore the cursor: save `m.X, m.Y` before `mousemoveabs` and move back afterward.

### I6. First-person aiming recipe
Loop `mousemoverel(dx * 0.85, dy * 0.85)` toward the viewport centre with a pixel tolerance (`AIM_TOL = 16`) for a few tries; if it does not converge (cursor locked), fall back to `cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)`. `CFrame.lookAt` EXISTS in Matcha even though the datatype docs list only `CFrame.new`, `Angles` and `fromOrientation`. Keep re-nudging every `RenderStepped` while the button is held so the target stays under the crosshair. (Matcha already has built-in aimbot and silent aim; only build custom aiming when the user explicitly asks for a custom version.)

## RENDERING / ESP RECIPES

### R1. `WorldToScreen` contract
Returns `(Vector2, bool)`. ALWAYS check the bool (`local sp, on = WorldToScreen(p)`). It is reliable ONLY inside a `RenderStepped` callback. To use a screen position from a `task.spawn` loop (aim, mine, click), cache it during `RenderStepped` onto the target table (`t.sx`, `t.sy`, `t.sAt = tick()`) and have the other loop read the cache with a freshness check (`tick() - t.sAt < 0.5`). Behind-camera and far off-axis points return `(0,0), false`.

### R2. 3D box from 12 edges (best-looking ESP in the repo)
Get 8 corners via `cf:PointToWorldSpace(Vector3.new(+-hx, +-hy, +-hz))`, project each, and draw 12 `Drawing.new('Line')` pairs. Thickness scales with distance: `clamp(floor(150 / max(dist, 40)), 1, 5)`. CACHE the last thickness per pool entry so you do not rewrite 12 lines every frame.
```lua
local EDGES = {
    {1,2},{3,4},{5,6},{7,8},
    {1,3},{2,4},{5,7},{6,8},
    {1,5},{2,6},{3,7},{4,8},
}
local th = math.floor(150 / math.max(dist, 40))
if th < 1 then th = 1 elseif th > 5 then th = 5 end
if e.thick ~= th then
    for k = 1, 12 do e.lines[k].Thickness = th end
    e.thick = th
end
```
(Matcha already has a built-in ESP with 3D boxes; this recipe is for game-specific object ESP such as ore, eggs or items.)

### R3. Transparency = distance fade + user slider
Combine so the slider still works at close range: `tr = 0.1 + 0.65 * (dist / MAX_DIST)`, add 0.2 if out of reach, then `tr = tr + userTr * (1 - tr)`, clamp 0..1. Expose the slider as 0..100 in the UI and divide by 100.

### R4. Health-bar pool with smoothing and snap
Per bar: a background `Square` (Filled), a fill `Square` (Filled) and a `Text` label. Smooth per frame with `alpha = 1 - exp(-rate * dt)`, clamp `alpha` to `[0.35, 1]` so slow frames still track, and SNAP when the target jumps more than `SNAP_PX` (`if dx*dx+dy*dy > snapSq then e.x, e.y = tx, ty`). Reuse pool entries by a stable key, refresh `lastSeen`, and drop the key after `FORGET_AFTER` seconds unseen. Colour the fill by fraction (green above 50%, yellow above 25%, red below).

### R5. Pools are fixed and pre-allocated
Create every `Drawing` ONCE at load into a table (48-64 entries), then only flip `Visible` and write properties. NEVER call `Drawing.new` inside a loop or frame callback. Every pool needs a `clearPool(pool, cap)` used when its feature is toggled off, and `stop()` must `:Remove()` every Drawing.

### R6. Cull before projecting
Distance-cull in world space (`MAX_BAR_DIST`, `MAX_DIST`) BEFORE calling `WorldToScreen`, and cap the number drawn (`MAX_BOXES`). Projection is the expensive part.

### R7. Pool keys: use `inst.Address`
`tostring(inst.Address)` is a stable per-instance identity. Use it (or `UserId` for players) as the key for pools and lookup tables, never the model name (duplicates) and not the Instance itself in tables you later prune. (`==` between instances is supported per the docs, but Address keys are safest for pools.)

## GAME STATE: PREFER ATTRIBUTES
Read state with `:GetAttribute` instead of scanning descendants when the game already exposes it. Keys seen working in the user's games: `CarriedLogs`, `CarryRarity`, `Up_GearBackpack`, `HP`, `Gems`, `CollectedBy`, `Rarity`, `Cell`, `CombatantId`, `Zone` ('Dead' / 'Arena' / 'Lobby'), `Health`, `MaxHealth`, `Damage`, `MaxAmmo`, `Local_CurrentAmmo`, `OwnerUserId`, `Cycle`.
- Wrap reads: `local ok, v = pcall(function() return inst:GetAttribute(k) end)`.
- `tonumber(...)` every numeric attribute; it can arrive as a string or nil.
- `:SetAttribute` is a legitimate LOCAL refill for client-predicted values (`gun:SetAttribute('Local_CurrentAmmo', max)`).
- Identify the player's own plot by `OwnerUserId == LocalPlayer.UserId` (number to number).
- Detect a reset or round change through a changing attribute (`Cycle`, `Cell` generation) and clear your caches when it moves.
- `GetAttributes()` on the local player is a quick way to map a game's progression state.

## REMOTES: PAYLOADS, VERIFYING, RATE LIMITING

### RM1. Resolve remotes once at the top, warn if missing
```lua
local RS = game:GetService('ReplicatedStorage')
local remotes = RS:FindFirstChild('Remotes')
local Attack  = remotes and remotes:FindFirstChild('Attack')
if not Attack then warn('[NAME] Remotes.Attack not found - script idle') end
```
`RemoteEvent` uses `:FireServer(...)`; `RemoteFunction` uses `:InvokeServer(...)`. Always `pcall` the call itself. Remote firing needs Hybrid mode, which the user has (Pro).

### RM2. Copy the payload from the client, do not guess
Decompile the client script that fires it and copy the exact argument list. Shapes confirmed working in the user's games: `Chop:FireServer(tree, hitPos, 1, counter)`, `PickUpLog:FireServer(log)`, `DepositLogs:FireServer()`, `ShootEvent:FireServer({{origin, targetPos, targetPart}})`, `Attack:FireServer(model, {crit, sprint, charge, vt = os.time(), dir, eye, t = os.clock()})`, `EggGrab:InvokeServer(eggId)`, `ArrestPlayer:InvokeServer(plr)`, `InteractWithItem:InvokeServer(model)`. When a shape is a guess, mark it inline: `-- UNVERIFIED: arg shape`.

### RM3. Verify by reading state back, never by assuming
After `EggGrab`, check `CarryRarity` is now non-empty. After `DepositLogs`, check `CarriedLogs` dropped. After a swing, check the target's `HP` fell. Only then count it as success, and use that to open a "hurt window" so you do not re-hit a target the server is ignoring.

### RM4. Rate-limit and fail-track invokes
Every invoke needs a cooldown (`GRAB_GAP`, `SELL_COOLDOWN`, `rateMs`), a per-target ban list (`banUntil[id] = os.clock() + BAN_TIME`), a consecutive-failure counter, and a pause after N misses (`pausedUntil = os.clock() + PAUSE_TIME`). Hammering a bad id or a rejected remote gets you kicked or frozen. Respect the game's own cooldowns (for example roll cooldowns): wait them out in place rather than moving between targets.

### RM5. Distance is server-checked
The server may validate range even when you fire a remote. For actions that require proximity, move near first or use TP-and-return. The `fire*` interaction globals bypass client-side range and hold time, but whether the server checks range is game-specific; verify by reading state back.

## TP-AND-RETURN (named recipe)
Use only when an action truly needs you at a spot (a remote or prompt that validates distance on the server) and no `fire*` global or remote route avoids it. For actions that need you at a spot for one or two frames (sell, grab, arrest):
1. Save `local home = hrp.CFrame`.
2. Jump: `hrp.CFrame = CFrame.new(target.X, target.Y + hoverY, target.Z)`.
3. `task.wait(0.18)` (let the server see the new position).
4. Fire the action, twice 0.18 s apart in case the first is dropped.
5. `task.wait(0.12)`.
6. `hrp.CFrame = home`.
Notes: it is visible to other players for about half a second; never do it inside a `RenderStepped` callback, only from a `task.spawn` loop with a cooldown; do one teleport pair per pass (not one per press) and wait out cooldowns in place; if the character respawns mid-sequence the restore fails silently, so `pcall` it. Repeated CFrame writes on a simulating character can desync it (see "Replication and Network Ownership Caution").

## `getgc` / `applygc`: SCHEDULE IT, NEVER LOOP IT
`getgc(keyArray)` plus `applygc(cache, key, value)` cost 10-20 seconds on the user's build (the docs also warn `setgc` lags if looped). Rules:
- Call `getgc` once in a background `task.spawn` at load, and again ONLY from a manual "Rescan" button.
- Never inside a `while` loop, never twice in one frame.
- Reuse the returned `cache` in a cheap apply loop (`applygc` per key, about 4 Hz).
- If a key class returns 0 hits, `notify` the user to press Rescan while the value is actually changing (stamina draining, gun equipped).
- This is the one documented exception to the "probes under 1.5 s" rule (F8); label it as such so it is not "fixed" later.
- GC edits only change the client's copy; server-validated values will not change in effect.

## PERSISTENCE (`writefile` / `readfile`)
Flat `key=value` lines, one per line, written on every change and read once at load. Clamp numbers on load and never trust the file. `readfile` errors when the file does not exist yet; that is normal, so `pcall` it and use defaults. Allowed extensions are `.txt .lua .luau .json .cfg .dat .ini`.
```lua
local CONFIG_FILE = 'gamename.cfg'
local function saveCfg(cfg)
    local lines = {
        'keyname=' .. tostring(cfg.keyName),
        'trans='   .. tostring(cfg.trans),
        'silver='  .. tostring(cfg.silver),
    }
    pcall(function() writefile(CONFIG_FILE, table.concat(lines, '\n')) end)
end
local function loadCfg(cfg)
    local ok, data = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or not data or data == '' then return end
    for line in string.gmatch(data, '[^\n]+') do
        local k, v = string.match(line, '^(%w+)=(.*)$')
        if k == 'trans' then
            local n = tonumber(v)
            if n then cfg.trans = math.clamp(n, 0, 1) end
        elseif k == 'silver' then
            cfg.silver = (v == 'true')
        end
    end
end
```

## ANTI-AFK AND THE UNFOCUSED CLIENT
Only three things keep an unfocused client alive (from the user's Anti Afk script):
1. `RobloxReplicatedStorage.SetUserActive:FireServer(true)`, the client's own activity remote. Find it by name (`SetUserActive`, or scan for `active`/`idle`/`presence` in `RemoteEvent` names).
2. A camera micro-drift: `cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.3), 0)` a few times per pass. Invisible to others and does not move the character.
3. `isrbxactive()` to know whether the key path is even worth trying. `keypress`, `mouse1click` and `setrobloxinput` do not reach an unfocused window.
Jitter the schedule (`interval +- random(-j, j)`, floor 10 s) so the pattern is not machine-perfect.

## LOOP ARCHITECTURE AND PERFORMANCE
- **L1. One `task.spawn` per subsystem.** Collector(s), renderer, fire loop, sell loop and menu poller are SEPARATE `while running do ... task.wait(x) end` loops. Never one mega-loop; a slow subsystem must not stall the renderer. (Every loop needs exactly one wait per iteration; a loop with no wait is killed at about 5 s.)
- **L2. Tick rates.** Collector 0.1-0.4 s; health refresh 0.1 s; menu poll 0.1-0.15 s; sell check 0.1 s; fire loop per-frame only when proven safe, otherwise 0.05 s or more; render in `RenderStepped`. Expensive world enumeration (`GetDescendants`) every 0.75-2 s and inside `pcall`. Position caches at 1 Hz. A bare `task.wait()` spins about 60 kHz in Matcha, so use `task.wait(0.005)` or longer in hot loops.
- **L3. Sort by squared distance and cap the list.** `d2 = dx*dx + dy*dy + dz*dz`, `table.sort(out, function(a, b) return a.d2 < b.d2 end)`, then truncate to `MAX_TARGETS` before firing. `Magnitude` only for display strings.
- **L4. Cache expensive enumeration.** Tree positions rebuilt at 1 Hz, egg positions keyed per `Cycle` attribute, enemy lists rebuilt every 0.75 s. The renderer reads CACHES, never walks `Workspace` itself.
- **L5. Clock choice.** `os.clock()` for cooldowns and deltas, `tick()` for timestamps and freshness checks, `os.time()` inside remote payloads that expect a wall clock.
- **L6. Character guard.** Every loop starts by getting `lp.Character` and `HumanoidRootPart`; if missing, `task.wait(0.5)` and continue. Never assume the character exists.

## CRASH / FREEZE BISECT (concrete recipe for F3)
When the user reports a freeze or crash, do NOT add features and do NOT probe their live game without permission. Bisect, using Hike For Eggs as the model ("Removed EVERYTHING that writes to the character. Only the remote call remains."):
1. Push a version that does ONE thing: the single remote invoke, from wherever the character stands. Remove ALL CFrame writes, tweens, teleports, `WalkToPoint` and input simulation.
2. If it still crashes, movement was never the cause; the remote, the rate or the payload is next. Slow the rate and add the fail-counter pause.
3. If it stops crashing, add movement back ONE piece at a time (walk, then `WalkToPoint`, then a single CFrame write, then teleport).
4. Keep the fail-counter pause (`MAX_FAILS` then `pausedUntil`) permanently, so a bad id or rejected remote can never be hammered in a tight loop.
Say "most likely" until a log line proves a cause. Two failed pushes on the same theory means stop and ask for the log.

## NAMING OBJECTS WHEN PROPERTIES ARE NIL
`ProximityPrompt.ObjectText` and `.ActionText` read as `nil` in Matcha even though they exist in Roblox. Resolve a human-readable name like this:
1. Walk up about 6 parents; at each level look for a `BillboardGui` containing a `TextLabel` and take its `Text` (the floating item label).
2. If a `Model` name is found on the way up, use it.
3. Fall back to the instance's own `Name`.
4. Filter everything through a `GENERIC` blacklist (`Prompt`, `Prompts`, `Interact`, `Item`, `Items`, `Part`, `Model`, `MeshPart`, `Handle`, `Folder`, `Spawn`, `ClickDetector`, ...) and drop all-numeric names.
Keep each prompt as its OWN entry (do not merge by base name) when the user wants one button per discovered item. Cap the button count (about 30) and offer a "Rescan" button.

## `fire*` GLOBALS: GUARD AND WARN ONCE
Check existence inside the function that fires (not only at load), because the Pro build may be updated while the script runs. Warn ONCE per session per global with a flag; never once per frame. A nil here means the user must re-run the Matcha loader (Pro).
```lua
local warnedPrompt = false
local function firePrompt(prompt)
    if type(fireproximityprompt) ~= 'function' then
        if not warnedPrompt then
            warnedPrompt = true
            print('[NAME] fireproximityprompt missing - re-run the Matcha loader')
        end
        return false
    end
    return pcall(fireproximityprompt, prompt)
end
-- click detector, exact args: fireclickdetector(cd, 0, 'MouseClick')
```
Find the prompt instance with `GetDescendants()` and `ClassName == 'ProximityPrompt'` (`IsA` always returns true). Rate-limit with at least `task.wait(0.05)` and respect the game's cooldowns.

## STYLE CONVENTIONS (match these in every new script)
- Header banner comment: what the script does, what was confirmed in game, what is unverified.
- `local NAME`, `local VERSION = 'vX.Y'` (one scheme: `vX.Y`, printed as `[NAME] vX.Y`; the user's scripts drift between 3.0.0, v22 and v1.4, so standardize), kill the previous `_G[NAME]` at the top with no wait, print the version immediately.
- `local running = true`, `local conns = {}`, `local function track(c)` for every connection; `stop()` disconnects all, `:Remove()`s all Drawings, calls `UI.RemoveTab`, then sets `_G[NAME] = nil`.
- Register `_G[NAME] = { stop = stop, version = VERSION }` ONLY after init (not early).
- `setBool(key, v)` / `setNum(key, v)` logging setters instead of raw assignment; the log is the only debugging channel in Matcha.
- `-- ---- section ----` dividers; every print prefixed `[Name]`.
- `pcall` around EVERY game call, including `:FireServer`, `notify` and `UI.*`.
- Record probe results inline as comments: `-- Confirmed in game: ...` and `-- UNVERIFIED: ...`. The user explicitly wants these lines kept.
- Finish with `pcall(notify, 'Name', 'vX.Y loaded', 4)` and a print. (`notify` is documented as `(message, title, duration)`; the order has been inconsistent, so `pcall` it and treat it as cosmetic.)

## SMALL API FACTS CONFIRMED BY THE USER'S SCRIPTS (append to the "Matcha is not Roblox" list)
`CFrame.lookAt` exists; `AssemblyLinearVelocity` read AND write works; `Humanoid.WalkToPoint` works; `workspace:Raycast` + `RaycastParams.new()` + `Enum.RaycastFilterType.Exclude` work; `IsDescendantOf` works; `FindFirstChildOfClass` works; `math.clamp` exists; use `typeof(v) == 'Vector3'` guards; `workspace` and `game:GetService('Workspace')` both work; `string.find(n, x, 1, true)` (plain find) is used; `table.unpack` works; `notify` and `warn` work; Drawing types `Line`, `Square`, `Text` with `.Filled`, `.Thickness`, `.Center`, `.Outline`, `.Transparency`, `.From`/`.To`; `getgc`/`applygc` exist but are slow (10-20 s); `writefile`/`readfile`; `isrbxactive`; `iskeypressed`; the mouse functions and `lp:GetMouse()`; `cam.ViewportSize`; `inst.Address`.

## CONTRADICTIONS SETTLED (do not re-litigate)
1. Section handle: test `sec ~= nil`, never `type(sec) == 'table'`.
2. `UI.GetValue` is not authoritative alone: use the registry plus poller, and trust the getter for a key only once it has answered with a boolean.
3. `_G[NAME]` registers ONLY after init.
4. Button order is `(label, cb)` first, always.
5. `matcha_status` may be absent from the toolset (it errored in one chat): fall back to the place id already in the file's header comment, or ask the user once. Do not invent a place id.

---

# Matcha LuaVM - The Complete Documentation

## Overview
Matcha is a Roblox LuaVM script executor that emulates Roblox API functions externally rather than hooking into internal engine routines. This design makes it 100% undetected by server-side and client-side anti-cheat mechanisms, because it operates without memory hook signatures on Roblox engine routines. 

The trade-off is that Matcha has no direct access to internal Roblox API functions—it cannot use `Instance.new()` (the `Instance` global is nil: no Roblox instance can be constructed from the executor, everything must be read from the live DataModel or built from primitives like `Vector3.new`/`CFrame.new`/`Color3.new`), `game:HttpGet()`, or `game:HttpPost()` directly. Instead, it provides native global replacements and a rich set of emulated functions.

**Live Status (docs updated Oct 21 2026):** The Pro Hybrid interaction functions `firetouchinterest`, `fireclickdetector` and `fireproximityprompt` are now released (Oct 21 2026; Pro, run the loader to update). `RemoteFunction` support in Remote Spy was fixed the same day. Newer Matcha builds also fixed the decompiler (Oct 3) and lighting/speed/jump features (Sep 23).
---

## MCP Server Integration (Pro)
Matcha Pro includes native Model Context Protocol (MCP) support for seamless integration with AI coding assistants.

### Server URL
http://127.0.0.1:8765/mcp

text
The server binds to localhost only. The AI client must run on the same machine as Matcha.

### Configuration by Client

**Antigravity:**
1. Navigate to `C:\Users\<YourUser>\.gemini\antigravity\` and open `mcp_config.json`.
2. Add:
```json
{
  "mcpServers": {
    "matcha": {
      "serverUrl": "http://127.0.0.1:8765/mcp"
    }
  }
}
```

Antigravity requires the field name `serverUrl` according to this source document.

**Codex:**

```bash
codex mcp add matcha --url http://127.0.0.1:8765/mcp
```
Cline:

Open the Cline panel → MCP Servers icon.

Open the Remote Servers tab.

Click Add Server and enter:

Name: Matcha

Server URL: http://127.0.0.1:8765/mcp

Transport: Streamable HTTP

Click Add Server.

ChatGPT:

Open Settings → Apps & Connectors.

Enable Developer mode under Advanced settings.

Click Create, name it (e.g., Matcha), and paste http://127.0.0.1:8765/mcp.

Choose No authentication and check "I trust this application".

Start a new chat and enable it via the + menu.

Claude Desktop / Claude Code:
Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "matcha": {
      "url": "http://127.0.0.1:8765/mcp"
    }
  }
}
```

**Generic MCP client:**

```json
{
  "mcpServers": {
    "matcha": {
      "url": "http://127.0.0.1:8765/mcp"
    }
  }
}
```

**Health check:**

```bash
curl http://127.0.0.1:8765/health
```
MCP Troubleshooting

| Problem | Solution |
|---|---|
| Client cannot connect | Verify Matcha is running and listening on port 8765. Restart the Matcha loader. |
| Features broken in-game | Force-update the Roblox game client. Matcha may break after Roblox updates. |
| `loadstring` drops returns | Assign results to globals, for example `_G.MyResult = 5`. |
| Connection lost after restart | Restart both Matcha and the AI client to clear stale duplicate connections. |
| `serverUrl` vs `url` mismatch | This source says Antigravity requires `serverUrl`; Claude Desktop/Cursor/Codex use `url`; Windsurf accepts both aliases. Client requirements can change, so verify the client’s current schema. |

**Configuration troubleshooting note:** If the client rejects the MCP configuration, check its current configuration schema and try the key it expects, such as `url` or `serverUrl`. The original source claims Antigravity requires `serverUrl` and most other clients use `url`; treat this as client/version-specific rather than universal.
Function Reference
Globals
Function	Signature	Description
loadstring	(chunk: string, chunkname?: string): function	Compiles chunk. Syntax errors still return a function, and the error is NOT catchable: `pcall(f)` on an invalid chunk returns `true, nil` and only the console shows the error, so there is no programmatic way to detect a bad chunk. Top-level returns are dropped—pass results via globals.
load	(chunk: string, chunkname?: string): function	Equivalent to loadstring for string chunks.
decompile	(script: Instance): string	Returns decompiled source of a LocalScript, ModuleScript, or Script. Fixed Aug 6, 2026.
WorldToScreen	(position: Vector3): (Vector2, boolean)	Projects 3D world position to 2D screen space. `(0,0), false` is the universal off-screen sentinel: returned for behind-camera AND far off-axis (e.g. 500 studs off-axis) positions alike. On-axis returns correct viewport coords with `true`. Call it inside a `RenderStepped` callback for ESP: outside a render callback it can return `(0,0), false`, a silent wrong answer rather than an error.
notify	(message: string, title: string, duration: number)	Shows a Matcha notification. This order was confirmed in one session, but another review reported inconsistent argument order across sources; wrap in `pcall` and treat it as cosmetic.
identifyexecutor	(): (string, string)	Returns ("Matcha", version).
getscripthash	(script: Instance): string	FNV-1a 64-bit hash of bytecode.
getgamename	(): string	Returns place title (e.g., "Baseplate").
getscripts	(): { Instance }	Returns all loaded script instances.
getscriptbytecode	(script: Instance): string	Raw compiled bytecode as binary string.
base64encode	(data: string): string	Encodes to Base64. Truncates at first null byte (\0)—destroys binary: `base64encode("a\0b\0c")` returns `"YQ=="` (base64 of `"a"` alone); a 7-byte input with nulls round-trips as 1 byte. Do not pass binary through base64; use raw `httpget` bytes.
base64decode	(data: string): string	Decodes Base64. base64decode("") returns "".
GetPingValue	(): number	Current ping in milliseconds.
tick	(): number	Monotonic high-precision time (not Unix timestamp).
typeof	(value: any): string	Returns specific datatype name (Vector3, CFrame, Instance, Drawing, …) instead of "userdata".
getfenv	(target: function | number): table	Returns environment table. No arg / 0 / 1 returns global environment (_G).
setfenv	(f: function, env: table): function	Sets the environment of function f.
Console & Input
Function	Description
print(...) / printl(...)	Prints to console, space-separated.
warn(...)	Yellow warning-styled line.
error(...) / errorl(...)	Red error-styled line. Does NOT halt execution—only prints. Use assert(false, message) for a catchable error. Via the MCP `matcha_exec` wrapper, any `error()` call flags the whole call `ok:false` even if the script ran to completion.
setrobloxinput(state: boolean)	Toggles whether Matcha's injected input reaches the game.
isrbxactive(): boolean	True while Roblox window is foreground.
setclipboard(value: string)	Copies value to system clipboard.
keypress(keycode: int)	Sends key-down (Windows VK code, e.g., 0x41 = A).
keyrelease(keycode: int)	Sends key-up.
iskeypressed(keycode: int): boolean	True while key is held.
ismouse1pressed() / ismouse2pressed()	Left/right mouse button held.
mouse1press() / mouse1release() / mouse1click()	Left mouse control.
mouse2press() / mouse2release() / mouse2click()	Right mouse control.
mousemoveabs(x, y)	Moves cursor to absolute pixel position in Roblox viewport space.
mousemoverel(x, y)	Moves cursor by relative offset.
mousescroll(amount: int)	Scrolls mouse wheel; sign sets direction.
Miscellaneous & Scheduler
Function	Description
run_secure(text: string)	Runs base64-encoded protected payload. Not usable with ordinary scripts—protection tooling is not public.
setfflag(FFlag, value)	Intended to set fast flag. Incomplete—no effect that getfflag can read.
getfflag(FFlag): number	Stub—returns 0 for every flag.
require(path: string): table (NOT Roblox `require`: `require(<Instance>)` does not return the module; to read a game module use `decompile(instance)` or `getgc`)	Loads .lua/.luau module by path. Extension is required and validated. Resolves from its own module root, separate from writefile/readfile workspace.
wait(time: number)	Yields current thread. Returns elapsed seconds like Roblox's wait (e.g. `wait(0.05)` returns ~0.0505).
spawn(target: function)	Runs target on a new thread immediately.
task.spawn(target: function, ...)	Runs target immediately (synchronously). Forwards extra arguments (verified: `task.spawn(fn, 1, 2)` receives 1, 2).
task.defer(target: function, ...)	Fires (verified). Not a no-op.
task.delay(time, target)	Fires after time (verified with `task.delay(0.1, ...)`). Not a no-op.
task.wait(time?: number)	**Not a frame yield.** With no argument it returns almost immediately (~16 µs per call, a busy yield at ~60 kHz, not synced to the render loop). With N it honors N (min resolution ~1 ms: `task.wait(0.001)` ≈ 1.06 ms, `task.wait(0.2)` ≈ 200 ms). Returns `1.0` regardless of N—NOT elapsed time, so `local dt = task.wait(N)` gives nonsense. For a real ~1 ms yield use `task.wait(0.001)`; for true frame sync use `RunService.Heartbeat:Connect(fn)`.
## Memory

Requires unsafe LuaU execution to be allowed.

| Function | Description |
|----------|-------------|
| getbase(): int | Returns base address of RobloxPlayerBeta.exe module. Functional (verified). |
| memory_write(memoryType, address, value) | Writes value to address as type (int, float, double, byte, string, uintptr_t). Wrong address can crash Roblox. |
| memory_read(memoryType, address): Any | Reads value at address. Functional (verified: `memory_read("int", getbase())` returned 9460301 = 0x00905A4D, the DOS `MZ` header magic). Reading unmapped address safely returns 0. String type reads until first non-printable byte. |

Memory Types: int → int, float → number, double → number, byte → int, string → string, uintptr_t → int.

Garbage Collector
Function	Description
getgc(name: string): { table } / getgc(names: { string }): { table }	Returns every GC value stored under name. Result entries: { key, value, type, addr }.
setgc(key: string, value: Any): int / setgc(values: { [string]: Any }): int	Sets every GC value stored under key. Scans on every call—do not run in loops.
applygc(cache: table, key: string, value: Any): int / applygc(cache: table, values: { [string]: Any }): int	Same as setgc but applies to a cache from getgc. Fast—safe for loops.
GC Modding Guide Summary:

Method 1 (Recommended): getgc once → cache → applygc in loops. Perfect for values the game resets (ammo, recoil).

Method 2 (One-offs): setgc for single modifications. Do not run in loops.

**GC edits only change the CLIENT copy.** `applygc`/`setgc` write into Luau tables in this client. Values the server validates (damage, cooldown, reach, fire rate, movement speed) will not change in effect, because the server applies its own number when the remote fires. Do not offer GC tweaks for combat or other server-validated values unless the user can show the value is client-trusted, and say so up front. `applygc` is broad (it writes the same value to every table carrying the key, not just the one you care about) and there is no automatic restore; respawn or rejoin to reset.

Practical example: For games that rebuild configuration values on respawn, the source recommends refreshing the `getgc` cache and then using `applygc`. The exact key and value depend on the target table and are not specified here.

**Example — cache first, then apply a known key/value:**

```lua
local cache = getgc("KNOWN_KEY") -- replace with a documented target key
-- Inspect/confirm the target before changing anything.
applygc(cache, "KNOWN_KEY", desiredValue)
```

`KNOWN_KEY` and `desiredValue` are placeholders, not literal API values. Memory/GC modification can destabilize the game; use only when the target is understood.

File System
Paths are relative to the Matcha workspace (e.g., C:\matcha\workspace\). / and \ are interchangeable; paths are case-insensitive. Allowed extensions: .txt .lua .luau .json .cfg .dat .ini. Others (.bin, .png, .exe) are rejected with the exact error text `Matcha:<line>: file extension not allowed`—pattern-match on that to handle failures.

Function	Description
writefile(path, content)	Creates/overwrites. Missing parent folders created automatically. Content is binary-safe.
readfile(path): string	Returns contents (binary-safe). Errors if file doesn't exist—guard with isfile or pcall.
appendfile(path, content)	Appends to end. No separator inserted.
makefolder(path)	Creates folder including parents. No-op if exists. Errors if file occupies path.
isfile(path): boolean	True only for existing files.
isfolder(path): boolean	True only for existing folders.
listfiles(path): { string }	Immediate children (not recursive), sorted alphabetically. listfiles("") lists workspace root.
delfile(path): boolean	Deletes file or empty folder. Errors for non-empty folders—use delfolder.
delfolder(path): boolean	Recursively deletes folder and contents. Always returns true.
HTTP
httpget and httppost are synchronous—they block until response. Responses are binary-safe (a real PNG was fetched intact: `89 50 4E 47` magic, 8090 bytes), so they are the safe transport for binary payloads.  Never raise errors: HTTP error status returns server response body; connection failure returns empty string.

Function	Signature
httpget	(url: string, headers?: table): string
httppost	(url: string, body: string, contentType?: string, headers?: table): string — contentType defaults to "application/json".
Full Lua 5.1 Base Library Reference
Matcha runs on a Luau-based VM. Standard Lua(U) globals are available per Lua 5.1 reference.

Math Library
math.abs, math.acos, math.asin, math.atan, math.atan2, math.ceil, math.cos, math.cosh, math.deg, math.exp, math.floor, math.fmod, math.frexp, math.huge, math.ldexp, math.log, math.log10, math.max, math.min, math.modf, math.pi, math.pow, math.rad, math.random, math.randomseed, math.sin, math.sinh, math.sqrt, math.tan, math.tanh.

String Library
string.byte, string.char, string.dump, string.find, string.format, string.gmatch, string.gsub, string.len, string.lower, string.match, string.rep, string.reverse, string.sub, string.upper.

Table Library
table.concat, table.insert, table.maxn, table.remove, table.sort.

OS Library
os.clock, os.date, os.difftime, os.execute, os.exit, os.getenv, os.remove, os.rename, os.setlocale, os.time, os.tmpname.

IO Library
The entire `io` table is absent (nil) in Matcha 1.0.0 despite being part of Lua 5.1. Use `readfile`/`writefile`/`appendfile` instead. `collectgarbage` is also missing.

Key Matcha-specific differences from Standard Lua
Function	Difference
type	Roblox datatypes and Instances report as "userdata"—use typeof for specific name.
tostring	Only Roblox datatypes get fixed 4-decimal formatting: `tostring(Vector3.new(1,2,3))` returns `"Vector3(1.0000, 2.0000, 3.0000)"`. Plain numbers follow standard Lua: `tostring(1.0)` returns `"1"`, `tostring(1/3)` returns `"0.3333333333333333"`.
tonumber	Trims whitespace, parses 0x hex, accepts base (2–36).
pairs	Does not honor Luau __iter metamethod—always iterates raw table.
unpack	Exposed as global (mainline Luau only provides table.unpack).
assert	Raises catchable error (Matcha: or assertion failed!)—the way to raise a catchable error in Matcha.
pcall	Returns false, "Matcha: ..." on runtime fault.
newproxy	Lua 5.1 holdover, fully supported.
Drawing API
Function	Description
Drawing.new(drawingType: string): DrawingObject	Types: Square, Line, Circle, Text, Triangle, Image.
DrawingObject:Remove()	Removes the drawing.
Shared properties: Color (Color3), Transparency (number), Visible (bool), Position (Vector2), ZIndex (int).
Square: Size (Vector2), Filled (bool).
Line: From (Vector2), To (Vector2), Thickness (int).
Circle: Radius (float), NumSides (int), Thickness (int).
Text: Text (string), Outline (bool), Center (bool), Font, FontSize (int).
Triangle: PointA, PointB, PointC (Vector2).
Image: Data (string, raw binary), Size (Vector2, default 50x50), Rounding (number, default 0).

Fonts (index map; use `Drawing.Fonts.<Name>` or the number): UI=0 (ProggyClean), System=1 (San Francisco), SystemBold=2, Minecraft=4, Monospace=5 (JetBrains), Pixel=7, Fortnite=8, ProximaSoftBold=11. Indices 3, 6, 9, 10 do not exist (count = 8); `Font = 3` fails silently.

**Example — draw a red line:**

```lua
local line = Drawing.new("Line")
line.From = Vector2.new(100, 100)
line.To = Vector2.new(200, 200)
line.Color = Color3.fromRGB(255, 0, 0)
line.Visible = true
```

UI Binding (Menu Binding)
Create custom menu tabs, widgets, sections and hotkey keybinds directly from Lua. Source: MatchaScripts Repository (github.com/cconstellation/MatchaScripts). Signatures below are from the current official docs (checked Oct 21 2026). **Argument order: `id` first, then the label.**

```lua
UI.AddTab("My Script", function(tab)
    local sec = tab:Section("Settings", "Left")
    sec:Toggle("enabled", "Enabled")
    sec:Keybind("enabled_kb", 0x46, "hold")
    sec:SliderInt("range", "Range", 1, 5000, 2000)
end)
```

Global functions:
- `UI.AddTab(name: string, fn: function)` creates a custom tab. `fn(tab)` runs every frame to render and update the tab.
- `UI.RemoveTab(name: string)` removes a tab.
- `UI.GetValue(id: string): any` reads a widget's current value from anywhere in the script.
- `UI.SetValue(id: string, value: any)` sets a widget's value programmatically.

Sections: `tab:Section(name, side)` where `side` is `"Left"` or `"Right"` and is REQUIRED (a section without a side leaves the tab empty). Pass an array of page names as a third argument for a tabbed section (check `sec.page` to render widgets per page: `0`, `1`, ...); pass `max_height` as a fourth argument for a scrollable section. A section closes automatically when a new section begins.

```lua
local sec = tab:Section("Aimbot", "Left", {"Main", "Advanced"}, 400)
if sec.page == 0 then
    -- Main page widgets
elseif sec.page == 1 then
    -- Advanced page widgets
end
```

Every widget method returns an object: `w.value`, `w:GetValue()`, `w:SetValue(v)`. All widgets accept an optional `callback` as the last argument.

| Widget | Signature | Callback args |
|---|---|---|
| Toggle | `sec:Toggle(id, label [, default: boolean] [, callback])` | `state` |
| Keybind | `sec:Keybind(id [, key: VK number or Enum.KeyCode] [, type: "toggle"/"hold"/"always"/"click"])` must be placed directly after a Toggle | none |
| SliderInt | `sec:SliderInt(id, label, min, max [, default] [, callback])` | `value` |
| SliderFloat | `sec:SliderFloat(id, label, min, max [, default] [, format: "%.1f"] [, callback])` | `value` |
| Combo (dropdown) | `sec:Combo(id, label, items: table [, default: 0-based index] [, callback])` | `index, text` |
| Button | `sec:Button(label [, callback])` or `sec:Button(label, width, height [, callback])` | none |
| ColorPicker | `sec:ColorPicker(id [, r, g, b, a] [, callback])` must follow a Toggle; values 0-1 | `Color3, alpha` |
| ColorPicker2 | `sec:ColorPicker2(id1, {r,g,b,a}, id2, {r,g,b,a} [, callback])` must follow a Toggle | `c1, a1, c2, a2` |
| InputText | `sec:InputText(id, label [, default] [, callback])` | `text` (fires when the field loses focus) |
| Text / Tip / Spacing | `sec:Text("label")`, `sec:Tip("tooltip for previous widget")`, `sec:Spacing()` | n/a |

Keybind object: `.value`/`:IsEnabled()` (active now), `:GetKey()`, `:SetKey(vk)`, `:GetKeyName()`, `:GetType()`, `:SetType(typeStr)`, `:AddToHotkey(label, toggle_id)` (shows in the on-screen hotkey overlay while the toggle is on), `:RemoveFromHotkey()`. Key codes: VK `0x01` LMB, `0x02` RMB, `0x04` MMB, `0x41`-`0x5A` A-Z; or `Enum.KeyCode.MouseButton1`/`A`-`Z`. Combo object: `c:Add(item)`, `c:Remove(item)`, `c:Clear()`, `c:GetItems()`, `c:GetText()`, `c:SetValue(index)`.

Reading values in a loop (the common pattern):
```lua
while true do
    if UI.GetValue("aim_on") then
        local fov = UI.GetValue("aim_fov")
        -- logic here
    end
    wait()
end
```

Example with callbacks:
```lua
UI.AddTab("Demo", function(tab)
    local sec = tab:Section("Objects", "Left")
    local t = sec:Toggle("demo_t", "Toggle", false, function(state) print("toggle", state) end)
    local s = sec:SliderInt("demo_s", "Slider", 0, 100, 50)
    local c = sec:Combo("demo_c", "Combo", {"A", "B", "C"}, 0)
    sec:Button("Reset", function()
        UI.SetValue("demo_t", false)
        UI.SetValue("demo_s", 50)
    end)
end)
```

**Matcha UI rules that prevent crashes and blank menus:** the tab callback runs every frame, so create widgets in a way that is safe to repeat (build once behind a flag, or rely on the widget ids), wrap the body in `pcall`, and keep widget counts reasonable. See "Menu Binding: Practical Rules" below. A previous AI session observed a different argument order (extra string before the boolean) and callbacks that passed unexpected arguments; the official docs above are authoritative, so if a call errors, read the exact error text and fix the call rather than guessing variants.

Roblox Classes Reference
Matcha emulates a subset of Roblox classes. These are accessed via game:GetService() or through Workspace, Players, etc.

Class	Properties / Methods
BasePart	Size (Vector3), Position (Vector3), Transparency (number), Color (Color3), Velocity (Vector3), AssemblyLinearVelocity (Vector3), CanCollide (bool), CFrame (CFrame), Anchored (bool), Material (Enum).
Camera	lookAt(at: Vector3, lookAt: Vector3), ViewportSize (Vector2), FieldOfView (number), Position (Vector3), CFrame (CFrame), Focus (CFrame).
DataModel	PlaceId, GameId, JobId, HttpGet, HttpPost, GetService(name), IsLoaded(): boolean, FindService(name).
HttpService	JSONEncode(tbl), JSONDecode(str), GenerateGUID().
Humanoid	MaxHealth (number), Health (number), WalkSpeed (number), JumpPower (number), MoveTo(position: Vector3, part?: BasePart), TakeDamage(amount: number). Observed: `Health` is readable but writing it fails; writing `WalkSpeed`/`JumpPower` errors; `Sit` reads nil and writing it errors with Unknown property. Treat humanoid state as read-only unless a test proves otherwise.
Model	PrimaryPart (BasePart), GetChildren(), FindFirstChild(name), WaitForChild(name).
Workspace	CurrentCamera (Camera), Raycast(origin, direction, params?): RaycastResult?, Gravity (number), FallenPartsDestroyHeight (number).
Lighting	Ambient (Color3), ClockTime (number), Brightness (number), GlobalShadows (bool), GetSunDirection().
Players	LocalPlayer (Player), GetPlayers(), GetPlayerFromCharacter(character).
RunService	IsClient(), IsServer(), IsStudio(), Heartbeat, RenderStepped, Stepped.
UserInputService	IsKeyDown(keyCode), GetMouseLocation(), MouseBehavior.
TweenService	Create(instance, info, propertyTable).
TeleportService	Teleport(placeId, player, teleportData).
MarketplaceService	PromptPurchase(player, assetId).
Datatypes Reference
Vector3
Constructors: Vector3.new(x,y,z), zero, one, xAxis, yAxis, zAxis.

Properties: X, Y, Z, Magnitude, Unit.

Operations: +, -, *, / (vector-vector and vector-number), unary minus, ==.

Methods: Abs, Angle, Ceil, Cross, Dot, Floor, FuzzyEq, Lerp, Max, Min, Sign.

Vector2
Constructors: Vector2.new(x,y), zero, one.

Properties: X, Y, Magnitude, Unit.

Operations: +, -, *, / (vector-vector and vector-number), unary minus, ==.

Methods: Abs, Angle, Ceil, Cross, Dot, Floor, FuzzyEq, Lerp, Max, Min, Sign.

CFrame
Constructors: CFrame.new(), CFrame.new(x,y,z), CFrame.Angles(rx,ry,rz), CFrame.fromEulerAnglesXYZ(rx,ry,rz), CFrame.lookAt(at, lookAt, up?).

NOTE: `CFrame.new(Vector3)` is NOT supported here (it errors with `CFrame.new expects 0, 3, 6, or 12 arguments`). Always pass three numbers: `CFrame.new(x, y, z)`.

Properties: X, Y, Z, LookVector, RightVector, UpVector, Position.

Operations: * (CFrame * CFrame, CFrame * Vector3), + (CFrame + Vector3), - (CFrame - Vector3), ==.

Methods: Inverse, Lerp, ToWorldSpace, ToObjectSpace, ToEulerAnglesXYZ, ToOrientation.

Color3
Constructors: Color3.new(r,g,b), Color3.fromRGB(r,g,b), Color3.fromHSV(h,s,v), Color3.fromHex(hex).

Properties: R, G, B.

Methods: Lerp, ToHSV, ToHex.

Instance
Properties: Name, Parent, ClassName, Archivable, Address (readable identity; see Instance Identity below). Setting `Parent = nil` errors (`invalid argument #3 (Instance expected, got nil)`); reparenting to a real service/instance works and holds.

Methods: FindFirstChild(name), WaitForChild(name), GetChildren(), GetDescendants(), IsA(className), Destroy(), Clone(). Observed missing: `Model:GetPivot()` and `Instance:HasTag()` error with `attempt to call missing method`; `Clone`/`Destroy` and instance events such as `.Touched` were reported as non-functional in practice, so do not build on them. Observed: `IsA()` ignores its argument and returns true for everything, so use `inst.ClassName == "Tool"` (etc.) instead. `Address` (readable) is the reliable identity key.

Events: Changed, ChildAdded, ChildRemoved, DescendantAdded, DescendantRemoving.

Drawing
See Drawing API section above.

VM Limitations & API Differences
Matcha is an external emulator—it does not inject into or hook Roblox engine memory functions.

Feature / Pattern	Supported?	Replacement / Workaround
Instance.new()	❌ No	`Instance` is nil (`Instance.new("Part")` errors with `attempt to index nil with 'new'`). Read from the live DataModel instead. Vector3/CFrame/Color3 constructors still exist
game:HttpGet() / game:HttpPost()	❌ No	Use httpget(url) / httppost(url, data, contentType)
loadstring()	⚠️ Partial	Top-level returns drop; syntax errors are uncatchable by pcall and print only on call. Pass results via globals
RunService.Stepped	⚠️ Partial	Receives 1 arg (deltaTime) instead of 2 (time, deltaTime)
base64encode()	⚠️ Partial	Truncates at first \0 byte—destroys binary. Use raw httpget bytes
inst1 == inst2	✅ Yes	Direct comparison supported (fixed Aug 6, 2026)
GetAttribute()	✅ Yes	Supported (fixed Aug 6)
SetAttribute()	✅ Yes	Supported (fixed Aug 6)
RemoteEvent:FireServer	✅ Yes	Supported in Pro Hybrid mode
RemoteFunction:InvokeServer / InvokeFunction	✅ Yes	Supported in Pro Hybrid mode (fixed Sep 11, 2026)
## Executor Global Support (live-tested on Matcha 1.0.0)

Results below come from live testing on Matcha 1.0.0 (place 135564683255158, Prison Life, hybrid mode). Presence was checked via `_G[n]` with a `loadstring("return "..n)()` fallback. They take precedence over older statements elsewhere in this file where they conflict. Re-verify after Matcha or Roblox updates.

### PRESENT — 49 core globals plus UI and Memory

```
Core:        loadstring, load, decompile, getscriptbytecode,
             getscripthash, getscripts, require, typeof, tick, wait, spawn
GC:          getgc, setgc, applygc
Env:         getfenv, setfenv
Filesystem:  writefile, readfile, appendfile, makefolder, isfile,
             isfolder, listfiles, delfile, delfolder
HTTP:        httpget (binary-safe), httppost
Input:       keypress, keyrelease, mouse1press/release/click,
             mouse2press/release/click, mousemoveabs, mousemoverel,
             mousescroll, iskeypressed, ismouse1pressed, ismouse2pressed,
             setrobloxinput, isrbxactive
Draw:        Drawing (all 6 types), WorldToScreen
UI:          UI.AddTab, UI.RemoveTab, UI.GetValue, UI.SetValue
Memory:      getbase, memory_read, memory_write (memory_write not exercised; wrong address crashes Roblox)
Misc:        identifyexecutor, getgamename, GetPingValue, setclipboard,
             run_secure, notify, base64encode, base64decode,
             setfflag (no-op), getfflag (always 0)
```

### ABSENT — nil globals (any script depending on these will error)

```
Instance:    Instance itself (the constructor; no datatype creation)
Metatable:   hookfunction, hookmetamethod, getrawmetatable,
             setrawmetatable, setreadonly, isreadonly,
             getnamecallmethod, newcclosure, checkcaller,
             islclosure, iscclosure, clonefunction
Environment: getgenv, getrenv, getsenv, getreg, getmenv,
             getupvalue, setupvalue, getupvalues, getconstants
Discovery:   getinstances, getnilinstances, getloadedmodules,
             getmodules, getcustomasset, getallthreads
Thread:      getthreadidentity, setthreadidentity, setidentity, getidentity
Remote:      getconnections, firesignal, getsignal, getcallbackvalue,
             getcallingscript
Network:     request, http_request, httprequest, syn,
             HttpGet, HttpGetAsync, HttpPost
Crypto:      crypt, hash, lz4compress, lz4decompress, md5, sha1, sha256
Scripts:     getfflags, getrunningscripts, getallscripts,
             getloadedscripts, getscriptfromthread,
             getscriptfromfunction, getscriptfromremote,
             register, unregister, getscriptfunction, getscriptclosure
Player:      getplayer, getplayers, getchar, getcharfromplayer,
             getnamefromplayer
GUI:         gethui, getgui, cleardrawcache, isrenderobj,
             getrenderproperty, setrenderproperty
Clipboard:   getclipboard, getexecutorname, messagebox,
             setfpscap, getfpscap, getwindow, getpixel
```

**Consequences:** no hooking means no namecall-based hooks; no `getconnections` means no signal/remote replay. NOTE: the interaction functions `fireproximityprompt`, `fireclickdetector` and `firetouchinterest` were ABSENT in the earlier live tests but were released for Pro on Oct 21 2026. If `type(fireproximityprompt) ~= "function"`, the user needs to rerun the Matcha loader (they already have Pro); do not assume they are missing forever. Matcha's design is "do it with input, drawing and DataModel reads, nothing else." Do not write scripts that depend on any global in the absent list.

### Lua stdlib trim

```
Missing:  io (entire table), collectgarbage,
          task.cancel, task.desynchronize, task.synchronize,
          debug.getupvalue, debug.setupvalue
          (the `debug` table exists but only has `traceback`)
Present:  os, string, table, math, coroutine, bit32, utf8,
          rawget, rawset, rawequal, setmetatable, getmetatable,
          pcall, xpcall, select, newproxy, assert, warn, error
```

### Verified behavior details
- `loadstring("this is not valid")` returns a function; calling it prints `Matcha:1: Incomplete statement...` and returns nil. `pcall` of it gives `ok=true, err=nil`. `loadstring("__g = 42")()` sets `__g`; `loadstring("return 1+1")()` returns nil.
- `getgc("Players")` returned 172 entries and `getgc({"Players","Workspace"})` 388, each shaped `{ key, value, type, addr }` with a numeric `addr`. An unknown name returns 0 entries.
- `getfenv(0)`, `getfenv(1)` and `getfenv(print)` all return tables. `setfenv(function() return X end, {X=5})()` returns 5.
- `httpget` custom headers work. A bad host and an empty-body 404 both return `""` and cannot be told apart.
- `decompile` works on real scripts (a ModuleScript returned 1,163 chars); `getscriptbytecode` returned binary (210 bytes for one script); `getscripthash` returns a FNV-1a 64 hash.
- `tostring(1.5)` is `"1.5"` and `tostring(0.0001)` is `"0.0001"` (standard Lua `%.14g`).
- `Font = 3` or `Font = 6` is a silent no-op.
- `setfflag` writes nothing readable (reads back 0); `getfflag` returns 0 for every key.

### Behavioral corrections vs the doc

These were corrected in place above; the table is a quick summary.

| Item | Live-tested behavior |
|---|---|
| `task.wait()` | Returns in ~0.016ms — NOT a frame yield |
| `task.wait(N)` | Honors N (min resolution ~1ms) |
| `task.wait(N)` return | `1.0` (not "nothing") |
| `wait(N)` return | Elapsed seconds (not "nothing") |
| `task.defer` | FIRES (doc says no-op) |
| `task.delay` | FIRES (doc says no-op) |
| `task.spawn(fn, ...)` | FORWARDS args (doc says it doesn't) |
| `loadstring(src)()` | Top-level return is DROPPED even for `"return 1+1"`; only global assignment survives |
| `base64encode` | Truncates at first `\0` — confirmed 7 -> 1 byte |
| `writefile` | Allowed: `.txt .lua .luau .json .cfg .dat .ini`. Error text: `"Matcha:<line>: file extension not allowed"` |
| `Drawing.Fonts` | UI=0, System=1, SystemBold=2, Minecraft=4, Monospace=5, Pixel=7, Fortnite=8, ProximaSoftBold=11 (indices 3, 6, 9, 10 are holes) |
| `WorldToScreen` | Returns `(0,0), false` for behind-camera AND far off-axis |
| `error(msg)` | Continues execution; MCP wrapper flags `ok:false` |
| `pcall(loadstring(bad))` | Returns `true, nil`; invalid chunks cannot be detected programmatically |
| `httpget` | Binary-safe |
| `os.clock()` | Wall time (delta across `task.wait(0.5)` = 0.5023); safe for deltas |
| `tostring(number)` | Standard Lua (`1.0` -> `"1"`); only datatypes are padded |

## Roblox-General Pitfalls (not Matcha-specific, but hit constantly)

### R6 vs R15 part names
R6 uses names with spaces: `"Right Arm"`, `"Left Arm"`, `"Right Leg"`, `"Left Leg"`. R15 has no spaces: `RightUpperArm`, `RightLowerArm`, `RightHand`, etc. Enumerate both or code silently fails on one rig type.

### Rig-agnostic directions
- Arm axis: `(Hand.Position - UpperArm.Position).Unit` works on both rigs regardless of CFrame rotation.
- Character right: `HumanoidRootPart.CFrame.RightVector` is the only stable one; head, torso and arm CFrames rotate with their own look/twist/swing.
- Aim direction: `Camera.CFrame.LookVector`, not character facing (third-person games decouple them).

### R6 arm LookVector
In R6, an arm's `CFrame.LookVector` does not point down the arm; it points outward or backward depending on pose. Anchoring a point to it lands behind and to the side. Use the shoulder-minus-hand axis instead.

## Transparency, Raycast and Visibility-Check Patterns

### LocalTransparencyModifier
Many games hide blockers by setting `LocalTransparencyModifier = 1` while leaving `Transparency = 0`. A see-through check reading only `Transparency` misses these. Read both, each wrapped in `pcall`:

```lua
local tr, ltm
pcall(function() tr = inst.Transparency end)
pcall(function() ltm = inst.LocalTransparencyModifier end)
if (tr and tr >= 0.95) or (ltm and ltm >= 0.8) then return true end
```

### Tinted glass
Tinted car windows sit at 0.2-0.6 transparency, so an 0.8 threshold misses them. If the part name or material looks like glass, use a threshold of 0.15 and treat it as transparent. Name keywords: glass, window, windshield, windscreen, visor, pane, tint, carwin, screen, clear.

### CanQuery, CanCollide and raycasts
- `CanQuery = false`: default `Workspace:Raycast` skips the part.
- `CanCollide = false`: raycasts still hit it unless `RespectCanCollide = true`.
- Multi-bounce walks need a bounce cap (5) and an epsilon (0.1 studs) between hits, or they loop forever or tunnel through thin geometry.

### Passing through other players
Pre-index every character's BaseParts into a flat `[Instance] = true` set once per collector tick, so "is this part on another player" is an O(1) lookup instead of an 8-hop parent walk per bounce. Walking `.Parent` also fails silently if a part is temporarily unparented during ragdoll/respawn.

## Property and Tree Levers (observed by direct test)

Writes to Roblox properties are not a faithful emulation of Studio. Observed behavior in a live session; re-test on your build before relying on any of it.

| Lever | Result | Note |
|---|---|---|
| `inst.Parent = nil` | Errors | `invalid argument #3 (Instance expected, got nil)` |
| `inst.Parent = <service or instance>` | Works and holds | The real way to remove something from its current place in the tree |
| `BasePart.CanTouch` write | Unknown property | Do not rely on it |
| `Humanoid.Sit` read | nil | Silent fallback, not an error |
| `Humanoid.Sit` write | Unknown property | |
| `Humanoid.Health` write | Fails | Readable, not writable |
| `Humanoid.WalkSpeed` / `JumpPower` write | Errors | |
| `inst.Address` read | Works | The reliable identity key |

Size and CanCollide writes on BaseParts worked in-place in the tested scenario. Property availability varies by class and build, so probe with `pcall` and read the value back after a wait.

## Instance Identity and Stale Data

- **Instance comparison.** The official docs (updated Aug 6 2026) say `instA == instB` is fully supported and `.Address` no longer has to be compared manually. One earlier session still saw equality fail on stale wrappers after reparenting, so treat `==` as supported but, for stale or reparented objects and for table keys, key by `inst.Address` (or `Player.UserId` for players) as the safe fallback.
- **Stale `GetDescendants`/`GetChildren` results.** After reparenting, a previously fetched list (or a count from it) can contain dead references, so a fresh count can be wrong. Confirm a reparent by comparing `.Address` sets before and after. Same addresses still out of the tree means the objects stayed moved; do not conclude the game "rebuilt" them from a count.
- **Prove a lever over a wait window.** Acting on an immediate read is the most common source of wrong conclusions. Apply the change, wait (for example 0.5-2 s), then re-read by `.Address` before building on it.

## Replication and Network Ownership Caution
Reparenting or moving a part that is under another client's or the server's network ownership can break replication; the object may snap back or desync when ownership resolves. If a script desyncs, first look for a `Parent` write or a `Position` write on a physics-simulated part. Prefer in-place property changes (such as `Size`, `CanCollide`) over reparenting or repositioning, and verify them over a wait window.

## Confirmed Absent (stop probing these)
- No `Instance` at all (not even `Instance.new`); every overlay must be built with `Drawing`.
- No hooking: `getrawmetatable`, `hookfunction`, `hookmetamethod`, `newcclosure`, `checkcaller` are all nil.
- `debug` exists but only has `traceback`.
- No `getgenv`/`getrenv`/`getinstances`, and no collision-group or physics-control API. (Touch, click-detector and proximity-prompt firing now exist for Pro: see F9.)
- Memory is only `getbase`, `memory_read`, `memory_write`: no scan, no AOB scan.
- A probe of ~150 candidate names found nothing undocumented beyond what this file lists. Treat this file as the ceiling of what the executor offers.

## VM Quirks That Break Ported Scripts
- `IsA()` ignores its argument and returns true for everything. Filters like "is this a Tool" silently accept any child. Compare `ClassName` instead.
- `loadstring` drops top-level returns, so the common `pcall(chunk)` / `local ok, result = pcall(loadstring(src))` loader pattern yields nil. Have the chunk assign to `_G` and read it afterward.
- `UserInputService.InputBegan` passes an input table with only `.KeyCode` (integer): no `gameProcessed` and no `UserInputType`.
- `notify(message, title, duration)` is the correct argument order.

## Testing and Probing Pitfalls
- **Existence vs behavior.** Test that a global exists (`type(x) ~= "nil"`) separately from testing what it does. A round-trip test can fall back to `_G` and pass even when the function under test (for example `getgenv`) is missing.
- **Harness note bug.** A pattern like `return condition, "mismatch"` returns the failure text whether the check passed or failed. Print notes only on failure, or a pass can look like a failure (99 passes once looked like 99 failures).
- **Cross-run contamination.** Output from a script still running from an earlier exec can pollute a later test. Stop or confirm earlier scripts finished before measuring.
- **Check presence two ways.** Use `_G[name]` and a `loadstring("return "..name)()` fallback, then record both results.

## Signals and Missing Methods (observed errors)

| Call | Result |
|---|---|
| `RunService.Heartbeat:Wait()` | Error: `attempt to call missing method 'Wait' of table` |
| `RunService.Heartbeat:Connect(fn)` | Works |
| `RunService.RenderStepped:Connect(fn)` | Works; the place `WorldToScreen` is reliable |
| `Model:GetPivot()` | Error: missing method of Instance |
| `Instance:HasTag()` | Error: missing method of Instance |
| `Instance:IsA(class)` | Silently returns true for everything; use `ClassName == "Foo"` |
| `CFrame.new(Vector3)` | Error: `CFrame.new expects 0, 3, 6, or 12 arguments` |

Rules: never `:Wait()` on any signal. To find a child use `FindFirstChild` by name; to detect a BasePart check `.Position ~= nil and .Size ~= nil`. A `CFrame.new` error inside a `pcall` in a loop can kill that thread silently, so validate argument shapes.

## Recognise These Exact Errors

| Error text | Meaning |
|---|---|
| `attempt to call missing method 'Wait' of table` | Signals have no `:Wait()`; use `:Connect` |
| `attempt to call missing method 'GetPivot' of Instance` | `GetPivot` does not exist |
| `attempt to call missing method 'HasTag' of Instance` | `HasTag` does not exist |
| `CFrame.new expects 0, 3, 6, or 12 arguments` | A Vector3 was passed; use `CFrame.new(x, y, z)` |
| `invalid argument #3 (string expected, got boolean)` | A widget call has its arguments in the wrong order; use `sec:Toggle(id, label, default, callback)` (id first, then the label string, then the boolean) |
| `invalid argument #3 (Instance expected, got nil)` | `Parent = nil` is not allowed; reparent to a real instance |
| `attempt to index nil with 'new'` | `Instance` is nil; nothing is constructible |
| `Matcha:<line>: file extension not allowed` | `writefile` rejected the extension |
| `attempt to index nil` | A link in your chain is missing; print each step |
| `attempt to call a nil value` | That global or function does not exist in this VM |

## Output Capture and Timing in the MCP Exec Tool
- `matcha_exec` returns only what `print()` emitted, and capture closes about 350 ms after the last print. Print incrementally; do not buffer a final report. Check `matcha_logs` for anything a spawned loop emits later.
- A top-level `task.wait` in an exec does not yield the way it does in a normal script; spawn a loop and read logs instead.
- One batched exec with many prints beats many single-print calls.

## Menu Binding: Practical Rules
Use the official signatures in "UI Binding (Menu Binding)" (id first, then label; Section needs a side). Practical lessons from real sessions:
1. **Build safely.** The tab callback runs every frame. Build widgets behind a flag or in a way that is safe to repeat, wrap the whole body in `pcall`, and keep widget counts modest. A tab-open crash was traced to too many widgets; test with a handful first and scale up (building ~200 toggles synchronously is a risk).
2. **Section needs a side.** `tab:Section(name)` without `"Left"`/`"Right"` can leave the tab blank (a script fix was "Section needs a side"). Always pass the side.
3. **Poll as the source of truth.** Reading `UI.GetValue(id)` every ~0.1 s is more robust than relying on callbacks; use the callback only for immediate side effects. If you must use the callback, the first argument is the state for a Toggle.
4. **Callbacks only set flags.** No `wait`, no input, no teleports and no heavy work inside a widget callback. Do all waiting in one spawned loop.
5. **No debounce.** A debounce on callbacks dropped clicks and looked like a stuck toggle.
6. **ColorPicker** gives a Color3 plus alpha; guard with `typeof(c) == "Color3"`.
7. **Log on change** so a broken wire is visible in the console.
8. **Button** is `sec:Button(label, callback)`. Do not insert an id.
9. A helper that retries argument variants is only a last resort when an exact error shows the signature differs on the user's build; prefer fixing the call from the error text.

## Investigation Playbook (finding what a game does)
Order that worked repeatedly:
1. `matcha_status` once: confirm in-game and hybrid mode (needed for `FireServer`).
2. Map remotes: search with an empty query plus a `ClassName` filter (`RemoteEvent`, then `RemoteFunction`).
3. If remotes are grouped under a ModuleScript that returns a table, that module is the authoritative list; decompile it.
4. To learn a remote's argument shape, decompile the client script that fires it and read the exact `FireServer(...)` line.
5. Dump `LocalPlayer:GetAttributes()`: it often exposes the whole progression state (counts, levels, perks).
6. For a model, `matcha_tree` at depth 1-2, then identify the part the game actually raycasts rather than the decorative one.
7. Distinguish states by combining an attribute (for example HP > 0) with a structural child (present/absent).
8. Batch many prints into one `matcha_exec`.
9. `getgc`/`applygc` only rewrite the client's copy. Server-authoritative values (damage, cooldowns, reach) will not change, so do not offer GC tweaks for combat values unless the user can show they are client-trusted.

## Always True of Matcha Scripts
- Never use an Instance as a table key or compare with `==`; key by `UserId`, `.Address` or a path string.
- Drawing objects are created once and pooled; creating them in a loop leaks until the VM restarts. Call `:Remove()` when done.
- Every loop must yield: a bare `while true do end` is killed at about 5 s. Use `task.wait(0.005)` or more in ESP/overlay loops if the overlay looks choppy.
- `game:GetService` works; `Instance.new`, `Clone`, `Destroy`, `.ChildAdded`, `.Touched` and `PlayerAdded` should not be relied on. To watch joins, poll `Players:GetPlayers()` and diff.
- Build scripts print-incremental, and give long scripts a `_G.<Name>.stop()` so the user can kill them without rejoining.

## Design Defaults for Generated Scripts
- Deliver full scripts, never diffs: copy-paste ready, one fenced block.
- Menu-only control; no keybinds unless asked.
- Widget count is a spec: if the user says 6 toggles, ship 6.
- No sliders for tunables unless asked; hardcode them as named constants at the top.
- Automation defaults ON; risky extras (teleports, GC edits) default OFF.
- Every sell/teleport/remote feature prints a one-line confirmation so "did not run" is distinguishable from "ran and was rejected".
- State unverified assumptions explicitly and name the one line to change if a remote argument or attribute name is wrong.

## Scheduler Performance Warning
A bare `task.wait()` loop that fires remotes does so as fast as the VM schedules and can starve the Drawing overlay (choppy ESP). If visuals look choppy, that loop is the usual cause; `task.wait(0.005)` keeps it fast and frees frames.

Because bare `task.wait()` is a ~16 µs busy yield, `while running do ... task.wait() end` spins at ~60,000 iterations per second and starves the scheduler (a direct cause of lag). Use `task.wait(0.001)` or a `Heartbeat`/`RenderStepped` `:Connect` callback in hot loops (never `:Wait()` on a signal).

## GitHub Delivery Workflow: Reference

The delivery rule at the TOP of this file is authoritative; if anything below conflicts with it, follow the top block. This section keeps the loader variants, skeleton, failure table and checklist.

Purpose: deliver scripts as a one-line loader the user pastes into the executor, with the source stored in their GitHub repo. Benefits: no pasting long code, every change is a commit with rollback, and history is browsable. Use this by default when the user has a repo and a GitHub tool/connector is available. Ask once for `<owner>/<repo>`, then reuse it for the rest of the conversation. Placeholders below (`<owner>`, `<repo>`, `<file>`, `<Name>`) must be replaced with the user's real values.

### Core rules
- Push the file, then reply with only the loader line (the exact form in section 2 at the top of this file), not the code. No changelog, version or stop command in the reply.
- The URL never changes between updates: same filename, same branch, overwritten in place. Never version filenames (`(1)`, `v2`); a stale copy gets cached and you end up debugging the wrong file.
- Never write to the user's repo unless asked. Reading is safe; pushing is a side effect. Confirm filename and commit message before a write.
- Verify a write happened (the blob sha changed, or the raw file shows the new version stamp) before saying "pushed".
- Scripts must be safe to make public: never commit tokens, webhooks, HWIDs or other secrets.

### Repo layout and naming
- Flat files at the repo root on `main`; no folders unless asked. One file per game/script.
- File names are the plain game name in Title Case with no extension (see section 5 at the top). Spaces become `%20` in raw URLs.
- Only touch a `README.md` if the user asks; do not add script listings or logs on your own.
- Raw URL pattern: `https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>`. Raw URLs are case-sensitive. A 404 means wrong branch, case or path.
- URL encoding: space `%20`, `#` `%23`, `?` `%3F`, `&` `%26`, `%` `%25`.

### Loader forms
The user's default loader is the cache-busted Hub loader from section 2 (`game:HttpGet(url .. "?v=" .. tostring(os.time()), true)`); see sections 11 and 12. If it errors with `attempt to call a nil value` in Matcha, switch to the Matcha-native `httpget` form. The cache-buster, hardened and chunkname variants below are only for when the user asks for them or reports the matching problem.

```lua
-- Matcha-native (default for Matcha)
loadstring(httpget("https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>"))()

-- Common executor form (only if the user says it works for them)
loadstring(game:HttpGet("https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>", true))()
```

The loader must stay one line, paste-able on its own, with the two call parentheses after `loadstring(...)`.

**Cache-buster** (raw.githubusercontent.com caches for minutes; if the user sees old behavior, the cache is stale, not the push):

```lua
local u = "https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>"
loadstring(httpget(u .. "?v=" .. tostring(os.time())))()
```

**Hardened loader** (when the user reports "loaded but nothing happens"). `httpget` never throws: on a 404 or connection failure it returns `""`, and `loadstring("")` returns a function that does nothing.

```lua
local u = "https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>"
local src = httpget(u .. "?v=" .. tostring(os.time()))
if src == nil or #src == 0 then
    warn("[loader] empty response - check path/branch")
else
    local fn = loadstring(src, "<Name>")
    if fn then pcall(fn) else warn("[loader] compile failed") end
end
```

Passing a chunkname as the second `loadstring` argument makes console errors read `<Name>:42: ...` instead of `Matcha:42: ...`. For a private repo, raw URLs need an Authorization header (`httpget(u, {["Authorization"] = "Bearer <token>"})`); never hardcode a token in a script given to the user, and prefer a public repo since scripts should contain no secrets.

### Script contract for loader-loaded files
- No top-level `return` (dropped by `loadstring`); communicate through globals.
- Register one uniquely named global, set only after successful init: `_G[NAME] = { stop = stop, version = VERSION }`, so two scripts can run together.
- Print a version stamp at load, for example `print("[" .. NAME .. "] loaded " .. VERSION)`. It is the only reliable confirmation a push took effect, since syntax errors are uncatchable and an empty `httpget` is silent.
- Reload-safe: at the top, `if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end`. Keep `stop` synchronous; observed behavior is that a top-level `task.wait` (or `:Wait()`) throws or misbehaves, so if a wait is unavoidable wrap the sequence in `task.spawn`.
- Three-part `stop()`: set `running = false`, `:Disconnect()` every stored connection, `:Remove()` every Drawing object. Route every `:Connect` through a `trackConn` helper and every `Drawing.new` through `trackDraw`, and `pcall` everything inside `stop`.

```lua
-- <file>
local VERSION = "<name> v1 <timestamp>"
local NAME    = "<Name>"
if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end   -- no wait here
local running = true
local conns, drawings = {}, {}
local function trackConn(c) conns[#conns+1] = c; return c end
local function trackDraw(d) drawings[#drawings+1] = d; return d end
local function stop()
    running = false
    for i = 1, #conns do pcall(function() conns[i]:Disconnect() end) end
    conns = {}
    for i = 1, #drawings do pcall(function() drawings[i]:Remove() end) end
    drawings = {}
    print("[" .. NAME .. "] stopped")
end
-- ... services, config, menu, loops ...
-- every :Connect -> trackConn(RunService.Heartbeat:Connect(fn))
-- every Drawing -> local box = trackDraw(Drawing.new("Square"))
_G[NAME] = { stop = stop, version = VERSION }
print("[" .. NAME .. "] loaded " .. VERSION)
```

### Pushing updates (GitHub tool calls)
Tool names depend on the connector; these are the common ones.
- **Single file:** `create_or_update_file`. Creating needs no sha; updating needs the current blob sha, so call `get_file_contents` on the same path and branch first. A missing sha is the most common failed update.
- **Several files:** `push_files` (one commit, array of `{path, content}`, no sha handling).
- **Risky rewrite:** `create_branch` from `main`, commit there, `create_pull_request`, merge after the user tests.
- **Delete a file:** `delete_file` exists (owner, repo, path, message, branch). Deleting or renaming the repo, changing visibility, webhooks, secrets, force-push and branch protection are not available through these tools.
- **Commit messages:** `<script>: v<N> <what changed>`, for example `my-game-esp: v3 fix sell teleport CFrame args`.
- **Verify after pushing:** call `get_file_contents` again and confirm the sha changed, or open the raw URL and check the version stamp. Never say "pushed" without one of these.
- **Check write access once** before the first real push: push a throwaway file (for example path `test`, content `test`); a returned commit sha confirms write access, then remove it with `delete_file`. This keeps a permission failure from being mistaken for a script bug.

### Permissions
Owner authentication is not the same as scopes, so verify rather than assume. Minimum for this workflow: Contents Read and write (for pushing) and Metadata Read; add Pull requests Read and write only for the branch + PR path. Issues, Actions, Administration, Codespaces and artifact scopes are not needed. Classic token equivalent: `repo` (or `public_repo` for a public repo).

### Iteration loop and reply shape
1. User says what to change (or "push it"). 2. Edit the local copy. 3. Commit (with sha, or `push_files`) with a one-line feature summary as the message. 4. Reply with only the loader line. 5. User re-runs the loader; the version stamp printed by the script confirms which build is live.

Default reply: the single loader line from section 2 in a `lua` fence, and nothing else. For large or risky changes, add one plain sentence above it saying so and offer the PR variant.

### Failure modes
| Symptom | Cause | Fix |
|---|---|---|
| Loader errors / no output | Wrong path, case, or missing `%20` | Open the raw URL in a browser |
| Old code still runs | CDN cache | Append `?v=os.time()` |
| "Loaded" but nothing happens | Empty `httpget` or a bad chunk | Check `#src` and the console |
| `attempt to call a nil value` on `game:HttpGet` | Running in Matcha | Use `httpget(url)` |
| Loops double, lag climbs | Previous instance not stopped | Reload-safety block |
| Drawings pile up / flicker | `stop()` only set a flag | Disconnect + Remove |
| 404 on load | Wrong branch | Use `refs/heads/main` |
| Push rejected | Branch protection | Branch + PR |
| Update call fails | Missing blob sha | `get_file_contents` first |
| Script loads then dies silently | Top-level `task.wait` threw | Move into `task.spawn` |

### Pre-push checklist
- File name is just the game name (Title Case, no extension, no place id or version), replacing the old file in place
- Version stamp updated and printed at load
- Reload-safety block at the top; `stop()` sets the flag, disconnects everything, removes all drawings
- No top-level `task.wait` and no top-level `return`; `_G[NAME]` set only after successful init
- No secrets or tokens in the file
- Raw URL opens in a browser and shows the script
- Commit message follows `<script>: v<N> <what changed>`
- Reply contains only the loader one-liner in the user's exact form

## Additional Documented API (not covered by the live tests above)

Taken from a second copy of the official Matcha docs. These appear in the docs but were not part of the live global sweep, so confirm with a quick probe before depending on them.

**Globals**
- `getrbxversion(): string` returns the Roblox client version (for example `"0.635.0.6350567"`).
- `gethwid(): string` returns the machine's hardware id. Never write it to a file, log, repo or chat output.
- `rawlen(t: table | string): number` standard raw length (bypasses metamethods).
- `gcinfo(): number` returns the VM's memory use in kilobytes.
- `setmetatable` on a table whose metatable is protected raises `cannot change a protected metatable`; `newproxy(true)` returns a userdata with a settable metatable (so `__index` and `__tostring` work).
- `tick()` is a monotonic clock, not a Unix timestamp; use it for elapsed time. `getscripthash` returns the FNV-1a 64-bit hash as a decimal string. `getgamename()` is the place title, distinct from `game.Name`.

**Extra classes**
- `ValueBase`: `Value` (any). Covers `ObjectValue`, `Color3Value`, `NumberValue`, `IntValue`, `FloatValue`, `BoolValue`, `StringValue`.
- `GuiObject`: `AbsoluteSize` (Vector2), `AbsolutePosition` (Vector2).
- `TextLabel`: `Text` (string).
- `MeshPart`: `TextureId` (string), `MeshId` (string).

**Extra datatypes**
- `UDim.new(scale, offset)` with `.Scale`, `.Offset`.
- `UDim2.new(xScale, xOffset, yScale, yOffset)` or `UDim2.new(x: UDim, y: UDim)`, plus `UDim2.fromOffset(x, y)`, `UDim2.fromScale(x, y)`, with `.X` and `.Y` (UDims).

**Fix notes from the docs (Aug 6 2026):** `decompile` stability and output improved; `GetAttribute`/`SetAttribute` now work; `GuiObject.AbsolutePosition`/`AbsoluteSize` return accurate values; `TextLabel.Text` reads and writes work. `RemoteFunction:InvokeServer` was fixed Sep 11 (Pro). The docs' compatibility table also lists `Stepped` as partial (it receives one argument, `deltaTime`, instead of two). If live behavior disagrees with these notes, trust the live result and record it.

## Docs Site Review (Oct 21 2026): Other New or Corrected Facts
Source: https://huoadf.github.io/matcha-docs/ (agents can also read `llms.txt` / `llms-full.txt` there, or add the docs MCP at `https://huoadf.github.io/matcha-docs/mcp`). When unsure about an API, fetch the docs page instead of guessing.
- **HTTP:** `httpget`/`httppost` never raise. An HTTP error status (for example 404) returns the server's response body (such as "404: Not Found" text), not an empty string; only a connection failure returns `""`. Check for both an empty string and error text. The docs call them the global equivalents of `game:HttpGet`/`game:HttpPost`, and `DataModel:HttpGet(url, headers?)` is listed in the Classes page; the VM-limitations page still says `game:HttpGet` is unsupported, so if it errors use `httpget`.
- **Remote Spy / hybrid (Pro):** `RemoteEvent:FireServer(...)`, `RemoteFunction:InvokeServer(...)` and `:InvokeFunction(...)` are supported in Hybrid mode; `RemoteFunction` logging in Remote Spy was fixed Oct 21 2026.
- **Memory:** `memory_read`/`memory_write` require "Allow Unsafe LuaU" to be enabled; types are `int`, `float`, `double`, `byte`, `string`, `uintptr_t`; reading an unmapped address returns `0`; `string` reads until the first non-printable byte.
- **GC:** `setgc` rescans on every call and must not run in a loop (it lags the client); use `getgc` once and `applygc` for repeated changes, and rerun `getgc` after respawn or weapon change. Both accept a table of keys. `getgc` entries have `key`, `value`, `type`, `addr`.
- **`wait` / `task.wait`:** the docs say they return nothing, `task.wait()` yields until the next frame, and `task.defer`/`task.delay` never run; earlier live tests in this file contradicted these (bare `task.wait()` returned in ~16 us, `defer`/`delay` fired, `wait(N)` returned elapsed time). Trust live results over the docs and re-test.
- **`require(path)`** loads a `.lua`/`.luau` module by path with the extension required, from its own module root (separate from the `writefile` workspace), so you cannot `writefile` a module and `require` it.
- **Classes/properties listed:** `Instance:FindFirstChildOfClass`, `FindFirstChildWhichIsA`, `GetFullName`, `IsDescendantOf`, `GetAttribute`, `GetAttributes`, `SetAttribute`, `WaitForChild`; `Workspace:Raycast(origin, direction, params?)`; `Camera.CFrame`, `FieldOfView`, `ViewportSize`; `Lighting.Ambient`, `ClockTime`, `ExposureCompensation`; `Mouse.X/Y` via `Player:GetMouse()`; `Players.PlayerAdded/PlayerRemoving`; `Player.UserId`, `Team`, `Character`; `Humanoid.MaxHealth/Health`; `Model.PrimaryPart`. `UserInputService.InputBegan/InputEnded` are listed with `(input, gameProcessed)` but one session observed an input table with only `.KeyCode`.
- **Datatypes:** `Ray.new(origin, direction)`; `UDim`/`UDim2`; `Vector3` methods Abs, Angle, Ceil, Cross, Dot, Floor, FuzzyEq, Lerp, Max, Min, Sign; `CFrame.fromOrientation`, `Angles`, `GetComponents`, `Inverse`, `Lerp`, `PointToObjectSpace/WorldSpace`, `VectorToObjectSpace/WorldSpace`, `ToEulerAnglesXYZ`, `ToOrientation`; `CFrame == CFrame` uses reference equality; `Color3.fromHex`.
- **Drawing:** six types (Square, Line, Circle, Text, Triangle, Image); Image has `Data` (raw bytes, for example from `httpget`), `Size`, `Rounding`; Square also has `Corner`.
- **Updating Matcha:** features are delivered by reopening the Matcha loader; Roblox must be on the forced current version. Pro adds Hybrid mode and the MCP server (`http://127.0.0.1:8765/mcp`).

## Open / Unverified
- `UI.GetValue` wiring (see UI Binding section): unverified until tested in-game.
- `WorldToScreen` for a point just outside the viewport rectangle but inside the FOV frustum: only tested with a large (500 stud) offset, which returned `(0,0), false`. Not isolated precisely.

Roles & Versions
Tier	Features
Buyer	Standard access: Matcha executor, drawing API, memory tools, base Lua library.
Pro	Early-access features: Hybrid Mode (Remote Spy, FireServer, InvokeFunction) + native AI Agent / MCP server integration.
FAQ (Quick Answers)
What is Matcha? A Roblox LuaVM script executor that emulates Roblox API functions externally without hooking into internal engine functions.

Is Matcha detectable? No. It operates externally without memory hook signatures on Roblox engine routines.

How do I update Matcha? Reopen the Matcha loader—it automatically downloads and applies the latest version.

Why are features broken in-game? Ensure your Roblox game client is updated to the latest forced version. If Roblox updated recently, force-update or reopen the loader.

Why is loadstring dropping returns? Matcha's loadstring drops top-level return statements. Pass values out via globals (e.g., _G.MyResult = 5).

How do I connect Matcha to Antigravity or Codex? See the MCP Integration section above. Antigravity uses serverUrl in mcp_config.json; Codex uses codex mcp add matcha --url http://127.0.0.1:8765/mcp.

Why is task.defer not working? It is, in live testing: task.defer and task.delay fire, and task.spawn forwards arguments. Older notes calling them no-ops are outdated.

How do I raise a catchable error? Use assert(false, "message"). The error() and errorl() functions only print to the console; they do not halt execution or raise catchable errors.

Changelog (Comprehensive)
Date	Version / Event	Notes
Oct 7, 2026	cec3ad5889b447cf	Updated to latest version; Vault Dev: "I will back at features update in week or sooner"
Oct 4, 2026	—	Fixed Auth. Run loader to update
Oct 3, 2026	—	Decompiler fixed (no restart needed)
Sep 23, 2026	—	Fixed Speed, Inf Jump, Jump, Float
Sep 22, 2026	—	Pro: Fixed RemoteFunction in Remote Spy
Sep 18, 2026	—	Fixed Decompiler
Sep 14, 2026	—	Fixed Lightings
Sep 13, 2026	—	Announced Hybrid features: fireclickdetector, fireproximityprompt, firetouchinterest
Oct 21, 2026	—	Released (Pro): firetouchinterest, fireclickdetector, fireproximityprompt; fixed RemoteFunction in Remote Spy
Sep 11, 2026	—	Pro: Fixed Bloxstrike Support, Fixed InvokeServer, Fixed Unsafe Lua Prompt & Hybrid Prompt
Aug 6, 2026	—	Decompiler stability fixed; Instance comparison (==) fully supported; GetAttribute/SetAttribute fixed
Resources
Matcha Docs: https://huoadf.github.io/matcha-docs

Lua 5.1 Reference: https://www.lua.org/manual/5.1/

MatchaScripts Repository: https://github.com/cconstellation/MatchaScripts

Windows Virtual-Key Codes: https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
