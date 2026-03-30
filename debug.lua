print("TotemTender: loading debug.lua")

-- Get the addon table WoW passes via ...
local ADDON_NAME, ADDON = ...
local TotemTender       = ADDON
_G.TotemTender          = TotemTender -- ensure global points to the same table

TotemTender.Debug       = TotemTender.Debug or {}
local Debug             = TotemTender.Debug

-- ----------------------------------------------------------------------
-- Settings / State
-- ----------------------------------------------------------------------
Debug.enabled           = Debug.enabled or false
Debug.paused            = Debug.paused or false
Debug.filters           = Debug.filters or {
  event = true,  -- ambient events / world nudges
  tick  = false, -- per-tick diagnostics (might be really busy)
  state = true,  -- state changes (summon/dismiss, toggles)
  ui    = true,  -- UI notes
  err   = true,  -- errors/warnings
}

local COLOR             = {
  event = { 0.60, 1.00, 0.60 },
  tick  = { 0.80, 0.80, 1.00 },
  state = { 1.00, 0.90, 0.50 },
  ui    = { 0.80, 1.00, 1.00 },
  err   = { 1.00, 0.30, 0.30 },
}

-- ----------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------
local function safe(func, ...)
  -- Run a function in pcall; print a red error to chat if it fails.
  local ok, r1, r2, r3 = pcall(func, ...)
  if not ok then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555TotemTender Debug UI error:|r " .. tostring(r1))
    else
      print("|cffff5555TotemTender Debug UI error:|r " .. tostring(r1))
    end
    if Debug and Debug.Add then Debug:Error(tostring(r1)) end
  end
  return ok, r1, r2, r3
end

function Debug:Info(text) self:Add("state", text) end

-- ----------------------------------------------------------------------
-- UI 
-- ----------------------------------------------------------------------
function Debug:EnsureUI()
  if self.frame then return end

  -- Frame
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local ok, f = safe(CreateFrame, "Frame", "TotemTenderDebugFrame", UIParent, template)
  if not ok then return end

  f:SetSize(420, 240)
  f:SetPoint("CENTER", UIParent, "CENTER", 360, 140)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetResizable(true)

  -- Resize bounds: Dragonflight uses SetResizeBounds; some Classic builds lack SetMinResize
  if f.SetResizeBounds then
    f:SetResizeBounds(300, 180, 1200, 900)
  elseif f.SetMinResize then
    f:SetMinResize(300, 180)
    if f.SetMaxResize then f:SetMaxResize(1200, 900) end
  end

  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets   = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.90)
  end

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", 10, -8)
  title:SetText("TotemTender Debug")

  -- Close
  local okClose, close = safe(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
  if okClose then
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() Debug:Hide() end)
  end

  -- Scrolling log
  local okMsg, msg = safe(CreateFrame, "ScrollingMessageFrame", nil, f)
  if not okMsg then return end
  msg:SetPoint("TOPLEFT", 8, -28)
  msg:SetPoint("BOTTOMRIGHT", -8, 36)
  msg:SetFontObject(GameFontHighlightSmall)
  msg:SetJustifyH("LEFT")
  msg:SetFading(false)
  msg:SetMaxLines(1000)
  msg:EnableMouseWheel(true)
  msg:SetScript("OnMouseWheel", function(_, delta)
    if delta > 0 then msg:ScrollUp() else msg:ScrollDown() end
  end)

  -- Buttons
  local function MakeButton(text, x, onClick)
    local okBtn, b = safe(CreateFrame, "Button", nil, f, "UIPanelButtonTemplate")
    if not okBtn then return nil end
    b:SetText(text)
    b:SetSize(60, 20)
    b:SetPoint("BOTTOMLEFT", x, 8)
    b:SetScript("OnClick", onClick)
    return b
  end

  MakeButton("Clear", 8, function() msg:Clear() end)

  local pauseBtn = MakeButton("Pause", 74, function()
    Debug.paused = not Debug.paused
    if pauseBtn and pauseBtn.SetText then
      pauseBtn:SetText(Debug.paused and "Resume" or "Pause")
    end
    Debug:Info(Debug.paused and "Paused logging" or "Resumed logging")
  end)

  -- Filter checkboxes
  local function MakeCheck(label, x, key, color)
    local okCB, cb = safe(CreateFrame, "CheckButton", nil, f, "UICheckButtonTemplate")
    if not okCB then return end
    cb:SetPoint("BOTTOMLEFT", x, 6)
    cb:SetChecked(Debug.filters[key])

    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end

    -- Make label clickable
    cb:SetHitRectInsets(0, -fs:GetStringWidth() - 6, 0, 0)
    fs:EnableMouse(true)
    fs:SetScript("OnMouseUp", function() cb:Click() end)

    cb:SetScript("OnClick", function(self)
      Debug.filters[key] = self:GetChecked() and true or false
      Debug:Info(("Filter '%s' %s"):format(key, Debug.filters[key] and "ON" or "OFF"))
    end)
  end

  MakeCheck("Events", 142, "event", COLOR.event)
  MakeCheck("Tick", 220, "tick", COLOR.tick)
  MakeCheck("State", 282, "state", COLOR.state)

  -- Resize handle
  local okRH, rh = safe(CreateFrame, "Button", nil, f)
  if okRH then
    rh:SetPoint("BOTTOMRIGHT", -2, 2)
    rh:SetSize(16, 16)
    rh:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    rh:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    rh:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rh:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    rh:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
  end

  self.frame, self.msg = f, msg
end

function Debug:Show()
  self.enabled = true
  local ok = safe(function() self:EnsureUI() end)
  if not ok then
    self.enabled = false
    return
  end
  self.frame:Show()
end

function Debug:Hide()
  self.enabled = false
  if self.frame then self.frame:Hide() end
end

function Debug:Toggle()
  if self.enabled and self.frame and self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function Debug:Clear()
  if self.msg then self.msg:Clear() end
end

-- ----------------------------------------------------------------------
-- Logging 
-- ----------------------------------------------------------------------
function Debug:Add(cat, text, r, g, b)
  if not self.enabled or self.paused then return end
  if self.filters[cat] == false then return end
  self:EnsureUI(); if not self.msg then return end
  local c = COLOR[cat]
  self.msg:AddMessage(("[%s] %s"):format(cat:upper(), tostring(text)),
    r or (c and c[1] or 1),
    g or (c and c[2] or 1),
    b or (c and c[3] or 1))
end

function Debug:Event(text) self:Add("event", text) end

function Debug:Tick(text) self:Add("tick", text) end

function Debug:State(text) self:Add("state", text) end

function Debug:UI(text) self:Add("ui", text) end

function Debug:Error(text) self:Add("err", text) end

function Debug:Printf(cat, fmt, ...) self:Add(cat, string.format(fmt, ...)) end
