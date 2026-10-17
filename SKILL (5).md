---
name: matcha-luavm
description: Read this skill first for ANY Matcha / Roblox executor script request. Reference AND delivery rules for the Matcha LuaVM Roblox executor. Scripts are delivered by pushing to the user's GitHub repo and replying with a one-line loadstring loader, not by pasting code in chat. Includes MCP server integration, all native globals, memory tools, drawing API, UI binding, Roblox classes, datatypes, full Lua 5.1 base library, and VM limitations.
---


# STOP: THREE RULES BEFORE YOU WRITE ANYTHING

1. **Scripts go to the user's GitHub repo (`bobashid/roblox-matcha`), never into the chat.** Do not output a Lua script of more than 40 lines in your reply unless the user used an override word (`inline`, `paste it here`, `give me the code`, `just the script`, `no github`, `in chat`). Your reply is one line + a loader + a stop command. The user has asked for this repeatedly; pasting code in chat is the main failure of this skill.
2. **If you cannot push, do not fall back to pasting.** Check your tool list for GitHub tools (`create_or_update_file`, `push_files`, `get_file_contents`). If none exist, reply only: "GitHub tools aren't enabled in this chat. Enable the GitHub connector, or say 'inline' and I'll paste the script here." Then stop. Do not write the script until they choose.
3. **Read the user's existing scripts first** (see "Match the user's code style") so new code follows their conventions, and check the built-in features table so you do not rebuild what Matcha already has.

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

## 2. Default behavior
- Any script over 40 lines: push it, then reply. This is the default and needs no request.
- The reply after a successful push is exactly three things: (1) one line saying what changed, with the file path and version; (2) the loader in a `lua` fence; (3) the stop command in a `lua` fence.
- Do not paste the script body: not collapsed, not "for reference", not partially.
- Under 40 lines, snippets, diffs, explanations, and one-line debugging fixes stay in chat. Do not push on every micro-edit; push once the shape settles.

Reply template (replace the bracketed parts):
```
Updated: <name> v<N> - <what changed> (<file path>)
```
```lua
loadstring(httpget("https://raw.githubusercontent.com/bobashid/roblox-matcha/refs/heads/main/<url-encoded file path>"), "<Name>")()
```
```lua
_G.<Name>.stop()
```

**Loader form.** `game:HttpGet` does not exist in Matcha (it fails as a nil call), so the default is the global `httpget` form above. If the user says their executor accepts `loadstring(game:HttpGet("<url>", true))()` and wants that form, use it exactly. Spaces in file names become `%20` in the URL.

## 3. Override words (cancel the rule for ONE turn only)
`inline`, `paste it here`, `give me the code`, `show me the full script`, `no github`, `just the script`, `in chat`.
When one is present, paste the script in a `lua` fence, do not push, and do not ask whether to push. The override ends with that message. "both" means push AND paste.

## 4. Push procedure (in order)
0. Read one or two of the user's existing scripts from the repo (`get_file_contents`) that resemble the new one, and match their style (see "Match the user's code style"). Skip only if the repo has no scripts yet.
1. Resolve the place id from `matcha_status` (use the live number, not a remembered one) when the file is game-specific.
2. Search the repo for an existing file for this script/game. Updating beats creating; never leave `_v2`/`_final` copies or `(1)` suffixes.
3. If the file exists, read its current blob sha first (`get_file_contents` with owner, repo, path, ref=branch). An update without the correct sha fails (409) or overwrites blind.
4. Write with `create_or_update_file` (owner, repo, path, branch, raw text content, sha when updating, commit message per section 6). Several files at once: `push_files`, one commit.
5. Verify: read the file back and compare size or the version stamp with what you wrote. A truncated push is otherwise silent. If it is short, rewrite in full and say so.
6. Reply in the section 2 format.

Do not create or update `CHANGELOG.md`, README listings, notes or log files in the repo. The only files you write are the script itself (and `lib/` helpers it needs). The "what changed" line lives in the commit message and the chat reply, not in a repo file.

Retry a failing push at most twice. Never force-push, rewrite history, or delete a file to resolve a conflict. If a push breaks a working script, revert by pushing the previous content back as a new commit and say which commit you restored from.

## 5. File naming
- New files: flat at the repo root, lowercase, hyphenated, `.lua`, no version numbers (for example `my-game-esp.lua`). If the game is known, putting the place id in the name is fine (`<place_id>-<name>.lua`).
- Existing files (even with spaces or no extension) keep their path and get overwritten in place. Encode spaces as `%20`; recommend renaming but do not rename unprompted.
- One file per feature unless the user asks for a monolith. If a helper is used by two scripts, put it in `lib/` and fetch it with a second `httpget`.
- The URL for a script never changes between updates.

## 6. Commit message format
```
<script>: v<N> <what changed>

verified: <how it was checked this session, or "untested">
```
The `verified` line is mandatory and never optimistic: if behavior was not confirmed with `matcha_exec` in this session, write `untested`, not "should work".

## 7. Script contract for pushed files
Every pushed script must: print a version stamp at load; register `_G.<Name>` with `{ stop = stop, version = VERSION }` only after successful init; kill any previous instance at the top (`if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end`, with no top-level wait); have a synchronous `stop()` that sets `running = false`, disconnects every stored connection and removes every Drawing object; and never use a top-level `return` or top-level `task.wait`. The reply always includes the stop command. Full skeleton and loader variants are in "GitHub Delivery Workflow: Reference" below.

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
- Commit message has a `verified` line; no changelog/log/notes file was written
- Stop function exists in the pushed script; no secrets in the content
- Reply is one line + loader + stop; the body is not pasted unless an override word appeared (no Lua block over 40 lines anywhere in the reply)
- You read at least one existing script from the repo first and matched its style

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
| Firing remotes | `RemoteEvent:FireServer` / `RemoteFunction:InvokeServer` (Pro, hybrid mode) | Replacing it with `fireclickdetector`-style globals (they are absent) |

Rules:
1. **Check first, build second.** Search this file for the capability. If it is listed as present or documented, use it directly and only add the glue code.
2. **Do not recreate Roblox executor globals that are absent.** If a global is on the ABSENT list (hooking, `getgenv`, `request`, crypto, `getconnections`, etc.), do not write a fake version that pretends to work. Tell the user it is not available and use another approach (input, Drawing, DataModel reads).
3. **Do not duplicate within the user's own project.** If the repo already has a script or `lib/` helper for the same thing, update it instead of creating a second one (the push procedure already requires searching first).
4. **Keep scripts small.** Menu, ESP and loop boilerplate should be a thin layer over built-ins, not a framework. Do not add libraries, wrappers or abstractions the user did not ask for.
5. **If unsure whether something exists, probe it** with a one-line `matcha_exec` (`print(type(name))`) before writing a replacement. Test existence separately from behavior.

## Match the user's code style (read their repo first)

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
- Menu widgets take an extra id argument, callback argument order is unreliable, and `UI.GetValue` is the safer source of truth: poll it rather than trusting the event. `UI.AddTab`'s callback runs every frame, so build once and wrap the body in `pcall`.
- Everything visual is `Drawing`, pooled, never created inside a loop.
- Fire remotes using the exact argument shape found by decompiling the client script that fires them.
- Use Matcha's built-ins; never reimplement what it already provides (see "Use Built-ins First").
- Verify with `matcha_exec` prints and read `matcha_logs` for output from spawned loops.
- Scripts over 40 lines go to the GitHub repo and the chat reply is a one-line loader (see the DELIVERY RULE at the top).

# Matcha LuaVM - The Complete Documentation

## Overview
Matcha is a Roblox LuaVM script executor that emulates Roblox API functions externally rather than hooking into internal engine routines. This design makes it 100% undetected by server-side and client-side anti-cheat mechanisms, because it operates without memory hook signatures on Roblox engine routines. 

The trade-off is that Matcha has no direct access to internal Roblox API functions—it cannot use `Instance.new()` (the `Instance` global is nil: no Roblox instance can be constructed from the executor, everything must be read from the live DataModel or built from primitives like `Vector3.new`/`CFrame.new`/`Color3.new`), `game:HttpGet()`, or `game:HttpPost()` directly. Instead, it provides native global replacements and a rich set of emulated functions.

**Live Status:** The Vault announced incoming Pro Hybrid features on Sep 13, 2026 (`fireclickdetector`, `fireproximityprompt`, `firetouchinterest`) with a "max 3 days" deadline. As of Oct 7, 2026, the update is 24+ days overdue. Vault Dev Update (Oct 7): "I will back at features update in week or sooner".

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
Create custom menu tabs, widgets, sections, and hotkey keybinds directly from Lua. Source: MatchaScripts Repository.

Global functions:

UI.AddTab(name: string, fn: function) — Creates tab; callback runs every frame to render/update.

UI.RemoveTab(name: string) — Removes tab.

UI.GetValue(id: string): any — Reads widget value from anywhere.

UI.SetValue(id: string, value: any) — Sets widget value programmatically.

Sections: tab:Section(name, side) where side is "Left" or "Right". Pass an array of page names for tabbed sections; pass max_height for scrollable.

Widgets:

Toggle: section:Toggle(name, default, callback) (documented signature; live behavior differs, see "Menu Binding: Observed Behavior")

Keybind: section:Keybind(name, default, mode, callback) (Must be placed directly after a Toggle widget. Modes: "toggle", "hold", "always", "click")

SliderInt: section:SliderInt(name, min, max, default, callback)

Dropdown: section:Dropdown(name, options, default, callback)

ColorPicker: section:ColorPicker(name, default, callback)

Textbox: section:Textbox(name, default, callback)

Button: section:Button(name, callback)

### Widget signatures: live-tested corrections
The widget list above is the documentation. Live testing on Matcha 1.0.0 shows it is wrong in several places; prefer this table and re-test on your build.

| Widget | Docs say | Reality |
|---|---|---|
| Toggle | `(name, default, cb)` | Error `invalid argument #3 (string expected, got boolean)` shows a second string (an id) sits before the boolean. Use `(name, id, default, cb)` or `(id, name, default, cb)` |
| SliderInt / ColorPicker | As documented | Also appear shifted; try id/name variants |
| Button | `(name, cb)` | Building with `(name, id, cb)` first succeeds but silently never wires the callback (a dead button). Try `(name, cb)` FIRST |
| UI.AddTab | `(name, fn)` | Works; `fn` receives a table (the tab) and runs every frame |
| tab:Section | `(name, side)` | Works; also accepts `(name)` alone |

Create every widget through a variant-trying helper:

```lua
local function safeToggle(sec, name, id, default, cb)
    local variants = {
        function() sec:Toggle(name, id, default, cb) end,
        function() sec:Toggle(id, name, default, cb) end,
    }
    for i = 1, #variants do
        if pcall(variants[i]) then return true end
    end
    return false
end

-- Button: (name, cb) MUST be tried first
local function safeButton(sec, name, id, cb)
    local variants = {
        function() sec:Button(name, cb) end,
        function() sec:Button(name, id, cb) end,
        function() sec:Button(id, name, cb) end,
    }
    for i = 1, #variants do
        if pcall(variants[i]) then return true end
    end
    return false
end
```

Build the tab once behind a `tabBuilt` flag and wrap the whole callback body in `pcall`: the callback re-runs every frame, and one bad widget can crash Matcha's renderer (a tab-open crash was traced to too many widgets plus an untested Button).

**Toggle callback: do not trust its arguments.** It has been observed passing the value, the id, the name, non-booleans, and double-firing.
- Preferred: poll `UI.GetValue(id)` (fallback `UI.GetValue(name)`) about every 0.1 s and drive your state from the menu; use the callback only as a fallback for keys the getter returns nil for.
- Fallback: loop `select(1..n)` and take the first argument where `type(v) == "boolean"`. Never write `v and true or false` on an unknown argument.
- No debounce: a 0.2 s debounce drops rapid clicks and reads as a stuck toggle.
- Print on change so a broken wire is visible: `print("[script] " .. key .. " = " .. tostring(val))`.

| Symptom | Cause | Fix |
|---|---|---|
| Toggle stuck / glued to true | Callback arg was a string/nil and the handler ignored it | Arg scan or poller |
| Needs several clicks | Debounce dropped clicks | Remove debounce |
| Flips then flips back | Callback double-fires | Poller as source of truth |
| Button does nothing | Built with the wrong signature, callback never wired | Try `(name, cb)` first |
| Tab open crashes Matcha | Unguarded callback / too many widgets | `tabBuilt` guard + `pcall` body |

**Example — add a toggle to a tab section:**

```lua
UI.AddTab("Example", function(tab)
    local section = tab:Section("Settings", "Left")
    section:Toggle("Enabled", false, function(value)
        UI.SetValue("enabled", value)
    end)
end)
```

**Partly resolved:** polling `UI.GetValue` works in practice if you try both the id and the name (see the table above), so do not rely on the callback. `UI.AddTab`, `UI.RemoveTab`, `UI.GetValue` and `UI.SetValue` are all present, but in one early test (tab -> section -> toggle, wait 0.15 s) `UI.GetValue("<toggle id>")` returned nil. Either the widget ID scheme differs from the string passed, or tab rendering is deferred past the test window. Scripts that poll `UI.GetValue(id)` may silently never apply. Needs an in-game test: create a toggle, flip it by hand, read it back.

This is an illustrative pattern based on the documented signatures. The source does not specify the callback's tab variable binding or widget ID semantics; adapt it to the actual MatchaScripts repository example if needed.

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
Remote:      fireclickdetector, fireproximityprompt, firetouchinterest,
             getconnections, firesignal, getsignal, getcallbackvalue,
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

**Consequences:** no hooking means no namecall-based hooks; no `getconnections` means no signal/remote replay; no `fireproximityprompt`/`fireclickdetector`/`firetouchinterest` means no interaction firing. Matcha's design is "do it with input, drawing and DataModel reads, nothing else." Do not write scripts that depend on any global in the absent list.

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

- **Wrappers do not reliably compare equal.** Two Lua values referring to the same Roblox object may fail `==`, even though older notes say `inst1 == inst2` was fixed. Key tables by `inst.Address` (or `Player.UserId` for players); never use an Instance as a table key or compare with `==`.
- **Stale `GetDescendants`/`GetChildren` results.** After reparenting, a previously fetched list (or a count from it) can contain dead references, so a fresh count can be wrong. Confirm a reparent by comparing `.Address` sets before and after. Same addresses still out of the tree means the objects stayed moved; do not conclude the game "rebuilt" them from a count.
- **Prove a lever over a wait window.** Acting on an immediate read is the most common source of wrong conclusions. Apply the change, wait (for example 0.5-2 s), then re-read by `.Address` before building on it.

## Replication and Network Ownership Caution
Reparenting or moving a part that is under another client's or the server's network ownership can break replication; the object may snap back or desync when ownership resolves. If a script desyncs, first look for a `Parent` write or a `Position` write on a physics-simulated part. Prefer in-place property changes (such as `Size`, `CanCollide`) over reparenting or repositioning, and verify them over a wait window.

## Confirmed Absent (stop probing these)
- No `Instance` at all (not even `Instance.new`); every overlay must be built with `Drawing`.
- No hooking: `getrawmetatable`, `hookfunction`, `hookmetamethod`, `newcclosure`, `checkcaller` are all nil.
- `debug` exists but only has `traceback`.
- No `getgenv`/`getrenv`/`getinstances`, and no collision-group, physics-control or touch-firing API.
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
| `invalid argument #3 (string expected, got boolean)` | The widget needs an id string before the default |
| `invalid argument #3 (Instance expected, got nil)` | `Parent = nil` is not allowed; reparent to a real instance |
| `attempt to index nil with 'new'` | `Instance` is nil; nothing is constructible |
| `Matcha:<line>: file extension not allowed` | `writefile` rejected the extension |
| `attempt to index nil` | A link in your chain is missing; print each step |
| `attempt to call a nil value` | That global or function does not exist in this VM |

## Output Capture and Timing in the MCP Exec Tool
- `matcha_exec` returns only what `print()` emitted, and capture closes about 350 ms after the last print. Print incrementally; do not buffer a final report. Check `matcha_logs` for anything a spawned loop emits later.
- A top-level `task.wait` in an exec does not yield the way it does in a normal script; spawn a loop and read logs instead.
- One batched exec with many prints beats many single-print calls.

## Menu Binding: Observed Behavior
The documented widget signatures do not match what runs. Treat these as observed on Matcha 1.0.0 and re-test on your build.

| Widget | Docs say | Live behavior |
|---|---|---|
| `UI.AddTab(name, fn)` | Creates tab | Works; `fn` receives the tab table and runs every frame |
| `tab:Section(name, side)` | side Left/Right | Works; also accepts `(name)` alone |
| `sec:Toggle(name, default, cb)` | 3 args | Error `invalid argument #3 (string expected, got boolean)` shows a second string (an id) sits before the boolean |
| `sec:SliderInt` / `ColorPicker` | As documented | Also appear shifted; try id/name variants |
| `sec:Button(name, cb)` | 2 args | Building it as `(name, id, cb)` succeeds but never wires the callback |

Rules:
1. **Build once.** The tab callback runs every frame: create widgets once behind a `tabBuilt` flag and wrap the whole body in `pcall` so a widget failure cannot crash the renderer. A crash on tab open was traced to too many widgets plus an untested Button.
2. **Variant-trying helper.** Create every widget through a helper that tries `(name, id, default, cb)` then `(id, name, default, cb)`. For `Button`, try `(name, cb)` first.
3. **Never trust the Toggle callback argument.** It has been seen passing the value, the id, the name, non-booleans, and double-firing. Preferred: poll `UI.GetValue(id)` (fallback `UI.GetValue(name)`) every ~0.1 s and write your config from that, using the callback only as a fallback for keys the getter returns nil for. If you must use the callback, loop `select(1..n)` and take the first argument where `type(v) == "boolean"`; never write `v and true or false` on an unknown argument.
4. **No debounce.** A 0.2 s debounce dropped rapid clicks, which looked like a stuck toggle.
5. **ColorPicker** yields a Color3; guard with `typeof(c) == "Color3"`.
6. **Widget id/name semantics remain unverified.** Try both id and name, and print a line whenever config actually changes so a broken wire is visible in the console.

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
- Push the file, then reply with the loader line, not the code. Default reply: one-line changelog (with version), the loader one-liner, and the stop command. Paste full code only if the user asks.
- The URL never changes between updates: same filename, same branch, overwritten in place. Never version filenames (`(1)`, `v2`); a stale copy gets cached and you end up debugging the wrong file.
- Never write to the user's repo unless asked. Reading is safe; pushing is a side effect. Confirm filename and commit message before a write.
- Verify a write happened (the blob sha changed, or the raw file shows the new version stamp) before saying "pushed".
- Scripts must be safe to make public: never commit tokens, webhooks, HWIDs or other secrets.

### Repo layout and naming
- Flat files at the repo root on `main`; no folders unless asked. One file per game/script.
- Lowercase, hyphenated, URL-safe names ending in `.lua` (for example `my-game-esp.lua`). Spaces become `%20` in raw URLs and break pasted lines; rename rather than encode, but if existing files already contain spaces, encode them in the loader and recommend (do not force) renaming.
- Only touch a `README.md` if the user asks; do not add script listings or logs on your own.
- Raw URL pattern: `https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>`. Raw URLs are case-sensitive. A 404 means wrong branch, case or path.
- URL encoding: space `%20`, `#` `%23`, `?` `%3F`, `&` `%26`, `%` `%25`.

### Loader forms
`game:HttpGet` does not exist in Matcha (it errors with `attempt to call a nil value`). Use the Matcha-native form unless the user confirms their loader with `game:HttpGet` works (then they are likely on a different executor and you should hand back the form they use).

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
1. User says what to change (or "push it"). 2. Edit the local copy. 3. Commit (with sha, or `push_files`). 4. Reply with the same loader one-liner, a one-line changelog and the stop command. 5. User re-runs the loader and the version stamp confirms which build is live.

Default reply:

```
Updated: <name> v6 - <what changed>
loadstring(httpget("https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/main/<file>"))()
stop: _G.<Name>.stop()
```

Put the loader in a normal line or `lua` fence, always include the stop command, and for large or risky changes say so and offer the PR variant.

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
- Filename lowercase, hyphenated, `.lua`, replacing the old file (no version suffix)
- Version stamp updated and printed at load
- Reload-safety block at the top; `stop()` sets the flag, disconnects everything, removes all drawings
- No top-level `task.wait` and no top-level `return`; `_G[NAME]` set only after successful init
- No secrets or tokens in the file
- Raw URL opens in a browser and shows the script
- Commit message follows `<script>: v<N> <what changed>`
- Reply contains the loader one-liner, version and stop command

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
Sep 13, 2026	—	Announced Hybrid features: fireclickdetector, fireproximityprompt, firetouchinterest (max 3 days—overdue)
Sep 11, 2026	—	Pro: Fixed Bloxstrike Support, Fixed InvokeServer, Fixed Unsafe Lua Prompt & Hybrid Prompt
Aug 6, 2026	—	Decompiler stability fixed; Instance comparison (==) fully supported; GetAttribute/SetAttribute fixed
Resources
Matcha Docs: https://huoadf.github.io/matcha-docs

Lua 5.1 Reference: https://www.lua.org/manual/5.1/

MatchaScripts Repository: https://github.com/cconstellation/MatchaScripts

Windows Virtual-Key Codes: https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
