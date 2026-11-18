# LibFlatyUI-1.0

Flat, dark controls for addon settings windows, built only from plain frames,
textures and font strings, so the look does not change between game versions.

Used by [Sigil](https://github.com/franlol/Sigil), [Tidy](https://github.com/franlol/Tidy) and [Tile](https://github.com/franlol/Tile).

## Usage

```lua
local UI = LibStub("LibFlatyUI-1.0"):New({ accent = { 0.7, 0.55, 1 } })
local win = UI.Window({ name = "MyAddonOptions", title = "MyAddon" })
win:AddNav("general", "General", function(container)
    local page = UI.Page(container, 2)
    local card = page:Add(1, UI.Card(page.content, "Look"))
    card:Add(UI.Check(card, "Enable", getter, setter))
end)
win:Select("general")
```

**[COMPONENTS.md](COMPONENTS.md)** lists every component, when to use each
one, and the design rules. The [Flaty Gallery](https://github.com/franlol/FlatyGallery) addon (`/flaty`) shows them all
in every state. Working on the lib: see [AGENTS.md](AGENTS.md).

Controls: `Button`, `Buttons`, `IconButton`, `Menu`, `Confirm`, `Check`, `CheckGroup`, `Switch`,
`Slider`, `Segmented`, `Tiles`, `Dropdown`, `Swatch`, `Input`, `SearchBox`, `CodeBox`, `Note`,
`Heading`, `Separator`, `List`,
`Card`, `Page`, `Split`, `Tabs`, `Dialog`, `Window`. The header of `LibFlatyUI-1.0.lua`
documents the options every control accepts.

`List` is one widget for every list: a fixed-height box that scrolls, with
optional icon / swatch / dot, secondary text, tag column, column titles, check
boxes, a remove button that asks for a second click, drag to reorder, and
groups that open and close. Long texts are cut and shown whole on hover.

`Card(parent, title, subtitle, { fold = true })` folds down to its title bar;
`card:AddHeaderButton(icon, onClick, opts)` puts icon buttons next to its title.
`page:AddSection(label)` puts a title across every column of a page, between cards.

## Media

A basic set that every addon gets, without SharedMedia: bar textures,
backgrounds, border edges, six fonts (Inter, Roboto Condensed, Rubik, Oswald,
Manrope, Nunito) and shapes (rounded squares from 0% to 100% round, square and circle included) with masks and
glows. Each one is named `Flaty: <name>` and registered in LibSharedMedia-3.0.
See the Media section of [COMPONENTS.md](COMPONENTS.md#media).

The fonts are under the SIL Open Font License 1.1; their license files are in
`Media/Fonts/LICENSES`. The textures are made for this lib (MIT).

## Embedding

In your `.pkgmeta`:

```yaml
externals:
  Libs/LibFlatyUI-1.0:
    url: https://github.com/franlol/LibFlatyUI-1.0
    tag: latest
```

and in your TOC, after LibStub:

```
Libs\LibFlatyUI-1.0\LibFlatyUI-1.0.lua
```

Keep it at `Libs\LibFlatyUI-1.0`: the lib finds its `Media` folder there.

## License

MIT
