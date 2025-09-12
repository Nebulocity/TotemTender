local ADDON, TotemTender = ...

-- Explicit aliases to avoid undeclared globals
local CONST = TotemTender.CONST
local ENVS = TotemTender.LEVELS

TotemTender.Running = false
TotemTender._ticker = TotemTender._ticker
TotemTenderDB = TotemTenderDB or {}

-- ----------------------------------------------
-- Deep copy for tables (handles nested tables)
-- ----------------------------------------------
local function deepCopy(table)
  if type(table) ~= "table" then return table end
  local out = {}
  for key, value in pairs(table) do out[key] = deepCopy(value) end
  return out
end


-- ----------------------------------------------
-- Build a default state
-- ----------------------------------------------
local function buildDefaultState(envIndex)
  local index = math.max(1, math.min(envIndex or 1, #ENVS))
  local environment = ENVS[index]
  return {
    envIndex = index,
    baseEnv = deepCopy(environment),
    env = deepCopy(environment.base),
    envHealth = CONST.START_ENV_HEALTH,
    level = CONST.START_LEVEL,
    xp = 0,
    harmony = CONST.START_HARMONY,
    unlocked = {},
    activeTotems = {},
    cooldowns = {},
  }
end

-- ----------------------------------------------
-- Unlocks all free totems by default
-- ----------------------------------------------
local function autoUnlockZeroCost()
  local totemState = TotemTender.State
  totemState.unlocked = totemState.unlocked or {}
  for _, totem in ipairs(TotemTender.TOTEMS or {}) do
    if (totem.unlock or 0) == 0 and (totemState.level or 1) >= (totem.unlockLevel or 1) then
      totemState.unlocked[totem.id] = true
    end
  end
end


-- ----------------------------------------------
-- Resets a level (NOT the entire game!)
-- ----------------------------------------------
function TotemTender.ResetLevel(levelId)
  TotemTender.State   = buildDefaultState(levelId)
  TotemTenderDB.state = deepCopy(TotemTender.State)
  autoUnlockZeroCost() 

  TotemTender.UI:Show()
  if TotemTender.State and TotemTender.State.baseEnv and TotemTender.State.baseEnv.art then
    TotemTender.UI:SetSceneBackground(TotemTender.State.baseEnv.art)
  end
  
  TotemTender.UI:ApplySceneMood(TotemTender.State.envHealth)
  TotemTender.UI:Refresh()
end

-- ----------------------------------------------
-- Load from SavedVariables, or create new game
-- ----------------------------------------------
local function loadOrInit()
  if TotemTenderDB.state and TotemTenderDB.state.baseEnv then
    TotemTender.State = TotemTenderDB.state
  else
    TotemTender.ResetLevel(1)
  end

  autoUnlockZeroCost()

  if TotemTender.State and TotemTender.State.baseEnv and TotemTender.State.baseEnv.art then
    TotemTender.UI:SetSceneBackground(TotemTender.State.baseEnv.art)
  end

  TotemTender.UI:ApplySceneMood(TotemTender.State.envHealth)
end

-- ----------------------------------------------
-- Start or restart the ticker
-- ----------------------------------------------
local function startTicker()
  if TotemTender._ticker then TotemTender._ticker:Cancel() end
  TotemTender._ticker = C_Timer.NewTicker(CONST.TICK_SECONDS, function()
    if TotemTender.Running then
      TotemTender.Tick()
      TotemTenderDB.state = TotemTender.State
    end
  end)
end


-- ----------------------------------------------
-- Group all totems by element
-- ----------------------------------------------
local function groupTotemsByElement()
  TotemTender.TOTEMS_BY_ELEM = { earth = {}, air = {}, fire = {}, water = {} }
  for _, totem in ipairs(TotemTender.TOTEMS or {}) do
    table.insert(TotemTender.TOTEMS_BY_ELEM[totem.element], totem)
  end
end

-- ----------------------------------------------
-- Slash commands for the WoW console
-- ----------------------------------------------
SLASH_TOTEMTENDER1 = "/totem"
SLASH_TOTEMTENDER2 = "/totemtender"
SlashCmdList["TOTEMTENDER"] = function(msg)
  -- match pattern to get any messages passed
  msg = (msg or ""):lower():gsub("^%s+", "")

  -- Resets the current level
  if msg == "reset" then
    TotemTender.ResetLevel(1)
    TotemTenderDB.state = TotemTender.State
    print("|cff33ff99TotemTender:|r reset to defaults.")
    return
    
  -- Clears/wipes SavedVariables to reset the entire game
  elseif msg == "wipe" or msg == "clear" then
    if type(wipe) == "function" then wipe(TotemTenderDB) else TotemTenderDB = {} end
    TotemTender.ResetLevel(1)
    print("|cff33ff99TotemTender:|r SavedVariables wiped.")
    return
    
  -- Sets the Level, Harmony, and Environment Health for the current level
  elseif msg:match("^set%s") then
    local Level, Health, EnvHealth = msg:match("^set%s+(%d+)%s+(%d+)%s*(%d*)")
    if Level and Health then
      local totemState   = TotemTender.State
      totemState.level   = tonumber(Level)
      totemState.harmony = tonumber(Health)
      if EnvHealth ~= "" then totemState.envHealth = tonumber(EnvHealth) end
      
      autoUnlockZeroCost()
      TotemTender.UI:Refresh()

      print(("|cff33ff99TotemTender:|r set Level=%d Harmony=%d%s")
        :format(totemState.level, totemState.harmony, EnvHealth ~= "" and ("Env Health=" .. totemState.envHealth) or ""))
    end
    return

  -- Sets the level to a specific level
  elseif msg:match("^level%s+%d+") then
    local n = tonumber(msg:match("^level%s+(%d+)"))
    if n and n >= 1 and n <= #ENVS then
      TotemTender.ResetLevel(n)
      print("|cff33ff99TotemTender:|r set level to " .. n .. " (" .. (ENVS[n].name or "Unknown") .. ")")
    end
    return

  -- Goes to the next level
  elseif msg == "next" then
    local S = TotemTender.State or {}
    local nextIndex = math.min((S.envIndex or 1) + 1, #ENVS)
    TotemTender.ResetLevel(nextIndex)
    print("|cff33ff99TotemTender:|r advanced to level " .. nextIndex)
    return

  -- Gets rid of all totems
  elseif msg == "unsummon all" then
    local S = TotemTender.State or {}
    for i = #(S.activeTotems or {}), 1, -1 do
      local inst = S.activeTotems[i]
      TotemTender.DismissTotem(inst)
    end
    print("|cff33ff99TotemTender:|r all totems dismissed.")
    return

  -- Opens the debug console
  elseif msg:match("^debug") then
    -- Abort in case debug.lua didn't load yet
    if not TotemTender.Debug then
      print("|cff33ff99TotemTender:|r Debug module not loaded. Make sure 'debug.lua' is in the .toc (before core.lua).")
      return
    end

    local sub = (msg:match("^debug%s+(.*)$") or ""):lower()

    -- Toggles debug
    if sub == "" or sub == "toggle" then
      TotemTender.Debug:Toggle()
      print("|cff33ff99TotemTender:|r Debug toggled.")

    -- Turns debug on
    elseif sub == "on" then
      TotemTender.Debug:Show()
      print("|cff33ff99TotemTender:|r Debug shown.")

    -- Turns debug off
    elseif sub == "off" then
      TotemTender.Debug:Hide()
      print("|cff33ff99TotemTender:|r Debug hidden.")

    -- Clears debug
    elseif sub == "clear" then
      TotemTender.Debug:Clear()
      print("|cff33ff99TotemTender:|r Debug cleared.")

    -- Pauses debug
    elseif sub == "pause" then
      TotemTender.Debug.paused = true
      TotemTender.Debug:State("Paused logging")

    -- Resumes debug
    elseif sub == "resume" then
      TotemTender.Debug.paused = false
      TotemTender.Debug:State("Resumed logging")

    -- Handles all other commands
    else

      -- Toggles events/tick/state debugging on
      local which, val = sub:match("^(events|tick|state)%s+(on|off)$")
      if which and val then
        TotemTender.Debug.filters[which] = (val == "on")
        TotemTender.Debug:State(("Filter '%s' %s"):format(which, val:upper()))
      
      -- Nothing else was passed or understood, print help
      else
        print("|cff33ff99TotemTender:|r debug commands:")
        print("  /totemtender debug on|off|toggle|clear|pause|resume")
        print("  /totemtender debug events|tick|state on|off")
      end
    end
    return
  end

  -- Toggle the addon window
  if not TotemTender.UI.root or not TotemTender.UI.root:IsShown() then
    TotemTender.UI:Show()
  else
    TotemTender.UI:Hide()
  end
end


-- -----------------------------------------------
-- Register addon loaded and player login events
-- -----------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "TotemTender" then
    groupTotemsByElement()
    TotemTender.UI:Create()
    loadOrInit()
  elseif event == "PLAYER_LOGIN" then
    -- Do not auto-run; just prepare ticker for when user presses Start
    TotemTender.Pause() -- ensure stopped
    startTicker()      -- builds ticker but it won't tick unless Running=true
  end
end)


-- ----------------------------------------------
-- Start the game
-- ----------------------------------------------
function TotemTender.Start()
  
  if TotemTender.UI and TotemTender.UI.CloseTotemList then TotemTender.UI:CloseTotemList() end

  TotemTender.Running = true

  -- (re)start ticker if needed
  if not TotemTender._ticker then
    TotemTender._ticker = C_Timer.NewTicker(TotemTender.CONST.TICK_SECONDS, function()
      if TotemTender.Running then
        TotemTender.Tick()
        TotemTenderDB.state = TotemTender.State
      end
    end)
  end
  if TotemTender.UI and TotemTender.UI.UpdateRunButtons then
    TotemTender.UI:UpdateRunButtons()
    TotemTender.UI:BannerToast("Totem Tender", "Started")
  end
end

-- ----------------------------------------------
-- Pause the game
-- ----------------------------------------------
function TotemTender.Pause()
  if TotemTender.UI and TotemTender.UI.CloseTotemList then TotemTender.UI:CloseTotemList() end
  TotemTender.Running = false
  if TotemTender._ticker then
    TotemTender._ticker:Cancel()
    TotemTender._ticker = nil
  end
  if TotemTender.UI and TotemTender.UI.UpdateRunButtons then
    TotemTender.UI:UpdateRunButtons()
    TotemTender.UI:BannerToast("Totem Tender", "Paused")
  end
end

-- ----------------------------------------------
-- Reset the current level
-- ----------------------------------------------
function TotemTender.Reset()
  if TotemTender.UI and TotemTender.UI.CloseTotemList then TotemTender.UI:CloseTotemList() end

  local idx = (TotemTender.State and TotemTender.State.envIndex) or 1

  -- Drop existing widgets/instances without starting cooldowns
  local oldS = TotemTender.State
  if oldS and oldS.activeTotems then
    for i = #oldS.activeTotems, 1, -1 do
      local inst = oldS.activeTotems[i]
      if TotemTender.UI and TotemTender.UI.RemoveTotemWidget then
        TotemTender.UI:RemoveTotemWidget(inst)
      end
      table.remove(oldS.activeTotems, i)
    end
  end
  if TotemTender.UI and TotemTender.UI.ClearAllTotemWidgets then
    TotemTender.UI:ClearAllTotemWidgets()
  end

  TotemTender.Pause()
  TotemTender.ResetLevel(idx)  -- stays paused after
  if TotemTender.UI and TotemTender.UI.UpdateRunButtons then
    TotemTender.UI:UpdateRunButtons()
  end
end



-- ----------------------------------------------
-- Dismisses a totem
-- ----------------------------------------------
function TotemTender.DismissTotem(instance)
  local totemState = TotemTender.State
  
  if not (totemState and totemState.activeTotems) then return end

  local removed = false
  
  for i = #totemState.activeTotems, 1, -1 do
    local inst = totemState.activeTotems[i]
    if inst == instance or (instance and inst.id == instance.id and inst.element == instance.element) then
      
      -- Removed the widget first
      if TotemTender.UI and TotemTender.UI.RemoveTotemWidget then
        TotemTender.UI:RemoveTotemWidget(inst)
      end

      -- Then remove the totem from active totems
      table.remove(totemState.activeTotems, i)

      -- start cooldown on that totem ID (MOVE THIS TO WHEN IT'S CREATED)
      -- if inst.id and TotemTender.CONST and TotemTender.CONST.TOTEM_COOLDOWN then
      --  TotemTender._StartCooldown(inst.id, TotemTender.CONST.TOTEM_COOLDOWN)
      --end
      
      removed = true
      break
    end
  end

  -- If the totem wasn't being tracked anyways, remove the widget just in case.
  if not removed and TotemTender.UI and TotemTender.UI.RemoveTotemWidget then
    TotemTender.UI:RemoveTotemWidget(instance)
  end

  -- Refresh the UI
  if TotemTender.UI and TotemTender.UI.Refresh then
    TotemTender.UI:Refresh()
  end
end



-- ----------------------------------------------
-- The sound when we plop a totem on the ground
-- ----------------------------------------------
function TotemTender.PlayTotemSummonSound()
  local path = "Interface\\AddOns\\TotemTender\\resources\\TotemBirthGenericA.ogg"
  if PlaySoundFile then
    pcall(PlaySoundFile, path, "SFX")
  end
end


