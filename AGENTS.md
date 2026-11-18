# Working on or with LibFlatyUI-1.0

## Using the lib in an addon

1. Read `COMPONENTS.md` first. It tells you which component fits each need,
   and the design rules every window follows.
2. Use the comments above each constructor in `LibFlatyUI-1.0.lua` for the
   exact options.
3. Don't build one-off widgets in an addon. If something is missing, add it to
   the lib.

## Changing the lib

- **Bump `MINOR`** at the top of `LibFlatyUI-1.0.lua` for every released
  change. LibStub loads the highest MINOR across all installed addons, so an
  addon's bundled copy may not be the one that runs.
- **Plain frames only:** frames, textures and font strings. No Blizzard
  templates except `BackdropTemplate`, and no image files for marks (draw them
  from bars, like the tick and the chevron).
- **Every new component or state goes in three places:** its comment in the
  code, `COMPONENTS.md` (including the "Picking a component" table when it
  changes a choice), and the [Flaty Gallery](https://github.com/franlol/FlatyGallery) addon (`/flaty`).
- **Media** (`Media/`): add an item to the `OWN` list (or a shape with
  `RegisterShape`), name it `Flaty: <name>`, and show it in the gallery's
  Media pages. Textures are white 32-bit TGA (RLE) so colors tint them; fonts
  only under the SIL Open Font License, with the license file in
  `Media/Fonts/LICENSES`. Addons embed the lib at `Libs\LibFlatyUI-1.0`; the
  media path depends on it.
- **Keep old calls working.** New options are optional, and defaults keep the
  current look.
- **Check before committing:** `luac -p LibFlatyUI-1.0.lua`, and look for
  accidental globals (`luac -p -l -l` and search for `SETTABUP _ENV`).
- Comments and docs use plain, short sentences.
