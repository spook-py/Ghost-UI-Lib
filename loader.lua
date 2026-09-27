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

@@ASSETS@@

_G.GhostUI = GhostUI
return GhostUI

