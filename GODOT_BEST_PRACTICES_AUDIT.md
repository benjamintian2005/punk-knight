# Punk Knight — Godot Best Practices & UI/UX Audit

## If I could only do 3 things

1. **Build one shared `Theme` resource** for buttons/panels/labels/sliders and apply it via `project.godot → gui/theme/custom`. Right now every screen hand-rolls its own `StyleBoxFlat` and font overrides, so styling is inconsistent (see below) and any visual tweak means editing 4+ files.
2. **Style the pause menu's Resume/Quit buttons.** They're the one interactive element in the whole game still on stock default-Godot-blue, sitting inside a custom dark panel — the single most visible "this looks unfinished" spot.
3. **Swap the default engine font for one custom display font**, applied once via the Theme (see font candidates below). This is the highest-leverage single change for "feel," and currently costs nothing structurally since font size/color is already being set by hand everywhere — you'd just be pointing those same calls at a real typeface instead of the engine default.

---

## UI/UX findings (priority order)

### 1. No custom font anywhere — everything is default engine font
**Why it matters:** Font is the single biggest lever for a game's visual identity, and "Punk Knight" currently uses Godot's plain default UI font for its title, HUD, judgment text, pause menu, and level-select prompts. It reads as an unstyled placeholder regardless of how good the art (`knight_title.png`, `title_logo.png`) is.
**Evidence:** `grep -rn "font\." project.godot` → nothing; zero `.ttf`/`.otf` files anywhere in the repo; every script sets size via `add_theme_font_size_override` (15 call sites across `BattleSide.gd`, `LevelSelect.gd`, `Main.gd`, `RhythmSide.gd`, `TitleScreen.gd`) but never a font resource.
**Fix:** Pick one display font for headers/titles and one clean readable font for body/HUD text (see candidates below), import as `.ttf`, wrap each in a `FontFile`/`FontVariation`, and set both on the shared Theme's default font + a couple of named theme font types (`title_font`, etc.). No code changes needed at call sites beyond removing the now-redundant per-node overrides over time.

### 2. Zero `Theme` resources — every screen hand-rolls its own styling
**Why it matters:** This is the root cause of both the button inconsistency (finding #3) and the duplication (code-quality #1). Because there's no single source of truth for "what does a button/panel look like in this game," every new screen invents its own answer, and they drift.
**Evidence:** `grep -rn "Theme.new\|Theme("` across `scripts/` → zero matches. `StyleBoxFlat.new()` appears independently in `BattleSide.gd:127,247`, `LevelSelect.gd:99`, `Main.gd:107`, `RhythmSide.gd:474` — five separate hand-built rounded-panel styles that are all subtly different (different corner radii, different border colors: compare `Main.gd`'s pause panel `border_color = Color(0.3, 0.3, 0.36)` vs `LevelSelect.gd`'s flag `style.set_corner_radius_all(3)` with no border at all).
**Fix:** One `Theme` resource (`res://theme/game_theme.tres`), authored via the editor's Theme editor (per Godot docs: Color/Constant/Font/Icon/StyleBox categories), covering `Panel`, `Button` (normal/hover/pressed/focus), `Label`, `HSlider`. Set it as the project's default theme so every `Panel.new()`/`Button.new()` picks it up with zero extra code.

### 3. Pause menu buttons are unstyled; everything else nearby is
**Why it matters:** Direct visual inconsistency in the single most-used menu in the game (opened via Escape from every level). The pause panel itself has a deliberately dark, bordered, rounded look (`Main.gd:106-113`), but `Resume` and `Quit to Level Select` (`Main.gd:184-189`, `_build_pause_button`) are plain `Button.new()` with **no** stylebox override at all — they render as Godot's stock light-blue default buttons, clashing hard against the dark custom panel around them.
**Evidence:** `Main.gd:184-189` — `_build_pause_button` sets only `text`/`position`/`size`, no theme override, vs. the deleted-but-instructive old `LevelSelect.gd` card buttons which *did* define normal/hover/pressed/focus StyleBoxFlats (now gone since the overworld rewrite — meaning the game currently has **zero** custom-styled buttons left anywhere).
**Fix:** Either give `_build_pause_button` its own hover/pressed StyleBoxFlat set (quick, ~15 lines, matches the old card-button pattern), or — better — fold this into finding #2's shared Theme so this is solved once for every future button too.

### 4. No focus/hover feedback for keyboard-driven menus
**Why it matters:** This game is 100% keyboard-controlled (arrow keys / D-F-J-K / Enter / Escape) with no mouse dependency, which is exactly the context where visible focus state matters most — a player tabbing/arrowing through a menu needs to *see* where they are. Right now `pause_resume_button.grab_focus()` (`Main.gd:143` area) is called correctly, but there's no `focus` StyleBoxFlat override anywhere in the project, so the focused button is only distinguishable by Godot's default thin focus rectangle.
**Evidence:** `grep -rn "add_theme_stylebox_override.*focus"` → zero matches project-wide.
**Fix:** Part of the shared Theme (finding #2) — give `Button` a `focus` style that's clearly brighter/bordered, not just Godot's default dotted outline. Cheap, and this game leans on keyboard nav more than most.

### 5. `LevelSelect.gd`'s overworld has no idle/ambient motion or arrival juice
**Why it matters: this session's guidance ("juice, hit-stop, particle feedback should come after structure is stable") applies well here — the overworld is structurally done (flags, path, walk, prompt) but static: the prompt label pops in/out with a hard `modulate.a` snap (`LevelSelect.gd:171` `_update_nearby_flag`), no tween. First impressions matter — this is the very first interactive screen after the title.
**Evidence:** `LevelSelect.gd:171` sets `prompt_label.modulate.a = 1.0 if nearby_index >= 0 else 0.0` directly, no `create_tween()`, unlike almost everywhere else in the codebase (`RhythmSide.gd`'s judgment/combo labels, `Main.gd`'s dim overlays) which do tween their fades.
**Fix:** Small — wrap that assignment in a `create_tween().tween_property(prompt_label, "modulate:a", target, 0.15)` for consistency with the rest of the project's own established fade convention.

---

## Code quality findings (priority order)

### 1. UI-building boilerplate is duplicated, not shared (root cause of UI findings above)
**Evidence:** `add_theme_font_size_override` appears **15 times** and `add_theme_color_override` **11 times** across 5 files with no shared helper; `StyleBoxFlat.new()` + manual `set_corner_radius_all`/border setup is repeated **5 separate times** for what is visually "a rounded dark panel" in 4 different files.
**Fix:** Two complementary things, not either/or:
- The Theme resource (UI finding #2) removes most of the *styling* duplication.
- A small `scripts/UiBuilder.gd` (or extend the existing pattern already used inside `Main.gd`'s `_build_volume_row`/`_build_pause_button`) with 2-3 static helper functions — e.g. `static func rounded_panel(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat` — removes the remaining *construction* duplication for one-off styleboxes that don't belong in the global Theme (e.g. `BattleSide.gd`'s pulse rings, `RhythmSide.gd`'s burst rings).

### 2. Zero `.tscn` scene composition — everything is runtime-built `Control.new()`
**Evidence:** All three scene files (`Main.tscn`, `LevelSelect.tscn`, `TitleScreen.tscn`) are identical one-node shells (`[node type="Control"] script = ExtResource("1")`, 8 lines each) — confirmed by reading all three directly. Every visible node in the entire game (labels, panels, buttons, sliders, the knight sprite, HP bars) is constructed by hand in `_ready()`/`_build_ui()` functions.
**Why this is worth naming even though it "works":** per official Godot best-practices docs, the guidance is "use scenes for reusable, self-contained objects with visual components; use scripts for logic-only functionality" — this project has inverted that for the whole UI layer. It's not wrong (this is a valid, if unusual, choice that keeps everything grep-able and diff-able in one script per screen — legitimate tradeoff for a fast-iterating solo project), but it's worth being deliberate about: the pause menu, the game-over overlay, and the volume-row control are all things that would normally be their own small `.tscn` + script, inspectable and tweakable in the visual editor instead of only through re-reading GDScript math.
**Recommendation, scoped to effort:** Don't do a wholesale rewrite. But the pause menu (`Main.gd:76-149`, ~75 lines of layout code) and the volume row (`Main.gd:151-179`) are strong, low-risk candidates to extract into their own `.tscn` + tiny script — they're reused nowhere else, self-contained, and would let you *see* and drag-tweak the pause menu layout in the editor instead of computing `Vector2(30.0, 200.0)` by hand.

### 3. Two `null`-typed variables, otherwise strong static typing discipline
**Evidence:** `grep` found only 2 untyped `var` declarations in the whole 1762-line codebase: `RhythmSide.gd:350` (`var best_note = null`) and `RhythmSide.gd:452` (`var existing = ring_tweens[lane]`). Everything else consistently uses `:=` or explicit `: Type`.
**Why it matters less than it sounds:** this is genuinely good — Godot's static typing gives faster bytecode and parse-time error catching, and this project already does it almost everywhere. These two are `null`-initialized-then-conditionally-assigned patterns where GDScript can't infer a concrete type from `null` alone, so they're a reasonable, minor exception, not a smell.
**Fix (low priority, ~2 min):** `var best_note: Dictionary = {}` (with an `.is_empty()` check instead of `!= null`) would close this out entirely and match the pattern already used in `BattleSide.gd`'s `_find_lane_target`-style empty-dict returns elsewhere in the project's history.

### 4. Signal usage and autoload scope are both already appropriate — no action needed
**Evidence:** Only 3 signals total (`player_died`, `note_hit`, `note_missed`), each a genuine cross-system event (not a substitute for a direct call where a direct call would be simpler); only 3 autoloads (`GameState`, `InputSetup`, `Settings`), each a legitimately global concern (level data, input rebinding, audio settings) — none of them are the "junk drawer" anti-pattern (mixing player state + UI + debug flags) that the research flagged as the common autoload mistake.
**Note:** worth protecting as the project grows — the temptation when adding the next system (e.g. a future SFX manager) will be to autoload it "because it's easier than passing references," which is exactly the trap the research calls out. The existing `RhythmSide → battle_side` direct-reference pattern (set via `set_battle_side()`) is the right template to keep following instead.

### 5. No project-wide constants file for shared visual language (lane colors, judgment colors)
**Evidence:** `LANE_COLORS` (the 4-color rhythm-lane palette) is defined independently in both `RhythmSide.gd` and was duplicated again during this session's now-reverted horde experiment in `BattleSide.gd` — i.e., the codebase has already drifted on this once. `PERFECT_COLOR`/`GOOD_COLOR` similarly live only in `BattleSide.gd` but are referenced conceptually (matching colors) from `RhythmSide.gd`'s `show_judgment` calls with hand-typed duplicate `Color(1.0, 0.9, 0.3)` / `Color(0.6, 1.0, 0.6)` literals that happen to visually match but aren't the same constant.
**Fix:** A tiny `scripts/GameColors.gd` (plain `class_name` resource or const-only script, not necessarily an autoload) holding `LANE_COLORS`, `PERFECT_COLOR`, `GOOD_COLOR`, `MISS_COLOR` once, referenced by both files. Prevents exactly the kind of silent-drift duplication this project already hit once this session.

---

## Recommended font candidates

Not fetched — for you to preview and pick before anything gets bundled into the repo.

**For the title/display (headers, "PUNK KNIGHT", judgment text like PERFECT/BIG):**
- **Wasted Youth** — grunge/punk display font, ships in 3 texture variants (clean edge / inky brush / marker pen); free, commercial-use friendly. Fits the "Punk Knight" name and the halftone/painterly logo directly. Search "Wasted Youth font" on the major free-font sites (DesignShack/1001Fonts grunge round-ups surfaced it).
- **Broken Drive** — grunge display font aimed at bold titles/posters, natural texture, handcrafted feel. Good alternative if Wasted Youth reads too legible/clean for the judgment-text use case.

**For body/HUD text (score, HP numbers, menu labels — needs to stay readable at small sizes):**
- **Pixeloid** (by GGBotNet, itch.io, SIL OFL 1.1) — clean pixel-style family, multi-language, explicitly OFL-licensed. Worth checking against the actual enemy sprite art style (`art/enemies/*.png` — described earlier in this project as a "fantasy sprite pack," likely pixel/retro-styled) since a pixel body font would tie the HUD to that sprite aesthetic rather than the painterly knight portrait.
- If the painterly/halftone look (not pixel) is the intended overall direction, a plain clean sans (e.g. anything OFL-licensed and simply "quiet") for body text paired with the grunge display font for titles is the safer pairing — avoids two competing "loud" typefaces fighting each other.

**Recommendation:** preview Wasted Youth (or Broken Drive) for titles/judgment-text against a screenshot of the actual title screen before committing — grunge fonts vary a lot in legibility at the judgment-text sizes this game uses (PERFECT/GOOD/MISS need to read instantly mid-combo).

---
Sources consulted: [GDScript style guide (Godot 4.4 docs)](https://docs.godotengine.org/en/4.4/tutorials/scripting/gdscript/gdscript_styleguide.html), [Godot Best Practices index](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html), [GDQuest Theme editor guide](https://school.gdquest.com/courses/learn_2d_gamedev_godot_4/telling_a_story/all_theme_editor_areas), [UhiyamaLab — Building Consistent UI with the Theme System](https://uhiyama-lab.com/en/notes/godot/theme-system-unified-ui/), [febucci — How to Create UI in Godot 4](https://blog.febucci.com/2024/11/godots-ui-tutorial-part-one/), [febucci — Dynamically Scale Font Size in Godot](https://blog.febucci.com/2025/08/how-to-dynamically-scale-font-size-in-godot/), [Godot 4 Autoload Singletons: When To Use, When To Avoid](https://zivadotsh.hashnode.dev/godot-4-autoload-singletons-when-to-use-when-to-avoid), [itch.io — Pixeloid font](https://ggbot.itch.io/pixeloid-font), [DesignShack — Best Grunge Fonts](https://designshack.net/articles/inspiration/grunge-fonts/)
