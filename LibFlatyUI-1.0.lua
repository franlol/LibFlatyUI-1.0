-------------------------------------------------------------------------------
-- LibFlatyUI-1.0
--
-- Flat, dark controls for addon settings windows, built only from plain
-- frames, textures and font strings (no Blizzard UI templates other than
-- BackdropTemplate), so the look does not change between game versions.
--
-- COMPONENTS.md (next to this file) lists every component, when to use
-- each one, and the design rules. Read it before building a window.
--
-- Usage
--   local UI = LibStub("LibFlatyUI-1.0"):New({ accent = { 0.7, 0.55, 1 } })
--   local win = UI.Window({ name = "MyAddonOptions", title = "MyAddon" })
--   win:AddNav("general", "General", function(container)
--       local page = UI.Page(container, 2)
--       local card = page:Add(1, UI.Card(page.content, "Look"))
--       card:Add(UI.Check(card, "Enable", getter, setter))
--   end)
--   win:Select("general")
--
-- Instances
--   :New(theme) returns an independent instance with its own colors and its
--   own list of controls. Every constructor of an instance is a plain
--   function (UI.Button(...), not UI:Button(...)).
--
-- Controls
--   Every control is a "row": a frame that takes the width its card gives
--   it. Rows accept an options table:
--     showIf()   -> the row is hidden when it returns false (the card closes
--                   the gap)
--     enableIf() -> the row is greyed out and ignores clicks when false
--     tip        -> help text shown in a tooltip when hovering the row
--     sub        -> a sub-option: sits close under the row before it
--   get/set pairs read and write the value the control shows. After a user
--   change the instance calls UI.OnChange(), if defined (usually to call
--   UI.RefreshAll()).
-------------------------------------------------------------------------------

local LOADER = ...   -- the addon whose TOC loads this file (for the media path)
local MAJOR, MINOR = "LibFlatyUI-1.0", 20
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local FLAT = "Interface\\Buttons\\WHITE8X8"

-------------------------------------------------------------------------------
-- Theme
-------------------------------------------------------------------------------
lib.defaultTheme = {
    accent = { 0.27, 0.75, 0.45 },          -- brand color: marks, thumbs, focus
    window = { 0.06, 0.06, 0.08, 0.97 },
    windowBorder = { 0.2, 0.2, 0.25, 1 },
    header = { 0.08, 0.1, 0.15, 1 },
    nav = { 0.1, 0.1, 0.12, 1 },
    navSelected = nil,                      -- (nil: a dark shade of the accent)
    button = { 0.15, 0.15, 0.18, 1 },
    border = { 0.25, 0.25, 0.3, 1 },
    field = { 0.05, 0.05, 0.06, 1 },
    fieldDark = { 0.03, 0.03, 0.04, 1 },
    card = { 0.095, 0.095, 0.118, 1 },
    cardBorder = { 0.19, 0.19, 0.235, 1 },
    text = { 1, 1, 1 },
    muted = { 0.65, 0.65, 0.65 },
    danger = { 1, 0.45, 0.35 },
    success = { 0.42, 0.84, 0.42 },
    labelFont = "GameFontHighlightSmall",
    titleFont = "GameFontNormal",
    rowHeight = 18,        -- height of a one-line control
    gap = 10,              -- space between rows of a card
    cardGap = 20,          -- space between cards, columns and split panes
    subGap = 2,            -- space above a sub-option (opts.sub) under its row
    pad = 10,              -- inner margin of a card
    pageMargin = 16,       -- space left and right of the cards (to the navigation and the window edge)
}

local function Merge(base, over)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(over or {}) do t[k] = v end
    return t
end

-------------------------------------------------------------------------------
-- Flat marks drawn from rotated bars (no image files, sharp at any scale)
-------------------------------------------------------------------------------
-- Tick for a 14x14 check box, and a dash for "some" (a group with part of
-- its items on). A frame, so it fades with SetAlpha. f:SetPartial(on)
local function NewTick(box, color)
    local f = CreateFrame("Frame", nil, box)
    f:SetAllPoints()
    f:SetFrameLevel(box:GetFrameLevel() + 1)
    local function Bar(w, h, x, y, deg)
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(color[1], color[2], color[3], 1)
        t:SetSize(w, h)
        t:SetPoint("CENTER", x, y)
        if deg then t:SetRotation(math.rad(deg)) end
        return t
    end
    -- tick corners (from the box center): (-3.5, 0) -> (-1, -2.5) -> (4, 3)
    f.short = Bar(4.6, 2, -2.25, -1.25, -45)
    f.long = Bar(8.4, 2, 1.5, 0.25, 47.7)
    f.dash = Bar(8, 2, 0, 0)
    function f:SetPartial(on)
        self.short:SetShown(not on)
        self.long:SetShown(not on)
        self.dash:SetShown(on and true or false)
    end
    f:SetPartial(false)
    return f
end

-- Chevron, 10x10: ">" closed, "v" open; turning rotates it a quarter turn.
-- f:SetOpen(open, animate), f:SetColor(r, g, b)
local TURN = 0.15
local function NewChevron(parent, color)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(10, 10)
    local a = f:CreateTexture(nil, "OVERLAY")
    local b = f:CreateTexture(nil, "OVERLAY")
    a:SetSize(6.4, 2)
    b:SetSize(6.4, 2)
    function f:SetColor(r, g, bl)
        a:SetColorTexture(r, g, bl, 1)
        b:SetColorTexture(r, g, bl, 1)
    end
    -- p = 0: ">" (bars from (-2, 4) and (-2, -4) to (2, 0)); p = 1: turned
    -- 90 degrees clockwise
    local function Draw(p)
        p = p * p * (3 - 2 * p)   -- smooth start and end
        local th = -math.pi / 2 * p
        local c, s = math.cos(th), math.sin(th)
        local function Put(tex, x, y, deg)
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", x * c - y * s, x * s + y * c)
            tex:SetRotation(math.rad(deg) + th)
        end
        Put(a, 0, 2, -45)
        Put(b, 0, -2, 45)
    end
    local function Step(self, elapsed)
        local d = elapsed / TURN
        if self.goal > self.p then self.p = math.min(self.goal, self.p + d)
        else self.p = math.max(self.goal, self.p - d) end
        Draw(self.p)
        if self.p == self.goal then self:SetScript("OnUpdate", nil) end
    end
    -- the first call, and any call while hidden, jumps straight to the state
    function f:SetOpen(open, animate)
        local goal = open and 1 or 0
        if self.goal == goal then return end
        local first = self.goal == nil
        self.goal = goal
        if first or not animate or not self:IsVisible() then
            self.p = goal
            self:SetScript("OnUpdate", nil)
            Draw(goal)
            return
        end
        self:SetScript("OnUpdate", Step)
    end
    -- hidden mid-turn (a reused list row): finish, or it stays crooked
    f:SetScript("OnHide", function(self)
        if self.goal and self.p ~= self.goal then
            self.p = self.goal
            self:SetScript("OnUpdate", nil)
            Draw(self.goal)
        end
    end)
    f:SetColor(color[1], color[2], color[3])
    return f
end

-- Small flat glyph for icon buttons, drawn from bars like the tick:
-- "plus", "minus", "close", "more", "up", "down", "left", "right".
-- g = size of the glyph box. f:SetColor(r, g, b)
local GLYPHS = { plus = true, minus = true, close = true, more = true,
    up = true, down = true, left = true, right = true }
local function NewGlyph(parent, kind, g)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(g, g)
    f:SetPoint("CENTER")
    f.bars = {}
    local function Bar(w, h, x, y, deg)
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetSize(w, h)
        t:SetPoint("CENTER", x, y)
        if deg then t:SetRotation(math.rad(deg)) end
        table.insert(f.bars, t)
        return t
    end
    if kind == "plus" then
        Bar(g, 2, 0, 0)
        Bar(2, g, 0, 0)
    elseif kind == "minus" then
        Bar(g, 2, 0, 0)
    elseif kind == "close" then
        Bar(g * 1.2, 2, 0, 0, 45)
        Bar(g * 1.2, 2, 0, 0, -45)
    elseif kind == "more" then
        local s = math.max(3, math.floor(g / 3 + 0.5))
        for _, x in ipairs({ -s, 0, s }) do Bar(2, 2, x, 0) end
    else
        -- chevron pointing right, turned to its direction (same shape as
        -- the fold chevron, scaled to the box)
        local th = math.rad(({ right = 0, down = -90, left = 180, up = 90 })[kind])
        local c, s = math.cos(th), math.sin(th)
        local len, off = 0.64 * g, 0.2 * g
        for _, p in ipairs({ { off, -45 }, { -off, 45 } }) do
            local y, deg = p[1], p[2]
            Bar(len, 2, -y * s, y * c, deg + math.deg(th))
        end
    end
    function f:SetColor(r, gr, b)
        for _, t in ipairs(self.bars) do t:SetColorTexture(r, gr, b, 1) end
    end
    return f
end

-- Only one dropdown list can be open at a time, for every instance
lib.openMenu = lib.openMenu
lib.closer = lib.closer or CreateFrame("Frame")
pcall(lib.closer.RegisterEvent, lib.closer, "GLOBAL_MOUSE_DOWN")
lib.closer:SetScript("OnEvent", function()
    local m = lib.openMenu
    if not m then return end
    if m:IsMouseOver() or (m.owner and m.owner:IsMouseOver()) then return end
    m:Hide()
    lib.openMenu = nil
end)

-------------------------------------------------------------------------------
-- Media: bar textures, backgrounds, borders, fonts and shapes shipped in the
-- Media folder, so an addon always has a basic set without SharedMedia.
--
-- The files are read from the copy that runs: the standalone addon
-- (AddOns\LibFlatyUI-1.0\Media) or the copy embedded in the addon that
-- loaded it, which must sit in <Addon>\Libs\LibFlatyUI-1.0.
--
-- Every item is named "Flaty: <name>" and registered in LibSharedMedia-3.0
-- when an addon loads it, so other addons can pick them too.
-------------------------------------------------------------------------------
local MEDIA = (LOADER == nil or LOADER == MAJOR)
    and "Interface\\AddOns\\LibFlatyUI-1.0\\Media\\"
    or ("Interface\\AddOns\\%s\\Libs\\LibFlatyUI-1.0\\Media\\"):format(LOADER)
lib.mediaPath = MEDIA
local PREFIX = "Flaty: "

-- Ours, by LibSharedMedia type: { name, file in the Media folder }
local OWN = {
    statusbar = {
        { "Smooth", "Bars\\Smooth" },
        { "Gradient", "Bars\\Gradient" },
        { "Gradient reverse", "Bars\\GradientReverse" },
        { "Soft", "Bars\\Soft" },
        { "Dark", "Bars\\Dark" },
        { "Striped", "Bars\\Striped" },
    },
    background = {
        { "Gradient up", "Backgrounds\\GradientUp" },
        { "Gradient down", "Backgrounds\\GradientDown" },
        { "Gradient left", "Backgrounds\\GradientLeft" },
        { "Gradient right", "Backgrounds\\GradientRight" },
    },
    border = {
        { "Pixel", "Borders\\Pixel" },
        { "Glow", "Borders\\Glow" },
        { "Shadow", "Borders\\Shadow" },
    },
    font = {
        { "Inter", "Fonts\\Inter-SemiBold.ttf" },
        { "Roboto Condensed", "Fonts\\RobotoCondensed-Bold.ttf" },
        { "Rubik", "Fonts\\Rubik-Medium.ttf" },
        { "Oswald", "Fonts\\Oswald-Medium.ttf" },
        { "Manrope", "Fonts\\Manrope-SemiBold.ttf" },
        { "Nunito", "Fonts\\Nunito-SemiBold.ttf" },
    },
}

-- The game's own: always there. A value is a file path or an atlas name.
local GAME = {
    statusbar = {
        { "Flat", FLAT },
        { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
        { "Raid frames", "RaidFrame-Hp-Fill" },
        { "Raid frames · resource", "_RaidFrame-Resource-Fill" },
        { "Arena frames", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
        { "Pet battles", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill" },
        { "Gloss", "Interface\\TargetingFrame\\BarFill2" },
        { "Skills", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    },
    background = {
        { "Solid", FLAT },
        { "Raid frames · background", "raidframe-hp-bg-white" },
    },
    border = {
        { "Tooltip", "Interface\\Tooltips\\UI-Tooltip-Border" },
        { "Dialog", "Interface\\DialogFrame\\UI-DialogBox-Border" },
    },
    font = {
        { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
        { "Arial Narrow", "Fonts\\ARIALN.TTF" },
        { "Skurri", "Fonts\\skurri.ttf" },
        { "Morpheus", "Fonts\\MORPHEUS.ttf" },
    },
}

local function LSM()
    return LibStub("LibSharedMedia-3.0", true)
end

-- Path of an item by its shown name ("Flaty: Smooth", "Blizzard"), or nil
function lib.Media(kind, name)
    for _, e in ipairs(OWN[kind] or {}) do
        if PREFIX .. e[1] == name then return MEDIA .. e[2] end
    end
    for _, e in ipairs(GAME[kind] or {}) do
        if e[1] == name then return e[2] end
    end
    local lsm = LSM()
    return lsm and lsm:IsValid(kind, name) and lsm:Fetch(kind, name, true) or nil
end

-- A saved path, ready to use. Our files are found in the running copy even
-- when the path points to another addon's copy. A file in the folder of an
-- addon that is not loaded (a SharedMedia texture, in an imported profile)
-- gives nil: the caller uses its fallback. Atlas names pass through.
function lib.ResolveMedia(path)
    if type(path) ~= "string" or path == "" then return nil end
    local unified = path:gsub("/", "\\")
    local low = unified:lower()
    local s, e = low:find("\\libflatyui-1.0\\media\\", 1, true)
    if s then return MEDIA .. unified:sub(e + 1) end
    local addon = low:match("^interface\\addons\\([^\\]+)\\")
    if addon and C_AddOns and C_AddOns.IsAddOnLoaded then
        local real = unified:match("^[^\\]+\\[^\\]+\\([^\\]+)\\")
        if not C_AddOns.IsAddOnLoaded(real) then return nil end
    end
    return path
end

-- Dropdown options for a media type: ours, the game's, then the rest of
-- LibSharedMedia (when an addon loads it), each path once.
-- kind = "statusbar", "background", "border" or "font"
-- opts.none = true: "None" first (value "none"); opts.noneLabel names it.
-- Fonts are drawn in their font; bars and backgrounds show a sample.
function lib.MediaList(kind, opts)
    opts = opts or {}
    local out, seen = {}, {}
    local sample = kind == "statusbar" or kind == "background"
    local function Add(value, label)
        local key = value:lower()
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = { value, label, kind == "font" and value or nil, sample and value or nil }
    end
    for _, e in ipairs(OWN[kind] or {}) do Add(MEDIA .. e[2], PREFIX .. e[1]) end
    for _, e in ipairs(GAME[kind] or {}) do Add(e[2], e[1]) end
    local lsm = LSM()
    if lsm then
        local extra = {}
        for name, path in pairs(lsm:HashTable(kind)) do
            if type(path) == "string" and name:sub(1, #PREFIX) ~= PREFIX then
                extra[#extra + 1] = { path, name }
            end
        end
        table.sort(extra, function(a, b) return a[2] < b[2] end)
        for _, e in ipairs(extra) do Add(e[1], e[2]) end
    end
    if opts.none then
        table.insert(out, 1, { "none", opts.noneLabel or "None" })
    end
    return out
end

local function IsNone(path) return path == nil or path == "" or path == "none" end

-- Bar texture from a saved value; "none" keeps the bar but hides the fill
function lib.SetBarTexture(bar, path)
    local none = IsNone(path)
    bar:SetStatusBarTexture(not none and lib.ResolveMedia(path) or FLAT)
    local t = bar:GetStatusBarTexture()
    if t then t:SetAlpha(none and 0 or 1) end
end

-- Plain texture (background) from a saved value: a file or an atlas;
-- "none" hides it
function lib.SetBgTexture(tex, path)
    local none = IsNone(path)
    local p = not none and lib.ResolveMedia(path) or FLAT
    if not none and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(p) then
        tex:SetAtlas(p)
    else
        tex:SetTexture(p)
    end
    tex:SetShown(not none)
end

-- Font from a saved value; the game's font when the file can't be used
function lib.SetFontFile(fs, path, size, flags)
    local p = lib.ResolveMedia(path) or STANDARD_TEXT_FONT
    if not fs:SetFont(p, size, flags or "") then
        fs:SetFont(STANDARD_TEXT_FONT, size, flags or "")
    end
end

-- Register ours in LibSharedMedia when an addon brings it
local function RegisterLSM()
    local lsm = LSM()
    if not lsm then return end
    for kind, list in pairs(OWN) do
        for _, e in ipairs(list) do lsm:Register(kind, PREFIX .. e[1], MEDIA .. e[2]) end
    end
end
RegisterLSM()
lib.mediaEvents = lib.mediaEvents or CreateFrame("Frame")
lib.mediaEvents:RegisterEvent("ADDON_LOADED")
lib.mediaEvents:RegisterEvent("PLAYER_LOGIN")
lib.mediaEvents:SetScript("OnEvent", RegisterLSM)

-------------------------------------------------------------------------------
-- Shapes: a mask (white shape that fills its file) and a glow (the same
-- shape filling the middle 3/4 of its file, fading out to the edges).
-- Masks work with Minimap:SetMaskTexture and with mask textures.
--
-- Rounded squares come in every percent of roundness, from 0 (square) to
-- 100 (circle): key "r0" ... "r100", or lib.Rounded(pct) for the key. The
-- named shapes are some of them. Addons can add more:
-- lib.RegisterShape({ key, name, mask, glow, hole }) (hole: optional, the
-- mask inside out at half size in the middle of its file, for rings).
-------------------------------------------------------------------------------
lib.shapes = lib.shapes or {}

function lib.RegisterShape(def)
    for i, s in ipairs(lib.shapes) do
        if s.key == def.key then
            lib.shapes[i] = def
            return
        end
    end
    lib.shapes[#lib.shapes + 1] = def
end

-- Key of the rounded square with pct% round corners (0-100)
function lib.Rounded(pct)
    pct = math.max(0, math.min(100, math.floor((tonumber(pct) or 0) + 0.5)))
    return "r" .. pct
end

local rounded = {}
local function RoundedShape(pct, name)
    if not rounded[pct] then
        local file = ("Rounded\\R%03d"):format(pct)
        rounded[pct] = { key = "r" .. pct, name = name or (PREFIX .. pct .. "%"), corners = pct,
            mask = MEDIA .. "Masks\\" .. file, glow = MEDIA .. "Glows\\" .. file,
            hole = MEDIA .. "Holes\\" .. file }
    end
    return rounded[pct]
end

for _, s in ipairs({
    { "square", "Square", 0 },
    { "slightly", "Slightly rounded", 8 },
    { "rounded", "Rounded square", 20 },
    { "round", "Round", 100 },
}) do
    local r = RoundedShape(s[3])
    lib.RegisterShape({ key = s[1], name = PREFIX .. s[2], corners = s[3], mask = r.mask, glow = r.glow })
end

-- Where the edge of a shape is, in a direction from its center: x, y
-- offsets for a frame of half width halfW and half height halfH (the shape
-- stretches to the frame). angle in degrees: 0 right, 90 up. extra: the
-- distance past the edge (negative: inside). For icons around a minimap.
-- Shapes without corners (added by addons) count as squares.
function lib.ShapeEdge(key, angle, halfW, halfH, extra)
    local rc = (lib.GetShape(key).corners or 0) / 100
    local a = math.rad(angle)
    local c, s = math.cos(a), math.sin(a)
    -- signed distance to the rounded square of half size 1
    local function SD(x, y)
        local qx, qy = math.abs(x) - (1 - rc), math.abs(y) - (1 - rc)
        local ox, oy = math.max(qx, 0), math.max(qy, 0)
        return math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0) - rc
    end
    -- the edge along the ray (between 1 for a circle and 1.42 for a corner)
    local lo, hi = 0, 1.5
    for _ = 1, 24 do
        local m = (lo + hi) / 2
        if SD(c * m, s * m) > 0 then hi = m else lo = m end
    end
    local t = (lo + hi) / 2
    extra = extra or 0
    return c * (t * halfW + extra), s * (t * halfH + extra)
end

-- A shape by key (a named one or "r0"-"r100"); the square for an unknown key
function lib.GetShape(key)
    local pct = type(key) == "string" and tonumber(key:match("^r(%d+)$"))
    if pct and pct <= 100 then return RoundedShape(pct) end
    for _, s in ipairs(lib.shapes) do
        if s.key == key then return s end
    end
    return lib.shapes[1]
end

-- Dropdown options: { key, name }
function lib.ShapeList()
    local out = {}
    for _, s in ipairs(lib.shapes) do out[#out + 1] = { s.key, s.name } end
    return out
end

-- Cut a texture to a shape (a mask texture, made once per texture)
function lib.SetShapeMask(tex, key)
    if not tex.flatyMask then
        tex.flatyMask = tex:GetParent():CreateMaskTexture()
        tex.flatyMask:SetAllPoints(tex)
        tex:AddMaskTexture(tex.flatyMask)
    end
    tex.flatyMask:SetTexture(lib.GetShape(key).mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
end

-- Cut a texture to the outline of a shape: a ring size px thick along its
-- edge, empty inside (a border that stays a border under a see-through
-- background). Two masks: the shape, and its hole file over the inside.
-- Size the texture first (SetSize); call again after it changes size.
-- Shapes without a hole file get the plain shape.
--   tex:SetTexture("Interface\\Buttons\\WHITE8X8")
--   tex:SetVertexColor(r, g, b, a)
--   lib.SetShapeRing(tex, key, 1)
function lib.SetShapeRing(tex, key, size)
    local shape = lib.GetShape(key)
    lib.SetShapeMask(tex, key)
    if not tex.flatyHole then
        tex.flatyHole = tex:GetParent():CreateMaskTexture()
    end
    local w, h = tex:GetSize()
    local iw, ih = w - 2 * size, h - 2 * size
    local ring = shape.hole and iw > 0 and ih > 0
    if ring ~= tex.flatyHoleOn then
        if ring then tex:AddMaskTexture(tex.flatyHole) else tex:RemoveMaskTexture(tex.flatyHole) end
        tex.flatyHoleOn = ring
    end
    if not ring then return end
    -- the shape's hole fills the middle half of the file: the file spans
    -- twice the inside, centered, and stays white past the outside
    tex.flatyHole:SetTexture(shape.hole, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    tex.flatyHole:ClearAllPoints()
    tex.flatyHole:SetPoint("CENTER", tex, "CENTER")
    tex.flatyHole:SetSize(2 * iw, 2 * ih)
end

-- Border and glow of a shape around a frame, drawn behind it. The frame's
-- content is cut by its owner (Minimap:SetMaskTexture or SetShapeMask).
--   local sb = lib.ShapeBorder(frame)
--   sb:SetShape(key)
--   sb:SetBorder(size, { r, g, b, a })   size 0 or no color: no border
--   sb:SetGlow({ r, g, b, a })           nil: no glow; it reaches 1/6 of
--                                        the size past the border
function lib.ShapeBorder(frame)
    local holder = CreateFrame("Frame", nil, frame:GetParent() or UIParent)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    holder:SetAllPoints(frame)
    local glow = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
    local border = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
    local sb = { frame = holder, key = "square", size = 1 }

    local function Layout()
        local shape = lib.GetShape(sb.key)
        local b = (sb.borderColor and sb.size or 0)
        border:SetTexture(shape.mask)
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", frame, "TOPLEFT", -b, b)
        border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", b, -b)
        border:SetShown(b > 0)
        if sb.borderColor then border:SetVertexColor(unpack(sb.borderColor)) end
        -- the glow's solid middle (3/4 of its file) covers frame and border
        local gx = (frame:GetWidth() + 2 * b) / 6
        local gy = (frame:GetHeight() + 2 * b) / 6
        glow:SetTexture(shape.glow)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -b - gx, b + gy)
        glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", b + gx, -b - gy)
        glow:SetShown(sb.glowColor ~= nil)
        if sb.glowColor then glow:SetVertexColor(unpack(sb.glowColor)) end
    end
    frame:HookScript("OnSizeChanged", Layout)

    function sb:SetShape(key) self.key = key Layout() end
    function sb:SetBorder(size, color) self.size, self.borderColor = size or 0, color Layout() end
    function sb:SetGlow(color) self.glowColor = color Layout() end
    Layout()
    return sb
end

-------------------------------------------------------------------------------
-- New instance
-------------------------------------------------------------------------------
function lib:New(theme)
    local T = Merge(lib.defaultTheme, theme)
    local A = T.accent
    T.navSelected = T.navSelected or { A[1] * 0.3, A[2] * 0.3, A[3] * 0.3, 1 }
    local UI = { theme = T, widgets = {}, pages = {}, inputs = {} }

    local function Register(w)
        table.insert(UI.widgets, w)
        return w
    end

    local function Changed()
        if UI.OnChange then UI.OnChange() end
    end

    ---------------------------------------------------------------------------
    -- Basics
    ---------------------------------------------------------------------------
    function UI.Backdrop(f, bg, border)
        f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        f:SetBackdropColor(unpack(bg or T.field))
        f:SetBackdropBorderColor(unpack(border or T.border))
    end

    -- Font string. fontObject: a font object name (theme label font by default)
    function UI.Text(parent, text, fontObject, color)
        local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or T.labelFont)
        fs:SetJustifyH("LEFT")
        fs:SetText(text or "")
        if color then fs:SetTextColor(unpack(color)) end
        return fs
    end

    -- Tooltip with a title and an optional wrapped description
    function UI.Tip(f, title, text)
        if not title and not text then return end
        f:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title or "", 1, 1, 1)
            if text then GameTooltip:AddLine(text, T.muted[1], T.muted[2], T.muted[3], true) end
            GameTooltip:Show()
        end)
        f:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function Hover(f, on)
        if on then f:SetBackdropBorderColor(A[1], A[2], A[3], 1)
        else f:SetBackdropBorderColor(unpack(f.borderColor or T.border)) end
    end

    -- Base frame of every control
    local function Row(parent, height, opts)
        local r = CreateFrame("Frame", nil, parent)
        r:SetSize(200, height)
        opts = opts or {}
        r.showIf, r.enableIf, r.sub = opts.showIf, opts.enableIf, opts.sub
        if opts.tip then
            r:EnableMouse(true)
            if r.SetMouseClickEnabled then r:SetMouseClickEnabled(false) end
            UI.Tip(r, opts.label, opts.tip)
        end
        return r
    end
    UI.Row = Row

    -- Grey and unclickable, without changing the layout
    function UI.SetEnabled(w, on)
        w:SetAlpha(on and 1 or 0.35)
        if not w.blocker then
            if on then return end
            w.blocker = CreateFrame("Frame", nil, w)
            w.blocker:SetAllPoints()
            w.blocker:EnableMouse(true)
        end
        w.blocker:SetFrameLevel(w:GetFrameLevel() + 30)
        w.blocker:SetShown(not on)
    end

    ---------------------------------------------------------------------------
    -- Buttons
    ---------------------------------------------------------------------------
    -- style: nil, "accent" (filled with the brand color) or "danger"
    function UI.Button(parent, text, w, h, onClick, style)
        local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(w or 100, h or 20)
        if style == "accent" then
            b.borderColor = { A[1], A[2], A[3], 1 }
            UI.Backdrop(b, { A[1] * 0.4, A[2] * 0.4, A[3] * 0.4, 1 }, b.borderColor)
        else
            b.borderColor = T.border
            UI.Backdrop(b, T.button)
        end
        b.text = UI.Text(b, text, T.labelFont, style == "danger" and T.danger or nil)
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        b:SetScript("OnEnter", function(self) Hover(self, true) end)
        b:SetScript("OnLeave", function(self) Hover(self, false) end)
        b:SetScript("OnClick", onClick)
        -- pressed: darker while the mouse button is held down
        local press = b:CreateTexture(nil, "ARTWORK", nil, 7)
        press:SetPoint("TOPLEFT", 1, -1)
        press:SetPoint("BOTTOMRIGHT", -1, 1)
        press:SetColorTexture(0, 0, 0, 0.35)
        press:Hide()
        b:HookScript("OnMouseDown", function() press:Show() end)
        b:HookScript("OnMouseUp", function() press:Hide() end)
        b:HookScript("OnLeave", function() press:Hide() end)
        b:HookScript("OnHide", function() press:Hide() end)
        return b
    end

    -- Turns a button into a two-step one: the first click asks to confirm,
    -- the second one (within 3 seconds) runs the action
    -- The one two-step click of the lib (every "confirm" uses it): the
    -- first click arms the button (show(true)), a second one within
    -- CONFIRM_TIME runs action. A double click does not count. It disarms
    -- by itself after CONFIRM_TIME and when the button hides. Only show()
    -- differs between controls: where "Click again to confirm" appears.
    -- b.armed is true while armed; b.Disarm() cancels.
    local CONFIRM_TIME, DOUBLE_CLICK = 3, 0.4
    local function TwoStep(b, action, show)
        local armedAt, token = 0, 0
        local function Disarm()
            if not b.armed then return end
            b.armed = nil
            show(false)
        end
        b:SetScript("OnClick", function(self, ...)
            if not self.armed then
                self.armed, armedAt = true, GetTime()
                show(true)
                token = token + 1
                local mine = token
                C_Timer.After(CONFIRM_TIME, function() if token == mine then Disarm() end end)
                return
            end
            if GetTime() - armedAt < DOUBLE_CLICK then return end
            Disarm()
            if action then action(self, ...) end
        end)
        b:HookScript("OnHide", Disarm)
        b.Disarm = Disarm
    end

    -- Text button: while armed its text reads "Click again to confirm"
    -- (or armedText). Buttons take it as a parameter: confirm = true.
    function UI.Confirm(b, armedText)
        local saved, r, g, bl
        TwoStep(b, b:GetScript("OnClick"), function(on)
            if on then
                saved = b.text:GetText()
                r, g, bl = b.text:GetTextColor()
                b.text:SetText(armedText or UI.strings.confirm)
                b.text:SetTextColor(1, 0.8, 0.3)
            else
                b.text:SetText(saved)
                b.text:SetTextColor(r, g, bl)
            end
        end)
        return b
    end

    -- Row of buttons sharing the width. list = { { text, onClick, style, tip,
    -- confirm = true }, ... }; confirm: asks first (or confirm = "armed text")
    function UI.Buttons(parent, list, opts)
        local r = Row(parent, 20, opts)
        r.buttons = {}
        for i, def in ipairs(list) do
            local b = UI.Button(r, def[1], 80, 20, def[2], def[3])
            if def[4] then UI.Tip(b, def[1], def[4]) end
            if def.confirm then UI.Confirm(b, type(def.confirm) == "string" and def.confirm or nil) end
            r.buttons[i] = b
        end
        r.OnWidth = function(w)
            local n = #r.buttons
            local bw = (w - (n - 1) * 6) / n
            for i, b in ipairs(r.buttons) do
                b:ClearAllPoints()
                b:SetPoint("LEFT", (i - 1) * (bw + 6), 0)
                b:SetWidth(bw)
            end
        end
        return r
    end

    ---------------------------------------------------------------------------
    -- Icon button: a small square button with a drawn glyph ("plus",
    -- "minus", "close", "more", "up", "down", "left", "right") or any
    -- texture (file path or atlas name) for the rest.
    --   size        default 16 (20 fits next to 20 px controls)
    --   opts.tip    tooltip text
    --   opts.style  "danger": glyph in the danger color
    --   opts.isOn() -> true: lit with the accent, like a selected option
    --                  (a toggle: lock, eye...); refreshed with the others
    --   opts.confirm = true  asks first: red border and "Click again to
    --                  confirm" in a tooltip until the second click
    ---------------------------------------------------------------------------
    local GLYPH_COLOR = { 0.8, 0.8, 0.84 }

    function UI.IconButton(parent, icon, size, onClick, opts)
        opts = opts or {}
        size = size or 16
        local b = UI.Button(parent, "", size, size, onClick)
        local danger = opts.style == "danger"
        local base = danger and T.danger or GLYPH_COLOR
        if GLYPHS[icon] then
            b.glyph = NewGlyph(b, icon, math.floor(size * 0.5 + 0.5))
            b.glyph:SetFrameLevel(b:GetFrameLevel() + 1)
            b.glyph:SetColor(unpack(base, 1, 3))
            -- hover: the glyph brightens with the border
            b:HookScript("OnEnter", function()
                if not danger then b.glyph:SetColor(unpack(T.text, 1, 3)) end
            end)
            b:HookScript("OnLeave", function()
                if not (danger or (opts.isOn and opts.isOn())) then b.glyph:SetColor(unpack(base, 1, 3)) end
            end)
        else
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 2, -2)
            b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(icon) then
                b.icon:SetAtlas(icon)
            else
                b.icon:SetTexture(icon)
            end
        end
        if opts.tip then UI.Tip(b, opts.tip) end
        if opts.isOn then
            b.Refresh = function()
                local on = opts.isOn()
                if on then
                    b.borderColor = { A[1], A[2], A[3], 1 }
                    b:SetBackdropColor(A[1] * 0.3, A[2] * 0.3, A[3] * 0.3, 1)
                else
                    b.borderColor = T.border
                    b:SetBackdropColor(unpack(T.button))
                end
                b:SetBackdropBorderColor(unpack(b.borderColor))
                if b.glyph and not danger then
                    b.glyph:SetColor(unpack((on or b:IsMouseOver()) and T.text or base, 1, 3))
                end
            end
            Register(b)
        end
        if opts.confirm then
            -- no room for text: the border turns red and a tooltip asks
            TwoStep(b, onClick, function(on)
                if on then
                    b.borderColor = { T.danger[1], T.danger[2], T.danger[3], 1 }
                    b:SetBackdropBorderColor(unpack(b.borderColor))
                    if b.glyph then b.glyph:SetColor(unpack(T.danger, 1, 3)) end
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                    GameTooltip:SetText(UI.strings.confirm, T.danger[1], T.danger[2], T.danger[3])
                    GameTooltip:Show()
                else
                    b.borderColor = T.border
                    b:SetBackdropBorderColor(unpack(T.border))
                    if b.glyph then b.glyph:SetColor(unpack(base, 1, 3)) end
                    if GameTooltip:GetOwner() == b then GameTooltip:Hide() end
                    if b.Refresh then b.Refresh() end
                end
            end)
        end
        return b
    end

    ---------------------------------------------------------------------------
    -- Check box (small square with a brand-color tick; the tick fades in/out)
    ---------------------------------------------------------------------------
    local function FadeTo(region, target, duration)
        region.fadeTarget = target
        local holder = region.fadeHolder
        if not holder:IsVisible() then region:SetAlpha(target) return end
        holder:SetScript("OnUpdate", function(self, elapsed)
            local a = region:GetAlpha()
            local step = elapsed / duration
            a = a < target and math.min(target, a + step) or math.max(target, a - step)
            region:SetAlpha(a)
            if a == target then self:SetScript("OnUpdate", nil) end
        end)
    end

    function UI.Check(parent, label, get, set, opts)
        opts = opts or {}
        opts.label = label
        local r = Row(parent, T.rowHeight, opts)
        local c = CreateFrame("Button", nil, r, "BackdropTemplate")
        c:SetSize(14, 14)
        c:SetPoint("LEFT")
        c.borderColor = T.border
        UI.Backdrop(c, T.field)
        c.mark = NewTick(c, A)
        c.mark.fadeHolder = c
        r.label = UI.Text(r, label)
        r.label:SetPoint("LEFT", c, "RIGHT", 6, 0)
        r.label:SetPoint("RIGHT")
        r.label:SetWordWrap(false)
        r.box = c
        r.OnWidth = function(w) c:SetHitRectInsets(0, -(w - 14), -2, -2) end
        r.Refresh = function(_, animate)
            local target = get() and 1 or 0
            if animate then FadeTo(c.mark, target, 0.12)
            elseif c.mark.fadeTarget ~= target or not c:GetScript("OnUpdate") then
                c:SetScript("OnUpdate", nil)
                c.mark.fadeTarget = target
                c.mark:SetAlpha(target)
            end
        end
        c:SetScript("OnClick", function()
            set(not get())
            r.Refresh(r, true)
            Changed()
        end)
        c:SetScript("OnEnter", function(self) Hover(self, true) end)
        c:SetScript("OnLeave", function(self) Hover(self, false) end)
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Switch (on / off) with a sliding knob
    ---------------------------------------------------------------------------
    function UI.Switch(parent, label, get, set, opts)
        opts = opts or {}
        opts.label = label
        local r = Row(parent, T.rowHeight + 2, opts)
        r.label = UI.Text(r, label)
        r.label:SetPoint("LEFT")
        r.label:SetPoint("RIGHT", -40, 0)
        r.label:SetWordWrap(false)

        local W, H, K = 28, 14, 10
        local sw = CreateFrame("Button", nil, r, "BackdropTemplate")
        sw:SetSize(W, H)
        sw:SetPoint("RIGHT")
        sw.borderColor = T.border
        UI.Backdrop(sw)
        sw.knob = sw:CreateTexture(nil, "OVERLAY")
        sw.knob:SetSize(K, K)
        r.switch = sw
        r.OnWidth = function(w) sw:SetHitRectInsets(-(w - W), 0, -3, -3) end

        local travel = W - 4 - K
        local function Mix(a, b, t) return a + (b - a) * t end
        local function Paint(p)
            local t = p * p * (3 - 2 * p)
            sw.knob:ClearAllPoints()
            sw.knob:SetPoint("LEFT", 2 + travel * t, 0)
            sw.knob:SetColorTexture(Mix(T.muted[1], 1, t), Mix(T.muted[2], 1, t), Mix(T.muted[3], 1, t), 1)
            sw:SetBackdropColor(Mix(T.field[1], A[1] * 0.7, t), Mix(T.field[2], A[2] * 0.7, t), Mix(T.field[3], A[3] * 0.7, t), 1)
        end
        local function Animate(self, elapsed)
            local step = elapsed / 0.15
            self.pos = self.pos < self.target and math.min(self.target, self.pos + step) or math.max(self.target, self.pos - step)
            Paint(self.pos)
            if self.pos == self.target then self:SetScript("OnUpdate", nil) end
        end
        r.Refresh = function(_, animate)
            local target = get() and 1 or 0
            if sw.target == target and sw:GetScript("OnUpdate") then return end
            sw.target = target
            if animate and sw.pos and sw:IsVisible() then
                sw:SetScript("OnUpdate", Animate)
            else
                sw:SetScript("OnUpdate", nil)
                sw.pos = target
                Paint(target)
            end
        end
        sw:SetScript("OnClick", function()
            set(not get())
            r.Refresh(r, true)
            Changed()
        end)
        sw:SetScript("OnEnter", function(self) Hover(self, true) end)
        sw:SetScript("OnLeave", function(self) Hover(self, false) end)
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Group of check boxes in columns (several on/off values at once)
    -- options = { { value, label }, ... }; get(value) -> bool; set(value, bool)
    ---------------------------------------------------------------------------
    function UI.CheckGroup(parent, label, options, get, set, opts)
        opts = opts or {}
        opts.label = label
        local columns = opts.columns or 2
        local top = label and 16 or 0
        local rows = math.ceil(#options / columns)
        local r = Row(parent, top + rows * (T.rowHeight + 2), opts)
        if label then
            r.label = UI.Text(r, label)
            r.label:SetPoint("TOPLEFT")
        end
        r.items = {}
        for i, o in ipairs(options) do
            local value = o[1]
            local item = UI.Check(r, o[2], function() return get(value) end, function(v) set(value, v) end)
            r.items[i] = item
        end
        r.OnWidth = function(w)
            local cw = math.floor(w / columns)
            for i, item in ipairs(r.items) do
                local col = (i - 1) % columns
                local row = math.floor((i - 1) / columns)
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", col * cw, -top - row * (T.rowHeight + 2))
                item:SetWidth(cw - 6)
                item.OnWidth(cw - 6)
            end
        end
        return r
    end

    ---------------------------------------------------------------------------
    -- Slider: label and value on top, track below. The < > buttons move it
    -- one step; clicking the value lets you type it.
    -- opts.format(value) -> text shown as the value
    ---------------------------------------------------------------------------
    function UI.Slider(parent, label, minV, maxV, step, get, set, opts)
        opts = opts or {}
        opts.label = label
        local fmt = opts.format
        local r = Row(parent, 34, opts)
        r.label = UI.Text(r, label)
        r.label:SetPoint("TOPLEFT")

        local value = CreateFrame("EditBox", nil, r)
        value:SetSize(70, 14)
        value:SetPoint("TOPRIGHT", 0, 1)
        value:SetFontObject(T.labelFont)
        value:SetJustifyH("RIGHT")
        value:SetAutoFocus(false)

        local s = CreateFrame("Slider", nil, r, "BackdropTemplate")
        s:SetOrientation("HORIZONTAL")
        s:SetPoint("TOPLEFT", 18, -17)
        s:SetPoint("TOPRIGHT", -18, -17)
        s:SetHeight(10)
        UI.Backdrop(s)
        local thumb = s:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(A[1], A[2], A[3], 1)
        thumb:SetSize(8, 12)
        s:SetThumbTexture(thumb)
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)

        local function Round(v)
            v = math.floor(v / step + 0.5) * step
            -- 4 decimals: drops float noise, keeps steps like 0.005
            if step < 1 then v = tonumber(("%.4f"):format(v)) end
            return math.min(maxV, math.max(minV, v))
        end
        local function Show(v) value:SetText(fmt and fmt(v) or tostring(v)) end
        local function Commit(v)
            v = Round(v)
            if v ~= get() then
                set(v)
                Changed()
            end
            s:SetValue(v)
            Show(v)
        end

        s:SetScript("OnValueChanged", function(_, v, user)
            v = Round(v)
            Show(v)
            if user and v ~= get() then set(v) end
        end)
        s:SetScript("OnMouseUp", Changed)
        -- no mouse wheel: it would catch the wheel meant to scroll the page
        -- (use the < > buttons, drag, or type the value)

        value:SetScript("OnEditFocusGained", function(self) self:SetText(tostring(get())) self:HighlightText() end)
        value:SetScript("OnEnterPressed", function(self)
            local n = tonumber(self:GetText())
            self:ClearFocus()
            if n then Commit(n) else Show(get()) end
        end)
        value:SetScript("OnEscapePressed", function(self) self:ClearFocus() Show(get()) end)
        value:SetScript("OnEditFocusLost", function() Show(Round(get() or minV)) end)

        local minus = UI.Button(r, "<", 14, 14, function() Commit((get() or minV) - step) end)
        minus:SetPoint("RIGHT", s, "LEFT", -3, 0)
        local plus = UI.Button(r, ">", 14, 14, function() Commit((get() or minV) + step) end)
        plus:SetPoint("LEFT", s, "RIGHT", 3, 0)

        r.Refresh = function()
            local v = get() or minV
            s:SetValue(v)
            Show(Round(v))
        end
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Segmented control: a few exclusive options side by side
    -- options = { { value, label }, ... }
    ---------------------------------------------------------------------------
    function UI.Segmented(parent, label, options, get, set, opts)
        opts = opts or {}
        opts.label = label
        local top = label and -16 or 0
        local r = Row(parent, (label and 16 or 0) + 20, opts)
        if label then
            r.label = UI.Text(r, label)
            r.label:SetPoint("TOPLEFT")
        end
        r.buttons = {}
        for i, o in ipairs(options) do
            local b = UI.Button(r, o[2], 50, 20, function()
                set(o[1])
                r.Refresh()
                Changed()
            end)
            b.value = o[1]
            r.buttons[i] = b
        end
        r.OnWidth = function(w)
            local n = #r.buttons
            local bw = (w - (n - 1) * 2) / n
            for i, b in ipairs(r.buttons) do
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", (i - 1) * (bw + 2), top)
                b:SetWidth(bw)
            end
        end
        r.Refresh = function()
            local cur = get()
            for _, b in ipairs(r.buttons) do
                if b.value == cur then
                    b.borderColor = { A[1], A[2], A[3], 1 }
                    b:SetBackdropColor(A[1] * 0.3, A[2] * 0.3, A[3] * 0.3, 1)
                    b.text:SetTextColor(1, 1, 1)
                else
                    b.borderColor = T.border
                    b:SetBackdropColor(unpack(T.button))
                    b.text:SetTextColor(unpack(T.muted))
                end
                b:SetBackdropBorderColor(unpack(b.borderColor))
            end
        end
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Tiles: exclusive options shown as pictures (shapes, styles), each with
    -- its name under it, spread across the row.
    -- options = { { value, label, texture }, ... } or a function that returns
    -- it. texture: a file or an atlas; grey, and the brand color when picked.
    -- opts.size: the tile's side (default 40)
    ---------------------------------------------------------------------------
    function UI.Tiles(parent, label, options, get, set, opts)
        opts = opts or {}
        opts.label = label
        local size = opts.size or 40
        local top = label and -16 or 0
        local r = Row(parent, (label and 16 or 0) + size + 18, opts)
        if label then
            r.label = UI.Text(r, label)
            r.label:SetPoint("TOPLEFT")
        end
        r.tiles = {}
        local width = 200

        local function List()
            return type(options) == "function" and options() or options
        end
        local function Paint(t, picked)
            local c = picked and A or T.muted
            t.borderColor = picked and { A[1], A[2], A[3], 1 } or T.border
            t:SetBackdropBorderColor(unpack(t.borderColor))
            t.pic:SetVertexColor(c[1], c[2], c[3], 1)
            t.name:SetTextColor(unpack(picked and T.text or T.muted))
        end
        local function Tile(i)
            local t = r.tiles[i]
            if t then return t end
            t = CreateFrame("Button", nil, r, "BackdropTemplate")
            t:SetSize(size, size)
            UI.Backdrop(t, T.field, T.border)
            t.pic = t:CreateTexture(nil, "ARTWORK")
            t.pic:SetPoint("TOPLEFT", 6, -6)
            t.pic:SetPoint("BOTTOMRIGHT", -6, 6)
            t.name = UI.Text(r, "")
            t.name:SetJustifyH("CENTER")
            t.name:SetWordWrap(false)
            t.name:SetPoint("TOP", t, "BOTTOM", 0, -3)
            t:SetScript("OnClick", function(self)
                set(self.value)
                r.Refresh()
                Changed()
            end)
            t:SetScript("OnEnter", function(self) Hover(self, true) end)
            t:SetScript("OnLeave", function(self) Hover(self, false) end)
            r.tiles[i] = t
            return t
        end
        -- one cell per option, the tile in its middle
        local function Place()
            local n = #List()
            local cell = width / math.max(n, 1)
            for i = 1, n do
                local t = Tile(i)   -- the card can lay out before the first refresh
                t:ClearAllPoints()
                t:SetPoint("TOP", r, "TOPLEFT", cell * (i - 0.5), top)
                t.name:SetWidth(cell - 4)
            end
        end
        r.OnWidth = function(w)
            width = w
            Place()
        end
        r.Refresh = function()
            local list, cur = List(), get()
            for i, o in ipairs(list) do
                local t = Tile(i)
                t.value = o[1]
                t.name:SetText(o[2])
                if o[3] and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(o[3]) then
                    t.pic:SetAtlas(o[3])
                else
                    t.pic:SetTexture(o[3])
                end
                Paint(t, o[1] == cur)
                t:Show()
                t.name:Show()
            end
            for i = #list + 1, #r.tiles do
                r.tiles[i]:Hide()
                r.tiles[i].name:Hide()
            end
            Place()
        end
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Scroll bar: draggable, with a brand-color thumb.
    -- onScroll(position) is called when the user moves it.
    -- bar:SetRange(max, visibleFraction), bar:SetPos(position)
    ---------------------------------------------------------------------------
    -- Built by hand (not a Slider widget): the thumb follows the cursor and
    -- the top of the bar is always the top of the content, in every client.
    function UI.ScrollBar(parent, onScroll)
        local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        bar:SetWidth(8)
        UI.Backdrop(bar, T.fieldDark, { 0.2, 0.2, 0.25, 1 })
        bar:EnableMouse(true)
        local thumb = CreateFrame("Frame", nil, bar)
        thumb:SetSize(6, 16)
        thumb:EnableMouse(true)
        thumb.tex = thumb:CreateTexture(nil, "OVERLAY")
        thumb.tex:SetAllPoints()
        thumb.tex:SetColorTexture(A[1], A[2], A[3], 0.9)
        bar.thumb = thumb
        bar.max, bar.cur = 0, 0

        local function Travel() return math.max(1, bar:GetHeight() - 2 - thumb:GetHeight()) end
        local function PlaceThumb()
            local f = bar.max > 0 and bar.cur / bar.max or 0
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", bar, "TOP", 0, -1 - f * Travel())
        end
        local function CursorY()
            local _, y = GetCursorPosition()
            return y / bar:GetEffectiveScale()
        end
        -- position from the cursor; grab = cursor distance from the thumb top
        local function MoveTo(y, grab)
            local offset = (bar:GetTop() - 1) - y - grab
            local v = math.floor(math.max(0, math.min(1, offset / Travel())) * bar.max + 0.5)
            if v ~= bar.cur then
                bar.cur = v
                PlaceThumb()
                onScroll(v)
            end
        end
        local function StartDrag(grab)
            thumb:SetScript("OnUpdate", function()
                if not IsMouseButtonDown("LeftButton") then
                    thumb:SetScript("OnUpdate", nil)
                    return
                end
                MoveTo(CursorY(), grab)
            end)
        end
        thumb:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            StartDrag(thumb:GetTop() - CursorY())
        end)
        thumb:SetScript("OnMouseUp", function() thumb:SetScript("OnUpdate", nil) end)
        -- click on the track: the thumb jumps there (centered) and can be dragged
        bar:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            local grab = thumb:GetHeight() / 2
            MoveTo(CursorY(), grab)
            StartDrag(grab)
        end)
        bar:SetScript("OnSizeChanged", PlaceThumb)

        function bar:SetRange(max, frac)
            self.max = math.max(0, math.floor((max or 0) + 0.5))
            thumb:SetHeight(math.max(16, (self:GetHeight() - 2) * math.min(1, frac or 1)))
            if self.cur > self.max then self.cur = self.max end
            PlaceThumb()
            self:SetShown(self.max > 0)
        end
        function bar:SetPos(v)
            self.cur = math.max(0, math.min(self.max, math.floor((v or 0) + 0.5)))
            PlaceThumb()
        end
        return bar
    end

    ---------------------------------------------------------------------------
    -- Dropdown: label above, button below; the list scrolls when long.
    -- options = { { value, label, font, texture }, ... } or a function that
    -- returns it. With font, the option is drawn in that font; with texture
    -- (a file path or an atlas name), a sample of it is shown behind the option.
    ---------------------------------------------------------------------------
    local MAX_ITEMS = 14

    function UI.CloseMenu()
        if lib.openMenu then
            lib.openMenu:Hide()
            lib.openMenu = nil
        end
    end

    local function ApplyFont(fs, font)
        if font then
            if not fs:SetFont(font, 12, "") then fs:SetFontObject(T.labelFont) end
        else
            fs:SetFontObject(T.labelFont)
        end
    end

    local function ApplyTexture(frame, tex)
        if not frame.preview then
            if not tex then return end
            frame.preview = frame:CreateTexture(nil, "BORDER")
            frame.preview:SetPoint("TOPLEFT", 1, -1)
            frame.preview:SetPoint("BOTTOMRIGHT", -1, 1)
            frame.preview:SetVertexColor(A[1] * 0.6, A[2] * 0.6, A[3] * 0.6, 1)
        end
        if tex then
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(tex) then
                frame.preview:SetAtlas(tex)
            else
                frame.preview:SetTexture(tex)
            end
        end
        frame.preview:SetShown(tex ~= nil)
    end

    -- The list that drops under a button (dropdowns and menus). Clicking the
    -- same owner again closes it. list = { { value, label, font, texture }, ... }
    -- isCurrent(value) -> true marks the current choice (and the list opens
    -- scrolled to it); onPick(value) runs after the list closes.
    local function OpenList(owner, list, isCurrent, onPick)
        if lib.openMenu then
            local was = lib.openMenu.owner
            UI.CloseMenu()
            if was == owner then return end
        end
        if #list == 0 then return end
        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        UI.Backdrop(menu, { 0.06, 0.06, 0.08, 1 }, { A[1], A[2], A[3], 1 })
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        menu.owner = owner
        local shown = math.min(#list, MAX_ITEMS)
        local width = math.max(owner:GetWidth(), 150)
        menu:SetSize(width, shown * 18 + 4)
        -- under the owner; a small owner (icon button) gets the list aligned
        -- to its right edge, so it opens toward the window
        if owner:GetWidth() < width then
            menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -1)
        else
            menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -1)
        end
        menu:EnableMouse(true)
        local offset, maxOffset = 0, math.max(0, #list - MAX_ITEMS)
        local items, bar = {}, nil
        local function Fill()
            for i = 1, shown do
                local o = list[i + offset]
                local it = items[i]
                it.value = o and o[1]
                ApplyFont(it.t, o and o[3])
                ApplyTexture(it, o and o[4])
                it.t:SetText(o and o[2] or "")
                it.sel:SetShown(o ~= nil and isCurrent ~= nil and isCurrent(o[1]) and true or false)
            end
        end
        local function ScrollTo(v)
            offset = math.max(0, math.min(maxOffset, math.floor(v + 0.5)))
            Fill()
            if bar then bar:SetPos(offset) end
        end
        local itemW = width - 4 - (maxOffset > 0 and 12 or 0)
        for i = 1, shown do
            local it = CreateFrame("Button", nil, menu)
            it:SetSize(itemW, 18)
            it:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18)
            local hl = it:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.1)
            it.sel = it:CreateTexture(nil, "ARTWORK")
            it.sel:SetAllPoints()
            it.sel:SetColorTexture(A[1], A[2], A[3], 0.2)
            it.t = UI.Text(it, "")
            it.t:SetPoint("LEFT", 4, 0)
            it.t:SetPoint("RIGHT", -4, 0)
            it.t:SetWordWrap(false)
            it:SetScript("OnClick", function(self)
                local v = self.value
                UI.CloseMenu()
                onPick(v)
            end)
            items[i] = it
        end
        if maxOffset > 0 then
            bar = UI.ScrollBar(menu, ScrollTo)
            bar:SetPoint("TOPRIGHT", -3, -3)
            bar:SetPoint("BOTTOMRIGHT", -3, 3)
            bar:SetRange(maxOffset, shown / #list)
            menu:EnableMouseWheel(true)
            menu:SetScript("OnMouseWheel", function(_, d) ScrollTo(offset - d) end)
            if isCurrent then
                for k, o in ipairs(list) do
                    if isCurrent(o[1]) then ScrollTo(k - math.ceil(shown / 2)) break end
                end
            end
        end
        Fill()
        lib.openMenu = menu
    end

    ---------------------------------------------------------------------------
    -- Menu: a list of actions that drops under any button (an icon button
    -- in a card header, usually). items = { { value, label }, ... } or a
    -- function that returns it; onPick(value). Same look as a dropdown list;
    -- one open at a time, closes on a click outside or on the button again.
    --   card:AddHeaderButton("plus", function(self)
    --       UI.Menu(self, templates, AddFromTemplate)
    --   end, { tip = "Add" })
    ---------------------------------------------------------------------------
    function UI.Menu(owner, items, onPick)
        if type(items) == "function" then items = items() end
        OpenList(owner, items or {}, nil, function(v)
            onPick(v)
            Changed()
        end)
    end

    function UI.Dropdown(parent, label, options, get, set, opts)
        opts = opts or {}
        opts.label = label
        local yOff = label and -14 or 0
        local r = Row(parent, (label and 14 or 0) + 20, opts)
        if label then
            r.label = UI.Text(r, label)
            r.label:SetPoint("TOPLEFT")
        end
        local b = UI.Button(r, "", 150, 20)
        b:SetPoint("TOPLEFT", 0, yOff)
        b:SetPoint("TOPRIGHT", 0, yOff)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", 6, 0)
        b.text:SetPoint("RIGHT", -16, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        -- the arrow: a thick chevron in the brand color
        b.arrow = CreateFrame("Frame", nil, b)
        b.arrow:SetSize(8, 5)
        b.arrow:SetPoint("RIGHT", -6, 0)
        for i, x in ipairs({ 0, 8 }) do
            local line = b.arrow:CreateLine(nil, "OVERLAY")
            line:SetThickness(2)
            line:SetColorTexture(A[1], A[2], A[3], 1)
            line:SetStartPoint("TOPLEFT", b.arrow, x, 0)
            line:SetEndPoint("BOTTOMLEFT", b.arrow, 4, 0)
            b.arrow[i] = line
        end
        r.button = b

        local function Opts() return type(options) == "function" and options() or options end

        r.Refresh = function()
            local cur = get()
            for _, o in ipairs(Opts()) do
                if o[1] == cur then
                    ApplyFont(b.text, o[3])
                    ApplyTexture(b, o[4])
                    b.text:SetText(o[2])
                    return
                end
            end
            ApplyFont(b.text, nil)
            ApplyTexture(b, nil)
            b.text:SetText(cur ~= nil and tostring(cur):match("([^\\]+)$") or "")
        end

        b:SetScript("OnClick", function()
            OpenList(b, Opts(), function(v) return v == get() end, function(v)
                set(v)
                r.Refresh()
                Changed()
            end)
        end)
        r:SetScript("OnHide", function()
            if lib.openMenu and lib.openMenu.owner == b then UI.CloseMenu() end
        end)
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Color swatch: color box on the left, label on the right.
    -- getColor() returns a { r, g, b, a } table that the picker edits.
    -- opts.alpha: the picker also edits the opacity
    -- opts.default = { r, g, b, a } (or a function that returns it): a red
    -- Reset button on the right, shown only while the color differs from
    -- it. It asks first ("Click again to confirm" in place of the label).
    ---------------------------------------------------------------------------
    local function SameColor(c, d)
        local function Near(x, y) return math.abs((x or 1) - (y or 1)) < 0.002 end
        return Near(c.r, d.r) and Near(c.g, d.g) and Near(c.b, d.b) and Near(c.a, d.a)
    end

    local function OpenColorPicker(c, hasAlpha, onChange)
        local prev = { r = c.r, g = c.g, b = c.b, a = c.a }
        local function Apply()
            c.r, c.g, c.b = ColorPickerFrame:GetColorRGB()
            if hasAlpha then
                c.a = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha())
                    or (OpacitySliderFrame and 1 - OpacitySliderFrame:GetValue()) or 1
            end
            onChange()
        end
        local function Cancel()
            c.r, c.g, c.b, c.a = prev.r, prev.g, prev.b, prev.a
            onChange()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r, g = c.g, b = c.b, opacity = c.a or 1, hasOpacity = hasAlpha,
                swatchFunc = Apply, opacityFunc = Apply, cancelFunc = Cancel,
            })
        else
            ColorPickerFrame.func = Apply
            ColorPickerFrame.opacityFunc = Apply
            ColorPickerFrame.cancelFunc = Cancel
            ColorPickerFrame.hasOpacity = hasAlpha
            ColorPickerFrame.opacity = 1 - (c.a or 1)
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end

    function UI.Swatch(parent, label, getColor, onChange, opts)
        opts = opts or {}
        opts.label = label
        local r = Row(parent, T.rowHeight, opts)
        local s = CreateFrame("Button", nil, r, "BackdropTemplate")
        s:SetSize(28, 14)
        s:SetPoint("LEFT")
        s.borderColor = { 0.6, 0.6, 0.6, 1 }
        UI.Backdrop(s, { 1, 1, 1, 1 }, s.borderColor)
        r.label = UI.Text(r, label)
        r.label:SetPoint("LEFT", s, "RIGHT", 6, 0)
        s:SetScript("OnEnter", function(self) Hover(self, true) end)
        s:SetScript("OnLeave", function(self) Hover(self, false) end)
        -- no color (nothing saved yet): the swatch shows empty, the rest of
        -- the window keeps refreshing
        local function Default()
            local d = opts.default
            if type(d) == "function" then d = d() end
            return d
        end
        -- Reset asks first (the shared two-step click); while armed,
        -- "Click again to confirm" shows in place of the label
        if opts.default then
            r.reset = UI.Button(r, UI.strings.reset, 40, 16, nil, "danger")
            r.reset:SetWidth(math.max(40, math.ceil(r.reset.text:GetStringWidth()) + 14))
            r.reset:SetPoint("RIGHT")
            r.label:SetPoint("RIGHT", r.reset, "LEFT", -6, 0)
            r.label:SetWordWrap(false)
            r.msg = UI.Text(r, UI.strings.confirm, T.labelFont, T.danger)
            r.msg:SetPoint("LEFT", s, "RIGHT", 6, 0)
            r.msg:SetPoint("RIGHT", r.reset, "LEFT", -6, 0)
            r.msg:SetWordWrap(false)
            r.msg:Hide()
            TwoStep(r.reset, function()
                local c, d = getColor(), Default()
                if not (c and d) then return end
                c.r, c.g, c.b, c.a = d.r, d.g, d.b, d.a
                r.Refresh()
                if onChange then onChange() end
                Changed()
            end, function(on)
                r.msg:SetShown(on)
                r.label:SetShown(not on)
                r.reset.borderColor = on and { T.danger[1], T.danger[2], T.danger[3], 1 } or T.border
                r.reset:SetBackdropBorderColor(unpack(r.reset.borderColor))
            end)
        end
        r.Refresh = function()
            local c = getColor()
            if c then s:SetBackdropColor(c.r, c.g, c.b, 1) else s:SetBackdropColor(0, 0, 0, 0) end
            if r.reset then
                local d = Default()
                local differs = c ~= nil and d ~= nil and not SameColor(c, d)
                if not differs then r.reset.Disarm() end
                r.reset:SetShown(differs)
            end
        end
        s:SetScript("OnClick", function()
            local c = getColor()
            if not c then return end
            OpenColorPicker(c, opts.alpha, function()
                r.Refresh()
                if onChange then onChange() end
            end)
        end)
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Text input
    ---------------------------------------------------------------------------
    -- Plain one-line edit box with the theme look. Tab moves to the next
    -- visible input of the instance, Shift+Tab to the previous one.
    function UI.EditBox(parent, w, h)
        local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
        e:SetSize(w or 120, h or 20)
        e.borderColor = T.border
        UI.Backdrop(e, T.fieldDark)
        e:SetFontObject(ChatFontNormal)
        e:SetTextInsets(5, 5, 0, 0)
        e:SetAutoFocus(false)
        e:SetScript("OnEscapePressed", e.ClearFocus)
        e:HookScript("OnEditFocusGained", function(self) Hover(self, true) end)
        e:HookScript("OnEditFocusLost", function(self) Hover(self, false) end)
        e:SetScript("OnTabPressed", function(self)
            local list = UI.inputs
            local dir = IsShiftKeyDown() and -1 or 1
            local at
            for i, other in ipairs(list) do if other == self then at = i break end end
            if not at then return end
            for k = 1, #list do
                local other = list[((at - 1 + k * dir) % #list) + 1]
                if other:IsVisible() then
                    other:SetFocus()
                    return
                end
            end
        end)
        table.insert(UI.inputs, e)
        return e
    end

    -- Labelled input: the value is saved on Enter (or when focus leaves, if
    -- opts.saveOnBlur)
    function UI.Input(parent, label, get, set, opts)
        opts = opts or {}
        opts.label = label
        local top = label and -14 or 0
        local r = Row(parent, (label and 14 or 0) + 20, opts)
        if label then
            r.label = UI.Text(r, label)
            r.label:SetPoint("TOPLEFT")
        end
        local e = UI.EditBox(r, 150)
        e:SetPoint("TOPLEFT", 0, top)
        e:SetPoint("TOPRIGHT", 0, top)
        local function Save()
            set(e:GetText())
            Changed()
        end
        e:SetScript("OnEnterPressed", function(self)
            Save()
            self:ClearFocus()
        end)
        e:HookScript("OnEditFocusLost", function(self)
            if opts.saveOnBlur then Save() else self:SetText(get() or "") end
        end)
        r.Refresh = function() if not e:HasFocus() then e:SetText(get() or "") end end
        r.edit = e
        return Register(r)
    end

    -- Search box: grey hint while empty, a clear button, and onChange(text)
    -- called on every keystroke
    function UI.SearchBox(parent, hint, onChange, opts)
        local r = Row(parent, 20, opts)
        local e = UI.EditBox(r, 150)
        e:SetAllPoints()
        e:SetTextInsets(5, 20, 0, 0)
        local placeholder = UI.Text(e, hint or UI.strings.search, T.labelFont, T.muted)
        placeholder:SetPoint("LEFT", 6, 0)
        local clear = UI.Button(e, "x", 16, 16, function()
            e:SetText("")
            e:ClearFocus()
        end)
        clear:SetPoint("RIGHT", -2, 0)
        clear:Hide()
        e:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            placeholder:SetShown(text == "")
            clear:SetShown(text ~= "")
            if onChange then onChange(text) end
        end)
        e:SetScript("OnEnterPressed", e.ClearFocus)
        r.edit = e
        return r
    end

    -- Multi-line text box with its own scroll (code, long text).
    -- height = visible height; the edit box is row.edit
    function UI.CodeBox(parent, height, opts)
        local r = Row(parent, height, opts)
        local box = CreateFrame("Frame", nil, r, "BackdropTemplate")
        box:SetAllPoints()
        box.borderColor = T.border
        UI.Backdrop(box, T.fieldDark)
        local sf = CreateFrame("ScrollFrame", nil, box)
        sf:SetPoint("TOPLEFT", 6, -6)
        sf:SetPoint("BOTTOMRIGHT", -14, 6)
        local e = CreateFrame("EditBox", nil, sf)
        e:SetMultiLine(true)
        e:SetAutoFocus(false)
        e:SetFontObject(ChatFontNormal)
        e:SetWidth(200)
        sf:SetScrollChild(e)
        local bar = UI.ScrollBar(box, function(v) sf:SetVerticalScroll(v) end)
        bar:SetPoint("TOPRIGHT", -3, -3)
        bar:SetPoint("BOTTOMRIGHT", -3, 3)
        local function Update()
            local max = math.max(0, e:GetHeight() - sf:GetHeight())
            bar:SetRange(max, sf:GetHeight() / math.max(1, e:GetHeight()))
            bar:SetPos(sf:GetVerticalScroll())
        end
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, d)
            local max = math.max(0, e:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 30)))
            Update()
        end)
        e:SetScript("OnCursorChanged", function(_, _, y, _, lineHeight)
            local top, view = sf:GetVerticalScroll(), sf:GetHeight()
            y = -y
            if y < top then sf:SetVerticalScroll(y)
            elseif y + lineHeight > top + view then sf:SetVerticalScroll(y + lineHeight - view) end
            Update()
        end)
        e:SetScript("OnTextChanged", Update)
        e:SetScript("OnEscapePressed", e.ClearFocus)
        e:HookScript("OnEditFocusGained", function() Hover(box, true) end)
        e:HookScript("OnEditFocusLost", function() Hover(box, false) end)
        box:EnableMouse(true)
        box:SetScript("OnMouseDown", function() e:SetFocus() end)
        r.OnWidth = function(w) e:SetWidth(w - 20) end
        r.edit = e
        return r
    end

    ---------------------------------------------------------------------------
    -- Help text: grey, wraps to the row width. row:SetText(text) changes it.
    ---------------------------------------------------------------------------
    function UI.Note(parent, text, opts)
        local r = Row(parent, 14, opts)
        r.text = UI.Text(r, text, T.labelFont, T.muted)
        r.text:SetPoint("TOPLEFT")
        r.text:SetWordWrap(true)
        r.OnWidth = function(w)
            r.text:SetWidth(w)
            r:SetHeight(math.max(12, r.text:GetStringHeight() + 2))
        end
        r.SetText = function(_, t)
            r.text:SetText(t)
            r.OnWidth(r:GetWidth())
        end
        return r
    end

    ---------------------------------------------------------------------------
    -- Dividers inside a card. Separator: a thin line between groups of rows.
    -- Heading: a small grey title with the line after it, a little more
    -- space above. A card hides a divider that would sit alone: a heading
    -- with no visible row under it (before the next divider), a separator
    -- also with none above it.
    -- opts.accent = true: the line takes the brand color (as faint as the
    -- line under a card title)
    ---------------------------------------------------------------------------
    local function DividerLine(r, accent)
        local line = r:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        if accent then line:SetColorTexture(A[1], A[2], A[3], 0.3)
        else line:SetColorTexture(unpack(T.cardBorder)) end
        return line
    end

    function UI.Separator(parent, opts)
        local r = Row(parent, 9, opts)
        r.divider = "line"
        r.line = DividerLine(r, opts and opts.accent)
        r.line:SetPoint("LEFT", 0, 0)
        r.line:SetPoint("RIGHT", 0, 0)
        return r
    end

    function UI.Heading(parent, text, opts)
        local r = Row(parent, 14, opts)
        r.divider = "heading"
        r.spaceAbove = 6
        r.text = UI.Text(r, text, T.labelFont, T.muted)
        r.text:SetPoint("LEFT")
        r.text:SetWordWrap(false)
        r.line = DividerLine(r, opts and opts.accent)
        r.line:SetPoint("LEFT", r.text, "RIGHT", 8, 0)
        r.line:SetPoint("RIGHT")
        return r
    end

    ---------------------------------------------------------------------------
    -- List: one widget for every list. A dark box that always shows `rows`
    -- rows (it does not shrink to its content) and scrolls when longer.
    --
    --   Row:  [box] [lead] Name ................ secondary  TAG  [x]
    --
    -- Every piece but the name is optional:
    --   opts.items()               -> the rows (already flattened, see groups)
    --   opts.label(item, i)        -> name text
    --   opts.off(item)             -> true: name dimmed (hidden / disabled item)
    --   opts.lead                  = "icon" | "swatch" | "dot"
    --   opts.icon(item)            -> texture             (lead = "icon")
    --   opts.color(item)           -> { r, g, b } or nil  (lead = "swatch"/"dot")
    --   opts.secondary(item)       -> grey text on the right (ID, count...)
    --   opts.tag(item)             -> text, { r, g, b }: short label in its own
    --                                 column (as wide as the longest, up to
    --                                 opts.tagWidth, default 90)
    --   opts.columns               = { name, secondary, tag }: column titles
    --                                 in a strip on top (adds height)
    --   opts.selected(item, i)     -> true for the selected row (returning the
    --                                 selected index also works)
    --   opts.onSelect(i, item)
    --   opts.checked(item)         -> true | false | "partial": check box on
    --                                 each row; on a group header "partial"
    --                                 shows a dash (some of the group);
    --                                 nil: no box on that row (the space
    --                                 stays, so the names line up)
    --   opts.onCheck(item, value)  without onSelect, a row click toggles too
    --   opts.onRemove(i, item)     red x on every row. The first click marks
    --                                 the row ("Click again to confirm", it
    --                                 wins the space over name and tag); the
    --                                 second removes it. A double click does
    --                                 not count; after 3 s it goes back.
    --                                 The addon keeps its own selection right.
    --   opts.canRemove(item)       -> false: no x on that row (built-in
    --                                 items, children of a group...)
    --   opts.confirmRemove = false x removes at once
    --   opts.onReorder(from, to)   rows can be dragged; the others slide
    --   opts.spell(item)           -> spell ID: spell tooltip on hover
    --   opts.empty                 text shown when there are no rows (or a
    --                                 function that returns it)
    --   opts.rows                  visible rows (default 8)
    --   opts.rowHeight             default 20
    --   opts.decorate(row, item, i) extra pieces per row (row.name, alias
    --                                 row.text)
    -- Groups: rows { header = true, label, count, closed, off } open and
    -- close with a chevron (opts.onToggle(item) changes `closed`); the
    -- items under an open header follow it in items(). Opening and closing
    -- slides the rows.
    -- opts.richHeaders = true: a header is a full row too (a thing that
    -- opens to show its parts): label(), lead, secondary(), tag, check box,
    -- x and spell tooltip like any row, with the chevron in front. A header
    -- with leaf = true has nothing to open (no chevron).
    -- Texts that do not fit end in "..." and show whole on hover. The name
    -- keeps at least 80 px; the secondary takes at most 40% of the row.
    ---------------------------------------------------------------------------
    function UI.List(parent, opts)
        local h = opts.rowHeight or 20
        local shown = opts.rows or 8
        local hh = opts.columns and 18 or 0   -- column titles strip
        local r = Row(parent, shown * h + 2 + hh, opts)
        local box = CreateFrame("Frame", nil, r, "BackdropTemplate")
        box:SetAllPoints()
        UI.Backdrop(box, T.fieldDark, T.border)
        box:SetFrameLevel(r:GetFrameLevel())
        if r.SetClipsChildren then r:SetClipsChildren(true) end   -- sliding rows stay inside

        local offset, lines = 0, {}
        local grouped = false
        local inset = 1                   -- right margin of the rows (12 with the scroll bar)
        local tagW = 0                    -- fits the longest tag (set on refresh)
        local rowW = 200                  -- width the card gives the list
        local RIGHT0 = opts.onRemove and 25 or 6   -- space kept for the x
        local MIN_NAME = 80
        local HEADER_X, ITEM_X = 22, 32   -- grouped rows sit 10 px in from their header

        local function IsSelected(item, i)
            if not opts.selected then return false end
            local s = opts.selected(item, i)
            if type(s) == "number" then return s == i end
            return s and true or false
        end

        -- width of a text without limits; the measuring string sits in an
        -- invisible frame (its own alpha resets when its font changes)
        local meterHolder = CreateFrame("Frame", nil, r)
        meterHolder:SetSize(1, 1)
        meterHolder:SetPoint("TOPLEFT")
        meterHolder:SetAlpha(0)
        local meter = meterHolder:CreateFontString(nil, "OVERLAY", T.labelFont)
        meter:SetPoint("TOPLEFT")
        local function Measure(text)
            if not text or text == "" then return 0 end
            meter:SetText(text)
            return math.ceil(meter:GetStringWidth())
        end

        -- column titles
        local cols
        if opts.columns then
            cols = CreateFrame("Frame", nil, r)
            cols:SetPoint("TOPLEFT", 1, -1)
            cols:SetPoint("TOPRIGHT", -1, -1)
            cols:SetHeight(hh)
            cols:SetFrameLevel(box:GetFrameLevel() + 2)
            local bg = cols:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.04)
            local line = cols:CreateTexture(nil, "BORDER")
            line:SetPoint("BOTTOMLEFT")
            line:SetPoint("BOTTOMRIGHT")
            line:SetHeight(1)
            line:SetColorTexture(unpack(T.cardBorder))
            local grey = { 0.55, 0.55, 0.6 }
            cols.name = UI.Text(cols, opts.columns.name or "", T.labelFont, grey)
            cols.sec = UI.Text(cols, opts.columns.secondary or "", T.labelFont, grey)
            cols.sec:SetJustifyH("RIGHT")
            cols.tag = UI.Text(cols, opts.columns.tag or "", T.labelFont, grey)
            for _, fs in ipairs({ cols.name, cols.sec, cols.tag }) do fs:SetWordWrap(false) end
        end

        local bar = UI.ScrollBar(r, function(v)
            offset = v
            r.Refresh()
        end)
        bar:SetPoint("TOPRIGHT", -2, -2 - hh)
        bar:SetPoint("BOTTOMRIGHT", -2, 2)
        bar:SetFrameLevel(box:GetFrameLevel() + 6)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d)
            if r.dragging then return end
            offset = offset - d
            r.Refresh()
        end)

        local empty = UI.Text(r, "", T.labelFont, T.muted)
        empty:SetPoint("LEFT", 12, -hh / 2)
        empty:SetPoint("RIGHT", -12, -hh / 2)
        empty:SetJustifyH("CENTER")
        empty:SetWordWrap(true)

        -- row slot i, moved down by `shift` pixels (animations)
        local function PlaceLine(line, i, shift)
            local y = -1 - hh - (i - 1) * h - (shift or 0)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 1, y)
            line:SetPoint("TOPRIGHT", -inset, y)
        end

        -- Opening or closing a group: each row starts where its item was
        -- (prevPos) and eases to its place; new rows come out from under
        -- their header and fade in.
        local prevPos, prevOffset, toggled = {}, 0, nil
        local slider = CreateFrame("Frame", nil, r)
        local function Slide(_, elapsed)
            local k = math.min(1, elapsed * 14)
            local busy = false
            for i, line in ipairs(lines) do
                if line:IsShown() and ((line.shift or 0) ~= 0 or line:GetAlpha() < 1) then
                    line.shift = line.shift - line.shift * k
                    if math.abs(line.shift) < 0.5 then line.shift = 0 end
                    line:SetAlpha(math.min(1, line:GetAlpha() + elapsed / 0.2))
                    PlaceLine(line, i, line.shift)
                    busy = true
                end
            end
            if not busy then slider:SetScript("OnUpdate", nil) end
        end

        -- remove: the row waiting for the second click. Same rules as the
        -- shared two-step click (TwoStep), but the armed state belongs to the
        -- item, not to a button: rows are reused while the list scrolls.
        local armed, armToken, armedAt = nil, 0, 0
        r:HookScript("OnHide", function() armed = nil end)

        -- Drag to reorder. The mouse is followed by hand from the press until
        -- the button is released (OnDragStart/Stop start late, so the row
        -- jumped, and a missed stop left it stuck).
        local dragFrom, dragLine, grab, press
        local function CursorY()
            local _, cy = GetCursorPosition()
            return cy / r:GetEffectiveScale()
        end
        local function DragTop()
            local n = math.min(shown, #opts.items() - offset)
            local y = (r:GetTop() - 1 - hh) - CursorY() - grab
            return math.max(0, math.min((n - 1) * h, y))
        end
        local function DropIndex()
            local i = math.floor((DragTop() + h / 2) / h) + 1 + offset
            return math.max(1, math.min(#opts.items(), i))
        end
        local function DragUpdate(elapsed)
            PlaceLine(dragLine, 1, DragTop())
            local to = DropIndex()
            local k = math.min(1, elapsed * 14)
            for i, line in ipairs(lines) do
                if line ~= dragLine and line:IsShown() then
                    local idx = i + offset
                    local target = 0
                    if dragFrom < to and idx > dragFrom and idx <= to then target = -h
                    elseif dragFrom > to and idx >= to and idx < dragFrom then target = h end
                    line.shift = (line.shift or 0) + (target - (line.shift or 0)) * k
                    if math.abs(line.shift - target) < 0.5 then line.shift = target end
                    PlaceLine(line, i, line.shift)
                end
            end
        end
        local function StartDrag(line)
            grab = line:GetTop() - press.y   -- keeps the grab point: no jump
            dragFrom, dragLine = line.index, line
            r.dragging = true
            line:SetFrameLevel(box:GetFrameLevel() + 4)
            line.bg:SetColorTexture(A[1], A[2], A[3], 0.35)
        end
        local function FinishDrag()
            r:SetScript("OnUpdate", nil)
            press = nil
            if not r.dragging then return end
            local to, from, line = DropIndex(), dragFrom, dragLine
            dragFrom, dragLine, r.dragging = nil, nil, nil
            line:SetFrameLevel(box:GetFrameLevel() + 2)
            line.justDropped = true   -- the click that follows the release is ignored
            for _, l in ipairs(lines) do l.shift = 0 end
            if to ~= from then opts.onReorder(from, to) end
            Changed()
            r.Refresh()
        end
        local function Watch(_, elapsed)
            if not IsMouseButtonDown("LeftButton") then FinishDrag() return end
            if not r.dragging then
                if math.abs(CursorY() - press.y) < 4 then return end
                StartDrag(press.line)
            end
            DragUpdate(elapsed)
        end

        local function Toggle(item, value)
            opts.onCheck(item, value)
            Changed()
        end

        local function NewLine(i)
            local line = CreateFrame("Button", nil, r)
            line:SetHeight(h)
            PlaceLine(line, i)
            line:SetFrameLevel(box:GetFrameLevel() + 2)
            line.bg = line:CreateTexture(nil, "BACKGROUND")
            line.bg:SetAllPoints()
            local hl = line:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.07)
            line.bar = line:CreateTexture(nil, "ARTWORK")
            line.bar:SetPoint("TOPLEFT")
            line.bar:SetPoint("BOTTOMLEFT")
            line.bar:SetWidth(2)
            line.bar:SetColorTexture(A[1], A[2], A[3], 1)
            -- faint line above a group header (not above the first row)
            line.sep = line:CreateTexture(nil, "BORDER")
            line.sep:SetPoint("TOPLEFT", 6, 0)
            line.sep:SetPoint("TOPRIGHT", -6, 0)
            line.sep:SetHeight(1)
            line.sep:SetColorTexture(1, 1, 1, 0.06)
            line.exp = NewChevron(line, { 0.55, 0.55, 0.6 })
            line.exp:SetPoint("LEFT", 6, 0)
            if opts.checked then
                local c = CreateFrame("Button", nil, line, "BackdropTemplate")
                c:SetSize(14, 14)
                c.borderColor = T.border
                UI.Backdrop(c, T.field)
                c.mark = NewTick(c, A)
                c:SetScript("OnEnter", function(self) Hover(self, true) end)
                c:SetScript("OnLeave", function(self) Hover(self, false) end)
                c:SetScript("OnClick", function(self)
                    local l = self:GetParent()
                    if l.item then Toggle(l.item, opts.checked(l.item) ~= true) end
                end)
                line.check = c
            end
            line.lead = line:CreateTexture(nil, "ARTWORK")
            line.name = UI.Text(line, "")
            line.name:SetWordWrap(false)
            line.text = line.name   -- name used by decorate before 9
            line.sec = UI.Text(line, "", T.labelFont, T.muted)
            line.sec:SetJustifyH("RIGHT")
            line.sec:SetWordWrap(false)
            line.tag = UI.Text(line, "")
            line.tag:SetWordWrap(false)

            if opts.onRemove then
                line.remove = UI.Button(line, "x", 16, 16, function(self)
                    local l = self:GetParent()
                    if not l.item then return end
                    -- a double click is not a confirmation
                    if armed == l.item and GetTime() - armedAt < DOUBLE_CLICK then return end
                    if opts.confirmRemove ~= false and armed ~= l.item then
                        armed, armedAt = l.item, GetTime()
                        armToken = armToken + 1
                        local mine = armToken
                        C_Timer.After(CONFIRM_TIME, function()
                            if armToken == mine and armed then
                                armed = nil
                                r.Refresh()
                            end
                        end)
                        r.Refresh()
                        return
                    end
                    armed = nil
                    opts.onRemove(l.index, l.item)
                    Changed()
                end)
                line.remove.text:SetTextColor(unpack(T.danger))
                line.remove:SetPoint("RIGHT", -3, 0)
            end

            line:SetScript("OnClick", function(self)
                local item = self.item
                if self.justDropped then
                    self.justDropped = nil
                    return
                end
                if not item then return end
                if type(item) == "table" and item.header then
                    if item.leaf then return end
                    toggled = item   -- the next refresh slides the rows
                    if opts.onToggle then opts.onToggle(item) end
                    Changed()
                elseif opts.onSelect then
                    opts.onSelect(self.index, item)
                    Changed()
                elseif opts.checked then
                    local state = opts.checked(item)
                    if state ~= nil then Toggle(item, state ~= true) end
                end
            end)
            -- tooltip: the spell, and the full texts when they were cut
            line:SetScript("OnEnter", function(self)
                if not self.item then return end
                local id = (not (type(self.item) == "table" and self.item.header) or opts.richHeaders) and opts.spell and opts.spell(self.item)
                if not id and not self.cut then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if id then
                    GameTooltip:SetSpellByID(id)
                else
                    GameTooltip:SetText(self.fullName or "", 1, 1, 1)
                end
                if self.cut and self.fullSec and self.fullSec ~= "" then
                    GameTooltip:AddLine(self.fullSec, T.muted[1], T.muted[2], T.muted[3], true)
                end
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() GameTooltip:Hide() end)
            if opts.onReorder then
                line:SetScript("OnMouseDown", function(self, button)
                    self.justDropped = nil
                    if button ~= "LeftButton" or not self.item or (type(self.item) == "table" and self.item.header) then return end
                    press = { line = self, y = CursorY() }
                    r:SetScript("OnUpdate", Watch)
                end)
                line:SetScript("OnMouseUp", function()
                    if press or r.dragging then FinishDrag() end
                end)
            end
            lines[i] = line
            return line
        end

        -- check box at x; returns where the next piece starts (a row without
        -- a box keeps its space, so the names line up)
        local function PaintCheck(line, item, x)
            local c = line.check
            if not c then return x end
            local state = opts.checked(item)
            c:SetShown(state ~= nil)
            c:ClearAllPoints()
            c:SetPoint("LEFT", x, 0)
            c.mark:SetPartial(state == "partial")
            c.mark:SetShown(state and true or false)
            return x + 14 + 6
        end

        -- Shares the row from the right: [x], tag column, secondary (up to
        -- 40%, never leaving the name under MIN_NAME), then the name.
        -- doomed (waiting for the second click on x): the message wins, the
        -- tag hides and the name gives up the space the message needs.
        local function Fit(line, nameX, secText, tagText, doomed)
            local W = rowW - 1 - inset
            local right = RIGHT0
            line.tag:ClearAllPoints()
            line.tag:SetPoint("RIGHT", -right, 0)
            line.tag:SetWidth(math.max(1, tagW))
            line.tag:SetText(doomed and "" or (tagText or ""))
            if tagW > 0 and not doomed then right = right + tagW + 8 end

            local sw = Measure(secText)
            local avail = W - right - nameX - 8
            local secW
            if doomed then
                secW = math.min(sw, math.max(0, avail))
            else
                secW = math.min(sw, math.max(0, math.min(math.floor(W * 0.4), avail - MIN_NAME)))
            end
            line.sec:ClearAllPoints()
            line.sec:SetPoint("RIGHT", -right, 0)
            line.sec:SetWidth(math.max(1, secW))
            line.sec:SetText(secText or "")
            line.sec:SetShown(secW > 0)
            if secW > 0 then right = right + secW + 8 end

            local nw = W - right - nameX
            line.name:ClearAllPoints()
            line.name:SetPoint("LEFT", nameX, 0)
            line.name:SetWidth(math.max(1, nw))
            line.name:SetShown(nw >= 12)
            line.fullName, line.fullSec = line.name:GetText(), secText
            line.cut = Measure(line.fullName) > nw or sw > secW
        end

        -- Group headers are structure, not state: same small font as the
        -- rows and neutral colors (the accent is for selection and checks);
        -- the chevron, the separator and the indent carry the hierarchy.
        local function PaintHeader(line, item)
            line.bg:SetColorTexture(1, 1, 1, 0)
            line.sep:SetShown(line.index > 1)
            line.bar:Hide()
            line.lead:Hide()
            -- animated only when this same group was toggled (not when the
            -- row slot now shows another group)
            local same = line.expItem == item
            line.expItem = item
            line.exp:SetOpen(not item.closed, same)
            line.exp:Show()
            line.name:SetText(item.label or "")
            if item.off then line.name:SetTextColor(0.45, 0.45, 0.45)
            else line.name:SetTextColor(0.85, 0.85, 0.88) end
            line.sec:SetTextColor(0.5, 0.5, 0.55)
            Fit(line, PaintCheck(line, item, HEADER_X), item.count, nil, false)
            if line.remove then line.remove:Hide() end
        end

        -- a row; with opts.richHeaders also a group header (chevron in front)
        local function PaintItem(line, item, i)
            local head = type(item) == "table" and item.header
            local on = IsSelected(item, i)
            local doomed = armed == item
            if doomed then
                line.bg:SetColorTexture(T.danger[1], T.danger[2], T.danger[3], 0.15)
            else
                line.bg:SetColorTexture(A[1], A[2], A[3], on and 0.22 or 0)
            end
            line.bar:SetShown(on)
            if head then
                local same = line.expItem == item
                line.expItem = item
                line.exp:SetOpen(not item.closed, same)
                line.exp:SetShown(not item.leaf)
                line.sep:SetShown(line.index > 1)
            else
                line.exp:Hide()
                line.sep:Hide()
            end
            local x = PaintCheck(line, item, head and HEADER_X or (grouped and ITEM_X or 8))
            local lead = line.lead
            lead:ClearAllPoints()
            lead:SetTexCoord(0, 1, 0, 1)
            if opts.lead == "icon" then
                lead:SetSize(16, 16)
                lead:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                lead:SetTexture(opts.icon(item) or 134400)
                lead:SetPoint("LEFT", x, 0)
                lead:Show()
                x = x + 16 + 6
            elseif opts.lead == "swatch" or opts.lead == "dot" then
                local s = opts.lead == "swatch" and 8 or 6
                local c = opts.color(item)
                lead:SetSize(s, s)
                lead:SetPoint("LEFT", x + (8 - s) / 2, 0)
                if c then lead:SetColorTexture(c[1], c[2], c[3], 1) end
                lead:SetShown(c ~= nil)
                x = x + 8 + 6
            else
                lead:Hide()
            end
            line.name:SetText(opts.label(item, i) or "")
            if opts.off and opts.off(item) then line.name:SetTextColor(0.45, 0.45, 0.45)
            else line.name:SetTextColor(unpack(T.text)) end
            local secText
            if doomed then
                secText = UI.strings.confirm
                line.sec:SetTextColor(unpack(T.danger))
            else
                secText = opts.secondary and opts.secondary(item) or ""
                line.sec:SetTextColor(unpack(T.muted))
            end
            local tagText, tagColor
            if opts.tag then tagText, tagColor = opts.tag(item) end
            line.tag:SetTextColor(unpack(tagColor or T.muted))
            Fit(line, x, secText, tagText, doomed)
            if line.remove then
                local b = line.remove
                b.borderColor = doomed and { T.danger[1], T.danger[2], T.danger[3], 1 } or T.border
                b:SetBackdropBorderColor(unpack(b.borderColor))
                b:SetShown(not opts.canRemove or opts.canRemove(item) and true or false)
            end
            if opts.decorate then opts.decorate(line, item, i) end
        end

        r.OnWidth = function(w)
            empty:SetWidth(w - 24)
            if w ~= rowW then
                rowW = w
                r.Refresh()
            end
        end

        r.Refresh = function()
            if r.dragging then return end
            local list = opts.items() or {}
            local n = #list
            local maxOff = math.max(0, n - shown)
            offset = math.max(0, math.min(offset, maxOff))
            bar:SetRange(maxOff, n > 0 and shown / n or 1)
            bar:SetPos(offset)
            grouped = false
            for _, item in ipairs(list) do
                if type(item) == "table" and item.header then grouped = true break end
            end
            inset = maxOff > 0 and 12 or 1
            if opts.tag then
                local w = Measure(opts.columns and opts.columns.tag)
                for _, item in ipairs(list) do
                    if not (type(item) == "table" and item.header) then w = math.max(w, Measure((opts.tag(item)))) end
                end
                tagW = math.min(w, opts.tagWidth or 90)
            end
            if cols then
                -- titles over their columns (the rows narrow with the scroll bar)
                local nameX = grouped and ITEM_X or 8
                if opts.checked then nameX = nameX + 20 end
                if opts.lead == "icon" then nameX = nameX + 22
                elseif opts.lead then nameX = nameX + 14 end
                local right = RIGHT0 + inset - 1
                cols.tag:ClearAllPoints()
                cols.tag:SetPoint("RIGHT", -right, 0)
                cols.tag:SetWidth(math.max(1, tagW))
                if tagW > 0 then right = right + tagW + 8 end
                local secW = math.min(Measure(cols.sec:GetText()), math.floor((rowW - 2) * 0.4))
                cols.sec:ClearAllPoints()
                cols.sec:SetPoint("RIGHT", -right, 0)
                cols.sec:SetWidth(math.max(1, secW))
                cols.sec:SetShown(secW > 0)
                if secW > 0 then right = right + secW + 8 end
                cols.name:ClearAllPoints()
                cols.name:SetPoint("LEFT", nameX, 0)
                cols.name:SetPoint("RIGHT", -right, 0)
            end
            -- after a group was opened or closed: where each row starts sliding
            local slide = toggled
            toggled = nil
            local headerSlot = slide and ((prevPos[slide] or 1) - prevOffset)
            local moving = false
            for i = 1, shown do
                local line = lines[i] or NewLine(i)
                local idx = i + offset
                local item = list[idx]
                line.item, line.index = item, idx
                if item then
                    line.shift = 0
                    line:SetAlpha(1)
                    if slide then
                        local old = prevPos[item]
                        if old then
                            line.shift = (old - prevOffset - i) * h
                        else
                            line.shift = (headerSlot - i) * h
                            line:SetAlpha(0)
                        end
                        line.shift = math.max(-shown * h, math.min(shown * h, line.shift))
                        if line.shift ~= 0 or line:GetAlpha() < 1 then moving = true end
                    end
                    PlaceLine(line, i, line.shift)
                    if type(item) == "table" and item.header and not opts.richHeaders then PaintHeader(line, item)
                    else PaintItem(line, item, idx) end
                    line:Show()
                else
                    line:Hide()
                end
            end
            if n == 0 then
                local e = opts.empty
                if type(e) == "function" then e = e() end
                empty:SetText(e or "")
            end
            empty:SetShown(n == 0)
            slider:SetScript("OnUpdate", moving and Slide or nil)
            prevPos, prevOffset = {}, offset
            for i, item in ipairs(list) do prevPos[item] = i end
        end
        return Register(r)
    end

    ---------------------------------------------------------------------------
    -- Card: box with a brand-color title and a line under it; its rows are
    -- stacked top to bottom. card:Add(row), card:Layout(width)
    --   opts.fold = true  the title bar folds the card down to its title:
    --                     the height slides, a chevron on the right turns,
    --                     and a folded card shows a grey summary after its
    --                     title (opts.summary() or the subtitle)
    --   opts.store, opts.key  where the folded state is kept (store[key] =
    --                     true while folded; pass a saved table to keep it
    --                     after /reload; key defaults to the title)
    --   opts.folded = true    starts folded (until store says otherwise)
    ---------------------------------------------------------------------------
    local FOLD_TIME = 0.15

    function UI.Card(parent, title, subtitle, opts)
        opts = opts or {}
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        UI.Backdrop(card, T.card, T.cardBorder)
        card.rows = {}
        local P = T.pad
        card.title = UI.Text(card, title, T.titleFont, A)
        card.title:SetPoint("TOPLEFT", P, -P)
        card.line = card:CreateTexture(nil, "ARTWORK")
        card.line:SetHeight(1)
        card.line:SetColorTexture(A[1], A[2], A[3], 0.3)
        if subtitle then
            card.subtitle = UI.Text(card, subtitle, T.labelFont, T.muted)
            card.subtitle:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
            card.subtitle:SetWordWrap(true)
        end

        function card:Add(w)
            w:SetParent(self)
            table.insert(self.rows, w)
            return w
        end

        -- Icon buttons on the right of the title, right to left (on a
        -- folding card, before the chevron; they stay while folded).
        -- Same arguments as UI.IconButton, size 16.
        function card:AddHeaderButton(icon, onClick, bopts)
            local b = UI.IconButton(self, icon, 16, onClick, bopts)
            b:SetFrameLevel(self:GetFrameLevel() + 6)
            if self.lastHeaderButton then
                b:SetPoint("RIGHT", self.lastHeaderButton, "LEFT", -4, 0)
            elseif self.chev then
                b:SetPoint("RIGHT", self.chev, "LEFT", -8, 0)
            else
                b:SetPoint("RIGHT", self, "TOPRIGHT", -P, -P - 7)
            end
            self.lastHeaderButton = b
            if self.summary then
                self.summary:SetPoint("RIGHT", b, "LEFT", -10, 0)
            end
            return b
        end

        -- rows and line under the title; returns the full height
        local function LayoutContent(self, width)
            self:SetWidth(width)
            local inner = width - 2 * P
            local top = P + 16
            if self.subtitle then
                self.subtitle:SetWidth(inner)
                top = top + self.subtitle:GetStringHeight() + 4
            end
            self.line:ClearAllPoints()
            self.line:SetPoint("TOPLEFT", P, -(top + 2))
            self.line:SetPoint("TOPRIGHT", -P, -(top + 2))
            local y = -(top + 10)
            local first = true
            local rows, vis = self.rows, {}
            for i, w in ipairs(rows) do vis[i] = (not w.showIf or w.showIf()) and true or false end
            -- no divider alone: a heading needs a visible row under it, a
            -- separator also one above it
            local above = false
            for i, w in ipairs(rows) do
                if w.divider then
                    if vis[i] then
                        local below = false
                        for k = i + 1, #rows do
                            if rows[k].divider then break end
                            if vis[k] then below = true break end
                        end
                        vis[i] = below and (w.divider == "heading" or above)
                    end
                elseif vis[i] then
                    above = true
                end
            end
            for i, w in ipairs(rows) do
                local visible = vis[i]
                w:SetShown(visible)
                if visible then
                    if w.enableIf then UI.SetEnabled(w, w.enableIf() and true or false) end
                    w:SetWidth(inner)
                    if w.OnWidth then w.OnWidth(inner) end
                    -- a sub-option sits close under the row it depends on
                    -- (not under the title, when that row is hidden)
                    if w.sub and not first then y = y + T.gap - T.subGap end
                    if w.spaceAbove and not first then y = y - w.spaceAbove end
                    first = false
                    w:ClearAllPoints()
                    w:SetPoint("TOPLEFT", P, y)
                    y = y - w:GetHeight() - T.gap
                end
            end
            return -y - T.gap + P
        end

        if not opts.fold then
            function card:Layout(width)
                self:SetHeight(LayoutContent(self, width))
            end
            return card
        end

        -- folding card
        local store = opts.store or {}
        local key = opts.key or title
        local function Folded()
            local v = store[key]
            if v == nil then return opts.folded and true or false end
            return v
        end
        local FOLDED_H = P * 2 + 14
        if card.SetClipsChildren then card:SetClipsChildren(true) end   -- content slides under the edge
        local chev = NewChevron(card, A)
        chev:SetPoint("RIGHT", card, "TOPRIGHT", -P - 2, -P - 7)
        card.chev = chev
        card.summary = UI.Text(card, "", T.labelFont, T.muted)
        card.summary:SetPoint("LEFT", card.title, "RIGHT", 10, 0)
        card.summary:SetPoint("RIGHT", chev, "LEFT", -10, 0)
        card.summary:SetWordWrap(false)

        -- the title bar is the button; on hover the title and chevron brighten
        local bar = CreateFrame("Button", nil, card)
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("TOPRIGHT", -1, -1)
        bar:SetHeight(P + 18)
        bar:SetFrameLevel(card:GetFrameLevel() + 5)
        local function Paint(k)
            local r, g, b = A[1] + (1 - A[1]) * k, A[2] + (1 - A[2]) * k, A[3] + (1 - A[3]) * k
            card.title:SetTextColor(r, g, b)
            chev:SetColor(r, g, b)
        end
        bar:SetScript("OnEnter", function() Paint(0.45) end)
        bar:SetScript("OnLeave", function() Paint(0) end)

        local function Relayout()
            if card.page then card.page:Layout() else UI.RefreshAll() end
        end
        bar:SetScript("OnClick", function()
            card.animFrom, card.animT = card:GetHeight(), 0
            store[key] = not Folded()
            card:SetScript("OnUpdate", function(self, elapsed)
                self.animT = self.animT + elapsed
                if self.animT >= FOLD_TIME then
                    self.animFrom = nil
                    self:SetScript("OnUpdate", nil)
                end
                Relayout()
            end)
            Relayout()
        end)

        function card:Layout(width)
            local folded = Folded()
            local moving = self.animFrom ~= nil
            chev:SetOpen(not folded, true)
            self.summary:SetText(folded and ((opts.summary and opts.summary()) or subtitle or "") or "")
            -- while sliding the content stays (clipped); hidden once folded
            local content = not folded or moving
            if self.subtitle then self.subtitle:SetShown(content) end
            self.line:SetShown(content)
            local target
            if content then
                local full = LayoutContent(self, width)
                target = folded and FOLDED_H or full
            else
                self:SetWidth(width)
                for _, w in ipairs(self.rows) do w:Hide() end
                target = FOLDED_H
            end
            if moving then
                local t = math.min(1, self.animT / FOLD_TIME)
                t = 1 - (1 - t) * (1 - t)   -- ease out
                self:SetHeight(self.animFrom + (target - self.animFrom) * t)
            else
                self:SetHeight(target)
            end
        end
        return card
    end

    ---------------------------------------------------------------------------
    -- Page: vertical scroll area with columns of cards.
    -- page:Add(column, card), page:Layout(). A card with card.showIf hides.
    -- The cards take the whole width; only while the page scrolls they make
    -- room on the right for the scroll bar.
    -- page:AddSection(label) starts a section: a title (or, with no label,
    -- just a line) across every column; the cards added after it go below,
    -- the columns starting level again. A section with no visible card
    -- hides its title. page:AddSection(label, { accent = true }): the line
    -- takes the brand color.
    ---------------------------------------------------------------------------
    local function BarRoom() return 1 + 8 + T.pad end   -- edge, scroll bar, space to the cards
    local SECTION_SPACE = 8   -- extra space above a section title (not at the top)

    function UI.Page(parent, columns)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        local sf = CreateFrame("ScrollFrame", nil, page)
        sf:SetPoint("TOPLEFT")
        sf:SetPoint("BOTTOMRIGHT")
        local content = CreateFrame("Frame", nil, sf)
        content:SetSize(10, 10)
        sf:SetScrollChild(content)
        page.content = content
        local nCols = columns or 2
        local function NewBand(head)
            local band = { head = head, cols = {}, cards = {} }   -- cards: in the order added
            for i = 1, nCols do band.cols[i] = {} end
            return band
        end
        page.bands = { NewBand(nil) }
        page.cols = page.bands[1].cols   -- columns of the current section

        local bar = UI.ScrollBar(page, function(v) sf:SetVerticalScroll(v) end)
        bar:SetPoint("TOPRIGHT", -1, 0)
        bar:SetPoint("BOTTOMRIGHT", -1, 0)
        local function UpdateBar()
            local h, view = content:GetHeight(), sf:GetHeight()
            local max = math.max(0, h - view)
            if sf:GetVerticalScroll() > max then sf:SetVerticalScroll(max) end
            bar:SetRange(max, h > 0 and view / h or 1)
            bar:SetPos(sf:GetVerticalScroll())
        end
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, d)
            local max = math.max(0, content:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
            bar:SetPos(self:GetVerticalScroll())
        end)

        -- span: how many columns the card takes, from col to the right
        -- (default 1)
        function page:Add(col, card, span)
            card:SetParent(self.content)
            card.page = self   -- a folding card lays out its page while it slides
            card.col = col
            card.span = math.max(1, math.min(span or 1, nCols - col + 1))
            table.insert(self.cols[col], card)
            table.insert(self.bands[#self.bands].cards, card)
            return card
        end

        function page:AddSection(label, sopts)
            local head = CreateFrame("Frame", nil, content)
            head:SetHeight(label and 16 or 1)
            head.line = head:CreateTexture(nil, "ARTWORK")
            head.line:SetHeight(1)
            if sopts and sopts.accent then head.line:SetColorTexture(A[1], A[2], A[3], 0.3)
            else head.line:SetColorTexture(1, 1, 1, 0.12) end
            head.line:SetPoint("RIGHT")
            if label then
                head.text = UI.Text(head, label, T.titleFont, { 0.85, 0.85, 0.88 })
                head.text:SetPoint("LEFT")
                head.text:SetWordWrap(false)
                head.line:SetPoint("LEFT", head.text, "RIGHT", 10, 0)
            else
                head.line:SetPoint("LEFT")
            end
            local band = NewBand(head)
            table.insert(self.bands, band)
            self.cols = band.cols
            return head
        end

        -- lays the cards out in a width; returns the height they take
        local function Place(self, w)
            content:SetWidth(w)
            local gap = T.cardGap
            local cw = math.floor((w - (nCols - 1) * gap) / nCols)
            local y = 0
            for _, band in ipairs(self.bands) do
                local vis, any = {}, false
                for _, card in ipairs(band.cards) do
                    vis[card] = (not card.showIf or card.showIf()) and true or false
                    if vis[card] then any = true end
                end
                if band.head then
                    band.head:SetShown(any)
                    if any then
                        if y < 0 then y = y - SECTION_SPACE end
                        band.head:ClearAllPoints()
                        band.head:SetPoint("TOPLEFT", 0, y)
                        band.head:SetWidth(w)
                        y = y - band.head:GetHeight() - T.gap
                    end
                end
                -- in the order added: each card goes under the lowest of the
                -- columns it takes; a wide card levels them below it
                local cy = {}
                for i = 1, nCols do cy[i] = y end
                for _, card in ipairs(band.cards) do
                    card:SetShown(vis[card])
                    if vis[card] then
                        local first, last = card.col, card.col + card.span - 1
                        local top = cy[first]
                        for i = first + 1, last do top = math.min(top, cy[i]) end
                        card:Layout(cw * card.span + gap * (card.span - 1))
                        card:ClearAllPoints()
                        card:SetPoint("TOPLEFT", (first - 1) * (cw + gap), top)
                        local below = top - card:GetHeight() - gap
                        for i = first, last do cy[i] = below end
                    end
                end
                local low = y
                for i = 1, nCols do low = math.min(low, cy[i]) end
                y = low
            end
            -- the last card has no gap under it
            return math.max(0, -y - gap)
        end

        local busy
        function page:Layout()
            local w, view = page:GetWidth(), page:GetHeight()
            if w <= 0 or busy then return end
            busy = true
            -- full width first; if it does not fit, again with room for the bar
            local h = Place(self, w)
            local scrolls = h > view
            if scrolls then h = Place(self, w - BarRoom()) end
            sf:SetPoint("BOTTOMRIGHT", scrolls and -BarRoom() or 0, 0)
            -- scrolled to the end, a little space under the last card
            content:SetHeight(scrolls and h + T.pad + 4 or h)
            busy = false
            UpdateBar()
        end
        page:SetScript("OnSizeChanged", function() page:Layout() end)
        table.insert(UI.pages, page)
        return page
    end

    ---------------------------------------------------------------------------
    -- Split: two one-column pages side by side, a fixed-width one on the left
    -- (usually a list to pick from) and the rest on the right, with the same
    -- gap as between cards. Returns leftPage, rightPage.
    ---------------------------------------------------------------------------
    function UI.Split(parent, leftWidth)
        local left = CreateFrame("Frame", nil, parent)
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(leftWidth)
        local right = CreateFrame("Frame", nil, parent)
        right:SetPoint("TOPLEFT", left, "TOPRIGHT", T.cardGap, 0)
        right:SetPoint("BOTTOMRIGHT")
        return UI.Page(left, 1), UI.Page(right, 1)
    end

    ---------------------------------------------------------------------------
    -- Tabs: a row of text tabs with a brand-color underline.
    -- list = { { key, label }, ... }; onSelect(key). tabs:Select(key)
    ---------------------------------------------------------------------------
    function UI.Tabs(parent, list, onSelect)
        local bar = CreateFrame("Frame", nil, parent)
        bar:SetHeight(26)
        bar.buttons = {}
        local x = 0
        for _, t in ipairs(list) do
            local key = t[1]
            local b = CreateFrame("Button", nil, bar)
            b.text = UI.Text(b, t[2], T.titleFont, T.muted)
            b.text:SetPoint("CENTER")
            local w = b.text:GetStringWidth() + 22
            b:SetSize(w, 26)
            b:SetPoint("TOPLEFT", x, 0)
            x = x + w
            b.line = b:CreateTexture(nil, "OVERLAY")
            b.line:SetPoint("BOTTOMLEFT", 5, 0)
            b.line:SetPoint("BOTTOMRIGHT", -5, 0)
            b.line:SetHeight(2)
            b.line:SetColorTexture(A[1], A[2], A[3], 1)
            b:SetScript("OnEnter", function(self) if bar.current ~= key then self.text:SetTextColor(unpack(T.text)) end end)
            b:SetScript("OnLeave", function(self) if bar.current ~= key then self.text:SetTextColor(unpack(T.muted)) end end)
            b:SetScript("OnClick", function() bar:Select(key) end)
            bar.buttons[key] = b
        end
        local sep = bar:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("BOTTOMLEFT")
        sep:SetPoint("BOTTOMRIGHT")
        sep:SetHeight(1)
        sep:SetColorTexture(1, 1, 1, 0.07)
        function bar:Select(key)
            self.current = key
            for k, b in pairs(self.buttons) do
                b.line:SetShown(k == key)
                b.text:SetTextColor(unpack(k == key and T.text or T.muted))
            end
            if onSelect then onSelect(key) end
        end
        return bar
    end

    ---------------------------------------------------------------------------
    -- Confirmation dialog over the screen (darkens what is behind)
    ---------------------------------------------------------------------------
    function UI.Dialog(text, acceptText, onAccept, cancelText)
        local d = UI.dialog
        if not d then
            d = CreateFrame("Frame", nil, UIParent)
            d:SetAllPoints()
            d:SetFrameStrata("FULLSCREEN_DIALOG")
            d:EnableMouse(true)
            local dim = d:CreateTexture(nil, "BACKGROUND")
            dim:SetAllPoints()
            dim:SetColorTexture(0, 0, 0, 0.55)
            d.box = CreateFrame("Frame", nil, d, "BackdropTemplate")
            d.box:SetSize(340, 120)
            d.box:SetPoint("CENTER")
            UI.Backdrop(d.box, T.window, { A[1], A[2], A[3], 1 })
            d.text = UI.Text(d.box, "", T.labelFont)
            d.text:SetPoint("TOPLEFT", 16, -16)
            d.text:SetPoint("TOPRIGHT", -16, -16)
            d.text:SetJustifyH("CENTER")
            d.text:SetWordWrap(true)
            d.accept = UI.Button(d.box, "", 120, 22, nil, "accent")
            d.accept:SetPoint("BOTTOMRIGHT", d.box, "BOTTOM", -4, 14)
            d.cancel = UI.Button(d.box, "", 120, 22, function() d:Hide() end)
            d.cancel:SetPoint("BOTTOMLEFT", d.box, "BOTTOM", 4, 14)
            d:EnableKeyboard(true)
            d:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    self:SetPropagateKeyboardInput(false)
                    self:Hide()
                else
                    self:SetPropagateKeyboardInput(true)
                end
            end)
            UI.dialog = d
        end
        d.text:SetText(text)
        d.box:SetHeight(math.max(110, d.text:GetStringHeight() + 70))
        d.accept.text:SetText(acceptText or UI.strings.accept)
        d.cancel.text:SetText(cancelText or UI.strings.cancel)
        d.accept:SetScript("OnClick", function()
            d:Hide()
            if onAccept then onAccept() end
        end)
        d:Show()
        return d
    end

    ---------------------------------------------------------------------------
    -- Window: header (logo, title, version, subtitle, buttons on the right),
    -- navigation buttons on the left, page area and an optional status line.
    --   opts = { name, title, version, width, height, navWidth,
    --            logo (texture path), status (false: no status line) }
    --   win:AddNav(key, label, build, dot)  build(container) runs on first open;
    --                                       dot() -> true/false shows a dot
    --   win:AddSection(label)               small caption in the navigation
    --   win:AddHeaderButton(label, onClick, isOn, tip)  isOn() lights it up
    --   win:Select(key), win:SetSubtitle(text), win:SetStatus(text)
    ---------------------------------------------------------------------------
    function UI.Window(opts)
        local W, H = opts.width or 760, opts.height or 606
        local NAV_W = opts.navWidth or 130
        local win = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
        win:SetSize(W, H)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        win:SetToplevel(true)
        UI.Backdrop(win, T.window, T.windowBorder)
        win:EnableMouse(true)
        win:SetMovable(true)
        win:SetClampedToScreen(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
        if opts.name then table.insert(UISpecialFrames, opts.name) end
        win:SetScript("OnHide", function() UI.CloseMenu() end)

        -- header: band with a soft brand-color glow from the left
        local header = CreateFrame("Frame", nil, win)
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(40)
        local hbg = header:CreateTexture(nil, "BACKGROUND")
        hbg:SetAllPoints()
        hbg:SetColorTexture(unpack(T.header))
        local glow = header:CreateTexture(nil, "BORDER")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 1)
        if not (CreateColor and pcall(glow.SetGradient, glow, "HORIZONTAL",
            CreateColor(A[1], A[2], A[3], 0.08), CreateColor(A[1], A[2], A[3], 0))) then
            glow:SetColorTexture(A[1], A[2], A[3], 0.03)
        end
        local hline = header:CreateTexture(nil, "ARTWORK")
        hline:SetPoint("BOTTOMLEFT")
        hline:SetPoint("BOTTOMRIGHT")
        hline:SetHeight(1)
        hline:SetColorTexture(A[1], A[2], A[3], 0.35)

        -- logo: the given texture, or a brand-color diamond
        local logo = header:CreateTexture(nil, "ARTWORK")
        if opts.logo then
            logo:SetSize(24, 24)
            logo:SetTexture(opts.logo)
        else
            logo:SetSize(12, 12)
            logo:SetColorTexture(A[1], A[2], A[3], 1)
            logo:SetRotation(math.rad(45))
        end
        logo:SetPoint("CENTER", header, "LEFT", 22, 0)
        local title = header:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 14, "")
        title:SetTextColor(1, 1, 1)
        title:SetText(opts.title or "")
        title:SetPoint("TOPLEFT", header, "TOPLEFT", 42, -6)
        local version = UI.Text(header, opts.version and ("v" .. opts.version) or "", "GameFontDisableSmall")
        version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
        local subtitle = UI.Text(header, "", T.labelFont, { 0.6, 0.64, 0.71 })
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        function win:SetSubtitle(text) subtitle:SetText(text or "") end

        local close = UI.Button(header, "X", 22, 20, function() win:Hide() end)
        close:SetPoint("RIGHT", -10, 0)
        local lastButton = close
        function win:AddHeaderButton(label, onClick, isOn, tip)
            local b = UI.Button(header, label, 110, 20, onClick)
            b:SetPoint("RIGHT", lastButton, "LEFT", -6, 0)
            lastButton = b
            if tip then UI.Tip(b, label, tip) end
            if isOn then
                b.Refresh = function()
                    if isOn() then
                        b.borderColor = { A[1], A[2], A[3], 1 }
                        b:SetBackdropColor(A[1] * 0.3, A[2] * 0.3, A[3] * 0.3, 1)
                    else
                        b.borderColor = T.border
                        b:SetBackdropColor(unpack(T.button))
                    end
                    b:SetBackdropBorderColor(unpack(b.borderColor))
                end
                Register(b)
            end
            return b
        end

        -- navigation and pages
        local navY = -50
        local navs, pages, builders, order = {}, {}, {}, {}
        local area = CreateFrame("Frame", nil, win)
        area:SetPoint("TOPLEFT", NAV_W + 10 + T.pageMargin, -50)
        area:SetPoint("BOTTOMRIGHT", -T.pageMargin, opts.status ~= false and 26 or 8)

        function win:AddSection(label)
            local t = UI.Text(win, label, "GameFontDisableSmall")
            t:SetPoint("TOPLEFT", 14, navY - 6)
            navY = navY - 22
        end

        local function PaintNav()
            for key, nb in pairs(navs) do
                local on = key == win.current
                nb:SetBackdropColor(unpack(on and T.navSelected or T.nav))
                nb.text:SetTextColor(unpack(on and T.text or { 0.85, 0.85, 0.88 }))
                if nb.dot then
                    local lit = nb.dotFn()
                    nb.dot:SetColorTexture(lit and A[1] or 0.3, lit and A[2] or 0.3, lit and A[3] or 0.35, 1)
                end
            end
        end

        function win:AddNav(key, label, build, dot)
            local nb = UI.Button(win, label, NAV_W, 26, function() win:Select(key) end)
            nb:SetPoint("TOPLEFT", 10, navY)
            nb.text:ClearAllPoints()
            nb.text:SetPoint("LEFT", 10, 0)
            if dot then
                nb.dot = nb:CreateTexture(nil, "OVERLAY")
                nb.dot:SetSize(6, 6)
                nb.dot:SetPoint("RIGHT", -9, 0)
                nb.dotFn = dot
            end
            navY = navY - 30
            navs[key] = nb
            builders[key] = build
            table.insert(order, key)
            return nb
        end

        function win:Select(key)
            UI.CloseMenu()
            self.current = key
            for k, p in pairs(pages) do p:SetShown(k == key) end
            if not pages[key] and builders[key] then
                local container = CreateFrame("Frame", nil, area)
                container:SetAllPoints()
                pages[key] = container
                builders[key](container)
            end
            if pages[key] then pages[key]:Show() end
            PaintNav()
            UI.RefreshAll()
        end

        -- status line at the bottom
        if opts.status ~= false then
            local status = UI.Text(win, "", T.labelFont, T.muted)
            status:SetPoint("BOTTOMLEFT", NAV_W + 10 + T.pageMargin, 9)
            function win:SetStatus(text) status:SetText(text or "") end
        else
            function win:SetStatus() end
        end

        function win:Toggle()
            self:SetShown(not self:IsShown())
            if self:IsShown() then UI.RefreshAll() end
        end

        win.header = header
        win.area = area
        win.PaintNav = PaintNav
        UI.window = win
        return win
    end

    ---------------------------------------------------------------------------
    -- Refresh every control (values, enabled state) and the visible pages
    ---------------------------------------------------------------------------
    function UI.RefreshAll()
        for _, w in ipairs(UI.widgets) do
            if w.Refresh then w.Refresh(w) end
        end
        for _, p in ipairs(UI.pages) do
            if p:IsVisible() then p:Layout() end
        end
        if UI.window and UI.window.PaintNav then UI.window.PaintNav() end
        if UI.OnRefresh then UI.OnRefresh() end
    end

    -- Value formatters
    UI.pct = function(v) return ("%d%%"):format(v * 100 + 0.5) end
    UI.px = function(v) return ("%d px"):format(v) end

    -- Texts the library shows on its own; replace them to translate
    UI.strings = {
        confirm = "Click again to confirm",
        search = "Search...",
        accept = "Accept",
        cancel = "Cancel",
        reset = "Reset",
        none = "None",
    }

    -- Media and shapes (see the Media section above lib:New)
    UI.Media, UI.ResolveMedia = lib.Media, lib.ResolveMedia
    UI.SetBarTexture, UI.SetBgTexture, UI.SetFontFile = lib.SetBarTexture, lib.SetBgTexture, lib.SetFontFile
    UI.GetShape, UI.ShapeList, UI.SetShapeMask, UI.ShapeBorder = lib.GetShape, lib.ShapeList, lib.SetShapeMask, lib.ShapeBorder
    UI.SetShapeRing = lib.SetShapeRing
    UI.Rounded, UI.ShapeEdge = lib.Rounded, lib.ShapeEdge
    function UI.MediaList(kind, opts)
        opts = opts or {}
        if opts.none and not opts.noneLabel then
            opts = { none = true, noneLabel = UI.strings.none }
        end
        return lib.MediaList(kind, opts)
    end

    return UI
end
