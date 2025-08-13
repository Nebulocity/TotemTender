local ADDON, TotemTender = ...
local CONST, ENVS, TOTEMS = TotemTender.CONST, TotemTender.ENVIRONMENTS, TotemTender.TOTEMS

local UI = {}
TotemTender.UI = UI

-- ---------------------------------------------------
-- helpers
-- ---------------------------------------------------
local function MakeDraggable(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
end

-- ---------------------------------------------------
-- root frame + layout
-- ---------------------------------------------------
function UI:Create()
  if self.root then return end

  local f = CreateFrame("Frame", "TotemTenderFrame", UIParent, "BackdropTemplate")
  f:SetSize(480, 320)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  f:SetBackdropColor(0,0,0,0.85)
  MakeDraggable(f)
  table.insert(UISpecialFrames, f:GetName()) -- ESC to close
  self.root = f

  -- banner
  local banner = CreateFrame("Frame", nil, f)
  banner:SetPoint("TOPLEFT", 8, -8)
  banner:SetPoint("TOPRIGHT", -8, -8)
  banner:SetHeight(28)

  local bannerBG = banner:CreateTexture(nil, "BACKGROUND")
  bannerBG:SetAllPoints()
  bannerBG:SetColorTexture(0.1, 0.2, 0.1, 0.8)

  local title = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("LEFT", 8, 0)
  title:SetText("Totem Tender")

  local stats = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  stats:SetPoint("RIGHT", -8, 0)
  self.statsText = stats

  -- scene
  local scene = CreateFrame("Frame", nil, f, "BackdropTemplate")
  scene:SetPoint("TOPLEFT", 8, -44)
  scene:SetPoint("BOTTOMRIGHT", -8, 56)
  scene:SetBackdropColor(0.05, 0.05, 0.07, 0.7)
  self.scene = scene

  self.sceneTexture = scene:CreateTexture(nil, "BACKGROUND")
  self.sceneTexture:SetAllPoints()
  -- default fallback color (gets replaced by SetSceneBackground)
  self.sceneTexture:SetColorTexture(0.08, 0.08, 0.1, 0.6)

  -- overlay for tinting/vibrancy
  self.sceneOverlay = scene:CreateTexture(nil, "OVERLAY")
  self.sceneOverlay:SetAllPoints()
  self.sceneOverlay:SetColorTexture(0,0,0,0)
  self.sceneOverlay:SetBlendMode("BLEND")

  -- bottom element bar
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("BOTTOMLEFT", 8, 8)
  bar:SetPoint("BOTTOMRIGHT", -8, 8)
  bar:SetHeight(40)

  local function MakeElemButton(label, r,g,b, onClick)
    local btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    btn:SetSize(108, 28)
    btn:SetText(label)
    btn:GetFontString():SetTextColor(r,g,b)
    btn:SetScript("OnClick", onClick)
    return btn
  end

  self.btnEarth = MakeElemButton("Earth", 0.6,0.8,0.6, function() UI:OpenTotemList("earth") end)
  self.btnAir = MakeElemButton("Air", 0.7,0.9,1.0, function() UI:OpenTotemList("air") end)
  self.btnFire = MakeElemButton("Fire", 1.0,0.6,0.4, function() UI:OpenTotemList("fire") end)
  self.btnWater = MakeElemButton("Water", 0.5,0.8,1.0, function() UI:OpenTotemList("water") end)

  self.btnEarth:SetPoint("LEFT", 0, 0)
  self.btnAir:SetPoint("LEFT", self.btnEarth, "RIGHT", 8, 0)
  self.btnFire:SetPoint("LEFT", self.btnAir, "RIGHT", 8, 0)
  self.btnWater:SetPoint("LEFT", self.btnFire, "RIGHT", 8, 0)

  -- toast
  local toast = CreateFrame("Frame", nil, f)
  toast:SetSize(220, 46)
  toast:SetPoint("TOP", f, "TOP", 0, -74)
  toast:SetAlpha(0)

  local tbg = toast:CreateTexture(nil, "BACKGROUND")
  tbg:SetAllPoints()
  tbg:SetColorTexture(0,0,0,0.6)

  local th = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  th:SetPoint("TOP", 0, -4)

  local ts = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ts:SetPoint("TOP", th, "BOTTOM", 0, -2)

  self.toast = toast
  self.toastHeader = th
  self.toastSub = ts

  self.totemWidgets = {}
end

function UI:Show()
  self:Create()
  self.root:Show()
  self:Refresh()
end

function UI:Hide()
  if self.root then self.root:Hide() end
end

-- ---------------------------------------------------
-- general ui updates
-- ---------------------------------------------------
function UI:Refresh()
  if not TotemTender.State or not self.root or not self.root:IsShown() then return end
  local S = TotemTender.State
  local banner = string.format("Lv %d | Harmony %d | %s | Health %d%%",
    S.level, S.harmony, S.baseEnv.name, S.envHealth)
  self.statsText:SetText(banner)

  -- cleanup removed widgets if any
  for i = #self.totemWidgets, 1, -1 do
    local w = self.totemWidgets[i]
    if w._removed then table.remove(self.totemWidgets, i) end
  end
end

function UI:BannerToast(header, sub)
  if not self.toast then return end
  self.toastHeader:SetText(header or "")
  self.toastSub:SetText(sub or "")
  self.toast:SetAlpha(1)
  UIFrameFadeOut(self.toast, 2.0, 1, 0)
end

-- ---------------------------------------------------
-- background art + mood
-- ---------------------------------------------------
function UI:SetSceneBackground(path)
  if not self.sceneTexture then return end
  if path and path ~= "" then
    self.sceneTexture:SetTexture(path)
    self.sceneTexture:SetVertexColor(1,1,1,1) -- reset tint to neutral
  else
    self.sceneTexture:SetTexture(nil)
    self.sceneTexture:SetColorTexture(0.08,0.08,0.1,0.6)
  end
end

-- 0..100 health -> tint & desaturation
function UI:ApplySceneMood(health)
  if not self.sceneTexture or not self.sceneOverlay then return end
  health = math.max(0, math.min(100, health or 50))

  -- Classic SetDesaturated is boolean; make it kick in when <= 50
  local desat = (health <= 50)
  self.sceneTexture:SetDesaturated(desat)

  -- Slight dim when very low; brighten a hair as health rises
  local dim = 0.85 + (health/100)*0.15 -- 0.85 → 1.0
  self.sceneTexture:SetVertexColor(dim, dim, dim, 1)

  -- Overlay tints
  if health <= 30 then
    -- danger: soft red wash (BLEND)
    self.sceneOverlay:SetBlendMode("BLEND")
    local a = 0.08 + ((30 - health) / 30) * 0.17 -- 0.08 → 0.25
    self.sceneOverlay:SetColorTexture(0.8, 0.05, 0.05, a)
  elseif health >= 80 then
    -- thriving: subtle green pop (ADD)
    self.sceneOverlay:SetBlendMode("ADD")
    local a = 0.04 + ((health - 80) / 20) * 0.12 -- 0.04 → 0.16
    self.sceneOverlay:SetColorTexture(0.15, 0.6, 0.15, a)
  else
    -- neutral
    self.sceneOverlay:SetBlendMode("BLEND")
    self.sceneOverlay:SetColorTexture(0,0,0,0)
  end
end

-- ---------------------------------------------------
-- totem list popup (single reusable)
-- ---------------------------------------------------
function UI:CloseTotemList()
  if self.list then
    self.list:Hide()
  end
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

function UI:OpenTotemList(element)
  self:Create()

  -- toggle if same element is open
  if self.list and self.list:IsShown() and self.listElement == element then
    return self:CloseTotemList()
  end

  -- create popup once
  if not self.list then
    local frame = CreateFrame("Frame", nil, self.root, "BackdropTemplate")
    frame:SetPoint("CENTER", self.root, "CENTER", 0, 0)
    frame:SetSize(360, 220)
    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile=true, tileSize=16, edgeSize=16,
      insets={ left=3, right=3, top=3, bottom=3 }
    })
    frame:SetBackdropColor(0,0,0,0.92)
    frame:SetFrameStrata("DIALOG")
    MakeDraggable(frame)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() UI:CloseTotemList() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetWidth(300)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    self.listTitle = title

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -36)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1,1)
    scroll:SetScrollChild(content)

    self.list = frame
    self.listScroll = scroll
    self.listContent = content
  end

  -- populate
  self.listElement = element
  self.list:Show()
  self.listTitle:SetText(string.upper(element).." TOTEMS")

  self:ClearTotemRows()

  local y = -2
  for _, t in ipairs(TOTEMS) do
    if t.element == element then
      local row = CreateFrame("Button", nil, self.listContent)
      row:SetSize(320, 36)
      row:SetPoint("TOPLEFT", 6, y)
      y = y - 38

      local icon = row:CreateTexture(nil, "ARTWORK")
      icon:SetSize(32,32)
      icon:SetPoint("LEFT", 0, 0)
      icon:SetTexture("Interface/ICONS/"..t.icon)

      local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      nameFS:SetPoint("LEFT", icon, "RIGHT", 8, 0)
      nameFS:SetWidth(260) -- fixed width prevents overlap
      nameFS:SetJustifyH("LEFT")
      nameFS:SetWordWrap(false)
      nameFS:SetText(t.name .. string.format(" (U:%d S:%d L:%d)", t.unlock, t.summon, t.unlockLevel))

      local locked = not TotemTender.State.unlocked[t.id]
      local enoughToUnlock = TotemTender.CanUnlock(t)
      local canSummon = TotemTender.CanSummon(t)

      local shade = row:CreateTexture(nil, "OVERLAY")
      shade:SetAllPoints()
      shade:SetColorTexture(0,0,0, locked and 0.5 or 0)

      row:SetScript("OnEnter", function()
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(t.name)
        GameTooltip:AddLine("Unlock Level: "..t.unlockLevel, 1,1,1)
        GameTooltip:AddLine("Unlock Cost: "..t.unlock, .8,.9,1)
        GameTooltip:AddLine("Summon Cost: "..t.summon, .8,.9,1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Influence:")
        for k,v in pairs(t.influence) do
          local label = (k=="env") and "Environment" or (k:gsub("^%l", string.upper))
          local sign = v>=0 and "+" or ""
          GameTooltip:AddLine(" - "..label..": "..sign..v, .9,.9,.9)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", GameTooltip_Hide)

      row:SetScript("OnClick", function()
        if locked then
          if enoughToUnlock then
            StaticPopupDialogs["TOTEM_TENDER_UNLOCK"] = {
              text = string.format("Unlock %s for %d Harmony?", t.name, t.unlock),
              button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
              OnAccept = function() TotemTender.UnlockTotem(t); UI:OpenTotemList(element) end
            }
            StaticPopup_Show("TOTEM_TENDER_UNLOCK")
          else
            UIErrorsFrame:AddMessage("Not enough Harmony to unlock!", 1, .2, .2)
          end
        else
          if canSummon then
            TotemTender.SummonTotem(t)
          else
            UIErrorsFrame:AddMessage("Cannot summon (cost or limit)", 1, .8, .2)
          end
        end
      end)
    end
  end

  -- size scroll content
  self.listContent:SetHeight(math.abs(y))
end

-- ---------------------------------------------------
-- summoned totems on scene
-- ---------------------------------------------------
function UI:AddTotemWidget(inst)
  self:Create()
  local w = CreateFrame("Frame", nil, self.scene)
  w:SetSize(30, 30)

  local width, height = self.scene:GetWidth(), self.scene:GetHeight()
  local x = math.random(10, math.max(10, width - 40))
  local y = math.random(10, math.max(10, height - 40))
  w:SetPoint("BOTTOMLEFT", x, y)

  local tex = w:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture("Interface/ICONS/"..inst.icon)
  tex:SetAlpha(0.95)

  w:SetScript("OnEnter", function()
    GameTooltip:SetOwner(w, "ANCHOR_RIGHT")
    GameTooltip:AddLine(inst.name)
    GameTooltip:Show()
  end)
  w:SetScript("OnLeave", GameTooltip_Hide)

  table.insert(self.totemWidgets, w)
end