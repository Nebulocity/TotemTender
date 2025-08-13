----------------------------------------------------------------
-- Core functions for the game
----------------------------------------------------------------

local ADDON, TotemTender = ...
local CONST, ENVS = TotemTender.CONST, TotemTender.ENVIRONMENTS

TotemTenderDB = TotemTenderDB or {}


----------------------------------------------------------------
-- This copies a table, even if it has nested tables inside
----------------------------------------------------------------
local function copyTable(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k,v in pairs(t) do r[k] = copyTable(v) end
  return r
end


----------------------------------------------------------------
-- This returns a fresh baseline when the addon inits/resets
-- To reset the game:
-- 		TotemTenderDB = copyTable(defaultState())
----------------------------------------------------------------
local function defaultState(envIndex)
  local envIndexSafe = math.max(1, math.min(envIndex or 1, #ENVS))
  local env = ENVS[envIndexSafe]
  return {
    envIndex = envIndexSafe,
    baseEnv = copyTable(env),
    env = copyTable(env.base),
    envHealth = CONST.START_ENV_HEALTH,
    level = CONST.START_LEVEL,
    xp = 0,
    harmony = CONST.START_HARMONY,
    unlocked = {},
    activeTotems = {},
  }
end

----------------------------------------------------------------
-- This This will reset a specific level back to default values
----------------------------------------------------------------
function TotemTender.ResetLevel(levelId)
  TotemTender.State = defaultState(levelId)
  TotemTenderDB.state = copyTable(TotemTender.State)
  TotemTender.UI:Show()
  if TotemTender.State and TotemTender.State.baseEnv and TotemTender.State.baseEnv.art then
    TotemTender.UI:SetSceneBackground(TotemTender.State.baseEnv.art)
  end
  TotemTender.UI:ApplySceneMood(TotemTender.State.envHealth)
  TotemTender.UI:Refresh()
end

----------------------------------------------------------------
-- Loads state from SavedVariables, otherwise inits a new game
----------------------------------------------------------------
local function loadOrInit()
  if TotemTenderDB.state and TotemTenderDB.state.baseEnv then
    TotemTender.State = TotemTenderDB.state
  else
    TotemTender.ResetLevel(1)
  end
  if TotemTender.State and TotemTender.State.baseEnv and TotemTender.State.baseEnv.art then
    TotemTender.UI:SetSceneBackground(TotemTender.State.baseEnv.art)
  end
  TotemTender.UI:ApplySceneMood(TotemTender.State.envHealth)
end

----------------------------------------------------------------
-- Starts the ticker for the game to run
----------------------------------------------------------------
local function startTicker()
  if TotemTender._ticker then TotemTender._ticker:Cancel() end
  TotemTender._ticker = C_Timer.NewTicker(CONST.TICK_SECONDS, function()
    TotemTender.Tick()
    TotemTenderDB.state = TotemTender.State
  end)
end

----------------------------------------------------------------
-- Fast filtering/grouping of totems by element
----------------------------------------------------------------
local function groupTotemsByElement()
  TotemTender.TOTEMS_BY_ELEM = { earth = {}, air = {}, fire = {}, water = {} }
  for _, t in ipairs(TotemTender.TOTEMS or {}) do
    table.insert(TotemTender.TOTEMS_BY_ELEM[t.element], t)
  end
end

----------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------
SLASH_TOTEMTENDER1 = "/totem"
SLASH_TOTEMTENDER2 = "/totemtender"
SlashCmdList["TOTEMTENDER"] = function(msg)
  if not TotemTender.UI.root or not TotemTender.UI.root:IsShown() then TotemTender.UI:Show() else TotemTender.UI:Hide() end
end

----------------------------------------------------------------
-- Event frame
----------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "TotemTender" then
    groupTotemsByElement()
    TotemTender.UI:Create()
    loadOrInit()
  elseif event == "PLAYER_LOGIN" then
    startTicker()
  end
end)