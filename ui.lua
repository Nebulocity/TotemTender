print("TotemTender: loading ui.lua")

local ADDON, TotemTender = ...

local UI = {}
TotemTender.UI = UI

-- Aliases
local CONST = TotemTender.CONST

-- ------------------------------
-- Helpers
-- ------------------------------

-- Re-parent + center a StaticPopup onto our addon window
local function attachPopupToRoot(frame)
  local ui, root = TotemTender and TotemTender.UI, TotemTender and TotemTender.UI and TotemTender.UI.root
  if not (root and root:IsShown()) then return end

  -- remember original parent/points so we can restore later
  frame._origParent = frame._origParent or frame:GetParent()
  frame._origPoints = frame._origPoints or { frame:GetPoint() }

  frame:SetParent(root)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", root, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetFrameLevel(root:GetFrameLevel() + 100)
end

local function restorePopupParent(frame)
  if frame._origParent then
    frame:SetParent(frame._origParent)
    frame:ClearAllPoints()
    if frame._origPoints then
      local p = frame._origPoints
      -- Point() tuple: point, relTo, relPoint, x, y
      frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    else
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
  end
  frame._origParent, frame._origPoints = nil, nil
end


local function makeDraggable(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
end

-- Robust capability checker for CanUnlock/CanSummon.
local function tryCapabilityCheck(fn, selfObj, totem)
  if type(fn) ~= "function" then return false end
  -- Prefer "." style first
  local ok, result = pcall(fn, totem)
  if ok and type(result) == "boolean" then return result end
  -- Fallback to ":" style
  ok, result = pcall(fn, selfObj, totem)
  if ok and type(result) == "boolean" then return result end
  return false
end

-- One-time unlock confirmation popup
if not StaticPopupDialogs["TOTEM_TENDER_UNLOCK"] then
  StaticPopupDialogs["TOTEM_TENDER_UNLOCK"] = {
    text = "Unlock %s for %d Harmony?",
    button1 = YES,
    button2 = NO,
    OnShow = function(self, data)
      attachPopupToRoot(self)
      local name = data and data.name or "this totem"
      local cost = data and data.unlock or 0
      self.text:SetFormattedText("Unlock %s for %d Harmony?", name, cost)
    end,
    OnAccept = function(self, data)
      if data then
        TotemTender.UnlockTotem(data)
        -- Refresh the same element list after unlock
        if TotemTender.UI and TotemTender.UI.OpenTotemList then
          TotemTender.UI:OpenTotemList(data.element)
        end
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, -- take a free popup slot even if others exist
  }
end

-- Is a given instance still present in S.activeTotems?
function UI:IsInstanceActive(inst)
  local S = TotemTender.State or {}
  if not inst or not S.activeTotems then return false end
  for _, cur in ipairs(S.activeTotems) do
    if cur == inst then return true end
  end
  return false
end

function UI:StartSceneWidgetSyncTicker()
  if self._sceneSyncTicker then return end
  self._sceneSyncTicker = C_Timer.NewTicker(0.5, function()
    -- remove any widget whose instance is gone or flagged removed
    for i = #self.totemWidgets, 1, -1 do
      local w = self.totemWidgets[i]
      if (not w) or w._removed or (not self:IsInstanceActive(w._inst)) then
        if w then
          w._removed = true; w:Hide()
        end
        table.remove(self.totemWidgets, i)
      end
    end
  end)
end

-- Stop the widget ticker
function UI:StopSceneWidgetSyncTicker()
  if self._sceneSyncTicker then self._sceneSyncTicker:Cancel() end
  self._sceneSyncTicker = nil
end

-- ------------------------------
-- Root frame + layout
-- ------------------------------
function UI:Create()
  if self.root then return end

  local root = CreateFrame("Frame", "TotemTenderFrame", UIParent, "BackdropTemplate")

  root:SetSize(480, 320)
  root:SetPoint("CENTER")
  root:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })

  root:SetBackdropColor(0.2, 0.1, 0.4, 1)
  makeDraggable(root)
  table.insert(UISpecialFrames, root:GetName()) -- ESC to close
  self.root = root

  root:SetFrameStrata("LOW") -- or "BACKGROUND" if you want it even lower
  root:SetToplevel(false)    -- never force on top of other UI
  root:SetFrameLevel(1)      -- low level within the LOW strata

  root:SetScript("OnHide", function()
    if TotemTender and TotemTender.UI and TotemTender.UI.CloseTotemList then
      TotemTender.UI:CloseTotemList()
    end
  end)

  -- Banner
  local banner = CreateFrame("Frame", nil, root)
  banner:SetPoint("TOPLEFT", 8, -8)
  banner:SetPoint("TOPRIGHT", -8, -8)
  banner:SetHeight(28)

  local bannerBG = banner:CreateTexture(nil, "BACKGROUND")
  bannerBG:SetAllPoints()
  bannerBG:SetColorTexture(0.2, 0.1, 0.4, 1)

  -- Close button (top-right of the main window)
  local closeBtn = CreateFrame("Button", nil, root, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", root, "TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function()
    UI:Hide()
  end)


  local title = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("LEFT", 8, 0)
  title:SetText("Totem Tender")

  local statsText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  statsText:SetPoint("RIGHT", -32, 0)
  self.statsText = statsText

  -- Scene area
  local scene = CreateFrame("Frame", nil, root, "BackdropTemplate")
  scene:SetPoint("TOPLEFT", 8, -44)
  scene:SetPoint("BOTTOMRIGHT", -8, 100)
  scene:SetBackdropColor(0.15, 0.15, 0.5, 1)
  self.scene        = scene

  self.sceneTexture = scene:CreateTexture(nil, "BACKGROUND")
  self.sceneTexture:SetAllPoints()
  self.sceneTexture:SetColorTexture(0.25, 0.2, 0.6, 1)

  self.sceneOverlay = scene:CreateTexture(nil, "OVERLAY")
  self.sceneOverlay:SetAllPoints()
  self.sceneOverlay:SetColorTexture(0, 0, 0, 0)
  self.sceneOverlay:SetBlendMode("BLEND")

  -- Footer with two rows
  local footer = CreateFrame("Frame", nil, root)
  footer:SetPoint("BOTTOMLEFT", 8, 8)
  footer:SetPoint("BOTTOMRIGHT", -8, 8)
  footer:SetHeight(84) -- 40 (elem) + 4 gap + 40 (ctrl)
  self.footer = footer

  local elemBar = CreateFrame("Frame", nil, footer)
  elemBar:SetPoint("TOPLEFT")
  elemBar:SetPoint("TOPRIGHT")
  elemBar:SetHeight(40)
  self.elemBar = elemBar

  local ctrlBar = CreateFrame("Frame", nil, footer)
  ctrlBar:SetPoint("BOTTOMLEFT")
  ctrlBar:SetPoint("BOTTOMRIGHT")
  ctrlBar:SetHeight(40)
  self.ctrlBar = ctrlBar

  local function makeElementButton(label, r, g, b, onClick)
    local btn = CreateFrame("Button", nil, elemBar, "UIPanelButtonTemplate")
    btn:SetSize(108, 28)
    btn:SetText(label)
    btn:GetFontString():SetTextColor(r, g, b)
    btn:SetScript("OnClick", onClick)
    return btn
  end

  self.btnEarth = makeElementButton("Earth", 0.6, 0.8, 0.6, function() UI:OpenTotemList("earth") end)
  self.btnFire  = makeElementButton("Fire", 1.0, 0.6, 0.4, function() UI:OpenTotemList("fire") end)
  self.btnWater = makeElementButton("Water", 0.5, 0.8, 1.0, function() UI:OpenTotemList("water") end)
  self.btnAir   = makeElementButton("Air", 0.7, 0.9, 1.0, function() UI:OpenTotemList("air") end)

  self.btnEarth:SetPoint("LEFT", 0, 0)
  self.btnFire:SetPoint("LEFT", self.btnEarth, "RIGHT", 8, 0)
  self.btnWater:SetPoint("LEFT", self.btnFire, "RIGHT", 8, 0)
  self.btnAir:SetPoint("LEFT", self.btnWater, "RIGHT", 8, 0)

  local function makeControl(label, onClick)
    local btn = CreateFrame("Button", nil, ctrlBar, "UIPanelButtonTemplate")
    btn:SetSize(80, 24)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
  end

  self.btnStart = makeControl("Start", function()
    if TotemTender.Start then TotemTender.Start() end
  end)

  self.btnPause = makeControl("Pause", function()
    if TotemTender.Pause then TotemTender.Pause() end
  end)

  self.btnReset = makeControl("Reset", function()
    StaticPopupDialogs["TOTEM_TENDER_RESET_CONFIRM"] = {
      text = "Reset the current game?",
      button1 = YES,
      button2 = NO,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      OnShow = function(self) attachPopupToRoot(self) end,
      OnHide = function(self) restorePopupParent(self) end,
      OnAccept = function() if TotemTender.Reset then TotemTender.Reset() end end,
    }
    StaticPopup_Show("TOTEM_TENDER_RESET_CONFIRM")
  end)

  -- Center them nicely on the second row
  self.btnStart:SetPoint("CENTER", ctrlBar, "CENTER", -90, 0)
  self.btnPause:SetPoint("LEFT", self.btnStart, "RIGHT", 8, 0)
  self.btnReset:SetPoint("LEFT", self.btnPause, "RIGHT", 8, 0)



  -- Toast
  local toast = CreateFrame("Frame", nil, root)
  toast:SetSize(220, 46)
  toast:SetPoint("TOP", root, "TOP", 0, -74)
  toast:SetAlpha(0)

  local toastBG = toast:CreateTexture(nil, "BACKGROUND")
  toastBG:SetAllPoints()
  toastBG:SetColorTexture(0, 0, 0, 0.6)

  local toastHeader = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  toastHeader:SetPoint("TOP", 0, -4)

  local toastSub = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  toastSub:SetPoint("TOP", toastHeader, "BOTTOM", 0, -2)

  self.toast        = toast
  self.toastHeader  = toastHeader
  self.toastSub     = toastSub

  self.totemWidgets = {}

  -- Ticker for expiring totems.
  if not self._expireTicker then
    self._expireTicker = C_Timer.NewTicker(1, function()
      for i = #self.totemWidgets, 1, -1 do
        local w = self.totemWidgets[i]
        local inst = w._inst
        if inst and inst.remaining then
          inst.remaining = inst.remaining - 1
          if inst.remaining <= 0 then
            w._removed = true
            w:Hide()
            table.remove(self.totemWidgets, i)
          end
        end
      end
    end)
  end
end

function UI:Show()
  self:Create()
  self.root:Show()
  self:Refresh()
  self:UpdateRunButtons()
end

function UI:Hide()
  if self.CloseTotemList then self:CloseTotemList() end
  if self.root then self.root:Hide() end
end

-- ------------------------------
-- General UI updates
-- ------------------------------
function UI:Refresh()
  if not TotemTender.State or not self.root or not self.root:IsShown() then return end
  local S = TotemTender.State

  local bannerText = string.format("Lv %d | Harmony %d | %s | Health %d%%", S.level, S.harmony, S.baseEnv.name,
    S.envHealth)

  self.statsText:SetText(bannerText)

  -- Cleanup any removed widgets
  for i = #self.totemWidgets, 1, -1 do
    local widget = self.totemWidgets[i]

    if widget._removed or (widget._inst and widget._inst.remaining and widget._inst.remaining <= 0) then
      widget._removed = true
      widget:Hide()
      table.remove(self.totemWidgets, i)
    end
  end
end

function UI:BannerToast(header, sub)
  if not self.toast then return end
  self.toastHeader:SetText(header or "")
  self.toastSub:SetText(sub or "")
  self.toast:SetAlpha(1)
  UIFrameFadeOut(self.toast, 2.0, 1, 0)
end

-- ------------------------------
-- Background art + mood tinting
-- ------------------------------

function UI:SetSceneBackground(texturePath)
  if not self.sceneTexture then return end

  -- normalize: allow extensionless paths in data.lua (works for .blp/.tga)
  local base = texturePath and texturePath:gsub("%.%w+$", "") or nil
  local candidates = {}
  if base then
    table.insert(candidates, base) -- extensionless
    table.insert(candidates, base .. ".blp")
    table.insert(candidates, base .. ".tga")
    table.insert(candidates, base .. ".png")
  end

  local applied = false
  for _, p in ipairs(candidates) do
    self.sceneTexture:SetTexture(nil)      -- hard reset
    self.sceneTexture:SetTexture(p)
    if self.sceneTexture:GetTexture() then -- assigned something
      applied = true
      -- re-apply next frame too (avoids rare blanking after swaps)
      C_Timer.After(0, function()
        local cur = self.sceneTexture:GetTexture()
        self.sceneTexture:SetTexture(nil)
        self.sceneTexture:SetTexture(cur)
      end)
      break
    end
  end

  if applied then
    self.sceneTexture:SetVertexColor(1, 1, 1, 1)
  else
    -- graceful fallback so the scene isn't empty
    self.sceneTexture:SetTexture(nil)
    self.sceneTexture:SetColorTexture(0.08, 0.08, 0.1, 0.6)
  end
end

-- health: 0..100
function UI:ApplySceneMood(health)
  if not self.sceneTexture or not self.sceneOverlay then return end
  health = math.max(0, math.min(100, health or 50))

  -- Classic: SetDesaturated takes boolean
  self.sceneTexture:SetDesaturated(health <= 50)

  -- Slight brightening as health rises
  local brightness = 0.85 + (health / 100) * 0.15 -- 0.85 → 1.0
  self.sceneTexture:SetVertexColor(brightness, brightness, brightness, 1)

  -- Overlay tints
  if health <= 30 then
    self.sceneOverlay:SetBlendMode("BLEND")
    local a = 0.08 + ((30 - health) / 30) * 0.17 -- 0.08 → 0.25
    self.sceneOverlay:SetColorTexture(0.8, 0.05, 0.05, a)
  elseif health >= 80 then
    self.sceneOverlay:SetBlendMode("ADD")
    local a = 0.04 + ((health - 80) / 20) * 0.12 -- 0.04 → 0.16
    self.sceneOverlay:SetColorTexture(0.15, 0.6, 0.15, a)
  else
    self.sceneOverlay:SetBlendMode("BLEND")
    self.sceneOverlay:SetColorTexture(0, 0, 0, 0)
  end
end

-- ------------------------------
-- Totem list popup (single reusable window)
-- ------------------------------
function UI:CloseTotemList()
  if self.list then self.list:Hide() end
  self:StopListCooldownTicker()
  self.listElement = nil
end

function UI:ClearTotemRows()
  if not self.listContent then return end
  local children = { self.listContent:GetChildren() }
  for _, child in ipairs(children) do
    child:Hide()
    child:SetParent(nil)
  end
end

function UI:OpenTotemList(element, opts)
  if TotemTender._CleanupExpiredActiveTotems then
    TotemTender._CleanupExpiredActiveTotems()
  end

  opts = opts or {}

  self:Create()

  if self.listMsg then
    self.listMsg:SetText("")
    self.listMsg:Hide()
    self.listMsg:SetAlpha(1)
  end

  -- only toggle-close if we didn't explicitly ask for a refresh
  if self.list and self.list:IsShown() and self.listElement == element and not opts.refreshOnly then
    return self:CloseTotemList()
  end

  -- Create popup once
  if not self.list then
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

    frame:ClearAllPoints()

    frame:SetPoint("TOPLEFT", self.root, "TOPLEFT", 24, -60)
    frame:SetPoint("BOTTOMRIGHT", self.root, "BOTTOMRIGHT", -24, 110)

    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })

    -- Make it fully opaque so visibility isn't wonky
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetFrameStrata("HIGH") -- above LOW/MEDIUM/HIGH
    frame:SetToplevel(false)
    frame:SetFrameLevel(10)

    -- A solid background layer that covers the whole panel,
    -- so text/cooldowns behind never “shine through” during scroll
    local solidBG = frame:CreateTexture(nil, "BACKGROUND")
    solidBG:SetAllPoints()
    solidBG:SetColorTexture(0, 0, 0, 1)

    frame:SetFrameLevel(self.root:GetFrameLevel() + 5)
    frame:EnableMouse(true)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() UI:CloseTotemList() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("TOP", 0, -10)
    title:SetWidth(360)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    self.listTitle = title

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 10, -31)
    scroll:SetPoint("BOTTOMRIGHT", -10, 28)
    scroll:SetClipsChildren(true)
    scroll:SetFrameLevel(frame:GetFrameLevel() + 1)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    -- Message line
    local msg = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    msg:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    msg:SetJustifyH("CENTER")
    msg:SetText("")
    msg:Hide()

    -- Adjust the font size for the messages
    msg:SetFontObject("GameFontNormalLarge")

    self.listMsg = msg
    self.list = frame
    self.listScroll = scroll
    self.listContent = content
  end

  -- Populate
  self.listElement = element
  self.list:Show()

  local byElem = TotemTender.TOTEMS_BY_ELEM or {}
  local totems = byElem[element] or {}
  local total  = #totems
  self.listTitle:SetText(("%s TOTEMS (%d)"):format(string.upper(element), total))

  self:ClearTotemRows()

  -- Layout constants
  local paddingX, paddingY = 14, 14
  local cellW, cellH       = 88, 88
  local iconSize           = 48

  -- Determine columns that fit current viewport width
  local viewportW          = (self.listScroll:GetWidth() or 360)
  local cols               = math.max(1, math.floor((viewportW + paddingX) / (cellW + paddingX)))

  -- Pre-size scroll child to avoid first-frame clipping
  local rows               = math.max(1, math.ceil(total / cols))
  local contentW           = cols * (cellW + paddingX) - paddingX
  local contentH           = rows * (cellH + paddingY) - paddingY
  self.listContent:SetSize(math.max(1, contentW), math.max(1, contentH))
  self.cells = {}

  -- Create cells
  for index, totem in ipairs(totems) do
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)

    local cell = CreateFrame("Button", nil, self.listContent, "BackdropTemplate")
    cell:SetSize(cellW, cellH)
    cell:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", col * (cellW + paddingX), -row * (cellH + paddingY))

    -- Icon
    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("TOP", 0, 0)
    icon:SetTexture("Interface\\Icons\\" .. totem.icon)

    -- (place this block before creating `lock` and `shade`)
    local unlockedById = (TotemTender.State and TotemTender.State.unlocked) or {}
    local isLocked     = not (totem.id and unlockedById[totem.id])
    local canUnlock    = isLocked and tryCapabilityCheck(TotemTender.CanUnlock, TotemTender, totem) or false
    local canSummon    = tryCapabilityCheck(TotemTender.CanSummon, TotemTender, totem)

    -- Padlock overlay for locked items
    local lock         = cell:CreateTexture(nil, "OVERLAY")
    lock:SetSize(18, 18)
    lock:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
    lock:SetTexture("Interface\\Buttons\\UI-Panel-Lock")
    lock:SetDrawLayer("OVERLAY", 2)
    lock:SetAlpha(isLocked and 0.9 or 0)

    -- Shade for locked state (disabled by default)
    local shade = cell:CreateTexture(nil, "OVERLAY")
    shade:SetAllPoints(icon)
    shade:SetColorTexture(0, 0, 0, isLocked and 0.55 or 0)

    -- Name under each totem icon
    local nameFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    nameFS:SetWidth(cellW - 6)
    nameFS:SetJustifyH("CENTER")
    nameFS:SetWordWrap(false)
    nameFS:SetText(totem.name)

    -- Unlock cost under the name
    local unlockCostFS = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    unlockCostFS:SetPoint("TOP", nameFS, "BOTTOM", 0, -3)
    unlockCostFS:SetWidth(cellW - 6)
    unlockCostFS:SetJustifyH("CENTER")
    unlockCostFS:SetText(string.format("Unlock: %d", totem.unlock))

    -- Summon cost under the unlock cost
    local summonCostFS = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    summonCostFS:SetPoint("TOP", nameFS, "BOTTOM", 0, -15)
    summonCostFS:SetWidth(cellW - 6)
    summonCostFS:SetJustifyH("CENTER")
    summonCostFS:SetText(string.format("Summon: %d", totem.summon))

    -- cooldown label under the Summon cost
    local cooldownFS = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cooldownFS:SetPoint("TOP", summonCostFS, "BOTTOM", 0, -2) -- anchor to summonCostFS
    cooldownFS:SetTextColor(1, 0.95, 0.2)
    cooldownFS:SetText("")
    cooldownFS:Hide()

    -- keep references for tickers/helpers
    cell._totem = totem
    cell.cdFS   = cooldownFS
    table.insert(self.cells, cell)

    -- Update the button after unlocking totem
    local function refreshCellAfterUnlock()
      isLocked  = false
      canSummon = tryCapabilityCheck(TotemTender.CanSummon, TotemTender, totem)

      -- visuals
      lock:SetAlpha(0)
      shade:SetAlpha(0)
      if unlockCostFS then unlockCostFS:SetTextColor(0.6, 0.6, 0.6) end
      UI:ListMessage(("Unlocked %s. Click again to summon."):format(totem.name), 0.6, 1, 0.6, 2.0)
    end

    -- Tooltip
    cell:SetScript("OnEnter", function()
      GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
      GameTooltip:AddLine(totem.name)
      GameTooltip:AddLine("Unlock Level: " .. totem.unlockLevel, 1, 1, 1)
      GameTooltip:AddLine("Unlock Cost: " .. totem.unlock, .8, .9, 1)
      GameTooltip:AddLine("Summon Cost: " .. totem.summon, .8, .9, 1)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Affinities:")
      for k, v in pairs(totem.affinity) do
        local label = (k == "env") and "Environment" or (k:gsub("^%l", string.upper))
        local sign  = v >= 0 and "+" or ""
        GameTooltip:AddLine(" - " .. label .. ": " .. sign .. v, .9, .9, .9)
      end
      GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", GameTooltip_Hide)

    -- WHen clicking a button...
    cell:SetScript("OnClick", function()
      -- This is re-evaluated every Tick to avoid stale values
      local S            = TotemTender.State or {}
      local unlockedById = S.unlocked or {}
      local isLockedNow  = not (totem.id and unlockedById[totem.id])
      local canUnlockNow = isLockedNow and (TotemTender.CanUnlock and TotemTender.CanUnlock(totem)) or false
      local canSummonNow = (not isLockedNow) and (TotemTender.CanSummon and TotemTender.CanSummon(totem)) or false

      if not TotemTender.Running then
        UI:ListMessage("Unpause the game before managing totems!", "Press Start!")
        return
      end

      -- If the totem is currently locked
      if isLockedNow then
        -- If the unlock cost is zero (Stoneskin totems), default to unlocked.
        if (totem.unlock == 0) then
          TotemTender.UnlockTotem(totem)
          refreshCellAfterUnlock()
          return
        end

        -- If a totem can be unlocked...
        if canUnlockNow then
          -- Dialog to prompt for unlocking
          StaticPopupDialogs["TOTEM_TENDER_UNLOCK"] = {
            text = string.format("Unlock %s for %d Harmony?", totem.name, totem.unlock),
            button1 = YES,
            button2 = NO,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnShow = function(self) attachPopupToRoot(self) end,
            OnHide = function(self) restorePopupParent(self) end,
            OnAccept = function()
              -- Unlock totem and refresh
              TotemTender.UnlockTotem(totem)
              refreshCellAfterUnlock()
            end
          }

          -- Show the dialog
          StaticPopup_Show("TOTEM_TENDER_UNLOCK")
        else
          -- If the totem can't be unlocked yet, get what's missing
          local needLevel, needHarmony = TotemTender.MissingForUnlock(totem)

          -- Determine if it's a missing level, or harmony
          if needLevel > 0 or needHarmony > 0 then
            local parts = {}
            if needLevel > 0 then table.insert(parts, ("Level %d"):format(totem.unlockLevel)) end
            if needHarmony > 0 then table.insert(parts, ("%d Harmony"):format(needHarmony)) end

            -- Provide a message stating missing requirements
            UI:ListMessage("Requires " .. table.concat(parts, " and ") .. ".", 1, 0.6, 0.2)
          else
            -- Fallback in case it can't be unlocked and we don't know why
            UI:ListMessage("Cannot unlock right now.", 1, 0.6, 0.2)
          end
        end
        return
      end

      -- Totem is unlocked and available to summon
      if canSummonNow then
        -- Prevent summoning if the game is paused
        if not TotemTender.Running then
          TotemTender.UI:BannerToast("Totem Tender paused", "Press Start to place totems")
          return
        end

        -- Try to summon regardless of any prior precheck
        local summonResult = TotemTender.SummonTotem(totem)

        if summonResult then
          -- Close only after a successful summon
          UI:CloseTotemList()
          UI:Refresh()
          return
        end

        -- Summon failed: explain why (keep the list open)
        local totemState   = TotemTender.State or {}
        local summonReason = TotemTender.CanSummonReason and TotemTender.CanSummonReason(totem)

        if summonReason == "limit" then
          TotemTender.UI:BannerToast("Limit reached", "Too many active totems")
        elseif summonReason == "cooldown" then
          UI:ShowCooldownMessage(totem)
        elseif summonReason == "cost" then
          local need = (totem.summon or 0) - (totemState.harmony or 0)
          TotemTender.UI:BannerToast("Not enough Harmony", ("Need %d more"):format(math.max(need, 1)))
        elseif summonReason == "active" then
          UI:ListMessage("That totem is currently up", 1, 0.6, 0.2)
        elseif summonReason == "locked" then
          TotemTender.UI:BannerToast("Locked", "Unlock this totem first")
        else
          TotemTender.UI:BannerToast("Cannot summon", "Unknown reason")
        end
        -- else
        --   -- Do we need this code block?  Doesn't the above block do the same thing?
        --   local why = TotemTender.CanSummonReason and TotemTender.CanSummonReason(totem)

        --   if why == "limit" then
        --     TotemTender.UI:BannerToast("Limit reached", "Too many active totems")
        --   elseif why == "cooldown" then
        --     UI:ShowCooldownMessage(totem)
        --   elseif why == "cost" then
        --     local need = (totem.summon or 0) - (S.harmony or 0)
        --     TotemTender.UI:BannerToast("Not enough Harmony", ("Need %d more"):format(math.max(need, 1)))
        --   elseif why == "active" then
        --     UI:ListMessage("That totem is currently up", 1, 0.6, 0.2)
        --   elseif why == "locked" then
        --     TotemTender.UI:BannerToast("Locked", "Unlock this totem first")
        --   else
        --     TotemTender.UI:BannerToast("Cannot summon", "Unknown reason")
        --   end

        --   UI:CloseTotemList()
      end
    end)
  end

  self:StartListCooldownTicker()
end

-- ------------------------------
-- Lay totems out in an even distribution
-- ------------------------------
function UI:LayoutTotemWidgetsEvenly()
  if not (self.scene and self.totemWidgets) then return end

  local sceneWidth = self.scene:GetWidth()
  if not sceneWidth or sceneWidth <= 0 then return end

  local sidePadding = 50 -- 50 left + 50 right = 100 total
  local usableWidth = math.max(0, sceneWidth - (sidePadding * 2))
  local baselineY   = 5
  local slots       = 4 -- fixed slots

  -- Collect visible widgets
  local widgets     = {}
  for _, w in ipairs(self.totemWidgets) do
    if w:IsShown() then table.insert(widgets, w) end
  end
  if #widgets == 0 then return end

  -- Sort by desired element order: Earth, Fire, Water, Air
  local order = { earth = 1, fire = 2, water = 3, air = 4 }
  table.sort(widgets, function(a, b)
    local ea = a._inst and a._inst.element and string.lower(a._inst.element) or ""
    local eb = b._inst and b._inst.element and string.lower(b._inst.element) or ""
    return (order[ea] or 99) < (order[eb] or 99)
  end)

  -- Compute four slot centers across the padded width
  local slotWidth = usableWidth / slots
  local centers = {}
  for i = 1, slots do
    centers[i] = sidePadding + (slotWidth * (i - 0.5))
  end

  -- Place up to 4 widgets into those centers in the sorted order
  local n = math.min(#widgets, slots)
  for i = 1, n do
    local w = widgets[i]
    local halfW = (w:GetWidth() or 0) / 2
    w:ClearAllPoints()
    w:SetPoint("BOTTOMLEFT", self.scene, "BOTTOMLEFT", centers[i] - halfW, baselineY)
  end
end

-- ------------------------------
-- Place totem in it's spot
-- ------------------------------
function UI:AddTotemWidget(instance)
  self:Create()
  local widget = CreateFrame("Frame", nil, self.scene)
  widget:SetSize(30, 30)

  local S     = TotemTender.State or {}
  local lvl   = S.baseEnv or {}
  local spots = lvl.totemSpots or {}
  local pos   = spots[instance.element]

  if pos then
    widget:SetPoint("BOTTOMLEFT", pos.x, pos.y)
    widget._lockedPos = true
  else
    widget._lockedPos = false
  end

  local tex = widget:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture("Interface\\Icons\\" .. instance.icon)
  tex:SetAlpha(0.95)

  local cd = CreateFrame("Cooldown", nil, widget, "CooldownFrameTemplate")
  cd:SetAllPoints()
  cd:SetDrawEdge(false)
  cd:SetReverse(false)
  cd:SetCooldown(GetTime(), math.max(0.01, instance.remaining or 0))

  widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
    GameTooltip:AddLine(instance.name)
    local secs = math.max(0, math.floor((instance.remaining or 0)))
    GameTooltip:AddLine(("Remaining: %ds"):format(secs), 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right-click: Dismiss Totem", 0.8, 0.6, 0.2)
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", GameTooltip_Hide)
  widget:EnableMouse(true)
  widget:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" then
      widget._removed = true
      widget:Hide()
      TotemTender.DismissTotem(instance)
    end
  end)

  widget._inst = instance
  table.insert(self.totemWidgets, widget)

  self:LayoutTotemWidgetsEvenly()
end

-- ------------------------------------
-- Displays messages related to totems
-- ------------------------------------
function UI:ListMessage(text, r, g, b, duration)
  if not self.list or not self.list:IsShown() then return end
  local msg = self.listMsg
  if not msg then return end

  msg:Show()
  msg:SetText(text or "")
  msg:SetTextColor(r or 1, g or 0.82, b or 0.2) -- warm yellow/orange by default

  -- simple fade-out after a short delay
  msg:SetAlpha(1)
  local secs = duration or 2.5
  if msg._fadeTicker then msg._fadeTicker:Cancel() end
  msg._fadeTicker = C_Timer.NewTimer(secs, function()
    if msg and msg:IsShown() then
      UIFrameFadeOut(msg, 0.8, 1, 0)
      C_Timer.After(0.9, function() if msg then msg:Hide() end end)
    end
  end)
end

function UI:UpdateRunButtons()
  if not (self.btnStart and self.btnPause and self.btnReset) then return end
  local running = TotemTender.Running == true
  self.btnStart:SetEnabled(not running)
  self.btnPause:SetEnabled(running)
  self.btnReset:SetEnabled(true)

  if running then
    self:StartListCooldownTicker()
    self:StartSceneWidgetSyncTicker()
  else
    self:StopListCooldownTicker()
    self:StopSceneWidgetSyncTicker()
  end
end

-- ----------------------------------------------------
-- Nuke all running widgets (called during reset)
-- ----------------------------------------------------
function UI:ClearAllTotemWidgets()
  if not self.totemWidgets then return end
  for i = #self.totemWidgets, 1, -1 do
    local w = self.totemWidgets[i]
    if w then
      w._removed = true; w:Hide()
    end
    table.remove(self.totemWidgets, i)
  end
end

-- ------------------------------------
-- Removes a widget by instance
-- ------------------------------------
function UI:RemoveTotemWidget(instance)
  if not self.totemWidgets then return end
  for i = #self.totemWidgets, 1, -1 do
    local w = self.totemWidgets[i]
    if w._inst == instance then
      w._removed = true
      w:Hide()

      table.remove(self.totemWidgets, i)
      break
    end
  end
end

-- ------------------------------------------
-- Smooth cooldown readout: prefers endAt, falls back to S.cooldowns
-- ------------------------------------------
function UI:GetCooldownRemaining(totemId)
  local S = TotemTender.State or {}
  local endAt = S.cooldownEndAt and S.cooldownEndAt[totemId]
  local fromEnd = endAt and (endAt - GetTime()) or nil
  local fromTable = S.cooldowns and S.cooldowns[totemId] or 0
  local secs = math.max(0, math.floor((fromEnd or fromTable or 0)))
  return secs
end

function UI:UpdateTotemListCooldowns()
  if not (self.list and self.list:IsShown() and self.cells) then return end
  for _, cell in ipairs(self.cells) do
    if cell._totem and cell.cdFS then
      local secs = self:GetCooldownRemaining(cell._totem.id)
      if secs > 0 then
        cell.cdFS:SetText(("Cooldown: %ds"):format(secs))
        cell.cdFS:Show()
      else
        cell.cdFS:SetText("")
        cell.cdFS:Hide()
      end
    end
  end
end

function UI:StartListCooldownTicker()
  if self._listCdTicker then self._listCdTicker:Cancel() end
  self._listCdTicker = C_Timer.NewTicker(0.2, function()
    if not (self.list and self.list:IsShown()) then return end
    self:UpdateTotemListCooldowns()
  end)
end

function UI:StopListCooldownTicker()
  if self._listCdTicker then self._listCdTicker:Cancel() end
  self._listCdTicker = nil
end

function UI:ShowCooldownMessage(totem)
  if not (self.list and self.list:IsShown() and self.listMsg and totem) then return end
  local msg = self.listMsg
  if msg._fadeTicker then msg._fadeTicker:Cancel() end -- cancel any pending fade
  msg:SetAlpha(1); msg:Show()

  if self._cooldownMsgTicker then self._cooldownMsgTicker:Cancel() end
  self._cooldownMsgTicker = C_Timer.NewTicker(0.2, function()
    if not (self.list and self.list:IsShown()) then return end
    local secs = self:GetCooldownRemaining(totem.id)
    if secs <= 0 then
      msg:SetText("Ready.")
      -- fade out shortly after becoming ready
      C_Timer.After(1.0,
        function()
          if msg and msg:IsShown() then
            UIFrameFadeOut(msg, 0.8, 1, 0); C_Timer.After(0.9, function() if msg then msg:Hide() end end)
          end
        end)
      self._cooldownMsgTicker:Cancel()
      self._cooldownMsgTicker = nil
    else
      msg:SetText(("On cooldown!  %ds remaining!"):format(secs))
      msg:SetTextColor(1, 0.95, 0.2)
    end
  end)
end
