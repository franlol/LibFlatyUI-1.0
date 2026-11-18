# LibFlatyUI-1.0 components

Every component, what it is for, and how to pick one. The comments in
`LibFlatyUI-1.0.lua` above each constructor list every option; this file is
the map. The **Flaty Gallery** addon (`/flaty`) shows every component in every
state, so look there when you're unsure how something looks.

## Contents

1. [Setup](#setup)
2. [Picking a component](#picking-a-component)
3. [Design rules](#design-rules)
4. [Rows: what every control shares](#rows-what-every-control-shares)
5. [Components](#components)
6. [Theme](#theme)

## Setup

```lua
local UI = LibStub("LibFlatyUI-1.0"):New({ accent = { 0.7, 0.55, 1 } })
UI.OnChange = function() UI.RefreshAll() end   -- after any user change

local win = UI.Window({ name = "MyAddonOptions", title = "MyAddon", version = "1.0" })
win:AddNav("general", "General", function(container)
    local page = UI.Page(container, 2)
    local card = page:Add(1, UI.Card(page.content, "Look"))
    card:Add(UI.Check(card, "Show health", function() return db.health end,
        function(v) db.health = v end))
    page:Layout()
end)
win:Select("general")
```

- `:New(theme)` returns an independent instance with its own colors. Its
  constructors are plain functions: `UI.Check(...)`, not `UI:Check(...)`.
- Controls read their value through `get` and write it through `set`. They
  never store it themselves.
- `UI.RefreshAll()` re-reads every control, re-applies `showIf`/`enableIf` and
  lays out the visible pages. Call it after changing data from code.
- `UI.OnRefresh` (optional) runs at the end of every `RefreshAll`. Use it to
  update texts that are not controls (a card title, a note).
- `UI.strings` holds the texts the lib shows on its own (`confirm`, `search`,
  `accept`, `cancel`). Replace them to translate.

## Picking a component

| You need | Use | Not |
|---|---|---|
| An option that is on or off | `Check` | `Segmented` with Yes/No |
| The main on/off of a whole feature or card (top of the card) | `Switch` | `Check` |
| Several on/off values of the same kind (which units, which auras) | `CheckGroup` | many `Check` rows |
| A number in a range | `Slider` | `Input` |
| One choice of 2 or 3 | `Segmented` | `Dropdown` |
| One choice of 4 or more, or a list that changes | `Dropdown` | `Segmented` |
| A font or texture | `Dropdown` with font / texture samples | |
| A color | `Swatch` | |
| A short text (name, label) | `Input` | `CodeBox` |
| Long or multi-line text (code, import string) | `CodeBox` | `Input` |
| Filtering a list | `SearchBox` | `Input` |
| An action (reset, copy, test) | `Buttons` | a dropdown plus an Apply button |
| A destructive action | `Buttons` with `"danger"` + `Confirm` (or `Dialog` for big ones) | a plain button |
| A small action next to a title or in a toolbar (add, remove, more) | `IconButton` / `card:AddHeaderButton` | a text button |
| A collection the user picks from, orders, checks or removes | `List` | many `Check` rows |
| Explaining something the label can't say | `Note` (or `tip` on the row) | a note that repeats the label |
| Grouping related options | `Card` | |
| Splitting one card into named groups | `Heading` | a second card with 1 row |
| Splitting one card without a name | `Separator` | an empty `Note` |
| Grouping cards on a page under a title | `page:AddSection` | a card that only holds a title |
| A card that needs the full width (big list, code box) | `page:Add(col, card, span)` | a one-column page just for it |
| A rarely used card that should not take room | `Card` with `fold = true` | hiding it |
| One item picked from a list, with its settings beside it | `Split` | two cards side by side |
| A few views inside one card or page | `Tabs` | separate nav pages for tiny views |
| A question before something irreversible | `Dialog` | `Confirm` alone, when the loss is big |
| Top-level areas of the settings | `win:AddNav` (+ `win:AddSection` for groups) | `Tabs` |

## Design rules

These keep every window built with the lib consistent. Follow them unless the
user asks otherwise.

- **Grey out, don't hide.** An option that does not apply right now uses
  `enableIf`, so the layout doesn't jump and the user sees it exists. Use
  `showIf` only for structure: the rows of a tab, rows behind a "Show
  advanced" switch, or settings of another kind of item.
- **Units on every slider:** `format = UI.px`, `UI.pct`, or a function such
  as `("%.1f s"):format(v)`. Plain counts need no unit.
- **Every color picker has opacity** (`alpha = true`), unless the color is
  used where opacity cannot apply.
- **Up to 3 choices: `Segmented`. More, or a list that changes: `Dropdown`.**
- **Actions are buttons.** No "pick something, then press Apply".
- **Reset and destructive actions:** `"danger"` style and `UI.Confirm` (two
  clicks), or `UI.Dialog` when a lot is lost.
- **No filler text.** No notes or tooltips that repeat the label. A subtitle or
  note must say something the controls don't.
- **Same thing, same control.** If an option exists for several kinds of
  items, it uses the same control, label and place for all of them.
- **Labels are short, in sentence case**, without a final period.
- **Nothing outside the lib** in a settings window. Add the missing piece to
  the lib (and to the gallery) instead of building one-off widgets.
- **Accent color is for state and titles:** selection, checks, card titles. Not
  for plain text.

## Rows: what every control shares

Every control except `Button`, `IconButton`, `EditBox`, `Tabs`, `Dialog` and
`ScrollBar` is a **row**: a frame that takes the width its card gives it.
Rows take an `opts` table with:

| Option | Effect |
|---|---|
| `showIf()` | false: the row is hidden and the card closes the gap |
| `enableIf()` | false: the row is greyed out and ignores clicks |
| `tip` | tooltip text when hovering the row (title = the label) |
| `sub = true` | a sub-option: sits close under the row before it |

Pass a new `opts` table to each control: constructors write into it.

To build your own row: `UI.Row(parent, height, opts)`, then set
`row.OnWidth = function(w) ... end` to lay out its parts. Refresh it from
`UI.OnRefresh`.

## Components

### Buttons

**`UI.Buttons(parent, list, opts)`** (row): buttons sharing the row width.
`list = { { text, onClick, style, tip }, ... }`. Style: `nil`, `"accent"` (the
main action) or `"danger"`. The buttons are `row.buttons[i]`.

```lua
local r = card:Add(UI.Buttons(card, {
    { "Test", Test },
    { "Reset", Reset, "danger" },
}))
UI.Confirm(r.buttons[2])
```

**`UI.Confirm(button, armedText)`**: the first click arms the button (text
turns to "Click again to confirm"), a second click within 3 s runs it.

**`UI.Button(parent, text, w, h, onClick, style)`**: a single button that you
place yourself (not a row). For card rows, use `Buttons`.

**`UI.IconButton(parent, icon, size, onClick, opts)`**: small square button.
`icon` is a drawn glyph (`"plus"`, `"minus"`, `"close"`, `"more"`, `"up"`,
`"down"`, `"left"`, `"right"`) or any texture path or atlas. Size 16 (default)
or 20. `opts.tip`, `opts.style = "danger"`, `opts.isOn()` lights it with the
accent (a toggle such as lock or pin). Not a row; inside a card use
`card:AddHeaderButton` or place it in a `UI.Row`.

### On / off

**`UI.Check(parent, label, get, set, opts)`**: check box. The default for any
option that is on or off.

**`UI.Switch(parent, label, get, set, opts)`**: sliding switch, label on the
left. For the main on/off of a feature, usually the first row of its card.

**`UI.CheckGroup(parent, label, options, get, set, opts)`**: check boxes in
columns. `options = { { value, label }, ... }`, `get(value)`,
`set(value, on)`, `opts.columns` (default 2). `label` can be nil.

### Values

**`UI.Slider(parent, label, min, max, step, get, set, opts)`**: drag, `< >`
buttons, or click the value to type it. `opts.format(v)` returns the shown
text. No mouse wheel, so the page keeps scrolling.

**`UI.Segmented(parent, label, options, get, set, opts)`**: 2 or 3 exclusive
choices side by side. `options = { { value, label }, ... }`. `label` can be nil.

**`UI.Dropdown(parent, label, options, get, set, opts)`**: a list of choices.
`options = { { value, label, font, texture }, ... }` or a function that
returns it (re-read on every open and refresh). With `font`, the choice is
drawn in that font; with `texture` (path or atlas), a sample shows behind it.
Over 14 choices it scrolls and opens on the current value. A value not in the
list shows its file name.

**`UI.Swatch(parent, label, getColor, onChange, opts)`**: color box that opens
the color picker. `getColor()` returns a `{ r, g, b, a }` table that the picker
edits in place; `nil` shows an empty swatch that does not open.
`opts.alpha = true` edits opacity too.

### Text

**`UI.Input(parent, label, get, set, opts)`**: one-line input. Saves on Enter;
`opts.saveOnBlur = true` also saves when focus leaves. Escape cancels. Tab
moves to the next input of the instance.

**`UI.SearchBox(parent, hint, onChange, opts)`**: grey hint while empty, an
x to clear it, `onChange(text)` on every key. The edit box is `row.edit`.

**`UI.CodeBox(parent, height, opts)`**: multi-line text with its own scroll.
Set and read the text through `row.edit`.

**`UI.EditBox(parent, w, h)`**: a bare themed edit box (not a row), for
building your own controls.

**`UI.Note(parent, text, opts)`**: grey text that wraps to the width.
`note:SetText(text)` changes it (then lay out the page).

### Dividers inside a card

**`UI.Heading(parent, text, opts)`**: small grey title with a line after it,
to name a group of rows inside a card. **`UI.Separator(parent, opts)`**: just
the line. `opts.accent = true` colors the line with the accent. The card hides
a divider that would sit alone: a heading with no visible row under it, or a
separator without visible rows on both sides.

### List

**`UI.List(parent, opts)`**: one widget for every list. A dark box that always
shows `opts.rows` rows (default 8) and scrolls when longer.

```
[box] [lead] Name ............... secondary  TAG  [x]
```

| Option | Meaning |
|---|---|
| `items()` | the rows, already flattened (see groups) |
| `label(item, i)` | name text (required) |
| `off(item)` | true: name dimmed (hidden or disabled item) |
| `lead` + `icon(item)` / `color(item)` | `"icon"`, `"swatch"` or `"dot"` before the name |
| `secondary(item)` | grey text on the right (ID, count) |
| `tag(item)` | `text, {r,g,b}`: short label in its own column |
| `columns` | `{ name, secondary, tag }` column titles |
| `selected(item, i)` + `onSelect(i, item)` | one selected row |
| `checked(item)` + `onCheck(item, v)` | check box per row; `"partial"` on a group header |
| `onRemove(i, item)` | red x, two clicks; `canRemove(item)` limits it |
| `onReorder(from, to)` | drag rows to reorder |
| `spell(item)` | spell ID: spell tooltip on hover |
| `empty` | text when there are no rows |
| `onToggle(item)` | opens and closes group headers |
| `richHeaders = true` | headers are full rows (lead, secondary, select) |

Groups: put `{ header = true, label, count, closed, off }` rows in `items()`,
followed by their items when open. `leaf = true` on a rich header has nothing
to open. The list does not change your data: `onRemove` and `onReorder` must
do it, and keep your selection right.

### Containers

**`UI.Card(parent, title, subtitle, opts)`**: box with an accent title. Add
rows with `card:Add(row)`; they stack top to bottom.
- `opts.fold = true`: the title bar folds the card. `opts.summary()` is the
  grey text shown when folded (else the subtitle). `opts.store` + `opts.key`
  keep the folded state (pass a saved table to keep it after reload).
  `opts.folded = true` starts folded.
- `card:AddHeaderButton(icon, onClick, opts)`: icon buttons on the right of
  the title, added right to left. They stay visible while folded.
- `card.showIf = function() ... end` hides the whole card.

**`UI.Page(container, columns)`**: scrolling area with columns of cards.
- `page:Add(col, card, span)`: adds a card to a column. `span` (default 1)
  makes it take several columns; it starts under the lowest of them.
- `page:AddSection(label, opts)`: a title across the page; the cards added
  after it go below it. No label: just a line. `opts.accent = true` colors the
  line. A section with no visible cards hides its title.
- `page:Layout()` after building. Cards are parented to `page.content`.

**`UI.Split(parent, leftWidth)`**: returns two one-column pages, a fixed-width
one on the left (usually a `List` to pick from) and the rest on the right.

**`UI.Tabs(parent, list, onSelect)`**: text tabs with an accent underline.
`list = { { key, label }, ... }`, `tabs:Select(key)`. Not a row: inside a card,
put it in a `UI.Row(card, 26)` and give the rows of each tab a `showIf`.

### Window and dialogs

**`UI.Window(opts)`**: the settings window: header, navigation on the left,
page area, status line. `opts = { name, title, version, width, height,
navWidth, logo, status = false }`. With `name`, Escape closes it.
- `win:AddNav(key, label, build, dot)`: `build(container)` runs the first time
  the page opens; `dot()` lights a dot next to the label.
- `win:AddSection(label)`: small caption between nav buttons.
- `win:AddHeaderButton(label, onClick, isOn, tip)`: button in the header;
  `isOn()` lights it.
- `win:Select(key)`, `win:Toggle()`, `win:SetSubtitle(text)`,
  `win:SetStatus(text)`.

**`UI.Dialog(text, acceptText, onAccept, cancelText)`**: centered question
that darkens the screen. Escape or Cancel closes it.

### Helpers

| Function | Use |
|---|---|
| `UI.Row(parent, height, opts)` | base of a custom row |
| `UI.Text(parent, text, font, color)` | font string with the theme font |
| `UI.Backdrop(frame, bg, border)` | flat 1 px border background |
| `UI.Tip(frame, title, text)` | tooltip on any frame |
| `UI.SetEnabled(frame, on)` | grey out any frame without moving it |
| `UI.ScrollBar(parent, onScroll)` | the themed scroll bar (`SetRange`, `SetPos`) |
| `UI.CloseMenu()` | close the open dropdown list |
| `UI.pct`, `UI.px` | slider formats |

## Theme

Pass any of these to `:New(theme)`. Colors are `{ r, g, b[, a] }`.

| Key | Default | Use |
|---|---|---|
| `accent` | green | brand color: titles, checks, selection, thumbs |
| `window`, `windowBorder`, `header`, `nav`, `navSelected` | dark | window parts (`navSelected`: a dark shade of the accent) |
| `button`, `border`, `field`, `fieldDark` | dark | controls |
| `card`, `cardBorder` | dark | cards |
| `text`, `muted`, `danger`, `success` | | text colors |
| `labelFont`, `titleFont` | `GameFontHighlightSmall`, `GameFontNormal` | fonts |
| `rowHeight` | 18 | height of a one-line control |
| `gap` | 10 | space between rows of a card |
| `cardGap` | 20 | space between cards and columns |
| `subGap` | 2 | space above a sub-option |
| `pad` | 10 | inner margin of a card |
| `pageMargin` | 16 | space left and right of the cards in a window |
