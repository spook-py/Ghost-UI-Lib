local GhostUI = {}
local ASSETS = {}

local V2, RGB = Vector2.new, Color3.fromRGB
local clock = os.clock
local floor, max, min, abs, exp, sin = math.floor, math.max, math.min, math.abs, math.exp, math.sin

local FONT = 8
local SUB = 0.5

local BASE = {
	Bg = { 17, 17, 19 }, Side = { 13, 13, 15 }, Border = { 38, 38, 42 }, Line = { 30, 30, 34 },
	Row = { 22, 22, 25 }, RowBorder = { 32, 32, 36 }, RowHover = { 27, 27, 31 }, RowBorderHover = { 50, 50, 56 },
	Pill = { 28, 28, 32 }, PillBorder = { 46, 46, 52 }, HoverPill = { 21, 21, 24 },
	Text = { 255, 255, 255 }, Accent = { 255, 255, 255 },
	Track = { 44, 44, 50 }, KnobOff = { 150, 150, 158 }, KnobOn = { 17, 17, 19 },
	Field = { 13, 13, 15 }, Option = { 32, 32, 36 }, Shade = { 0, 0, 0 },
}
local THEMES = {
	Mono = { Accent = { 255, 255, 255 }, KnobOn = { 17, 17, 19 } },
	Ocean = { Accent = { 86, 156, 255 }, KnobOn = { 255, 255, 255 } },
	Crimson = { Accent = { 255, 82, 98 }, KnobOn = { 255, 255, 255 } },
	Mint = { Accent = { 72, 219, 151 }, KnobOn = { 17, 17, 19 } },
	Violet = { Accent = { 157, 120, 255 }, KnobOn = { 255, 255, 255 } },
	Amber = { Accent = { 255, 176, 64 }, KnobOn = { 17, 17, 19 } },
}
GhostUI.Themes = { "Mono", "Ocean", "Crimson", "Mint", "Violet", "Amber" }
GhostUI.Icons = { "home", "sword", "eye", "gear", "user", "bolt" }
local function buildTheme(t)
	if type(t) == "string" then t = THEMES[t] end
	local out = {}
	for k, v in pairs(BASE) do out[k] = { v[1], v[2], v[3] } end
	for k, v in pairs(t or {}) do out[k] = { v[1], v[2], v[3] } end
	return out
end
GhostUI.ActiveTheme = buildTheme("Mono")

local Z = {
	row = 403, rowLine = 404, rowFx = 405, rowText = 406, rowTop = 407, head = 408,
	side = 410, sideLine = 411, pill = 412, bar = 413, sideText = 414,
	border = 420, pop = 425, popText = 426, tip = 430, tipText = 431,
	panel = 440, panelText = 441, dim = 450, dlg = 451, dlgText = 452,
}

local ROWH, GAP, OPTH, SEARCHH = 40, 6, 30, 34
local HEADER_H = 58
local TAB_Y, TAB_H, TAB_STEP = 70, 34, 38
local SUB_H = 28
local LOADER_BOX, LOADER_BG = 104, { 22, 22, 24 }

local function clamp(x, a, b) a = a or 0 b = b or 1 return x < a and a or (x > b and b or x) end
local function lerp(a, b, t) return a + (b - a) * t end
local function ease(cur, target, speed, dt) return cur + (target - cur) * (1 - exp(-speed * dt)) end
local function outCubic(t) t = 1 - clamp(t) return 1 - t * t * t end
local function inOutCubic(t) t = clamp(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
local function outBack(t)
	t = clamp(t)
	return 1 + 2.70158 * (t - 1) ^ 3 + 1.70158 * (t - 1) ^ 2
end
local function mixT(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function mix(a, b, t)
	return RGB(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
end
local function rgb(c) return RGB(c[1], c[2], c[3]) end
local function spring(s, target, dt, k, d)
	k, d = k or 260, d or 20
	local h = dt / 2
	for _ = 1, 2 do
		s.v = s.v + ((target - s.x) * k - s.v * d) * h
		s.x = s.x + s.v * h
	end
	return s.x
end

local function rgbToHsv(r, g, b)
	local mx, mn = max(r, g, b), min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, mx > 0 and d / mx or 0, mx
end
local function toHex(c)
	return string.format("#%02X%02X%02X", floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5))
end
local function fromHex(s)
	local r, g, b = tostring(s):match("#?(%x%x)(%x%x)(%x%x)")
	if not r then return nil end
	return RGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end
local function commas(n, dec)
	local s = string.format("%." .. (dec or 0) .. "f", n)
	local int, frac = s:match("^(-?%d+)(.*)$")
	if not int then return s end
	int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(-?),", "%1")
	return int .. frac
end

local measurer
local function measure(str, size)
	if str == "" then return 0 end
	if not measurer then measurer = Drawing.new("Text") measurer.Visible = false measurer.Outline = false end
	measurer.Font = FONT measurer.Size = size measurer.Text = str
	local ok, b = pcall(function() return measurer.TextBounds end)
	if ok and b and b.X and b.X > 0 and b.Y > 0 then return b.X * size / b.Y end
	return #str * size * 0.55
end
local function fitText(s, size, maxW, keepEnd)
	if measure(s, size) <= maxW then return s end
	for n = #s - 1, 0, -1 do
		local t = keepEnd and ("..." .. s:sub(#s - n + 1)) or (s:sub(1, n) .. "...")
		if measure(t, size) <= maxW then return t end
	end
	return "..."
end
local function wrap(text, size, maxW)
	local lines, cur = {}, ""
	for word in tostring(text):gmatch("%S+") do
		local try = cur == "" and word or (cur .. " " .. word)
		if measure(try, size) <= maxW then
			cur = try
		else
			if cur ~= "" then lines[#lines + 1] = cur end
			while measure(word, size) > maxW and #word > 1 do
				local n = #word - 1
				while n > 1 and measure(word:sub(1, n), size) > maxW do n = n - 1 end
				lines[#lines + 1] = word:sub(1, n)
				word = word:sub(n + 1)
			end
			cur = word
		end
	end
	if cur ~= "" then lines[#lines + 1] = cur end
	return lines
end

local IMG = {}
local function img(name)
	if not name then return nil end
	if IMG[name] == nil then
		local data = ASSETS[name]
		if data then
			data = base64decode(data)
		else
			local ok, raw = pcall(readfile, name)
			if ok and type(raw) == "string" and #raw > 0 then
				data = string.sub(raw, 2, 4) == "PNG" and raw or base64decode(raw)
			end
		end
		IMG[name] = data or false
	end
	return IMG[name] or nil
end

local function fire(cb, ...)
	if type(cb) ~= "function" then return end
	local args, n = { ... }, select("#", ...)
	task.spawn(function()
		local ok, err = pcall(cb, (table.unpack or unpack)(args, 1, n))
		if not ok then warn("[GhostUI] callback: " .. tostring(err)) end
	end)
end

local function copy(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in pairs(v) do o[k] = x end
	return o
end

local KEYS, KEYNAME = {}, {}
local function addKey(vk, name, ch, sh)
	KEYS[#KEYS + 1] = { vk = vk, name = name, ch = ch, sh = sh }
	KEYNAME[vk] = name
end
for i = 0, 25 do local c = string.char(65 + i) addKey(0x41 + i, c, c:lower(), c) end
do
	local sd = ")!@#$%^&*("
	for i = 0, 9 do addKey(0x30 + i, tostring(i), tostring(i), sd:sub(i + 1, i + 1)) end
end
addKey(0x20, "SPACE", " ", " ")
for _, k in ipairs({ { 0xBD, "-", "-", "_" }, { 0xBB, "=", "=", "+" }, { 0xDB, "[", "[", "{" }, { 0xDD, "]", "]", "}" },
	{ 0xDC, "\\", "\\", "|" }, { 0xBA, ";", ";", ":" }, { 0xDE, "'", "'", "\"" }, { 0xBC, ",", ",", "<" },
	{ 0xBE, ".", ".", ">" }, { 0xBF, "/", "/", "?" }, { 0xC0, "`", "`", "~" } }) do addKey(k[1], k[2], k[3], k[4]) end
for i = 1, 12 do addKey(0x6F + i, "F" .. i) end
for _, k in ipairs({ { 0x08, "BACK" }, { 0x09, "TAB" }, { 0x0D, "ENTER" }, { 0x14, "CAPS" }, { 0x1B, "ESC" },
	{ 0x21, "PGUP" }, { 0x22, "PGDN" }, { 0x23, "END" }, { 0x24, "HOME" }, { 0x25, "LEFT" }, { 0x26, "UP" },
	{ 0x27, "RIGHT" }, { 0x28, "DOWN" }, { 0x2D, "INS" }, { 0x2E, "DEL" }, { 0xA0, "LSHIFT" }, { 0xA1, "RSHIFT" },
	{ 0xA2, "LCTRL" }, { 0xA3, "RCTRL" }, { 0xA4, "LALT" }, { 0xA5, "RALT" }, { 0x02, "MB2" }, { 0x04, "MB3" },
	{ 0x05, "MB4" }, { 0x06, "MB5" } }) do addKey(k[1], k[2]) end
local NAMEVK = {}
for vk, n in pairs(KEYNAME) do NAMEVK[n] = vk end
local EDITVK = { [0x08] = true, [0x0D] = true, [0x1B] = true, [0x25] = true, [0x27] = true, [0x24] = true, [0x23] = true, [0x2E] = true }
GhostUI.KeyName = function(vk) return KEYNAME[vk] or "NONE" end
GhostUI.KeyCode = function(name) return NAMEVK[string.upper(tostring(name))] end
local function toVK(k)
	if type(k) == "number" then return k end
	if type(k) == "string" then return NAMEVK[string.upper(k)] end
	return nil
end

local function prevWord(t, c)
	while c > 0 and t:sub(c, c) == " " do c = c - 1 end
	while c > 0 and t:sub(c, c) ~= " " do c = c - 1 end
	return c
end
local function nextWord(t, c)
	while c < #t and t:sub(c + 1, c + 1) == " " do c = c + 1 end
	while c < #t and t:sub(c + 1, c + 1) ~= " " do c = c + 1 end
	return c
end
local function editKey(st, k, shift, ctrl, maxLen, allow)
	local t, c = st.text, st.caret
	local vk = k.vk
	if vk == 0x25 then c = ctrl and prevWord(t, c) or max(0, c - 1)
	elseif vk == 0x27 then c = ctrl and nextWord(t, c) or min(#t, c + 1)
	elseif vk == 0x24 then c = 0
	elseif vk == 0x23 then c = #t
	elseif vk == 0x08 then
		if ctrl then
			local p = prevWord(t, c)
			t = t:sub(1, p) .. t:sub(c + 1)
			c = p
		elseif c > 0 then
			t = t:sub(1, c - 1) .. t:sub(c + 1)
			c = c - 1
		end
	elseif vk == 0x2E then
		if c < #t then t = t:sub(1, c) .. t:sub(c + 2) end
	elseif k.ch and #t < (maxLen or 64) then
		local ch = shift and k.sh or k.ch
		if allow and not string.find(allow, ch, 1, true) then return false end
		t = t:sub(1, c) .. ch .. t:sub(c + 1)
		c = c + 1
	else
		return false
	end
	st.text, st.caret = t, c
	st.blinkAt = clock()
	return true
end
local function viewText(st, size, maxW)
	local key = st.text .. "\1" .. st.caret .. "\1" .. maxW
	if st._key == key then return st._shown, st._cx end
	local t, c = st.text, st.caret
	local cxFull = measure(t:sub(1, c), size)
	st.scroll = st.scroll or 0
	if cxFull - st.scroll > maxW then st.scroll = cxFull - maxW end
	if cxFull - st.scroll < 0 then st.scroll = cxFull end
	local i = 0
	while i < #t and measure(t:sub(1, i + 1), size) <= st.scroll + 0.5 do i = i + 1 end
	local shown = t:sub(i + 1)
	while #shown > 0 and measure(shown, size) > maxW + 2 do shown = shown:sub(1, -2) end
	local cx = measure(t:sub(i + 1, c), size)
	st._key, st._shown, st._cx = key, shown, cx
	return shown, cx
end
local function newEdit(text) text = tostring(text or "") return { text = text, caret = #text, scroll = 0, blinkAt = clock() } end

local OX, OY, SC = 0, 0, 1
local CT, CB = nil, nil
local function clipA(y, h)
	if not CT then return 1 end
	return clamp(1 - (CT - y) / 10) * clamp(1 - (y + h - CB) / 10)
end
local function sqRaw(d, x, y, w, h, a, color, corner)
	local vis = a > 0.01 and w > 0.5 and h > 0.5
	d.Visible = vis
	if not vis then return end
	d.Position = V2(OX + x * SC, OY + y * SC)
	d.Size = V2(w * SC, h * SC)
	if corner then d.Corner = min(corner, h / 2, w / 2) * SC end
	d.Transparency = a
	if color then d.Color = color end
end
local function sq(d, x, y, w, h, a, color, corner)
	sqRaw(d, x, y, w, h, a * clipA(y, h), color, corner)
end
local function sqc(d, x, y, w, h, a, color, corner)
	if CT then
		local y1, y2 = max(y, CT - 4), min(y + h, CB + 4)
		if y2 - y1 < 1 then d.Visible = false return end
		a = a * clamp((y2 - y1) / 20)
		y, h = y1, y2 - y1
	end
	sqRaw(d, x, y, w, h, a, color, corner)
end
local function tx(d, x, y, size, a, color, text)
	a = a * clipA(y, size)
	local vis = a > 0.01
	d.Visible = vis
	if not vis then return end
	if text then d.Text = text end
	d.Position = V2(floor(OX + x * SC + 0.5), floor(OY + y * SC + 0.5))
	d.Size = floor(size * SC + 0.5)
	d.Transparency = a
	if color then d.Color = color end
end
local function ln(d, x1, y1, x2, y2, a, color)
	a = a * clipA(min(y1, y2), abs(y2 - y1))
	local vis = a > 0.01
	d.Visible = vis
	if not vis then return end
	d.From = V2(OX + x1 * SC, OY + y1 * SC)
	d.To = V2(OX + x2 * SC, OY + y2 * SC)
	d.Transparency = a
	if color then d.Color = color end
end
local function cir(d, x, y, r, a, color)
	a = a * clipA(y - r, r * 2)
	local vis = a > 0.01
	d.Visible = vis
	if not vis then return end
	d.Position = V2(OX + x * SC, OY + y * SC)
	d.Radius = r * SC
	d.Transparency = a
	if color then d.Color = color end
end
local function inRect(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end
local function hide(...) for _, d in ipairs({ ... }) do d.Visible = false end end

do
	local Loader = {}
	Loader.__index = Loader
	local LDEF = { Title = "SCRIPT NAME", Icon = "ghost", BoxSize = LOADER_BOX, Height = LOADER_BOX, Corner = 24, TextSize = 42,
		Duration = nil, Bg = LOADER_BG, Border = { 8, 8, 9 }, Text = { 0, 0, 0 } }
	local T_POP, T_ICON, T_EXPAND, T_TYPE = 0.45, { 0.2, 0.6 }, { 0.9, 1.5 }, 0.045
	local T_CLOSE_TEXT, T_CLOSE_SHRINK, T_CLOSE_POP = 0.25, 0.45, 0.35
	local function seg(t, a, b) return clamp((t - a) / (b - a)) end

	function GhostUI.new(opts)
		local self = setmetatable({}, Loader)
		local cfg = {}
		for k, v in pairs(LDEF) do cfg[k] = v end
		for k, v in pairs(opts or {}) do cfg[k] = v end
		self.cfg = cfg
		self.dead = false
		local function mk(kind, props)
			local d = Drawing.new(kind)
			if kind == "Text" then d.Font = FONT d.Outline = false end
			for k, v in pairs(props) do if k ~= "Color" then d[k] = v end end
			if props.Color then d.Color = props.Color end
			return d
		end
		self.bg = mk("Square", { Filled = true, Color = rgb(cfg.Bg), Corner = cfg.Corner, ZIndex = 200, Transparency = 0, Visible = true })
		self.border = mk("Square", { Filled = false, Thickness = 1, Color = rgb(cfg.Border), Corner = cfg.Corner, ZIndex = 201, Transparency = 0, Visible = true })
		self.icon = mk("Image", { ZIndex = 202, Transparency = 0, Visible = true })
		self.text = mk("Text", { Text = "", Size = cfg.TextSize, ZIndex = 202, Transparency = 0, Visible = true, Color = rgb(cfg.Text) })
		local data = img(cfg.Icon)
		if data then self.icon.Data = data end
		self.titleW = measure(cfg.Title, cfg.TextSize)
		self.t0 = clock()
		task.spawn(function()
			while not self.dead do
				local ok, err = pcall(self._step, self)
				if not ok then warn("[GhostUI] loader: " .. tostring(err)) self:Destroy() break end
				task.wait()
			end
		end)
		return self
	end

	function Loader:_introEnd() return T_EXPAND[2] + #self.cfg.Title * T_TYPE + 0.15 end
	function Loader:Finish(wait)
		if self.closeAt then return end
		self.closeAt = max(clock() - self.t0, self:_introEnd() + 0.3)
		if wait then while not self.dead do task.wait() end end
	end
	function Loader:Morph(cb)
		self.morph = true
		self.onMorph = cb
		self:Finish()
	end
	function Loader:Destroy()
		if self.dead then return end
		self.dead = true
		for _, d in ipairs({ self.bg, self.border, self.icon, self.text }) do
			pcall(function() d.Visible = false d:Remove() end)
		end
	end
	function Loader:_step()
		local cfg = self.cfg
		local t = clock() - self.t0
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or V2(1920, 1080)
		local cx, cy = vp.X / 2, vp.Y / 2
		local S, H = cfg.BoxSize, cfg.Height
		local iconSz = S * 0.62
		local pad = (H - iconSz) / 2
		local gap = 22
		local fullW = pad + iconSz + gap + self.titleW + pad + 8
		if cfg.Duration and not self.closeAt and t > self:_introEnd() + cfg.Duration then self:Finish() end
		local pop = outBack(seg(t, 0, T_POP))
		local alpha = seg(t, 0, T_POP * 0.6)
		local ex = outCubic(seg(t, T_EXPAND[1], T_EXPAND[2]))
		local n = #cfg.Title
		local chars = floor(clamp((t - T_EXPAND[1] - 0.25) / (n * T_TYPE)) * n + 0.5)
		local iconA = outCubic(seg(t, T_ICON[1], T_ICON[2]))
		if self.closeAt then
			local c = t - self.closeAt
			local ct = seg(c, 0, T_CLOSE_TEXT)
			local cs = inOutCubic(seg(c, T_CLOSE_TEXT, T_CLOSE_TEXT + T_CLOSE_SHRINK))
			local cp = seg(c, T_CLOSE_TEXT + T_CLOSE_SHRINK, T_CLOSE_TEXT + T_CLOSE_SHRINK + T_CLOSE_POP)
			if self.morph and cs >= 1 then
				self:Destroy()
				if self.onMorph then self.onMorph() end
				return
			end
			chars = floor(n * (1 - ct) + 0.5)
			ex = ex * (1 - cs)
			pop = 1 - cp * cp
			alpha = alpha * (1 - cp)
			iconA = iconA * (1 - cp)
			if cp >= 1 then self:Destroy() return end
		end
		local w = lerp(S, fullW, ex) * pop
		local h = lerp(S, H, ex) * pop
		local x, y = cx - w / 2, cy - h / 2
		local corner = min(cfg.Corner * pop, h / 2)
		self.bg.Position, self.bg.Size, self.bg.Corner, self.bg.Transparency = V2(x, y), V2(w, h), corner, alpha
		self.border.Position, self.border.Size, self.border.Corner, self.border.Transparency = V2(x, y), V2(w, h), corner, alpha
		local bob = sin(t * 3.2) * 2.5 * iconA
		local isz = iconSz * pop * lerp(0.6, 1, iconA)
		local ix = x + (lerp(S, h, ex) * pop - isz) / 2
		local iy = y + (h - isz) / 2 + bob
		self.icon.Position, self.icon.Size, self.icon.Transparency = V2(ix, iy), V2(isz, isz * (236 / 243)), iconA
		local shown = string.sub(cfg.Title, 1, chars)
		local typing = chars > 0 and chars < n
		local caret = (typing or (ex > 0.99 and not self.closeAt and t < self:_introEnd() + 0.6)) and (floor(t * 4) % 2 == 0) and "|" or ""
		self.text.Text = shown .. caret
		self.text.Position = V2(floor(x + pad + iconSz + gap + 0.5), floor(cy - cfg.TextSize / 2 - 1 + 0.5))
		self.text.Transparency = (chars > 0 or caret ~= "") and alpha or 0
	end
	function GhostUI.Play(opts)
		opts = opts or {}
		if opts.Duration == nil then opts.Duration = 1.5 end
		return GhostUI.new(opts)
	end
end

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab

function GhostUI.Window(opts)
	opts = opts or {}
	local self = setmetatable({}, Window)
	self.title = opts.Title or "SCRIPT NAME"
	self.W = opts.Width or 700
	self.H = opts.Height or 470
	self.T = buildTheme(opts.Theme or "Mono")
	self.themeName = type(opts.Theme) == "string" and opts.Theme or "Mono"
	GhostUI.ActiveTheme = self.T
	self.draws, self.winDraws, self.themed, self.tabs, self.Flags, self.elements, self.binds = {}, {}, {}, {}, {}, {}, {}
	self.playerDrops = {}
	self.toggleKey = toVK(opts.Key) or 0xA1
	self.SWo = max(180, floor(56 + measure(self.title, 18) + 20))
	self.SWc = 64
	self.sideOpen, self.sideHoverAt = 0, 0
	self.mini, self.mm = false, 0

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or V2(1920, 1080)
	self.vp = vp
	self.x = floor(vp.X / 2 - self.W / 2)
	self.y = floor(vp.Y / 2 - self.H / 2)
	self.tx, self.ty = self.x, self.y

	self.visible = false
	self.o = 0
	self.sc = { x = 0.92, v = 0 }
	self.openAt = clock()
	self.ind = { x = TAB_Y, v = 0 }
	self.barH = 0
	self.hoverAmt = 0
	self.keyPrev, self.keyRep = {}, {}
	self.overlay = { Watermark = opts.Watermark ~= false, Keybinds = opts.Keybinds ~= false, Active = opts.Active ~= false }
	self.frameMs = 0

	local function d(kind, props) return self:_d(kind, props) end
	self.bg = d("Square", { Filled = true, ZIndex = Z.row - 2, Theme = "Bg" })
	self.side = d("Square", { Filled = true, ZIndex = Z.side, Theme = "Side" })
	self.sidePatch = d("Square", { Filled = true, ZIndex = Z.side, Theme = "Side" })
	self.divider = d("Line", { Thickness = 1, ZIndex = Z.sideLine, Theme = "Line" })
	self.border = d("Square", { Filled = false, Thickness = 1, ZIndex = Z.border, Theme = "Border" })
	self.tabHover = d("Square", { Filled = true, ZIndex = Z.sideLine, Theme = "HoverPill" })
	self.pill = d("Square", { Filled = true, ZIndex = Z.pill, Theme = "Pill" })
	self.pillOl = d("Square", { Filled = false, Thickness = 1, ZIndex = Z.pill, Theme = "PillBorder" })
	self.bar = d("Square", { Filled = true, ZIndex = Z.bar, Theme = "Accent" })
	self.ghost = d("Image", { ZIndex = Z.sideText })
	self.ghostB = d("Image", { ZIndex = Z.sideText })
	self.titleD = d("Text", { Text = self.title, ZIndex = Z.sideText, Theme = "Text" })
	self.hint = d("Text", { Text = "", ZIndex = Z.sideText, Theme = "Text" })
	self.scrollbar = d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Track" })
	self.grip1 = d("Line", { Thickness = 1.5, ZIndex = Z.border, Theme = "RowBorderHover" })
	self.grip2 = d("Line", { Thickness = 1.5, ZIndex = Z.border, Theme = "RowBorderHover" })
	self.minBox = d("Square", { Filled = true, ZIndex = Z.head, Theme = "Field" })
	self.minOl = d("Square", { Filled = false, Thickness = 1, ZIndex = Z.head, Theme = "PillBorder" })
	self.minH = d("Line", { Thickness = 1.5, ZIndex = Z.head, Theme = "Text" })
	self.minV = d("Line", { Thickness = 1.5, ZIndex = Z.head, Theme = "Text" })
	self.minHov = 0
	self:SetToggleKey(self.toggleKey)
	local wIcon, bIcon = img(opts.Icon or "ghost_white"), img("ghost")
	if wIcon then self.ghost.Data = wIcon end
	if bIcon then self.ghostB.Data = bIcon end

	self.search = self:_makeSearch()
	self.tip = { bg = d("Square", { Filled = true, ZIndex = Z.tip, Theme = "Bg" }),
		ol = d("Square", { Filled = false, Thickness = 1, ZIndex = Z.tip, Theme = "PillBorder" }), lines = {}, a = 0 }
	for i = 1, 5 do self.tip.lines[i] = d("Text", { Text = "", ZIndex = Z.tipText, Theme = "Text" }) end
	self:_makeDialog()

	self._ovMode = true
	self.panels = {
		Active = self:_makePanel("ACTIVE", 58),
		Keybinds = self:_makePanel("KEYBINDS", nil),
	}
	self.panels.Keybinds.anchor = self.panels.Active
	self.wm = self:_makeWatermark()
	self._ovMode = false

	local lp = game:GetService("Players").LocalPlayer
	self.lp = lp
	self.mouse = lp and lp:GetMouse()
	self.conns = {}
	self.m1, self.m2 = false, false
	self.keyDown = false
	self.activeAt, self.active = 0, true
	self.lastT = clock()
	self.fps = 60

	local rs = game:GetService("RunService")
	local sig = rs.RenderStepped or rs.Heartbeat
	self.conns[#self.conns + 1] = sig:Connect(function(dt)
		if self.dead then return end
		local t0 = clock()
		local ok, err = pcall(self._frame, self, dt)
		if not ok and not self._errd then self._errd = true warn("[GhostUI] " .. tostring(err)) end
		self.frameMs = ease(self.frameMs, (clock() - t0) * 1000, 3, 1 / 60)
	end)

	task.spawn(function()
		if opts.Loader then
			local l = GhostUI.new({ Title = self.title })
			task.wait(opts.LoaderTime or 1.2)
			self:_autoload(opts)
			l:Morph(function() self:_grow() end)
			while not l.dead do task.wait() end
		else
			task.wait()
			self:_autoload(opts)
			self:SetVisible(true)
		end
	end)
	return self
end

function Window:_autoload(opts)
	if opts.AutoLoad == false then return end
	local name = self:GetAutoload()
	if name and self:LoadConfig(name) then
		GhostUI.Notify({ Title = "Config loaded", Content = "Autoloaded \"" .. name .. "\".", Duration = 3 })
	end
end

function Window:_d(kind, props)
	local d = Drawing.new(kind)
	if kind == "Text" then d.Font = FONT d.Outline = false end
	for k, v in pairs(props) do if k ~= "Color" and k ~= "Theme" then d[k] = v end end
	if props.Theme then
		d.Color = rgb(self.T[props.Theme])
		self.themed[#self.themed + 1] = { d, props.Theme }
	elseif props.Color then
		d.Color = props.Color
	end
	d.Visible = false
	self.draws[#self.draws + 1] = d
	if not self._ovMode then self.winDraws[#self.winDraws + 1] = d end
	return d
end

function Window:SetTheme(t)
	local target = buildTheme(t)
	if type(t) == "string" then self.themeName = t end
	self.themeFrom = {}
	for k, v in pairs(self.T) do self.themeFrom[k] = { v[1], v[2], v[3] } end
	self.themeTo = target
	self.themeAt = clock()
end

function Window:_themeStep(now)
	if not self.themeAt then return end
	local f = outCubic((now - self.themeAt) / 0.45)
	for k, to in pairs(self.themeTo) do
		local fr = self.themeFrom[k] or to
		local cur = self.T[k]
		if not cur then cur = {} self.T[k] = cur end
		cur[1], cur[2], cur[3] = lerp(fr[1], to[1], f), lerp(fr[2], to[2], f), lerp(fr[3], to[3], f)
	end
	for _, p in ipairs(self.themed) do p[1].Color = rgb(self.T[p[2]]) end
	if f >= 1 then self.themeAt = nil end
end

function Window:SetToggleKey(vk)
	self.toggleKey = toVK(vk) or self.toggleKey
	self.hint.Text = (KEYNAME[self.toggleKey] or "?") .. " TO HIDE"
end

function Window:SetOverlay(name, on) self.overlay[name] = on and true or false end
function Window:SetMinimized(on) self.mini = on and true or false end
function Window:Stats() return { frameMs = self.frameMs, drawings = #self.draws, fps = self.fps } end

function Window:SetVisible(v)
	if v == self.visible then return end
	self.visible = v
	if v then
		self.openAt = clock()
		self.sc.x, self.sc.v = 0.92, 0
		if self.selected then self.selected.selAt = clock() - 0.07 end
	else
		if self.focus then self.focus:blur() end
		self.listening = nil
	end
end

function Window:_grow()
	self.growAt = clock()
	self.o = 1
	self.sc.x, self.sc.v = 1, 0
	self.visible = true
	self.openAt = clock() + 0.25
	if self.selected then self.selected.selAt = clock() + 0.2 end
end

function Window:Toggle() self:SetVisible(not self.visible) end

function Window:_setGameInput(on)
	if self.gameInput == on then return end
	self.gameInput = on
	if type(setrobloxinput) == "function" then pcall(setrobloxinput, on) end
end

function Window:Destroy()
	if self.dead then return end
	self.dead = true
	if type(setrobloxinput) == "function" then pcall(setrobloxinput, true) end
	for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
	for _, d in ipairs(self.draws) do pcall(function() d.Visible = false d:Remove() end) end
	if measurer then pcall(function() measurer:Remove() end) measurer = nil end
end

local Http = game:GetService("HttpService")
local CFG_DIR = "GhostUI/configs"
function Window:_configData()
	local data = {}
	for flag, e in pairs(self.elements) do if e.ser then data[flag] = e:ser() end end
	return data
end
function Window:_applyData(data)
	if type(data) ~= "table" then return false end
	for flag, v in pairs(data) do
		local e = self.elements[flag]
		if e and e.deser then pcall(e.deser, e, v) end
	end
	return true
end
function Window:SaveConfig(name)
	pcall(makefolder, "GhostUI")
	pcall(makefolder, CFG_DIR)
	local ok, err = pcall(writefile, CFG_DIR .. "/" .. name .. ".json", Http:JSONEncode(self:_configData()))
	if not ok then warn("[GhostUI] save failed: " .. tostring(err)) end
	return ok
end
function Window:LoadConfig(name)
	local ok, raw = pcall(readfile, CFG_DIR .. "/" .. name .. ".json")
	if not ok or type(raw) ~= "string" then return false end
	local ok2, data = pcall(function() return Http:JSONDecode(raw) end)
	if not ok2 then return false end
	return self:_applyData(data)
end
function Window:ListConfigs()
	local out = {}
	local ok, files = pcall(listfiles, CFG_DIR)
	if ok and type(files) == "table" then
		for _, f in ipairs(files) do
			local n = tostring(f):match("([^/\\]+)%.json$")
			if n then out[#out + 1] = n end
		end
	end
	table.sort(out)
	return out
end
function Window:SetAutoload(name)
	pcall(makefolder, "GhostUI")
	pcall(makefolder, CFG_DIR)
	if name then pcall(writefile, CFG_DIR .. "/autoload.txt", name)
	else pcall(delfile, CFG_DIR .. "/autoload.txt") end
end
function Window:GetAutoload()
	local ok, n = pcall(readfile, CFG_DIR .. "/autoload.txt")
	if ok and type(n) == "string" and n ~= "" then return n end
	return nil
end
function Window:ExportConfig()
	local s = Http:JSONEncode(self:_configData())
	if type(setclipboard) == "function" then pcall(setclipboard, s) end
	return s
end
function Window:ImportConfig(s)
	if type(s) ~= "string" or s == "" then
		local ok, raw = pcall(readfile, CFG_DIR .. "/import.txt")
		if not ok or type(raw) ~= "string" then return false end
		s = raw
	end
	local ok, data = pcall(function() return Http:JSONDecode(s) end)
	if not ok then return false end
	return self:_applyData(data)
end

function Window:Tab(name, o)
	o = o or {}
	local tab = setmetatable({ win = self, name = name, elements = {}, i = #self.tabs + 1,
		scroll = 0, scrollT = 0, shift = 0, selAt = clock(), pageAt = 0 }, Tab)
	tab.tab, tab.page = tab, tab
	tab.cols = { tab }
	tab.pages = { tab }
	tab.cur = tab
	tab.label = self:_d("Text", { Text = name, ZIndex = Z.sideText, Theme = "Text" })
	tab.head = self:_d("Text", { Text = name, ZIndex = Z.head, Theme = "Text" })
	tab.headLine = self:_d("Line", { Thickness = 1, ZIndex = Z.head, Theme = "Line" })
	local iconData = img(o.Icon)
	if iconData then
		tab.icon = self:_d("Image", { ZIndex = Z.sideText })
		tab.icon.Data = iconData
	end
	self.tabs[#self.tabs + 1] = tab
	self.SWc = max(self.SWc, floor(measure(name, 16) + 58 + (tab.icon and 24 or 0)))
	self.SWo = max(self.SWo, self.SWc + 20)
	if not self.selected then self:Select(tab) end
	return tab
end

function Tab:SubTabs(names)
	local tab = self.tab
	local win = tab.win
	tab.pages = {}
	tab.subs = {}
	tab.subBg = win:_d("Square", { Filled = true, ZIndex = Z.head, Theme = "Field" })
	tab.subOl = win:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.head, Theme = "RowBorder" })
	tab.subPill = win:_d("Square", { Filled = true, ZIndex = Z.head, Theme = "Pill" })
	tab.subPillOl = win:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.head, Theme = "PillBorder" })
	tab.subX, tab.subW = { x = 0, v = 0 }, { x = 0, v = 0 }
	local out = {}
	for i, n in ipairs(names) do
		local pg = setmetatable({ win = win, tab = tab, name = n, elements = {}, scroll = 0, scrollT = 0, i = i }, Tab)
		pg.page = pg
		pg.cols = { pg }
		pg.text = win:_d("Text", { Text = n, ZIndex = Z.head + 1, Theme = "Text" })
		pg.tw = measure(n, 14)
		pg.lit = 0
		tab.pages[i] = pg
		out[i] = pg
	end
	tab.cur = tab.pages[1]
	return (table.unpack or unpack)(out)
end

function Tab:Columns()
	local pg = self.page
	if #pg.cols < 2 then
		pg.cols[2] = setmetatable({ win = pg.win, tab = pg.tab, page = pg, elements = {} }, Tab)
	end
	return pg.cols[1], pg.cols[2]
end

local function eachEl(tab, fn)
	for _, pg in ipairs(tab.pages) do
		for _, col in ipairs(pg.cols) do for _, e in ipairs(col.elements) do fn(e) end end
	end
end
local function hidePage(pg)
	for _, col in ipairs(pg.cols) do
		for _, e in ipairs(col.elements) do for _, d in ipairs(e.draws) do d.Visible = false end end
	end
end
local function hideTab(tab)
	for _, pg in ipairs(tab.pages) do hidePage(pg) end
	tab.head.Visible = false
	tab.headLine.Visible = false
	if tab.subs then
		hide(tab.subBg, tab.subOl, tab.subPill, tab.subPillOl)
		for _, pg in ipairs(tab.pages) do pg.text.Visible = false end
	end
end

function Window:Select(tab)
	if self.selected == tab then return end
	local now = clock()
	if self.selected then self.selected.leaveAt = now end
	tab.leaveAt = nil
	tab.selAt = now
	self.selected = tab
	self.barH = 0
	if self.focus and self.focus.closeOnSwitch then self.focus:blur() end
end

function Window:_setPage(tab, pg)
	if tab.cur == pg then return end
	if self.focus and self.focus.closeOnSwitch then self.focus:blur() end
	hidePage(tab.cur)
	tab.cur = pg
	tab.pageAt = clock()
end

function Window:_primeKeys()
	for _, k in ipairs(KEYS) do self.keyPrev[k.vk] = iskeypressed(k.vk) end
end

function Window:_focus(obj)
	if self.focus and self.focus ~= obj then self.focus:blur() end
	self.focus = obj
	self:_primeKeys()
end

function Window:_bind(vk, mode, label, onFire, isActive)
	local b = { vk = vk, mode = mode or "Press", label = label, onFire = onFire, isActive = isActive,
		state = false, prevDown = false, pulse = 0 }
	self.binds[#self.binds + 1] = b
	return b
end

function Window:_checkConflict(b)
	if not b.vk then return end
	local other
	if b.vk == self.toggleKey then other = "the menu key" end
	for _, o in ipairs(self.binds) do
		if o ~= b and o.vk == b.vk then other = "\"" .. tostring(o.label) .. "\"" break end
	end
	if other then
		GhostUI.Notify({ Title = "Key already in use", Content = (KEYNAME[b.vk] or "That key") .. " is also bound to " .. other .. ".", Duration = 4 })
	end
end

local function newRow(col, e)
	local win = col.win
	e.tab, e.page, e.col, e.win, e.hov, e.draws = col.tab, col.page, col, win, 0, {}
	e.h = e.h or ROWH
	e.section = col.lastSection
	function e:d(kind, props)
		local dr = win:_d(kind, props)
		self.draws[#self.draws + 1] = dr
		return dr
	end
	e.bg = e:d("Square", { Filled = true, ZIndex = Z.row, Theme = "Row" })
	e.ol = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowLine, Theme = "RowBorder" })
	e.label = e:d("Text", { Text = e.name or "", ZIndex = Z.rowText, Theme = "Text" })
	if not e.height then e.height = function(self) return self.h end end
	col.elements[#col.elements + 1] = e
	if e.flag then win.elements[e.flag] = e end
	return e
end

local function drawRow(e, x, y, w, h, a, dt, hot, accent)
	local T = e.win.T
	e.hov = ease(e.hov, hot and 1 or 0, 14, dt)
	local fl = e.flashT and clamp(1 - (clock() - e.flashT) / 0.9) or 0
	local olc = mixT(T.RowBorder, T.RowBorderHover, e.hov)
	sqc(e.bg, x, y, w, h, a, mix(T.Row, T.RowHover, e.hov), 8)
	sqc(e.ol, x, y, w, h, a, mix(olc, T.Accent, max(accent or 0, fl * 0.9)), 8)
	tx(e.label, x + 14 + e.hov * 2, y + 11, 16, a)
end

local function drawField(win, box, ol, text, caret, st, focused, x, y, w, h, size, a, placeholder, fo)
	local T = win.T
	sq(box, x, y, w, h, a, nil, 6)
	sq(ol, x, y, w, h, a, mix(T.PillBorder, T.Accent, (fo or (focused and 1 or 0)) * 0.8), 6)
	local ty = y + (h - size) / 2 - 1
	if focused then
		local shown, cx = viewText(st, size, w - 20)
		tx(text, x + 9, ty, size, a, nil, shown)
		local blink = ((clock() - (st.blinkAt or 0)) % 1 < 0.55) and 1 or 0
		sq(caret, x + 10 + cx, ty, 1.5, size + 2, a * blink, nil, 0)
	else
		local empty = st.text == ""
		local shown = empty and (placeholder or "") or fitText(st.text, size, w - 20, true)
		tx(text, x + 9, ty, size, a * (empty and 0.35 or 1), nil, shown)
		caret.Visible = false
	end
end

function Tab:Section(name, o)
	o = o or {}
	local e = newRow(self, { h = 26, kind = "section", name = name, folded = o.Collapsed and true or false })
	e.section = nil
	e.fold = e.folded and 0 or 1
	e.text = e:d("Text", { Text = string.upper(name), ZIndex = Z.rowText, Theme = "Text" })
	e.line = e:d("Line", { Thickness = 1, ZIndex = Z.rowText, Theme = "Line" })
	e.ch1 = e:d("Line", { Thickness = 1.5, ZIndex = Z.rowText, Theme = "Text" })
	e.ch2 = e:d("Line", { Thickness = 1.5, ZIndex = Z.rowText, Theme = "Text" })
	e.tw = measure(string.upper(name), 12)
	self.lastSection = e
	function e:click() self.folded = not self.folded end
	function e:render(x, y, w, a, dt, hovered)
		hide(self.bg, self.ol, self.label)
		self.fold = ease(self.fold, self.folded and 0 or 1, 12, dt)
		self.hov = ease(self.hov, hovered and 1 or 0, 14, dt)
		local ta = a * (SUB + (1 - SUB) * self.hov)
		tx(self.text, x + 2, y + 9, 12, ta)
		ln(self.line, x + self.tw + 12, y + 15, x + w - 22, y + 15, a)
		local cx, cy, d = x + w - 8, y + 15, 2.5 * (2 * self.fold - 1)
		ln(self.ch1, cx - 4, cy - d, cx, cy + d, ta)
		ln(self.ch2, cx, cy + d, cx + 4, cy - d, ta)
	end
	return e
end

function Tab:Label(text)
	local e = newRow(self, { h = 22, kind = "label" })
	e.text = e:d("Text", { Text = text, ZIndex = Z.rowText, Theme = "Text" })
	function e:Set(t) self.text.Text = t end
	function e:render(x, y, w, a)
		hide(self.bg, self.ol, self.label)
		tx(self.text, x + 4, y + 4, 14, a * 0.7)
	end
	return e
end

function Tab:Stat(o)
	local e = newRow(self, { name = o.Name, kind = "stat", tip = o.Tip, prefix = o.Prefix or "", suffix = o.Suffix or "",
		dec = o.Decimals or 0 })
	e.valD = e:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" })
	e.value = o.Value or 0
	e.shownNum = type(e.value) == "number" and e.value or 0
	function e:Set(v) self.value = v end
	function e:Get() return self.value end
	function e:render(x, y, w, a, dt, hovered)
		drawRow(self, x, y, w, self.h, a, dt, hovered)
		local text
		if type(self.value) == "number" then
			self.shownNum = ease(self.shownNum, self.value, 8, dt)
			if abs(self.shownNum - self.value) < 10 ^ -(self.dec + 1) then self.shownNum = self.value end
			text = self.prefix .. commas(self.shownNum, self.dec) .. self.suffix
		else
			text = self.prefix .. tostring(self.value) .. self.suffix
		end
		if text ~= self.lastText then self.lastText = text self.tw = measure(text, 15) end
		tx(self.valD, x + w - 14 - self.tw, y + 12, 15, a * 0.85, nil, text)
	end
	return e
end

function Tab:Progress(o)
	local e = newRow(self, { name = o.Name, h = 52, kind = "progress", tip = o.Tip, maxV = o.Max or 100,
		suffix = o.Suffix, percent = o.Suffix == nil })
	e.value = clamp(o.Value or 0, 0, e.maxV)
	e.f = e.value / e.maxV
	e.valD = e:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" })
	e.track = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Track" })
	e.fill = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Accent" })
	e.shine = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Color = RGB(255, 255, 255) })
	function e:Set(v, maxV)
		if maxV then self.maxV = maxV end
		self.value = clamp(v, 0, self.maxV)
		self.changedAt = clock()
	end
	function e:Get() return self.value, self.maxV end
	function e:render(x, y, w, a, dt, hovered)
		drawRow(self, x, y, w, self.h, a, dt, hovered)
		self.f = ease(self.f, self.value / self.maxV, 10, dt)
		local text = self.percent and (floor(self.f * 100 + 0.5) .. "%")
			or (commas(self.value) .. " / " .. commas(self.maxV) .. (self.suffix ~= "" and (" " .. self.suffix) or ""))
		if text ~= self.lastText then self.lastText = text self.tw = measure(text, 15) end
		tx(self.valD, x + w - 14 - self.tw, y + 12, 15, a * (SUB + (1 - SUB) * self.hov), nil, text)
		local tX, tW, tY = x + 14, w - 28, y + 35
		sq(self.track, tX, tY, tW, 6, a, nil, 3)
		sq(self.fill, tX, tY, max(tW * self.f, 0.6), 6, a, nil, 3)
		local st = self.changedAt and (clock() - self.changedAt) / 0.6 or 1
		if st < 1 then
			local fw = tW * self.f
			local sw = 30
			sq(self.shine, tX + (fw - sw) * outCubic(st), tY, min(sw, fw), 6, a * 0.35 * (1 - st), nil, 3)
		else
			self.shine.Visible = false
		end
	end
	return e
end

function Tab:Toggle(o)
	local win = self.win
	local e = newRow(self, { name = o.Name, kind = "toggle", value = o.Default and true or false, default = o.Default and true or false,
		cb = o.Callback, flag = o.Flag or o.Name, tip = o.Tip })
	e.k = { x = e.value and 1 or 0, v = 0 }
	e.track = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Track" })
	e.knob = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "KnobOff" })
	win.Flags[e.flag] = e.value
	function e:Set(v)
		v = v and true or false
		if v == self.value then return end
		self.value = v
		win.Flags[self.flag] = v
		fire(self.cb, v)
	end
	function e:Get() return self.value end
	function e:ser() return self.value end
	function e:deser(v) self:Set(v) end
	function e:reset() self:Set(self.default) end
	if o.Keybind ~= nil then
		local dk = toVK(o.Keybind)
		e.bind = win:_bind(dk, "Toggle", o.Name, function() e:Set(not e.value) end, function() return e.value end)
		e.chip = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Field" })
		e.chipOl = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowText, Theme = "PillBorder" })
		e.chipT = e:d("Text", { Text = "", ZIndex = Z.rowTop, Theme = "Text" })
		e.cw = 30
		function e:SetKey(k, quiet)
			self.bind.vk = toVK(k)
			self.bind.prevDown = true
			if not quiet then win:_checkConflict(self.bind) end
		end
		win.elements[e.flag .. " key"] = {
			ser = function() return KEYNAME[e.bind.vk] or "NONE" end,
			deser = function(_, v) e:SetKey(v ~= "NONE" and v or nil, true) end,
		}
	end
	function e:chipRect()
		return self._x + self._w - 14 - 36 - 8 - self.cw, self._y + 10, self.cw, 20
	end
	function e:click(lx, ly)
		if self.chip then
			local cx, cy, cw, ch = self:chipRect()
			if inRect(lx, ly, cx - 2, cy - 2, cw + 4, ch + 4) then
				if win.listening == self then win.listening = nil else win.listening = self win:_primeKeys() end
				return
			end
		end
		self:Set(not self.value)
	end
	function e:render(x, y, w, a, dt, hovered)
		local T = win.T
		self._x, self._y, self._w = x, y, w
		drawRow(self, x, y, w, self.h, a, dt, hovered)
		local k = spring(self.k, self.value and 1 or 0, dt, 380, 24)
		local kc = clamp(k)
		local tw, th = 36, 20
		local tX, tY = x + w - tw - 14, y + (self.h - th) / 2
		sq(self.track, tX, tY, tw, th, a, mix(T.Track, T.Accent, kc), 10)
		local stretch = min(6, abs(self.k.v) * 0.6)
		local ks = 14
		local kx = tX + 3 + (tw - ks - 6) * k - (self.value and stretch or 0)
		sq(self.knob, kx, tY + 3, ks + stretch, ks, a, mix(T.KnobOff, T.KnobOn, kc), 7)
		if self.chip then
			local listening = win.listening == self
			local text = listening and "..." or (KEYNAME[self.bind.vk] or "-")
			if text ~= self.chipShown then self.chipShown = text self.chipW = measure(text, 12) end
			self.cw = ease(self.cw, self.chipW + 14, 16, dt)
			local cx, cy, cw, ch = self:chipRect()
			local pulse = listening and (0.55 + 0.45 * sin(clock() * 7)) or 0
			sq(self.chip, cx, cy, cw, ch, a, nil, 5)
			sq(self.chipOl, cx, cy, cw, ch, a, mix(T.PillBorder, T.Accent, pulse), 5)
			tx(self.chipT, cx + (cw - self.chipW) / 2, cy + 4, 12, a * (listening and 1 or SUB + (1 - SUB) * self.hov), nil, text)
		end
	end
	return e
end

function Tab:Slider(o)
	local win = self.win
	local minV, maxV = o.Min or 0, o.Max or 100
	local step = o.Step or 1
	local dec = 0
	if step < 1 then dec = math.ceil(-math.log10(step) - 1e-9) end
	local e = newRow(self, { name = o.Name, h = 52, kind = "slider", cb = o.Callback,
		flag = o.Flag or o.Name, suffix = o.Suffix or "", tip = o.Tip, closeOnSwitch = true })
	e.value = clamp(o.Default or minV, minV, maxV)
	e.default = e.value
	e.f = (e.value - minV) / (maxV - minV)
	e.grab = 0
	e.valD = e:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" })
	e.track = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Track" })
	e.fill = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Accent" })
	e.knob = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Accent" })
	e.eBox = e:d("Square", { Filled = true, ZIndex = Z.rowFx, Theme = "Field" })
	e.eOl = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowText, Theme = "PillBorder" })
	e.eText = e:d("Text", { Text = "", ZIndex = Z.rowTop, Theme = "Text" })
	e.eCaret = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Accent" })
	win.Flags[e.flag] = e.value
	local function num(v) return string.format("%." .. dec .. "f", v) end
	e.valText = num(e.value) .. e.suffix
	e.valW = measure(e.valText, 15)
	function e:Set(v)
		v = clamp(minV + floor((v - minV) / step + 0.5) * step, minV, maxV)
		if v == self.value then return end
		self.value = v
		self.valText = num(v) .. self.suffix
		self.valW = measure(self.valText, 15)
		win.Flags[self.flag] = v
		fire(self.cb, v)
	end
	function e:Get() return self.value end
	function e:ser() return self.value end
	function e:deser(v) if type(v) == "number" then self:Set(v) end end
	function e:reset() self:Set(self.default) end
	function e:valRect() return self._x + self._w - 14 - max(self.valW, 30) - 8, self._y + 6, max(self.valW, 30) + 16, 24 end
	function e:click(lx, ly)
		local vx, vy, vw, vh = self:valRect()
		if inRect(lx, ly, vx, vy, vw, vh) then
			if win.focus ~= self then
				self.st = newEdit(num(self.value))
				win:_focus(self)
			end
			return
		end
		win.dragging = self
		self:drag(lx)
	end
	function e:drag(lx)
		local tX, tW = self._x + 14, self._w - 28
		self:Set(minV + clamp((lx - tX) / tW) * (maxV - minV))
	end
	function e:key(k, shift, ctrl)
		if k.vk == 0x0D then
			local n = tonumber(self.st.text)
			if n then self:Set(n) end
			self:blur()
		elseif k.vk == 0x1B then
			self:blur()
		else
			editKey(self.st, k, false, ctrl, 16, "0123456789.-")
		end
	end
	function e:blur() if win.focus == self then win.focus = nil end end
	function e:render(x, y, w, a, dt, hovered)
		self._x, self._y, self._w = x, y, w
		local held = win.dragging == self
		local editing = win.focus == self
		drawRow(self, x, y, w, self.h, a, dt, hovered or held or editing)
		self.grab = ease(self.grab, held and 1 or 0, 18, dt)
		self.f = ease(self.f, (self.value - minV) / (maxV - minV), 22, dt)
		if editing then
			local tw = max(measure(self.st.text, 15), 30)
			local bw = tw + 22
			local bx = x + w - 14 - bw + 6
			drawField(win, self.eBox, self.eOl, self.eText, self.eCaret, self.st, true, bx, y + 6, bw, 24, 15, a, nil, 1)
			self.valD.Visible = false
		else
			hide(self.eBox, self.eOl, self.eText, self.eCaret)
			tx(self.valD, x + w - 14 - self.valW, y + 12, 15, a * (SUB + (1 - SUB) * max(self.hov, self.grab)), nil, self.valText)
		end
		local tX, tW, tY = x + 14, w - 28, y + 36
		sq(self.track, tX, tY, tW, 4, a, nil, 2)
		sq(self.fill, tX, tY, max(tW * self.f, 0.6), 4, a, nil, 2)
		local ks = 10 + self.hov * 2 + self.grab * 4
		sq(self.knob, tX + tW * self.f - ks / 2, tY + 2 - ks / 2, ks, ks, a, nil, ks / 2)
	end
	return e
end

function Tab:RangeSlider(o)
	local win = self.win
	local minV, maxV = o.Min or 0, o.Max or 100
	local step = o.Step or 1
	local dec = 0
	if step < 1 then dec = math.ceil(-math.log10(step) - 1e-9) end
	local e = newRow(self, { name = o.Name, h = 52, kind = "range", cb = o.Callback,
		flag = o.Flag or o.Name, suffix = o.Suffix or "", tip = o.Tip })
	local d0 = type(o.Default) == "table" and o.Default or { minV, maxV }
	e.lo, e.hi = clamp(d0[1] or minV, minV, maxV), clamp(d0[2] or maxV, minV, maxV)
	e.default = { e.lo, e.hi }
	e.flo, e.fhi = (e.lo - minV) / (maxV - minV), (e.hi - minV) / (maxV - minV)
	e.grab = 0
	e.valD = e:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" })
	e.track = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Track" })
	e.fill = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Accent" })
	e.k1 = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Accent" })
	e.k2 = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Accent" })
	local function fmt(v) return string.format("%." .. dec .. "f", v) end
	function e:_sync()
		self.valText = fmt(self.lo) .. " - " .. fmt(self.hi) .. self.suffix
		self.valW = measure(self.valText, 15)
		win.Flags[self.flag] = { self.lo, self.hi }
	end
	function e:Set(lo, hi)
		if type(lo) == "table" then lo, hi = lo[1], lo[2] end
		local function snap(v) return clamp(minV + floor((v - minV) / step + 0.5) * step, minV, maxV) end
		lo, hi = snap(lo), snap(hi)
		if lo > hi then lo, hi = hi, lo end
		if lo == self.lo and hi == self.hi then return end
		self.lo, self.hi = lo, hi
		self:_sync()
		fire(self.cb, lo, hi)
	end
	function e:Get() return self.lo, self.hi end
	function e:ser() return { self.lo, self.hi } end
	function e:deser(v) if type(v) == "table" then self:Set(v[1], v[2]) end end
	function e:reset() self:Set(self.default[1], self.default[2]) end
	function e:click(lx)
		local tX, tW = self._x + 14, self._w - 28
		local v = minV + clamp((lx - tX) / tW) * (maxV - minV)
		self.which = abs(v - self.lo) <= abs(v - self.hi) and 1 or 2
		if self.lo == self.hi then self.which = v < self.lo and 1 or 2 end
		win.dragging = self
		self:drag(lx)
	end
	function e:drag(lx)
		local tX, tW = self._x + 14, self._w - 28
		local v = minV + clamp((lx - tX) / tW) * (maxV - minV)
		if self.which == 1 then self:Set(min(v, self.hi), self.hi) else self:Set(self.lo, max(v, self.lo)) end
	end
	function e:render(x, y, w, a, dt, hovered)
		self._x, self._y, self._w = x, y, w
		local held = win.dragging == self
		drawRow(self, x, y, w, self.h, a, dt, hovered or held)
		self.grab = ease(self.grab, held and 1 or 0, 18, dt)
		self.flo = ease(self.flo, (self.lo - minV) / (maxV - minV), 22, dt)
		self.fhi = ease(self.fhi, (self.hi - minV) / (maxV - minV), 22, dt)
		tx(self.valD, x + w - 14 - self.valW, y + 12, 15, a * (SUB + (1 - SUB) * max(self.hov, self.grab)), nil, self.valText)
		local tX, tW, tY = x + 14, w - 28, y + 36
		sq(self.track, tX, tY, tW, 4, a, nil, 2)
		sq(self.fill, tX + tW * self.flo, tY, max(tW * (self.fhi - self.flo), 0.6), 4, a, nil, 2)
		for i, k in ipairs({ self.k1, self.k2 }) do
			local f = i == 1 and self.flo or self.fhi
			local ks = 10 + self.hov * 2 + ((held and self.which == i) and 4 or 0)
			sq(k, tX + tW * f - ks / 2, tY + 2 - ks / 2, ks, ks, a, nil, ks / 2)
		end
	end
	e:_sync()
	return e
end

function Tab:Button(o)
	local e = newRow(self, { name = o.Name, kind = "button", cb = o.Callback, flash = 0, tip = o.Tip,
		confirm = o.Confirm, confirmText = o.ConfirmText or "Click again to confirm" })
	e.arrow = e:d("Text", { Text = ">", ZIndex = Z.rowText, Theme = "Text" })
	e.sweep = e:d("Square", { Filled = true, ZIndex = Z.rowFx, Theme = "Accent" })
	function e:click(lx)
		self.flash = 1
		self.sweepT = clock()
		self.sweepX = lx - self._x
		if self.confirm and not self.armedAt then
			self.armedAt = clock()
			self.label.Text = self.confirmText
			return
		end
		self.armedAt = nil
		self.label.Text = self.name
		fire(self.cb)
	end
	function e:render(x, y, w, a, dt, hovered)
		self._x = x
		if self.armedAt and clock() - self.armedAt > 2.5 then self.armedAt = nil self.label.Text = self.name end
		self.flash = ease(self.flash, 0, 7, dt)
		local armed = self.armedAt and (0.5 + 0.5 * sin(clock() * 8)) or 0
		drawRow(self, x, y, w, self.h, a, dt, hovered, armed)
		self.sweep.Visible = false
		if self.sweepT then
			local t = (clock() - self.sweepT) / 0.45
			if t >= 1 then self.sweepT = nil else
				local r = outCubic(t) * w
				local l, rr = max(0, self.sweepX - r), min(w, self.sweepX + r)
				sq(self.sweep, x + l, y, rr - l, self.h, a * (1 - t) * 0.08, nil, 8)
			end
		end
		tx(self.arrow, x + w - 24 + self.hov * 3 + self.flash * 5, y + 11, 16, a * (SUB + (1 - SUB) * self.hov))
	end
	return e
end

function Tab:Dropdown(o)
	local win = self.win
	local e = newRow(self, { name = o.Name, kind = "dropdown", multi = o.Multi and true or false, cb = o.Callback,
		flag = o.Flag or o.Name, open = false, ex = 0, opts = {}, items = {}, filt = {}, tip = o.Tip,
		searchable = o.Search and true or false, st = newEdit(""), closeOnSwitch = true })
	e.valD = e:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" })
	e.ch1 = e:d("Line", { Thickness = 1.5, ZIndex = Z.rowText, Theme = "Text" })
	e.ch2 = e:d("Line", { Thickness = 1.5, ZIndex = Z.rowText, Theme = "Text" })
	e.sep = e:d("Line", { Thickness = 1, ZIndex = Z.rowLine, Theme = "RowBorder" })
	if e.searchable then
		e.sBox = e:d("Square", { Filled = true, ZIndex = Z.rowFx, Theme = "Field" })
		e.sOl = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowText, Theme = "PillBorder" })
		e.sText = e:d("Text", { Text = "", ZIndex = Z.rowTop, Theme = "Text" })
		e.sCaret = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Accent" })
	end
	if e.multi then
		e.value = {}
		for _, v in ipairs(type(o.Default) == "table" and o.Default or {}) do e.value[v] = true end
	else
		e.value = o.Default or (o.Options and o.Options[1])
	end
	e.default = e.multi and copy(e.value) or e.value
	function e:selectedList()
		if not self.multi then return self.value end
		local out = {}
		for _, v in ipairs(self.opts) do if self.value[v] then out[#out + 1] = v end end
		return out
	end
	function e:_sync()
		local list = self:selectedList()
		win.Flags[self.flag] = list
		if self.multi then
			self.display = #list > 0 and table.concat(list, ", ") or "None"
		else
			self.display = list ~= nil and tostring(list) or "None"
		end
		self.fitKey = nil
	end
	function e:_filter()
		self.filt = {}
		local q = string.lower(self.st.text)
		for i, v in ipairs(self.opts) do
			if q == "" or string.find(string.lower(tostring(v)), q, 1, true) then self.filt[#self.filt + 1] = i end
		end
		self.lastQuery = self.st.text
	end
	function e:Refresh(list)
		self.opts = list or {}
		for i = #self.items + 1, #self.opts do
			self.items[i] = {
				hl = self:d("Square", { Filled = true, ZIndex = Z.rowFx, Theme = "Option" }),
				text = self:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" }),
				dot = self:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Accent" }),
				hov = 0, sel = 0,
			}
		end
		if not self.multi and self.value ~= nil then
			local found = false
			for _, x in ipairs(self.opts) do if x == self.value then found = true end end
			if not found then self.value = nil end
		end
		self:_filter()
		self:_sync()
	end
	function e:isSel(v) if self.multi then return self.value[v] and true or false end return self.value == v end
	function e:Set(v)
		if self.multi then
			self.value = {}
			for _, x in ipairs(type(v) == "table" and v or { v }) do self.value[x] = true end
		else
			self.value = v
		end
		self:_sync()
		fire(self.cb, self:selectedList())
	end
	function e:Get() return self:selectedList() end
	function e:ser() return self:selectedList() end
	function e:deser(v) self:Set(v) end
	function e:reset()
		if self.multi then
			local l = {}
			for k in pairs(self.default) do l[#l + 1] = k end
			self:Set(l)
		else
			self:Set(self.default)
		end
	end
	function e:optTop() return ROWH + 4 + (self.searchable and SEARCHH or 0) end
	function e:height() return ROWH + self.ex * ((self.searchable and SEARCHH or 0) + #self.filt * OPTH + 8) end
	function e:setOpen(v)
		self.open = v
		if v then
			self.st = newEdit("")
			self:_filter()
			if self.searchable then win:_focus(self) end
		elseif win.focus == self then
			win.focus = nil
		end
	end
	function e:blur() if self.open then self:setOpen(false) end end
	function e:key(k, shift, ctrl)
		if k.vk == 0x1B then self:setOpen(false)
		elseif k.vk == 0x0D then
			local i = self.filt[1]
			if i then self:pick(self.opts[i]) end
		else
			editKey(self.st, k, shift, ctrl, 32)
			if self.st.text ~= self.lastQuery then self:_filter() end
		end
	end
	function e:pick(v)
		if self.multi then
			self.value[v] = not self.value[v] or nil
			self:_sync()
			fire(self.cb, self:selectedList())
		else
			self.value = v
			self:_sync()
			fire(self.cb, v)
			self:setOpen(false)
		end
	end
	function e:click(lx, ly)
		if ly < self._y + ROWH then self:setOpen(not self.open) return end
		if self.ex < 0.9 then return end
		local j = floor((ly - (self._y + self:optTop())) / OPTH) + 1
		local i = self.filt[j]
		if i then self:pick(self.opts[i]) end
	end
	function e:render(x, y, w, a, dt, hovered, lx, ly)
		self._x, self._y, self._w = x, y, w
		self.ex = ease(self.ex, self.open and 1 or 0, 14, dt)
		local h = self:height()
		drawRow(self, x, y, w, h, a, dt, (hovered and ly < y + ROWH) or self.open)
		local maxW = w * 0.5
		if self.fitKey ~= maxW then
			self.fitKey = maxW
			self.fitText = fitText(self.display, 15, maxW)
			self.fitW = measure(self.fitText, 15)
		end
		tx(self.valD, x + w - 34 - self.fitW, y + 12, 15, a * (SUB + (1 - SUB) * self.hov), nil, self.fitText)
		local cx, cy, d = x + w - 20, y + 20, 3 * (1 - 2 * self.ex)
		ln(self.ch1, cx - 5, cy - d, cx, cy + d, a)
		ln(self.ch2, cx, cy + d, cx + 5, cy - d, a)
		ln(self.sep, x + 1, y + ROWH, x + w - 1, y + ROWH, a * self.ex)
		if self.searchable then
			local sa = a * clamp((self.ex - 0.2) / 0.5)
			drawField(win, self.sBox, self.sOl, self.sText, self.sCaret, self.st, win.focus == self,
				x + 8, y + ROWH + 6, w - 16, SEARCHH - 8, 14, sa, "Search...", nil)
		end
		local top = y + self:optTop()
		for j, it in ipairs(self.items) do
			local i = self.filt[j]
			local v = i and self.opts[i]
			if v ~= nil then
				if it.shownText ~= v then it.shownText = v it.text.Text = tostring(v) end
				local oy = top + (j - 1) * OPTH
				local vis = self.ex > 0.01 and clamp(((y + h) - oy) / OPTH) or 0
				local oa = a * vis * clamp(self.ex * 1.5 - (j - 1) * 0.06)
				local oh = vis > 0 and hovered and inRect(lx, ly, x + 6, oy, w - 12, OPTH - 2)
				it.hov = ease(it.hov, oh and 1 or 0, 16, dt)
				it.sel = ease(it.sel, self:isSel(v) and 1 or 0, 16, dt)
				sq(it.hl, x + 6, oy, w - 12, OPTH - 2, oa * it.hov, nil, 6)
				tx(it.text, x + 18 + it.sel * 10, oy + 7, 15, oa * (SUB + (1 - SUB) * max(it.sel, it.hov)))
				local ds = 6 * it.sel
				sq(it.dot, x + 21 - ds / 2, oy + 14 - ds / 2, ds, ds, oa, nil, 3)
			else
				hide(it.hl, it.text, it.dot)
			end
		end
	end
	e:Refresh(o.Options or {})
	return e
end

function Tab:PlayerDropdown(o)
	local win = self.win
	local e = self:Dropdown({ Name = o.Name, Multi = o.Multi, Search = true, Options = {}, Flag = o.Flag,
		Callback = o.Callback, Tip = o.Tip })
	e.includeSelf = o.IncludeSelf
	e.lastList = ""
	win.playerDrops[#win.playerDrops + 1] = e
	win.playersAt = 0
	return e
end

function Window:_refreshPlayers()
	if #self.playerDrops == 0 then return end
	local names = {}
	local ok, list = pcall(function() return game:GetService("Players"):GetPlayers() end)
	if not ok or type(list) ~= "table" then return end
	local me = self.lp and self.lp.Name
	for _, p in ipairs(list) do
		local n = p.Name
		if n then names[#names + 1] = n end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	for _, e in ipairs(self.playerDrops) do
		local l = {}
		for _, n in ipairs(names) do if e.includeSelf or n ~= me then l[#l + 1] = n end end
		local key = table.concat(l, "\0")
		if key ~= e.lastList then e.lastList = key e:Refresh(l) end
	end
end

function Tab:Keybind(o)
	local win = self.win
	local e = newRow(self, { name = o.Name, kind = "keybind", cb = o.Callback, changed = o.Changed,
		flag = o.Flag or o.Name, tip = o.Tip, mode = o.Mode or "Press" })
	local vk = toVK(o.Default)
	e.default = vk
	e.bind = win:_bind(vk, e.mode, o.Name, function(state) fire(e.cb, state) end)
	e.box = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Field" })
	e.boxOl = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowText, Theme = "PillBorder" })
	e.keyT = e:d("Text", { Text = "", ZIndex = Z.rowTop, Theme = "Text" })
	e.modeT = e:d("Text", { Text = string.upper(e.mode), ZIndex = Z.rowText, Theme = "Text" })
	e.modeW = measure(string.upper(e.mode), 11)
	e.bw = 40
	win.Flags[e.flag] = KEYNAME[vk] or "NONE"
	function e:SetKey(k, quiet)
		self.bind.vk = toVK(k)
		self.bind.prevDown = true
		self.bind.state = false
		win.Flags[self.flag] = KEYNAME[self.bind.vk] or "NONE"
		if not quiet then win:_checkConflict(self.bind) end
		fire(self.changed, self.bind.vk, KEYNAME[self.bind.vk])
	end
	function e:Get() return self.bind.vk, KEYNAME[self.bind.vk] end
	function e:ser() return KEYNAME[self.bind.vk] or "NONE" end
	function e:deser(v) self:SetKey(v ~= "NONE" and v or nil, true) end
	function e:reset() self:SetKey(self.default, true) end
	function e:click()
		if win.listening == self then win.listening = nil return end
		win.listening = self
		win:_primeKeys()
	end
	function e:render(x, y, w, a, dt, hovered)
		local T = win.T
		local listening = win.listening == self
		drawRow(self, x, y, w, self.h, a, dt, hovered or listening)
		local text = listening and "..." or (KEYNAME[self.bind.vk] or "NONE")
		if text ~= self.shown then self.shown = text self.tw = measure(text, 13) end
		self.bw = ease(self.bw, self.tw + 20, 16, dt)
		local bx = x + w - 14 - self.bw
		local on = self.bind.state or (clock() - self.bind.pulse < 0.25)
		local pulse = listening and (0.55 + 0.45 * sin(clock() * 7)) or (on and 0.9 or self.hov * 0.25)
		sq(self.box, bx, y + 9, self.bw, 22, a, nil, 6)
		sq(self.boxOl, bx, y + 9, self.bw, 22, a, mix(T.PillBorder, T.Accent, pulse), 6)
		tx(self.keyT, bx + (self.bw - self.tw) / 2, y + 13, 13, a * (listening and 1 or 0.85), nil, text)
		tx(self.modeT, bx - 10 - self.modeW, y + 14, 11, a * 0.35)
	end
	return e
end

function Tab:ColorPicker(o)
	local win = self.win
	local PH = 112
	local e = newRow(self, { name = o.Name, kind = "color", cb = o.Callback, flag = o.Flag or o.Name, open = false, ex = 0, tip = o.Tip })
	local c = o.Default or RGB(255, 255, 255)
	e.default = c
	e.hh, e.ss, e.vv = rgbToHsv(c.R, c.G, c.B)
	e.hexT = e:d("Text", { Text = "", ZIndex = Z.rowText, Theme = "Text" })
	e.sw = e:d("Square", { Filled = true, ZIndex = Z.rowText, Color = c })
	e.swOl = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowTop, Theme = "PillBorder" })
	e.svBase = e:d("Square", { Filled = true, ZIndex = Z.rowFx, Color = RGB(255, 0, 0) })
	e.svImg = e:d("Image", { ZIndex = Z.rowText })
	e.hueImg = e:d("Image", { ZIndex = Z.rowText })
	e.svCur = e:d("Circle", { Filled = false, Thickness = 2, NumSides = 24, ZIndex = Z.rowTop, Color = RGB(255, 255, 255) })
	e.hueCur = e:d("Square", { Filled = false, Thickness = 2, ZIndex = Z.rowTop, Color = RGB(255, 255, 255) })
	local sv, hue = img("sv"), img("hue")
	if sv then e.svImg.Data = sv end
	if hue then e.hueImg.Data = hue end
	pcall(function() e.svImg.Rounding = 4 e.hueImg.Rounding = 4 end)
	function e:_sync(silent)
		self.value = Color3.fromHSV(self.hh, self.ss, self.vv)
		self.hex = toHex(self.value)
		self.hexW = measure(self.hex, 13)
		win.Flags[self.flag] = self.value
		if not silent then fire(self.cb, self.value) end
	end
	function e:Set(col)
		self.hh, self.ss, self.vv = rgbToHsv(col.R, col.G, col.B)
		self:_sync()
	end
	function e:Get() return self.value end
	function e:ser() return self.hex end
	function e:deser(v) local col = fromHex(v) if col then self:Set(col) end end
	function e:reset() self:Set(self.default) end
	function e:height() return ROWH + self.ex * PH end
	function e:rects()
		local x, y, w = self._x, self._y, self._w
		local py = y + ROWH + 4
		return x + 14, py, w - 28 - 30, 96, x + w - 14 - 18, py, 18, 96
	end
	function e:click(lx, ly)
		if ly < self._y + ROWH then self.open = not self.open return end
		if self.ex < 0.9 then return end
		local sx, sy, sw, sh, hx, hy, hw, hh = self:rects()
		if inRect(lx, ly, sx - 4, sy - 4, sw + 8, sh + 8) then self.mode = "sv"
		elseif inRect(lx, ly, hx - 4, hy - 4, hw + 8, hh + 8) then self.mode = "hue"
		else return end
		win.dragging = self
		self:drag(lx, ly)
	end
	function e:drag(lx, ly)
		local sx, sy, sw, sh, hx, hy, hw, hh = self:rects()
		if self.mode == "sv" then
			self.ss = clamp((lx - sx) / sw)
			self.vv = 1 - clamp((ly - sy) / sh)
		else
			self.hh = clamp((ly - hy) / hh) * 0.9999
		end
		self:_sync()
	end
	function e:render(x, y, w, a, dt, hovered, lx, ly)
		self._x, self._y, self._w = x, y, w
		self.ex = ease(self.ex, self.open and 1 or 0, 14, dt)
		drawRow(self, x, y, w, self:height(), a, dt, (hovered and ly < y + ROWH) or self.open)
		sq(self.sw, x + w - 14 - 30, y + 11, 30, 18, a, self.value, 5)
		sq(self.swOl, x + w - 14 - 30, y + 11, 30, 18, a, nil, 5)
		tx(self.hexT, x + w - 14 - 30 - 10 - self.hexW, y + 13, 13, a * (SUB + (1 - SUB) * self.hov), nil, self.hex)
		local pa = a * clamp((self.ex - 0.35) / 0.65)
		local sx, sy, sw, sh, hx, hy, hw, hh = self:rects()
		sq(self.svBase, sx, sy, sw, sh, pa, Color3.fromHSV(self.hh, 1, 1), 4)
		sq(self.svImg, sx, sy, sw, sh, pa)
		sq(self.hueImg, hx, hy, hw, hh, pa)
		cir(self.svCur, sx + self.ss * sw, sy + (1 - self.vv) * sh, 5, pa)
		sq(self.hueCur, hx - 2, hy + self.hh * hh - 2, hw + 4, 4, pa, nil, 2)
	end
	e:_sync(true)
	return e
end

function Tab:Textbox(o)
	local win = self.win
	local e = newRow(self, { name = o.Name, kind = "text", cb = o.Callback, flag = o.Flag or o.Name, tip = o.Tip,
		value = o.Default or "", placeholder = o.Placeholder or "Type here", maxLen = o.MaxLength or 64, fo = 0 })
	e.default = e.value
	e.st = newEdit(e.value)
	e.box = e:d("Square", { Filled = true, ZIndex = Z.rowText, Theme = "Field" })
	e.boxOl = e:d("Square", { Filled = false, Thickness = 1, ZIndex = Z.rowText, Theme = "PillBorder" })
	e.txt = e:d("Text", { Text = "", ZIndex = Z.rowTop, Theme = "Text" })
	e.caret = e:d("Square", { Filled = true, ZIndex = Z.rowTop, Theme = "Accent" })
	win.Flags[e.flag] = e.value
	function e:Set(v, silent)
		self.value = tostring(v or "")
		self.st = newEdit(self.value)
		win.Flags[self.flag] = self.value
		if not silent then fire(self.cb, self.value) end
	end
	function e:Get() return self.value end
	function e:ser() return self.value end
	function e:deser(v) self:Set(v) end
	function e:reset() self:Set(self.default) end
	function e:blur(cancel)
		if win.focus ~= self then return end
		win.focus = nil
		if cancel then self:Set(self.value, true) else self:Set(self.st.text) end
	end
	function e:key(k, shift, ctrl)
		if k.vk == 0x0D then self:blur()
		elseif k.vk == 0x1B then self:blur(true)
		else editKey(self.st, k, shift, ctrl, self.maxLen) end
	end
	function e:click()
		if win.focus ~= self then
			self.st = newEdit(self.value)
			win:_focus(self)
		end
	end
	function e:render(x, y, w, a, dt, hovered)
		local focused = win.focus == self
		drawRow(self, x, y, w, self.h, a, dt, hovered or focused)
		self.fo = ease(self.fo, focused and 1 or 0, 16, dt)
		local bw = min(220, w * 0.5)
		drawField(win, self.box, self.boxOl, self.txt, self.caret, self.st, focused,
			x + w - 14 - bw, y + 7, bw, 26, 14, a, self.placeholder, self.fo)
	end
	return e
end

local SB_W, SB_H, SR_W = 170, 26, 250
function Window:_makeSearch()
	local win = self
	local s = { st = newEdit(""), fo = 0, results = {}, rows = {}, ra = 0, closeOnSwitch = false }
	s.box = self:_d("Square", { Filled = true, ZIndex = Z.head, Theme = "Field" })
	s.ol = self:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.head, Theme = "PillBorder" })
	s.text = self:_d("Text", { Text = "", ZIndex = Z.head, Theme = "Text" })
	s.caret = self:_d("Square", { Filled = true, ZIndex = Z.head, Theme = "Accent" })
	s.pbg = self:_d("Square", { Filled = true, ZIndex = Z.pop, Theme = "Bg" })
	s.pol = self:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.pop, Theme = "PillBorder" })
	s.empty = self:_d("Text", { Text = "No matches", ZIndex = Z.popText, Theme = "Text" })
	for i = 1, 6 do
		s.rows[i] = { hl = self:_d("Square", { Filled = true, ZIndex = Z.pop, Theme = "Option" }),
			name = self:_d("Text", { Text = "", ZIndex = Z.popText, Theme = "Text" }),
			where = self:_d("Text", { Text = "", ZIndex = Z.popText, Theme = "Text" }), hov = 0 }
	end
	function s:update()
		self.results = {}
		self.lastQuery = self.st.text
		local q = string.lower(self.st.text)
		if q == "" then return end
		for _, tab in ipairs(win.tabs) do
			eachEl(tab, function(e)
				if #self.results < 6 and e.name and e.kind ~= "label" and string.find(string.lower(e.name), q, 1, true) then
					self.results[#self.results + 1] = e
				end
			end)
		end
		for i, e in ipairs(self.results) do
			local r = self.rows[i]
			r.name.Text = fitText(e.name, 14, SR_W - 110)
			local where = e.tab.name .. ((e.page ~= e.tab and e.page.name) and (" / " .. e.page.name) or "")
			r.where.Text = fitText(string.upper(where), 11, 90)
			r.whereW = measure(r.where.Text, 11)
		end
	end
	function s:key(k, shift, ctrl)
		if k.vk == 0x1B then self.st = newEdit("") self:update() self:blur()
		elseif k.vk == 0x0D then if self.results[1] then win:_jump(self.results[1]) end
		else
			editKey(self.st, k, shift, ctrl, 32)
			if self.st.text ~= self.lastQuery then self:update() end
		end
	end
	function s:blur() if win.focus == self then win.focus = nil end end
	return s
end

function Window:_jump(e)
	self:Select(e.tab)
	if e.page ~= e.tab then self:_setPage(e.tab, e.page) end
	if e.section then e.section.folded = false end
	self.jumpTo, self.jumpUntil = e, clock() + 0.45
	e.flashT = clock() + 0.15
	self.search.st = newEdit("")
	self.search:update()
	self.search:blur()
end

function Window:_makeDialog()
	local g = { a = 0, lines = {}, btns = {} }
	g.dim = self:_d("Square", { Filled = true, ZIndex = Z.dim, Theme = "Shade" })
	g.bg = self:_d("Square", { Filled = true, ZIndex = Z.dlg, Theme = "Bg" })
	g.ol = self:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.dlg, Theme = "PillBorder" })
	g.title = self:_d("Text", { Text = "", ZIndex = Z.dlgText, Theme = "Text" })
	for i = 1, 6 do g.lines[i] = self:_d("Text", { Text = "", ZIndex = Z.dlgText, Theme = "Text" }) end
	for i = 1, 3 do
		g.btns[i] = { bg = self:_d("Square", { Filled = true, ZIndex = Z.dlg, Theme = "Row" }),
			ol = self:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.dlgText, Theme = "PillBorder" }),
			text = self:_d("Text", { Text = "", ZIndex = Z.dlgText, Theme = "Text" }), hov = 0 }
	end
	self.dlg = g
end

function Window:Dialog(o)
	o = o or {}
	local g = self.dlg
	local buttons = o.Buttons or { { Name = "OK", Primary = true } }
	g.cur = { title = o.Title or "Are you sure?", buttons = {} }
	g.title.Text = g.cur.title
	local lines = wrap(o.Content or "", 14, 300)
	g.n = min(#lines, #g.lines)
	for i, d in ipairs(g.lines) do d.Text = lines[i] or "" end
	for i = 1, min(#buttons, 3) do
		local b = buttons[i]
		g.cur.buttons[i] = { name = b.Name or "OK", cb = b.Callback, primary = b.Primary, w = measure(b.Name or "OK", 14) + 32 }
		g.btns[i].text.Text = b.Name or "OK"
	end
	g.openAt = clock()
	g.closing = false
	self.mini = false
	if not self.visible then self:SetVisible(true) end
	if self.focus then self.focus:blur() end
	self.listening = nil
end

function Window:_closeDialog(btn)
	local g = self.dlg
	if not g.cur or g.closing then return end
	g.closing = true
	if btn and btn.cb then fire(btn.cb) end
end

function Window:_makePanel(title, y)
	local p = { title = title, x = nil, y = y, w = 210, h = 34, rows = {}, pool = {}, a = 0, anchor = nil, dragged = false }
	p.bg = self:_d("Square", { Filled = true, ZIndex = Z.panel, Theme = "Bg" })
	p.ol = self:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.panel, Theme = "Border" })
	p.titleT = self:_d("Text", { Text = title, ZIndex = Z.panelText, Theme = "Text" })
	p.line = self:_d("Line", { Thickness = 1, ZIndex = Z.panelText, Theme = "Line" })
	p.none = self:_d("Text", { Text = "None", ZIndex = Z.panelText, Theme = "Text" })
	return p
end

function Window:_panelRow(p, id)
	local r = p.pool[id]
	if r then return r end
	for _, x in pairs(p.pool) do
		if x.free then x.free = false p.pool[x.id] = nil x.id = id p.pool[id] = x x.a = 0 x.y = nil return x end
	end
	self._ovMode = true
	r = { id = id, a = 0,
		left = self:_d("Text", { Text = "", ZIndex = Z.panelText, Theme = "Text" }),
		right = self:_d("Text", { Text = "", ZIndex = Z.panelText, Theme = "Text" }),
		dot = self:_d("Square", { Filled = true, ZIndex = Z.panelText, Theme = "Accent" }) }
	self._ovMode = false
	p.pool[id] = r
	return r
end

function Window:_drawPanel(p, rows, show, dt, interactive, mx, my, clicked, down)
	local vp = self.vp
	if not p.x then p.x = vp.X - 16 - p.w end
	if p.anchor and not p.dragged then
		p.y = (p.anchor.a > 0.05 and (p.anchor.y + p.anchor.h + 10) or p.anchor.y)
	end
	local want = #rows > 0 or (self.visible and self.o > 0.5)
	p.a = ease(p.a, (show and want) and 1 or 0, 12, dt)
	local th = 34 + max(#rows, 1) * 22 + 6
	p.h = ease(p.h, th, 14, dt)
	local a = p.a
	local over = interactive and inRect(mx, my, p.x, p.y, p.w, p.h) and a > 0.5
	if over and clicked and my <= p.y + 30 and not self.dragPanel then
		self.dragPanel = { p, mx - p.x, my - p.y }
	end
	if self.dragPanel and self.dragPanel[1] == p and down then
		p.x = clamp(mx - self.dragPanel[2], 0, vp.X - p.w)
		p.y = clamp(my - self.dragPanel[3], 0, vp.Y - 40)
		p.dragged = true
	end
	sq(p.bg, p.x, p.y, p.w, p.h, a, nil, 10)
	sq(p.ol, p.x, p.y, p.w, p.h, a, nil, 10)
	tx(p.titleT, p.x + 12, p.y + 10, 12, a * SUB)
	ln(p.line, p.x + 1, p.y + 30, p.x + p.w - 1, p.y + 30, a)
	tx(p.none, p.x + 12, p.y + 38, 14, a * (#rows == 0 and 0.35 or 0))
	local seen = {}
	for i, row in ipairs(rows) do
		local r = self:_panelRow(p, row.id)
		seen[row.id] = true
		local ty = p.y + 36 + (i - 1) * 22
		r.y = r.y and ease(r.y, ty, 16, dt) or ty
		r.a = ease(r.a, 1, 14, dt)
		local ra = a * r.a * clamp(((p.y + p.h) - r.y - 4) / 18)
		r.lit = ease(r.lit or 0, row.lit and 1 or 0, 14, dt)
		if r.leftText ~= row.left then r.leftText = row.left r.left.Text = fitText(row.left, 14, p.w - 90) end
		if r.rightText ~= row.right then r.rightText = row.right r.rightW = measure(row.right, 12) end
		local ds = 5 * r.lit
		sq(r.dot, p.x + 14 - ds / 2, r.y + 9 - ds / 2, ds, ds, ra, nil, 2.5)
		tx(r.left, p.x + 14 + r.lit * 10, r.y + 2, 14, ra * (0.55 + 0.45 * r.lit))
		tx(r.right, p.x + p.w - 12 - r.rightW, r.y + 3, 12, ra * (0.35 + 0.4 * r.lit), nil, row.right)
	end
	for id, r in pairs(p.pool) do
		if not seen[id] then
			r.a = ease(r.a, 0, 18, dt)
			if r.a < 0.02 then r.free = true hide(r.left, r.right, r.dot)
			else
				local ra = a * r.a
				tx(r.left, p.x + 14, r.y + 2, 14, ra * 0.55)
				tx(r.right, p.x + p.w - 12 - (r.rightW or 0), r.y + 3, 12, ra * 0.35)
				r.dot.Visible = false
			end
		end
	end
	return over
end

function Window:_makeWatermark()
	local wm = { a = 0, text = "", tw = 0, nextAt = 0 }
	wm.bg = self:_d("Square", { Filled = true, ZIndex = Z.panel, Theme = "Bg" })
	wm.ol = self:_d("Square", { Filled = false, Thickness = 1, ZIndex = Z.panel, Theme = "Border" })
	wm.icon = self:_d("Image", { ZIndex = Z.panelText })
	wm.textD = self:_d("Text", { Text = "", ZIndex = Z.panelText, Theme = "Text" })
	wm.accent = self:_d("Square", { Filled = true, ZIndex = Z.panelText, Theme = "Accent" })
	local w = img("ghost_white")
	if w then wm.icon.Data = w end
	return wm
end

function Window:_drawWatermark(dt, now)
	local wm = self.wm
	wm.a = ease(wm.a, self.overlay.Watermark and 1 or 0, 10, dt)
	if now >= wm.nextAt then
		wm.nextAt = now + 0.5
		local ping = "?"
		pcall(function()
			local p = GetPingValue()
			if type(p) == "number" then ping = tostring(floor((p < 5 and p * 1000 or p) + 0.5)) end
		end)
		local t = ""
		pcall(function() t = os.date("%H:%M") end)
		wm.text = self.title .. "   " .. floor(self.fps + 0.5) .. " FPS   " .. ping .. " MS" .. (t ~= "" and ("   " .. t) or "")
		wm.textD.Text = wm.text
		wm.tw = measure(wm.text, 13)
	end
	local w = 40 + wm.tw + 14
	local x, y = self.vp.X - 16 - w, 16
	local a = wm.a
	sq(wm.bg, x, y, w, 30, a, nil, 8)
	sq(wm.ol, x, y, w, 30, a, nil, 8)
	sq(wm.accent, x + 1, y + 8, 2, 14, a, nil, 1)
	sq(wm.icon, x + 12, y + 7, 16, 16 * (236 / 243), a)
	tx(wm.textD, x + 36, y + 9, 13, a * 0.85)
end

function Window:_keys(now)
	if self.dlg.cur and not self.dlg.closing then
		for _, vk in ipairs({ 0x1B, 0x0D }) do
			local d = iskeypressed(vk)
			if d and not self.keyPrev[vk] then
				if vk == 0x1B then self:_closeDialog(nil)
				else
					for _, b in ipairs(self.dlg.cur.buttons) do if b.primary then self:_closeDialog(b) break end end
				end
			end
			self.keyPrev[vk] = d
		end
		return
	end
	if self.focus then
		local f = self.focus
		local shift = iskeypressed(0x10) or iskeypressed(0xA0) or iskeypressed(0xA1)
		local ctrl = iskeypressed(0x11) or iskeypressed(0xA2) or iskeypressed(0xA3)
		for _, k in ipairs(KEYS) do
			if k.ch or EDITVK[k.vk] then
				local d = iskeypressed(k.vk)
				if d then
					local go = false
					if not self.keyPrev[k.vk] then
						go = true
						self.keyRep[k.vk] = now + 0.42
					elseif now >= (self.keyRep[k.vk] or 1e9) then
						go = true
						self.keyRep[k.vk] = now + 0.035
					end
					if go and self.focus == f then f:key(k, shift, ctrl) end
				end
				self.keyPrev[k.vk] = d
			end
		end
		return
	end
	if self.listening then
		for _, k in ipairs(KEYS) do
			local d = iskeypressed(k.vk)
			if d and not self.keyPrev[k.vk] then
				local e = self.listening
				self.listening = nil
				e:SetKey(k.vk ~= 0x1B and k.vk or nil)
				self:_primeKeys()
				self.keyDown = true
				return
			end
			self.keyPrev[k.vk] = d
		end
		return
	end
	local kd = iskeypressed(self.toggleKey)
	if kd and not self.keyDown then self:Toggle() end
	self.keyDown = kd
	for _, b in ipairs(self.binds) do
		if b.vk then
			local d = iskeypressed(b.vk)
			if d ~= b.prevDown then
				if b.mode == "Hold" then
					if d or b.state then
						b.state = d
						b.onFire(d)
					end
				elseif d then
					if b.mode == "Toggle" then
						b.state = not b.state
						b.onFire(b.state)
					else
						b.pulse = now
						b.onFire()
					end
				end
			end
			b.prevDown = d
		end
	end
end

function Window:_frame(dt)
	local now = clock()
	dt = type(dt) == "number" and dt or (now - self.lastT)
	self.lastT = now
	if dt > 0 then self.fps = ease(self.fps, 1 / dt, 4, dt) end
	dt = clamp(dt, 0, 1 / 30)
	local T = self.T
	local W, H = self.W, self.H

	if now - self.activeAt > 0.25 then
		self.activeAt = now
		local ok, act = pcall(isrbxactive)
		self.active = not ok or act and true or false
	end
	if self.active then self:_keys(now) end
	self:_themeStep(now)
	if #self.playerDrops > 0 and now >= (self.playersAt or 0) then self.playersAt = now + 2 self:_refreshPlayers() end

	local mx, my = 0, 0
	if self.mouse then mx, my = self.mouse.X or 0, self.mouse.Y or 0 end
	local down = self.active and ismouse1pressed() or false
	local down2 = self.active and ismouse2pressed() or false
	local clicked = down and not self.m1
	local rclicked = down2 and not self.m2
	local released = self.m1 and not down
	self.m1, self.m2 = down, down2
	if released then self.dragging, self.dragWin, self.dragScroll, self.dragPanel, self.resizing = nil, nil, nil, nil, nil end

	OX, OY, SC, CT, CB = 0, 0, 1, nil, nil
	local menuOn = self.visible and self.o > 0.85
	self:_drawWatermark(dt, now)
	local actRows, kbRows = {}, {}
	for flag, e in pairs(self.elements) do
		if e.kind == "toggle" and e.value then actRows[#actRows + 1] = { id = flag, left = e.name, right = e.bind and KEYNAME[e.bind.vk] or "", lit = true } end
	end
	table.sort(actRows, function(a, b) return a.left < b.left end)
	for i, b in ipairs(self.binds) do
		if b.vk then
			local lit = b.isActive and b.isActive() or b.state or (now - b.pulse < 0.3)
			kbRows[#kbRows + 1] = { id = tostring(i), left = b.label, right = (KEYNAME[b.vk] or "?") .. (b.mode ~= "Press" and (" " .. string.upper(b.mode)) or ""), lit = lit }
		end
	end
	local overPanel = self:_drawPanel(self.panels.Active, actRows, self.overlay.Active, dt, menuOn, mx, my, clicked, down)
	overPanel = self:_drawPanel(self.panels.Keybinds, kbRows, self.overlay.Keybinds, dt, menuOn, mx, my, clicked and not overPanel, down) or overPanel
	if overPanel and clicked then clicked = false end

	self.o = ease(self.o, self.visible and 1 or 0, self.visible and 10 or 16, dt)
	local s = spring(self.sc, self.visible and 1 or 0.95, dt, 200, 18)
	if not self.visible and self.o < 0.01 then
		self:_setGameInput(true)
		if not self._hidden then
			self._hidden = true
			for _, d in ipairs(self.winDraws) do d.Visible = false end
		end
		return
	end
	self._hidden = false
	local gA = clamp(self.o)

	local g, gc = 1, 1
	if self.growAt then
		local gt = now - self.growAt
		g = outCubic(gt / 0.5)
		gc = clamp((gt - 0.28) / 0.3)
		if gt > 0.8 then self.growAt = nil end
	end

	self.mm = ease(self.mm, self.mini and 1 or 0, 10, dt)
	local mm = outCubic(self.mm)
	local DH = lerp(H, HEADER_H + 2, mm)
	local body = 1 - clamp(self.mm * 1.6)

	self.x = ease(self.x, self.tx, 28, dt)
	self.y = ease(self.y, self.ty, 28, dt)
	if abs(1 - s) < 0.003 and abs(self.sc.v) < 0.05 then s = 1 end
	local cx, cy = self.x + W / 2, self.y + H / 2
	OX, OY, SC = floor(cx - W / 2 * s + 0.5), floor(cy - H / 2 * s + 0.5), s
	CT, CB = nil, nil

	local lx, ly = (mx - OX) / s, (my - OY) / s
	local dlg = self.dlg
	local dlgOpen = dlg.cur ~= nil
	local interactive = self.visible and self.o > 0.85 and gc > 0.9
	local inside = inRect(lx, ly, 0, 0, W, DH)
	self:_setGameInput(not (self.visible and self.active and
		(inside or overPanel or dlgOpen or self.dragging or self.dragWin or self.dragScroll or self.dragPanel or self.resizing
			or self.focus or self.listening)))
	local uiOK = interactive and not dlgOpen

	local sideHot = uiOK and body > 0.9 and inRect(lx, ly, 0, 0, self.SWc + (self.SWo - self.SWc) * self.sideOpen, DH)
	if sideHot then self.sideHoverAt = now end
	self.sideOpen = ease(self.sideOpen, (now - self.sideHoverAt < 0.25) and 1 or 0, 5, dt)
	local so = outCubic(self.sideOpen)
	local SW = floor(lerp(self.SWc, self.SWo, so) + 0.5)

	local gw, gh = lerp(LOADER_BOX, W, g), lerp(LOADER_BOX, DH, g)
	local gx, gy = (W - gw) / 2, (DH - gh) / 2
	local corner = lerp(24, 12, g)
	sq(self.bg, gx, gy, gw, gh, gA, self.growAt and mix(LOADER_BG, T.Bg, g) or nil, corner)
	sq(self.border, gx, gy, gw, gh, gA * gc, nil, corner)
	local ia = gA * gc
	sq(self.side, 0, 0, SW, DH, ia, nil, 12)
	sq(self.sidePatch, SW - 12, 0, 12, DH, ia, nil, 0)
	ln(self.divider, SW, 0, SW, DH, ia)

	local openT = now - self.openAt
	local hA = gA * outCubic((openT - 0.05) / 0.35)
	local gs = lerp(LOADER_BOX * 0.62, 26, g)
	local gxp = lerp(W / 2 - gs / 2, 16, g)
	local gyp = lerp(DH / 2 - gs / 2, 16 + sin(now * 3.2) * 1.5, g)
	if self.growAt then
		sq(self.ghost, gxp, gyp, gs, gs * (236 / 243), gA * clamp(g * 1.4 - 0.3))
		sq(self.ghostB, gxp, gyp, gs, gs * (236 / 243), gA * (1 - clamp(g * 1.4 - 0.3)))
	else
		self.ghostB.Visible = false
		sq(self.ghost, 16, 16 + sin(now * 3.2) * 1.5, 26, 26 * (236 / 243), gA)
	end
	tx(self.titleD, 50 - (1 - max(so, mm)) * 12, 21, 18, hA * max(so, mm))
	tx(self.hint, 18, DH - 26, 12, gA * SUB * 0.7 * so * body * outCubic((openT - 0.5) / 0.4))

	local hoverTab
	for i, tab in ipairs(self.tabs) do
		local ty = TAB_Y + (i - 1) * TAB_STEP
		local hov = uiOK and body > 0.9 and inRect(lx, ly, 10, ty, SW - 20, TAB_H)
		if hov then hoverTab = tab end
		local sel = self.selected == tab
		tab.shift = ease(tab.shift, sel and 10 or (hov and 4 or 0), 16, dt)
		tab.lit = ease(tab.lit or 0, (sel or hov) and 1 or 0, 14, dt)
		local ta = ia * body * outCubic((openT - 0.12 - i * 0.05) / 0.3)
		local la = ta * (SUB + (1 - SUB) * tab.lit)
		local lxp = 22 + tab.shift - (1 - ta) * 14
		if tab.icon then
			sq(tab.icon, lxp, ty + 9, 16, 16, la)
			lxp = lxp + 24
		end
		tx(tab.label, lxp, ty + 9, 16, la)
		if hov and clicked then self:Select(tab) end
	end
	if hoverTab and hoverTab ~= self.selected then self.hoverTab = hoverTab end
	self.hoverAmt = ease(self.hoverAmt, (hoverTab and hoverTab ~= self.selected) and 1 or 0, 16, dt)
	if self.hoverTab then
		sq(self.tabHover, 10, TAB_Y + (self.hoverTab.i - 1) * TAB_STEP, SW - 20, TAB_H, ia * body * self.hoverAmt, nil, 8)
	end
	if self.selected then
		local iy = spring(self.ind, TAB_Y + (self.selected.i - 1) * TAB_STEP, dt, 260, 20)
		local stretch = min(6, abs(self.ind.v) * 0.01)
		local pa = ia * body * outCubic((openT - 0.1) / 0.3)
		sq(self.pill, 10, iy - stretch / 2, SW - 20, TAB_H + stretch, pa, nil, 8)
		sq(self.pillOl, 10, iy - stretch / 2, SW - 20, TAB_H + stretch, pa, nil, 8)
		self.barH = ease(self.barH, 14, 12, dt)
		sq(self.bar, 16, iy + (TAB_H - self.barH) / 2, 3, self.barH, pa, nil, 1.5)
	end

	local mbx, mby = W - 16 - 26, 16
	local minHot = uiOK and inRect(lx, ly, mbx, mby, 26, 26)
	self.minHov = ease(self.minHov, minHot and 1 or 0, 16, dt)
	sq(self.minBox, mbx, mby, 26, 26, ia, nil, 6)
	sq(self.minOl, mbx, mby, 26, 26, ia, mix(T.PillBorder, T.Accent, self.minHov * 0.6), 6)
	ln(self.minH, mbx + 8, mby + 13, mbx + 18, mby + 13, ia * (0.6 + 0.4 * self.minHov))
	ln(self.minV, mbx + 13, mby + 13 - 5 * mm, mbx + 13, mby + 13 + 5 * mm, ia * mm * (0.6 + 0.4 * self.minHov))

	local srch = self.search
	local sbx, sby = mbx - 8 - SB_W, 16
	local sfoc = self.focus == srch
	local sHot = uiOK and inRect(lx, ly, sbx, sby, SB_W, SB_H)
	srch.fo = ease(srch.fo, sfoc and 1 or (sHot and 0.35 or 0), 16, dt)
	drawField(self, srch.box, srch.ol, srch.text, srch.caret, srch.st, sfoc, sbx, sby, SB_W, SB_H, 14, ia, "Search", srch.fo)
	local showRes = sfoc and srch.st.text ~= ""
	srch.ra = ease(srch.ra, showRes and 1 or 0, 16, dt)
	local nres = #srch.results
	local rx, ry = mbx + 26 - SR_W, sby + SB_H + 6
	local rh = max(nres, 1) * 30 + 8
	local hitRes
	sq(srch.pbg, rx, ry, SR_W, rh * (0.85 + 0.15 * srch.ra), ia * srch.ra, nil, 8)
	sq(srch.pol, rx, ry, SR_W, rh * (0.85 + 0.15 * srch.ra), ia * srch.ra, nil, 8)
	tx(srch.empty, rx + 12, ry + 11, 14, ia * srch.ra * (nres == 0 and 0.35 or 0))
	for i, r in ipairs(srch.rows) do
		local e = srch.results[i]
		if e and srch.ra > 0.01 then
			local oy = ry + 4 + (i - 1) * 30
			local h = uiOK and inRect(lx, ly, rx + 4, oy, SR_W - 8, 28)
			if h then hitRes = e end
			r.hov = ease(r.hov, h and 1 or 0, 16, dt)
			local ra = ia * srch.ra
			sq(r.hl, rx + 4, oy, SR_W - 8, 28, ra * r.hov, nil, 6)
			tx(r.name, rx + 12 + r.hov * 3, oy + 7, 14, ra)
			tx(r.where, rx + SR_W - 12 - (r.whereW or 0), oy + 9, 11, ra * 0.4)
		else
			hide(r.hl, r.name, r.where)
		end
	end
	local popOver = srch.ra > 0.5 and inRect(lx, ly, rx, ry, SR_W, rh)

	local x0 = SW + 20
	local cw = W - x0 - 24
	local hitEl, grabbedBar, hitSub
	local busy = self.dragWin or self.dragScroll or self.resizing or popOver or not uiOK or body < 0.9
	for _, tab in ipairs(self.tabs) do
		local sel = self.selected == tab
		local leaving = tab.leaveAt and not sel
		if sel or leaving then
			local la = 1
			if leaving then
				la = 1 - clamp((now - tab.leaveAt) / 0.12)
				if la <= 0 then tab.leaveAt = nil hideTab(tab) end
			end
			if la > 0 then
				local since = now - tab.selAt
				local hA2 = (sel and outCubic((since - 0.05) / 0.3) or la) * gc * body
				tx(tab.head, x0 + 2 - (1 - hA2) * 14, 18, 24, gA * hA2)
				ln(tab.headLine, x0, 54, x0 + (W - 16 - x0) * (sel and outCubic((since - 0.05) / 0.45) or 1), 54, gA * hA2)

				local clipTop = 66
				if tab.subs then
					local sx, subY = x0, 66
					local tot = 8
					for _, pg in ipairs(tab.pages) do tot = tot + pg.tw + 28 end
					sq(tab.subBg, sx, subY, tot, SUB_H, gA * hA2, nil, 8)
					sq(tab.subOl, sx, subY, tot, SUB_H, gA * hA2, nil, 8)
					local px = sx + 4
					for _, pg in ipairs(tab.pages) do
						local pw = pg.tw + 28
						local hov = sel and uiOK and not busy and inRect(lx, ly, px, subY, pw, SUB_H)
						if hov then hitSub = { tab, pg } end
						local cur = tab.cur == pg
						if cur then
							if tab.subX.x == 0 then tab.subX.x, tab.subW.x = px, pw end
							spring(tab.subX, px, dt, 300, 24)
							spring(tab.subW, pw, dt, 300, 24)
						end
						pg.lit = ease(pg.lit, (cur or hov) and 1 or 0, 14, dt)
						tx(pg.text, px + 14, subY + 7, 14, gA * hA2 * (SUB + (1 - SUB) * pg.lit))
						px = px + pw
					end
					sq(tab.subPill, tab.subX.x, subY + 3, tab.subW.x, SUB_H - 6, gA * hA2, nil, 6)
					sq(tab.subPillOl, tab.subX.x, subY + 3, tab.subW.x, SUB_H - 6, gA * hA2, nil, 6)
					clipTop = subY + SUB_H + 10
				end
				local clipBot = DH - 12

				local pg = tab.cur
				local ncol = #pg.cols
				local colW = ncol > 1 and (cw - 12) / 2 or cw
				local total = 0
				local layouts = {}
				for ci, col in ipairs(pg.cols) do
					local y = 0
					local lay = {}
					for i, e in ipairs(col.elements) do
						local f = e.section and outCubic(e.section.fold) or 1
						local eh = e:height()
						lay[i] = { e = e, y = y, h = eh, f = f }
						e._ly = y
						y = y + (eh + GAP) * f
					end
					layouts[ci] = lay
					total = max(total, y)
				end
				local view = max(1, clipBot - clipTop)
				local maxScroll = max(0, total - GAP - view)
				if sel and self.jumpTo and self.jumpTo.tab == tab and self.jumpTo.page == pg then
					pg.scrollT = self.jumpTo._ly - 12
					if now > self.jumpUntil then self.jumpTo = nil end
				end
				pg.scrollT = clamp(pg.scrollT, 0, maxScroll)
				pg.scroll = ease(pg.scroll, pg.scrollT, 16, dt)

				CT, CB = clipTop, clipBot
				local inClip = ly >= clipTop and ly <= clipBot and lx > SW
				local pageSince = now - max(tab.selAt, tab.pageAt or 0)
				for ci, lay in ipairs(layouts) do
					local cxp = x0 + (ci - 1) * (colW + 12)
					for i, L in ipairs(lay) do
						local e = L.e
						local ea, dy
						if sel then
							ea = outCubic((pageSince - 0.07 - i * 0.03) / 0.28)
							dy = (1 - ea) * 12
						else
							ea, dy = la, -(1 - la) * 6
						end
						local fa = clamp((L.f - 0.4) / 0.6)
						local ey = clipTop - pg.scroll + L.y + dy
						local hovered = sel and inClip and ea > 0.9 and L.f > 0.95 and not busy
							and (not self.dragging or self.dragging == e)
							and inRect(lx, ly, cxp, ey, colW, L.h)
						if hovered then hitEl = e end
						local ra = gA * ea * gc * body * (e.kind == "section" and 1 or fa)
						if ra > 0.001 then
							e:render(cxp, ey, colW, ra, dt, hovered, lx, ly)
						else
							for _, d in ipairs(e.draws) do d.Visible = false end
						end
					end
				end
				CT, CB = nil, nil

				if sel then
					if maxScroll > 0 and body > 0.05 then
						local bh = max(30, view * view / (total - GAP))
						local by = clipTop + (view - bh) * (pg.scroll / maxScroll)
						local onBar = uiOK and inRect(lx, ly, W - 20, clipTop, 20, view)
						if onBar and clicked then
							if ly < by or ly > by + bh then
								pg.scrollT = clamp((ly - clipTop - bh / 2) / (view - bh)) * maxScroll
							end
							self.dragScroll = { ly, pg.scrollT }
							grabbedBar = true
							hitEl = nil
						end
						if self.dragScroll and down then
							pg.scrollT = clamp(self.dragScroll[2] + (ly - self.dragScroll[1]) * maxScroll / (view - bh), 0, maxScroll)
						end
						self.barHov = ease(self.barHov or 0, (onBar or self.dragScroll) and 1 or 0, 14, dt)
						local bw = 3 + self.barHov * 2
						sq(self.scrollbar, W - 11 - bw / 2, by, bw, bh, gA * gc * body, mix(T.Track, T.KnobOff, self.barHov), bw / 2)
					else
						self.scrollbar.Visible = false
					end
				end
			end
		end
	end

	local gripHot = uiOK and body > 0.9 and inRect(lx, ly, W - 18, DH - 18, 18, 18)
	self.gripHov = ease(self.gripHov or 0, (gripHot or self.resizing) and 1 or 0, 14, dt)
	local gcol = mix(T.RowBorderHover, T.Accent, self.gripHov * 0.7)
	ln(self.grip1, W - 14, DH - 6, W - 6, DH - 14, ia * body, gcol)
	ln(self.grip2, W - 10, DH - 6, W - 6, DH - 10, ia * body, gcol)
	if gripHot and clicked then
		self.resizing = { mx, my, W, H }
		clicked = false
	end
	if self.resizing and down then
		local r = self.resizing
		self.W = clamp(r[3] + (mx - r[1]) / s, 580, self.vp.X - 40)
		self.H = clamp(r[4] + (my - r[2]) / s, 380, self.vp.Y - 40)
	end

	local tip = self.tip
	local tipEl = (hitEl and hitEl.tip and not down) and hitEl or nil
	if tipEl ~= tip.el then
		tip.el, tip.since = tipEl, now
		if tipEl then
			local lines = wrap(tipEl.tip, 13, 220)
			tip.n = min(#lines, #tip.lines)
			tip.w = 0
			for i, d in ipairs(tip.lines) do
				d.Text = lines[i] or ""
				if lines[i] then tip.w = max(tip.w, measure(lines[i], 13)) end
			end
		end
	end
	tip.a = ease(tip.a, (tip.el and now - tip.since > 0.45) and 1 or 0, 14, dt)
	if tip.a > 0.01 and tip.n then
		OX, OY, SC = 0, 0, 1
		local tw, th = tip.w + 20, tip.n * 17 + 12
		local tpx = clamp(mx + 16, 4, self.vp.X - tw - 4)
		local tpy = clamp(my + 20, 4, self.vp.Y - th - 4)
		tip.x = tip.x and ease(tip.x, tpx, 20, dt) or tpx
		tip.y = tip.y and ease(tip.y, tpy, 20, dt) or tpy
		sq(tip.bg, tip.x, tip.y + (1 - tip.a) * 4, tw, th, tip.a, nil, 6)
		sq(tip.ol, tip.x, tip.y + (1 - tip.a) * 4, tw, th, tip.a, nil, 6)
		for i, d in ipairs(tip.lines) do
			if i <= tip.n then tx(d, tip.x + 10, tip.y + 7 + (i - 1) * 17 + (1 - tip.a) * 4, 13, tip.a * 0.85)
			else d.Visible = false end
		end
		OX, OY, SC = floor(cx - W / 2 * s + 0.5), floor(cy - H / 2 * s + 0.5), s
	else
		hide(tip.bg, tip.ol)
		for _, d in ipairs(tip.lines) do d.Visible = false end
		if not tip.el then tip.x, tip.y = nil, nil end
	end

	local hitBtn
	if dlgOpen then
		if not dlg.closing then dlg.a = ease(dlg.a, 1, 14, dt) else
			dlg.a = ease(dlg.a, 0, 18, dt)
			if dlg.a < 0.02 then
				dlg.cur = nil
				hide(dlg.dim, dlg.bg, dlg.ol, dlg.title)
				for _, d in ipairs(dlg.lines) do d.Visible = false end
				for _, b in ipairs(dlg.btns) do hide(b.bg, b.ol, b.text) end
			end
		end
		if dlg.cur then
			local a = dlg.a * gA
			local sc2 = 0.94 + 0.06 * outCubic(dlg.a)
			local bw = 340
			local bh = 20 + 22 + 10 + dlg.n * 18 + 20 + 32 + 16
			local dw, dh = bw * sc2, bh * sc2
			local dx, dy = W / 2 - dw / 2, DH / 2 - dh / 2
			sq(dlg.dim, 0, 0, W, DH, a * 0.6, nil, 12)
			sq(dlg.bg, dx, dy, dw, dh, a, nil, 10)
			sq(dlg.ol, dx, dy, dw, dh, a, nil, 10)
			tx(dlg.title, dx + 20, dy + 20, 18, a)
			for i, d in ipairs(dlg.lines) do
				if i <= dlg.n then tx(d, dx + 20, dy + 52 + (i - 1) * 18, 14, a * 0.7) else d.Visible = false end
			end
			local bxp = dx + dw - 20
			local byp = dy + dh - 16 - 32
			for i = #dlg.btns, 1, -1 do
				local b, info = dlg.btns[i], dlg.cur.buttons[i]
				if info then
					bxp = bxp - info.w
					local hov = interactive and not dlg.closing and inRect(lx, ly, bxp, byp, info.w, 32)
					if hov then hitBtn = info end
					b.hov = ease(b.hov, hov and 1 or 0, 16, dt)
					local fillC = info.primary and mix(T.Accent, T.Text, b.hov * 0.2) or mix(T.Row, T.RowHover, b.hov)
					sq(b.bg, bxp, byp, info.w, 32, a, fillC, 8)
					sq(b.ol, bxp, byp, info.w, 32, a, info.primary and rgb(T.Accent) or mix(T.PillBorder, T.RowBorderHover, b.hov), 8)
					tx(b.text, bxp + 16, byp + 8, 14, a, info.primary and rgb(T.KnobOn) or rgb(T.Text))
					bxp = bxp - 8
				else
					hide(b.bg, b.ol, b.text)
				end
			end
		end
	end

	if clicked and interactive then
		if dlgOpen then
			if hitBtn then self:_closeDialog(hitBtn) end
		elseif grabbedBar then
		elseif minHot then
			self.mini = not self.mini
			if self.focus then self.focus:blur() end
		elseif hitRes then
			self:_jump(hitRes)
		elseif sHot then
			if not sfoc then srch.st = newEdit(srch.st.text) self:_focus(srch) end
		elseif hitSub then
			self:_setPage(hitSub[1], hitSub[2])
		else
			if self.focus and hitEl ~= self.focus then self.focus:blur() end
			if self.listening and hitEl ~= self.listening then self.listening = nil end
			for _, tab in ipairs(self.tabs) do
				eachEl(tab, function(e)
					if e.kind == "dropdown" and e.open and e ~= hitEl then e:setOpen(false) end
				end)
			end
			if hitEl and hitEl.click then hitEl:click(lx, ly) end
			if not hitEl and not hoverTab and inRect(lx, ly, 0, 0, W, HEADER_H) then
				self.dragWin = { mx - self.tx, my - self.ty }
			end
		end
	end
	if rclicked and uiOK and hitEl and hitEl.reset then
		hitEl:reset()
		hitEl.flashT = now
	end
	if self.dragging and down and self.dragging.drag then self.dragging:drag(lx, ly) end
	if self.dragWin and down then
		self.tx, self.ty = mx - self.dragWin[1], my - self.dragWin[2]
	end
end

local NW, NPAD, NMAX, NGAP = 300, 12, 6, 8
local NZ = 520
local notifs = {}
local nConn, nMouse, nLast

local function nRemove(n)
	for _, d in ipairs(n.draws) do pcall(function() d.Visible = false d:Remove() end) end
end

local function nFrame(dt)
	local now = clock()
	dt = type(dt) == "number" and dt or (now - (nLast or now))
	nLast = now
	dt = clamp(dt, 0, 1 / 30)
	OX, OY, SC, CT, CB = 0, 0, 1, nil, nil
	local mx, my = 0, 0
	if nMouse then mx, my = nMouse.X or 0, nMouse.Y or 0 end
	local T = GhostUI.ActiveTheme
	local y = 16
	local i = 1
	while i <= #notifs do
		local n = notifs[i]
		if not n.exitAt then
			n.ty = y
			y = y + n.h + NGAP
		end
		if n.y == nil then n.y = n.ty end
		n.y = ease(n.y, n.ty, 14, dt)
		local hovered = inRect(mx, my, 16 + n.xs.x, n.y, NW, n.h)
		if not n.exitAt then
			if not hovered then n.left = n.left - dt end
			if n.left <= 0 then n.exitAt = now end
		end
		local xo = spring(n.xs, 0, dt, 220, 22)
		local a = outCubic((now - n.born) / 0.25)
		if n.exitAt then
			local t = clamp((now - n.exitAt) / 0.3)
			a = 1 - t
			xo = xo - t * t * (NW + 30)
			if t >= 1 then
				nRemove(n)
				table.remove(notifs, i)
				i = i - 1
			end
		end
		if notifs[i] == n then
			local x = 16 + xo
			local ny = n.y
			n.hov = ease(n.hov, hovered and 1 or 0, 14, dt)
			sq(n.bg, x, ny, NW, n.h, a, rgb(T.Bg), 10)
			sq(n.ol, x, ny, NW, n.h, a, mix(T.Border, T.RowBorderHover, n.hov), 10)
			sq(n.icon, x + NPAD, ny + 11, 18, 18 * (236 / 243), a)
			tx(n.title, x + 38, ny + 12, 16, a, rgb(T.Text))
			for li, d in ipairs(n.lines) do
				tx(d, x + 38, ny + 34 + (li - 1) * 18, 14, a * 0.7, rgb(T.Text))
			end
			n.shown = ease(n.shown, clamp(n.left / n.dur), 20, dt)
			local bw = NW - NPAD * 2
			sq(n.barBg, x + NPAD, ny + n.h - 8, bw, 2, a, rgb(T.Track), 1)
			sq(n.bar, x + NPAD, ny + n.h - 8, bw * n.shown, 2, a * (0.6 + 0.4 * n.hov), rgb(T.Accent), 1)
		end
		i = i + 1
	end
	if #notifs == 0 and nConn then
		nConn:Disconnect()
		nConn = nil
	end
end

function GhostUI.Notify(o)
	o = type(o) == "table" and o or { Content = tostring(o) }
	local n = { draws = {}, dur = max(0.5, o.Duration or 4), born = clock(), hov = 0, shown = 1,
		xs = { x = -(NW + 30), v = 0 } }
	n.left = n.dur
	local function d(kind, props)
		local dr = Drawing.new(kind)
		if kind == "Text" then dr.Font = FONT dr.Outline = false end
		for k, v in pairs(props) do dr[k] = v end
		dr.Visible = false
		n.draws[#n.draws + 1] = dr
		return dr
	end
	n.bg = d("Square", { Filled = true, ZIndex = NZ })
	n.ol = d("Square", { Filled = false, Thickness = 1, ZIndex = NZ + 1 })
	n.icon = d("Image", { ZIndex = NZ + 2 })
	local icon = img("ghost_white")
	if icon then n.icon.Data = icon end
	n.title = d("Text", { Text = tostring(o.Title or "Notification"), ZIndex = NZ + 2 })
	n.lines = {}
	local content = o.Content or o.Text
	if content and content ~= "" then
		for _, line in ipairs(wrap(content, 14, NW - 38 - NPAD)) do
			n.lines[#n.lines + 1] = d("Text", { Text = line, ZIndex = NZ + 2 })
		end
	end
	n.barBg = d("Square", { Filled = true, ZIndex = NZ + 1 })
	n.bar = d("Square", { Filled = true, ZIndex = NZ + 2 })
	n.h = 34 + #n.lines * 18 + (#n.lines > 0 and 10 or 0) + 4
	table.insert(notifs, n)
	local live = 0
	for j = #notifs, 1, -1 do
		if not notifs[j].exitAt then
			live = live + 1
			if live > NMAX then notifs[j].exitAt = clock() end
		end
	end
	if not nConn then
		local lp = game:GetService("Players").LocalPlayer
		nMouse = nMouse or (lp and lp:GetMouse())
		nLast = clock()
		local rs = game:GetService("RunService")
		nConn = (rs.RenderStepped or rs.Heartbeat):Connect(function(dt)
			local ok, err = pcall(nFrame, dt)
			if not ok then warn("[GhostUI] notify: " .. tostring(err)) end
		end)
	end
	local handle = {}
	function handle:Dismiss() if not n.exitAt then n.exitAt = clock() end end
	return handle
end

function Window:Notify(o) return GhostUI.Notify(o) end

ASSETS["ghost"] = "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"
ASSETS["ghost_white"] = "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"
ASSETS["sv"] = "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"
ASSETS["hue"] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAEACAYAAAC6UvZOAAAAmElEQVR42u3asQlDMRBEwRUY91+vObjfwFe0DkcFTKDocezZZFO8T74JAAAAAAAAAADwb+DsdKV6ZsvU/aX8AwAAAAAAAAAA4K1U05ZqytoGAAAAAAAAAAAupTrdUTazZeqWtQ0AAAAAAAAAALyXaspSLQcQAAAAAAAAAADAZehalurZTLs/6GobAAAAAAAAAAC4lGq3lH0AheaYtwJjIjUAAAAASUVORK5CYII="
ASSETS["home"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACOklEQVR42u2XvW8TQRDF35ztWCiKgIIG0YTSoqJBQAMoVWqEFJGI0NOEP4E/gJKOygilo6RDoqKipCQNUEUukGVI8MePZlYa1o5zti8fBdPcnnd25s2bt7tn6b8tYIABxVklL8K4dibJgQZw1cf100pe9+c14B3wA7h3KiBC8lXgK//aZmoHYCeZ/D6wx7gNgZ3UosrE6Uqv+XgzS/oK2AB+hd/alYkzU/pLrzJV+yTMtbKWfABWF9JFqPoC0A7Be6HfdaARdPEl+O0BrblAZGI7NmhZsLMmb2Vim0prmXb5DinKgNgAuiH5mzLCygS7lQn2dfSbeKYDl4AXYVEHeDrr1gos3gQ+h3jvgRuRiRSwMLORpAeSbknalfRJ0oGku8AdSZTdtmY2AC5K2pZ0KOmbpLfushXyTg20HpA/LiukRC9wOeigfZR/fcLipqSBpBWveuhV5ILLq8DMhvFd0r6kK5KaDr4u6Y+zPQ7AzAAGTuFIkrmPZX4jSaMSHak5UDymYvIxACUsXcM7km47O4UD7El6Zma9WQLOCiAxsSZpfcL8cwdyYgCSdV0nA6fZJP0su1OqAFCEtQnAXDdfWQBFUjEwzEUZRRe2aq1KAF0zS5QLOJx0BJhZJ7x3AKoAgKQ1YFlSQ1Jf0vVMlJK0BGwHES5LWlrk0+sh0Ad+M9n6wMCfaZzbgc/tHnWSTmOg6fP1Bdhr+nNllhak4/SjpEfegnm/ctPa71ns82N2zK1W1V+uUX4HnBv7C4/c1BNbCBsGAAAAAElFTkSuQmCC"
ASSETS["sword"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABgElEQVR42u2XsUoDQRCGdy93IgqWCtrok/gMNlYGOzXG57EKokY0eQo7nyB1GsFeRFFz8bPwXxwPFYTdO0QXlhm45f6bf/7bmXHury2g1SR41iR4LrsBLMn3KQF9oBsoZHeAa2BBz30y8GrOgU3e1oVlJEsB7r1Hftd7PwX2nXNDHSnrov1UEV8Cx8AIuAPaloFU4H2BP8geArPACrAYXYBfgD8BJTAFDpIK7htwgK0gxujK/wF40WTk/+C/EDwAVa7U+sAbjdz4HQOe10n7PHCkl5+Y52kFZ6Ls6uX3sj3ttGo3DMypegE8875K46f51cJdrd0DXhT1REXl1pTTKOAfGhI1EoXs1DnndQbZkfe+r3SVKS6a0Ltti+qJoT2k4yx0uLErWybbNoILub+S/yg7APJoPb6iaQF7Ju8AY2C98huWQEfns1gf0FJEA0P5GFirdLbnwG70IUOqDykYAjfAatBFNddJJpwAAswAy5/NcUpVuvGqUguameNsOupYr1saj92xPG5QAAAAAElFTkSuQmCC"
ASSETS["eye"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACs0lEQVR42u2Wu2tUURDGv9lsYnYLNQZiQFOkiKBgoY2VNiZ2FjaKlY0Woils/B9sBK2sBLEwkkawCCgqQtRCS4UENT7wQSAYExM1+/pZOFcm13uTjdhlB5a9nDvnm+/M4ztXalnL1rvZWpyBxL+Qs7cuSWbGfyPgQQu/ca3WJNE2x26YWeOfCABJ0HpY65BUlrRbUq8kAkZV0rikipnNpw8QcVYlABQS5sAWSUOSDkvaK6lHUncO71lJPyU9djJjZjYZy7dqefzkAgaAy8A02VYFav5fBeoZPovAXWAwjZ9Za6DozyeAhRTYF+AhMAI887WG/wA+ADeAUeBzBplrQDnVzH81joCrqY13gKPA1kBu0U+dBK95BkbcZzNwALgEzAesF0AvUFiWiRD8WHB+BRxMkez3wITgBBIAw6k9A56ZxG7GmEnqC8Am4J2f5D3QnzgCne533kEqGSmuOaknQAfQnpTUcUYD6aE/JELdjwSwM762wf8Tn1sOUs0gkIB/A7oy+qoPmHO/pFTF2JHl8PzJa5QWkYXVNEjSj9S+uqd7VlLF10oKkpo4P5X03UHOmlnDzKp+gqRrb/tz1izX/N24pHmg3fGLLkKnXD9M0r30BCRpuhhSeh0oBZ92oAt4ndEHtaADQ0AxdrlPzpK/nwBK3neWbsROYDIATwDDQHcA2wm8zNCBOnA6yjYw6EIUbX+cAstQqG2SLkg6HpI0LemRp3dK0pKkYUmDktokPZd0RdJbl+pDkvZI2hUwpiSdNLMHUerzrlv5ySdyZPirZ6HiE/EReJPjO+eSvn3Z/K90FyREgLKr4EiOvObZDHAfOAfsSAtes9dxMd7/wEZPa4+kfZL6AgY+YmM+SeNmNpMK3Mi6Ca2Jj5E2SeTd503sXfGjxNYIWGhyT30tn2Uta9n6tl+Adf3molfDcgAAAABJRU5ErkJggg=="
ASSETS["gear"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAADh0lEQVR42tWXO4tdVRTH/+ueM5OnTgKCEqKJoFYWIoqkiuBnSCxMP2lS2Fn7EWxszQxMohbRIoUQghZxLPwAIiSNIQQkOIjEzJzHz8L/gTXbc84dxUIXbNa9Z+/12Ou9Q/8AgEpS5G8R0er/CLHkpgtJRAT+HxEBcE7SaUmYRyPpZkQ0/5pmFj78DuPa+CZ/hZP57MAj8xmDxZSPI6IHTgGrvnUk//8mqZX0u/EjSQsrGMPZiOjNZ3FgBSy8A85K+l7SZj4bEZ2F1mktIuJRRLQR0Q+uBbaAdSuxcmCzA2eAe8m8G/6+ArwD3AV6oPP+E+AGcCW5YiPRXyrdOiocCOAF4KEJGy+A68B3iWnPODwEthN953UZqCaVsPAFsGZhJOFdIXhMeOtFQZMvUDuGJq2QI3gzMR5wVwgdU6YvaAA2s5WXxUEMWgLXCob5du2EUArhd+aELwrBtaRKUgWsSjrriM6EmK6S9KukHe9XkvqCdyfpVeAtf6ssJw6SEeeLm2S//uSIfxY46cy4PRIvg/8/Xup34DRwAbhofKdQoLOp7wMvTvD6vKAZYmTH2XXCCh/LREN5fY95aMxs3ecPD+Z0fQhfYicpm2NkB/gZ+AX4ZJCdc3LXFe6JcV/4vbbPP3Mu70YEXo2kKiLuS7qd/J+b3pqkZySdkPT0sFH/zU7ZS9qzQlPweOJ7k0r43lgvOOTNw8ZRKNNJOi7pDbfneqSEH5H05kSfWZF0xHifBQZTfSPpooUh6QNJr3u/Skw+lHQ+IpohfiR1EdECVyS9km6a4Ut3z1rSdnLtZHZcLlIpR/c14KV09ijwfqr9fXH+1lI/Ox3zrHdU0g+SnkuTzxAHC9/mK/v2NUkvj/BvzfOCpC9swdZTVjfblPz725FiNPafiXLdAz86ZZdOR6XwjZFmVOZ2k8zOSMUcGtjVsYY3Ooq5Zc6142ZmFmiLypnxdbf6fU2pNAleXydft8bbzoh6ZpquvO6apk8F7W0XI2an8eSCS+lmQz8/B3zkkloOKbvALeBd4KliJLsHnFk6liUlVozXga00DQ/7z7u2A+xZgRsjfD4FHnjA1ew0NPcuyPOC4+S4rdAAj423fOZQsuIqcGpO+GQvyPO853uAznjVjSXzWEtner+i9iQ9ABZTeV/Pvtv+nPHHYFfSVUnHUtndV17TYyZm+PzHH6dLYqS03nR5nYE/APQf4tqXtG/nAAAAAElFTkSuQmCC"
ASSETS["user"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACMUlEQVR42s2Xz2oUQRDGv5oxa4wHIYIiiLiCT5CD5uBBRLwYwYPoIeITePEhPOozKHgT0YtHBZW8wx6iYBAERfEgSLIzPy/V0MxOJu32DGtB00z1n6+6uuqrHmnBYvMsAgpJRVNtZtXgFjv4fmM2qAeA0swq4Lyk65Iu+NAXSa/M7F0wwszo++SHvL8L/KZdngQvzeONzpN7v9kA/AF8a+ieAqU36xP8sgNUQA08AE4Aq8AVYDsy4nHstWzXAwa8iAy41zJvDOz4+C/g+LyBORPVwDHgq5/8retG4a6Bw667Hxl5M8ULqS4qfK5J+uzXgpnVDlK57lM0f5S6cYrUkqaSkHTGCceiaC9dN47m7/aWfguLgf8iCxbOA0MzYU4t2GjUgpeD1oIQUMCoY3ypq1pmeSCcPvo+ImklpJ2Z/WwSWIoXLLH+Y2YAq5KuSrohaU3SSZ+2J+m9pA+SXpvZpM3orMeHp913DpY/wDPgdFYqBnAnmDcRwBTYi/ggtKAPsgPcmcuIqMicAz76hrsOlCKxIZsxl6RGegEsA5MI/F+lcq8AXEo2IiKcRxng8XXhB1k5kKACfQLr0Z3W5Em4jodt8dAkDfPcvSWp9PKby+eF73PbHy5VlwGVM92Gf5c9EGjh74OzktacT8qZFxFQmFkNjCWdcnIxX5wrU8dal7QVe7Vo8cZFSUclLfmiPtqy99e63oSBtyeSnvtdlT3VsbDXVgNr8WL7PMXLgfBm/qD/AmTMC/1P0z5NAAAAAElFTkSuQmCC"
ASSETS["bolt"] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACBElEQVR42sWXP2sUURTFz52dIOwHcCubBVNb2KQSS0EEwcYioH4CC6uUlgZSiaWCNgE7G20t/QRiQCy00MZKiMnOzs/C8+Sx7JrZtzubC5c3zMx99995Z+5IaxIgdF6SnAODZW2rNTgfRATAE0kXN1oNoPb6EHgPREkVVnW+w195md/v23nlbEfAEdACd0sCqAoBN7DtU0mXJSHpeFOl3/J64NJPgV9A/wDM+r4LNMCJg/gIDN2W6Mv5wOs2MHHfTx3A61IAVl1BJ6kFRpLe2g5JKduvpYnVS4CuNejGkhrbtn7tg7OvgbnbRMR0XaBLZSfDwZXSCsRZoIuIBrgj6dAZ1zN2p5LeuCXzJGW+FxFfgCoi2q5kUwFj4LtBN6VMnnuvujPZWGvgU1buRdL4ZCRtgN9+dpizZ1fnla9feJPjGQeT7CjOk6n1s+n6356dyMbRPi4sd2udANtnzQnxH8a75ecx572UzSNJVw3OxA2Nr+9HxKsE5L7Y8VtW8vyIHuRHuJh63Y5ZveD1usGWwDlJtGzbrV6+C9kH6V7muBh0q8yE11JMxkgr6UZE/JDUjWxKhhHrMOOHE7dht/eRLBu/Rx5CpmsD3ZL9v5k57xd0CwLYN9kcLc10qwZgZ++c/bj0j2iV/g+Bn8CDjf0HzMyEt4FnGwHdggpcchWqc/0jXpf8AYZNcLD7oveCAAAAAElFTkSuQmCC"

_G.GhostUI = GhostUI
return GhostUI
