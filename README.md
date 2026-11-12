# LibFlatyUI-1.0

Flat, dark controls for addon settings windows, built only from plain frames,
textures and font strings, so the look does not change between game versions.

Used by [Sigil](https://github.com/franlol/Sigil) and [Tidy](https://github.com/franlol/Tidy).

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

Controls: `Button`, `Buttons`, `Confirm`, `Check`, `CheckGroup`, `Switch`, `Slider`,
`Segmented`, `Dropdown`, `Swatch`, `Input`, `SearchBox`, `CodeBox`, `Note`, `List`,
`Card`, `Page`, `Tabs`, `Dialog`, `Window`. The header of `LibFlatyUI-1.0.lua`
documents the options every control accepts.

`List` is one widget for every list: a fixed-height box that scrolls, with
optional icon / swatch / dot, secondary text, tag column, column titles, check
boxes, a remove button that asks for a second click, drag to reorder, and
groups that open and close. Long texts are cut and shown whole on hover.

`Card(parent, title, subtitle, { fold = true })` folds down to its title bar.

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

## License

MIT
