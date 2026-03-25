# WowReminder — Rotation Builder

A World of Warcraft Retail addon to build a custom spell rotation and track it in-game via an interactive HUD.

---

## Installation

1. Copy the `WowReminder` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
2. Launch (or restart) WoW Retail.
3. On the character selection screen, click **AddOns** (bottom-left) and make sure **WowReminder** is checked.
4. Log in — the following message confirms the addon is loaded:
   ```
   WowReminder loaded — /wr to open.
   ```

---

## Commands

| Command | Action |
|---|---|
| `/wr` | Open or close the configuration window |
| `/wowreminder` | Same as `/wr` |
| `/wr reset` | Move the configuration window back to the center of the screen |
| `/wr overlay` | Show or hide the in-game HUD |
| `/wr o` | Shortcut for `/wr overlay` |

---

## Configuration Window (`/wr`)

The window is split into two panels:

```
┌──────────────────────────────────────────────────────────────┐
│                WowReminder — Rotation Builder                │
├─────────────────────────────┬────────────────────────────────┤
│   Available Spells          │   My Rotation                  │
│  ┌───────────────────────┐  │                                │
│  │ Search...             │  │  1. [icon] Spell A  [▲][▼][✕]  │
│  └───────────────────────┘  │  2. [icon] Spell B  [▲][▼][✕]  │
│  [By ID]  [Rescan]          │  3. [icon] Spell A  [▲][▼][✕]  │
│                             │                                │
│  [icon] Spell A   + Add     │            [Clear all]         │
│  [icon] Spell B   + Add     │                                │
├─────────────────────────────┴────────────────────────────────┤
│  [Show overlay]                                              │
└──────────────────────────────────────────────────────────────┘
```

The window is **movable** (click and drag the title bar) and its position is saved automatically.

### Left Panel — Available Spells

| Element | Role |
|---|---|
| Search field | Filters the list by name in real time (case-insensitive) |
| **+ Add** | Adds the spell to the rotation (duplicates are allowed) |
| **By ID** | Adds any spell by entering its Spell ID manually |
| **Rescan** | Re-scans the spellbook (useful after learning a new spell) |

> **Finding a Spell ID**: search for the spell on wowhead.com — the ID appears in the URL.
> Example: `https://www.wowhead.com/spell/133` → ID = **133**

### Right Panel — My Rotation

| Button | Role |
|---|---|
| **▲ / ▼** | Move the spell up or down one position (disabled at list boundaries) |
| **✕** | Remove the spell |
| **Clear all** | Empty the entire rotation |

---

## In-Game HUD — Overlay (`/wr overlay`)

A floating window to keep open while playing. It is used both to **record** a rotation by casting spells and to **track** the rotation in real time.

```
┌──────────────────────────────────┐
│ Rotation ● REC      ≡  ◎  [✕]  │  ← title + REC indicator + modes + close
├──────────────────────────────────┤
│  → [icon] Spell A        (yellow)│
│  ✓ [icon] Spell B        (green) │
│  ✗ [icon] Spell C        (red)   │
│    [icon] Spell D        (grey)  │
├──────────────────────────────────┤
│  [⏺ Record]       [↺ Restart]   │
└──────────────────────────────────┘
```

---

## Recording a Rotation by Playing

Instead of building the rotation manually, you can record it directly by casting spells in-game.

1. Open the overlay with `/wr overlay` (or the button in `/wr`)
2. If needed, clear the existing rotation via **Clear all** in `/wr`
3. Click **⏺ Record** in the overlay — the `● REC` indicator appears in red
4. Cast your spells in the desired order — each spell is added automatically
5. Click **⏹ Stop** to finish — a chat message confirms the number of recorded spells

> Spells are appended to the existing rotation. Duplicates are allowed (useful for repeated sequences).

---

## Tracking the Rotation In-Game

Once the rotation is built (manually or via recording):

### Color codes

| Color | Meaning |
|---|---|
| **Yellow** | Next spell to cast |
| **Green** | Spell correctly cast |
| **Red** | Wrong spell cast — the rotation resets to the beginning |
| **Grey** | Spell not yet reached in the sequence |

### Behavior

- **Correct spell cast** → the spell turns green and the rotation advances to the next one.
- **Wrong spell cast** → the entire rotation resets to spell #1 (everything turns grey).
- **↺ Restart button** → manually resets the rotation to spell #1.

> Detection works on spell name in addition to spell ID, which handles variant spells (e.g. Warlock Grimoire spells).

### Two Display Modes

Toggle with the `≡` and `◎` buttons in the title bar. The chosen mode is saved.

**`≡` List Mode** — the full rotation is visible, with automatic scrolling to the current spell.

**`◎` Next Spell Mode** — displays only the spell to cast in large format:

```
┌──────────────────────────────────┐
│ Rotation            ≡  ◎  [✕]   │
├──────────────────────────────────┤
│                                  │
│         ┌──────────┐             │
│         │  [icon]  │             │
│         └──────────┘             │
│           Spell name             │
│             #3 / 7               │
│                                  │
├──────────────────────────────────┤
│  [⏺ Record]       [↺ Restart]   │
└──────────────────────────────────┘
```

---

## Moving and Resizing the Overlay

| Action | How |
|---|---|
| **Move** | Click and drag the title bar |
| **Resize** | Click and drag the `⤡` grip in the bottom-right corner |

Minimum size: 220 × 180 px — Maximum size: 700 × 900 px.
Position and size are saved automatically between sessions.

When the game's **Edit Mode** is active (`/editmode`), a golden border appears around the overlay to indicate it can be repositioned.

---

## Saved Data

The following data is saved automatically in the `SavedVariables`:

| Data | Description |
|---|---|
| Rotation | Ordered list of spells |
| Config window position | Coordinates of the `/wr` window |
| Overlay position | Coordinates of the in-game HUD |
| Overlay size | Width and height of the in-game HUD |
| Display mode | List (`≡`) or Next Spell (`◎`) |

Save file location:
```
World of Warcraft/_retail_/WTF/Account/<NAME>/SavedVariables/WowReminder.lua
```

---

## Known Limitations

- **The spell list only comes from the logged-in character's spellbook.** There is no WoW API to list all spells in the game. To add a spell not in the list, use the **By ID** button.
- The overlay only detects spells **successfully cast** (`UNIT_SPELLCAST_SUCCEEDED`). Failed or interrupted casts are not counted.
- The overlay does not natively integrate into WoW's Edit Mode panel (reserved for Blizzard frames), but reacts visually when Edit Mode is activated.
