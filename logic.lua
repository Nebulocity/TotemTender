print("TotemTender: loading logic.lua")

local ADDON, TotemTender = ...

-- Explicit aliases to avoid undeclared globals
local CONST = TotemTender.CONST
local ENVS = TotemTender.LEVELS

-- ------------------------------
-- Math helpers
-- ------------------------------
local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

-- ------------------------------
-- Misc helpers
-- ------------------------------
-- local function maybeStartObjective(S)
-- if S.objective then return end
-- Start one when player is stable or just leveled (light rule of thumb)
-- if S.level % 2 == 1 and S.harmony >= 40 then
-- S.objective = { kind="hold_balance", ticks=0, goal=4 } -- keep balance for 4 ticks
-- TotemTender.UI:BannerToast("New Contract", "Maintain balance for a short while")
-- end
-- end

-- local function updateObjective(S)
-- if not S.objective then return end
-- local o = S.objective
-- if o.kind == "hold_balance" then
-- local target, tol = CONST.TARGET_BALANCE, CONST.BALANCE_TOLERANCE
-- local e=S.env
-- local ok = (math.abs(e.earth-target)<=tol and math.abs(e.air-target)<=tol
-- and math.abs(e.fire-target)<=tol and math.abs(e.water-target)<=tol)
-- if ok then o.ticks = o.ticks + 1 else o.ticks = 0 end
-- if o.ticks >= o.goal then
-- S.harmony = math.min(9999, S.harmony + 25)
-- TotemTender.UI:BannerToast("Contract Cleared", "+25 Harmony")
-- S.objective = nil
-- end
-- end
-- end



-- ------------------------------
-- Harmony calculation
-- WHY: reward balanced environments, penalize extremes
-- ------------------------------
local function computeHarmonyDelta(state)
  local target = CONST.TARGET_BALANCE
  local tol = CONST.BALANCE_TOLERANCE
  local env = state.env
  local worstGap = math.max(
    math.abs(env.earth - target),
    math.abs(env.air - target),
    math.abs(env.fire - target),
    math.abs(env.water - target)
  )

  if worstGap <= tol then
    return CONST.HARMONY_GAIN_BASE + math.floor((tol - worstGap) / 2)
  else
    return -(CONST.HARMONY_LOSS_BASE + math.floor((worstGap - tol) / 5))
  end
end

-- ------------------------------
-- Apply each active totem's influence to the environment
-- ------------------------------
local function applyActiveTotemAffinities(state)
  for _, totem in ipairs(state.activeTotems) do
    for key, delta in pairs(totem.influence) do
      if key == "env" then
        state.envHealth = clamp(state.envHealth + delta, 0, 100)
      else
        state.env[key] = clamp(state.env[key] + delta, 0, 100)
      end
    end
  end
end

-- ------------------------------
-- Drift environment back toward its base by difficulty
-- ------------------------------
local function applyEnvironmentDrift(state)
  local base = state.baseEnv.base
  for key, baseValue in pairs(base) do
    local current = state.env[key]
    local towardBase = (baseValue - current)
    local difficultyPull = math.max(1, state.baseEnv.difficulty) * 0.4
    state.env[key] = current + math.floor(towardBase * 0.05 * difficultyPull)
  end
end

-- ------------------------------
-- Leveling from positive harmony deltas
-- ------------------------------
local function applyLeveling(state, deltaHarmony)
  if deltaHarmony <= 0 then return end
  state.xp = state.xp + deltaHarmony
  local needed = 50 + (state.level * 10)
  while state.xp >= needed and state.level < CONST.MAX_LEVEL do
    state.xp    = state.xp - needed
    state.level = state.level + 1
    TotemTender.UI:BannerToast("Shaman Level Up!", "Level " .. state.level)
    needed = 50 + (state.level * 10)
  end
end

-- ------------------------------
-- End conditions: collapse vs. thrive
-- ------------------------------
local function checkEndConditions(state)
  if state.envHealth <= 0 then
    TotemTender.UI:BannerToast("Environment Collapsed", "Try a friendlier zone")
    return "loss"
  end
  if state.level >= CONST.MAX_LEVEL and state.envHealth >= 80 then
    TotemTender.UI:BannerToast("Environment Thrives!", "You are ready for the next zone")
    return "win"
  end
end


-- ------------------------------
-- Public: main game tick (no objectives; event hook added)
-- ------------------------------
function TotemTender.Tick()
  local totemState = TotemTender.State
  if not totemState then return end

  -- Optional pacing flags (auto-off unless defined in data.lua)
  local HAS_DURATION = (TotemTender.CONST.TOTEM_DURATION ~= nil)
  local HAS_COOLDOWN = (TotemTender.CONST.TOTEM_COOLDOWN ~= nil)
  local HAS_UPKEEP   = (TotemTender.CONST.TOTEM_UPKEEP ~= nil)

  local DURATION     = (TotemTender.CONST.TOTEM_DURATION or 45)
  local COOLDOWN     = (TotemTender.CONST.TOTEM_COOLDOWN or 30)
  local UPKEEP       = (TotemTender.CONST.TOTEM_UPKEEP ~= nil) and TotemTender.CONST.TOTEM_UPKEEP or 1

  -- Bootstrap new fields (harmless if already present)
  totemState.cooldowns = totemState.cooldowns or {} -- [totemId] = seconds left
  -- NOTE: S.objective intentionally not used (objectives disabled)

  -- 1) Active totems influence the world this tick
  applyActiveTotemAffinities(totemState)

  -- 2) The world drifts toward its base (by difficulty)
  applyEnvironmentDrift(totemState)

  -- 3) Harmony delta from current balance, then leveling
  local delta = computeHarmonyDelta(totemState)
  totemState.harmony   = clamp(totemState.harmony + delta, 0, 9999)
  applyLeveling(totemState, delta)

  if TotemTender.Debug then
    TotemTender.Debug:Tick((
      "ΔH=%+.1f H=%d Env:{E=%d A=%d F=%d W=%d} Health=%d"
    ):format(delta, totemState.harmony, totemState.env.earth, totemState.env.air, totemState.env.fire, totemState.env.water, totemState.envHealth))
  end


  -- 4) Environment health nudges (close to target rises, otherwise falls)
  local avg = (totemState.env.earth + totemState.env.air + totemState.env.fire + totemState.env.water) / 4
  local closeToTarget = (avg >= TotemTender.CONST.TARGET_BALANCE - 5)
      and (avg <= TotemTender.CONST.TARGET_BALANCE + 5)
  if closeToTarget then
    totemState.envHealth = clamp(totemState.envHealth + 2, 0, 100)
  else
    totemState.envHealth = clamp(totemState.envHealth - 1, 0, 100)
  end

  -- 5) (Optional) Totem upkeep + durations + expiry → cooldowns
  if HAS_DURATION or HAS_UPKEEP then
    local upkeepCost = 0

    for _, inst in ipairs(totemState.activeTotems) do
      -- Upkeep (only if enabled)
      if HAS_UPKEEP then
        local u = inst.upkeep
        if u == nil then u = UPKEEP end
        upkeepCost = upkeepCost + (u or 0)
      end

      -- Duration ticking (only if enabled)
      if HAS_DURATION then
        if inst.remaining == nil then
          inst.remaining = DURATION -- backfill existing summons
        else
          inst.remaining = math.max(0, inst.remaining - TotemTender.CONST.TICK_SECONDS)
        end
      end
    end

    if HAS_UPKEEP and upkeepCost > 0 then
      totemState.harmony = clamp(totemState.harmony - upkeepCost, 0, 9999)
    end

    -- Expire finished totems and start cooldowns (if enabled)
    for i = #totemState.activeTotems, 1, -1 do
      local inst = totemState.activeTotems[i]
      local expired = HAS_DURATION and ((inst.remaining or 0) <= 0)
      if expired then
        if TotemTender.UI and TotemTender.UI.RemoveTotemWidget then
          TotemTender.UI:RemoveTotemWidget(inst)
        end
        table.remove(totemState.activeTotems, i)
        if HAS_COOLDOWN and inst.id then
          TotemTender._StartCooldown(inst.id, COOLDOWN)
        end
      end
    end
  end

  -- 6) (Optional) Cooldowns tick down
  if HAS_COOLDOWN then
    for id, secs in pairs(totemState.cooldowns) do
      local newv = math.max(0, secs - TotemTender.CONST.TICK_SECONDS)
      if newv <= 0 then totemState.cooldowns[id] = nil else totemState.cooldowns[id] = newv end
    end
  end

  -- 7) Ambient world nudges (keep some steering pressure)
  if math.random() < 0.15 then
    local r = math.random()
    if r < 0.34 then
      totemState.env.air = clamp(totemState.env.air + 3, 0, 100)
      if TotemTender.UI and TotemTender.UI.BannerToast then
        TotemTender.UI:BannerToast("Gusty Skies", "+Air drift")
      end
      if TotemTender.Debug then TotemTender.Debug:Event(("Gusty Skies → Air=%d"):format(totemState.env.air)) end
    elseif r < 0.67 then
      totemState.env.fire = clamp(totemState.env.fire + 3, 0, 100)
      if TotemTender.UI and TotemTender.UI.BannerToast then
        TotemTender.UI:BannerToast("Dry Heat", "+Fire drift")
      end
      if TotemTender.Debug then TotemTender.Debug:Event(("Dry Heat → Fire=%d"):format(totemState.env.fire)) end
    else
      totemState.env.water = clamp(totemState.env.water + 3, 0, 100)
      if TotemTender.UI and TotemTender.UI.BannerToast then
        TotemTender.UI:BannerToast("Light Rain", "+Water drift")
      end
      if TotemTender.Debug then TotemTender.Debug:Event(("Light Rain → Water=%d"):format(totemState.env.water)) end
    end
  end


  -- 8) FUTURE DYNAMIC EVENTS (rain/heat/cold/plague) — hook here
  -- TODO: When ready, add a lightweight event system:
  --   if not S.events then S.events = {} end
  --   TotemTender.BeginEvent(S, "rain", { duration=60, water=+4 })
  --   TotemTender.UpdateEvents(S, TotemTender.CONST.TICK_SECONDS)   -- apply per-tick effects
  --   TotemTender.ClearExpiredEvents(S)
  -- Keep this section; it runs after base drift and upkeep so players must counterbalance.

  -- 9) Scene mood tint & UI updates
  if TotemTender.UI and TotemTender.UI.ApplySceneMood then
    TotemTender.UI:ApplySceneMood(totemState.envHealth)
  end

  -- 10) Win/Loss & level transition
  local outcome = checkEndConditions(totemState)

  -- if outcome == "loss" then
  --   TotemTender.ResetLevel(1)
  -- elseif outcome == "win" then
  --   local nextIndex = math.min(S.envIndex + 1, #TotemTender.LEVELS)
  --   TotemTender.ResetLevel(nextIndex)
  -- end

  if TotemTender.UI and TotemTender.UI.Refresh then
    TotemTender.UI:Refresh()
  end
end

-- ------------------------------
-- Capability checks
-- ------------------------------
function TotemTender.CanUnlock(totem)
  local totemState = TotemTender.State
  if not (totemState and totem and totem.id) then return false end
  local unlocked = totemState.unlocked and totemState.unlocked[totem.id]
  return (totemState.level >= totem.unlockLevel) and (totemState.harmony >= totem.unlock) and not unlocked
end

function TotemTender.CanSummonReason(totem)

  if TotemTender._CleanupExpiredActiveTotems then
    TotemTender._CleanupExpiredActiveTotems()
  end



  local totemState = TotemTender.State
  if not (totemState and totem and totem.id) then return "internal" end

 
  -- 1) Locked?
  if not (totemState.unlocked and totemState.unlocked[totem.id]) then
    return "locked"
  end

  -- 2) Global active limit?
  if #totemState.activeTotems >= (TotemTender.CONST and TotemTender.CONST.SUMMON_LIMIT or 6) then
    return "limit"
  end

  -- 3) Cooldown?
  totemState.cooldowns   = totemState.cooldowns   or {}
  totemState.cooldownEndAt = totemState.cooldownEndAt or {}
  local id = totem.id
  local now = GetTime()
  local endAt = totemState.cooldownEndAt[id]
  local cd = totemState.cooldowns[id] or 0

  -- Prefer wall-clock cooldown if we have one.
  if endAt then
    if now < endAt then
      return "cooldown"
    else
      -- expired → clear both trackers
      totemState.cooldownEndAt[id] = nil
      totemState.cooldowns[id]     = nil
    end
  elseif cd > 0 then
    -- Legacy tick-based cooldown: only honor it if we’ve actually summoned this totem
    local hadHistory = totemState._hadEverSummoned and totemState._hadEverSummoned[id]
    if hadHistory then
      return "cooldown"
    else
      -- stray pre-first-summon cooldown → clear it
      totemState.cooldowns[id] = nil
    end
  end

  -- 4) Already active instance?
  for _, inst in ipairs(totemState.activeTotems) do
    if inst.id == id then
      return "active"
    end
  end

  -- 5) Cost?
  if (totemState.harmony or 0) < (totem.summon or 0) then
    return "cost"
  end

  return nil
end


function TotemTender.CanSummon(totem)
  local totemState = TotemTender.State
  if not (totemState and totem and totem.id) then return false end
  return TotemTender.CanSummonReason(totem) == nil
end

-- ------------------------------
-- Actions
-- ------------------------------
function TotemTender.UnlockTotem(totem)
  if TotemTender.CanUnlock(totem) then
    TotemTender.State.harmony = TotemTender.State.harmony - totem.unlock
    TotemTender.State.unlocked[totem.id] = true
    TotemTender.UI:BannerToast("Unlocked", totem.name)
    TotemTender.UI:Refresh()
  end
end

function TotemTender.SummonTotem(totem)
  local totemState = TotemTender.State
  if not totemState or not totem or not totem.id then return false end

  local why = TotemTender.CanSummonReason and TotemTender.CanSummonReason(totem)
  if why ~= nil then return false end

  -- Ensure tables exist
  totemState.activeTotems = totemState.activeTotems or {}
  totemState.cooldowns    = totemState.cooldowns or {}

  -- Remove any existing totem of the same element (and start its cooldown if it truly ran)
  for i = #totemState.activeTotems, 1, -1 do
    local inst = totemState.activeTotems[i]
    if inst.element == totem.element then
      if TotemTender.UI and TotemTender.UI.RemoveTotemWidget then
        TotemTender.UI:RemoveTotemWidget(inst)
      end
      table.remove(totemState.activeTotems, i)  -- FIX: was S.activeTotems

      if TotemTender.CONST and TotemTender.CONST.TOTEM_COOLDOWN and inst.id then
        local ran = inst.startedAt and (GetTime() - inst.startedAt >= 0.01)
        if ran then
          TotemTender._StartCooldown(inst.id, TotemTender.CONST.TOTEM_COOLDOWN)
        end
      end
      break
    end
  end

  -- Pay the summon cost
  totemState.harmony = math.max(0, (totemState.harmony or 0) - (totem.summon or 0))  -- FIX: was S.harmony

  -- Duration / upkeep
  local DURATION = (totem.duration ~= nil) and totem.duration or (TotemTender.CONST and TotemTender.CONST.TOTEM_DURATION)
  local UPKEEP   = (totem.upkeep   ~= nil) and totem.upkeep   or (TotemTender.CONST and TotemTender.CONST.TOTEM_UPKEEP)

  -- Create the active instance
  local inst = {
    id        = totem.id,
    name      = totem.name,
    icon      = totem.icon,
    element   = totem.element,
    affinity = totem.affinity,
    remaining = DURATION,
    upkeep    = UPKEEP,
    startedAt = GetTime(),
    _initDuration = DURATION,
  }
  table.insert(totemState.activeTotems, inst)  -- FIX: was S.activeTotems

  -- Mark history
  totemState._hadEverSummoned = totemState._hadEverSummoned or {}  -- FIX block
  totemState._hadEverSummoned[totem.id] = true

  -- UI hooks (unchanged)
  if TotemTender.UI and TotemTender.UI.AddTotemWidget then
    TotemTender.UI:AddTotemWidget(inst)
    if TotemTender.PlayTotemSummonSound then
      TotemTender.PlayTotemSummonSound()
    end
  end
  if TotemTender.UI and TotemTender.UI.Refresh then
    TotemTender.UI:Refresh()
  end
  if TotemTender.Debug and TotemTender.Debug.State then
    TotemTender.Debug:State(("Summoned %s (%s)"):format(totem.name, totem.element))
  end

  return true
end


-- ------------------------------------------
-- What are we missing to unlock this totem?
-- ------------------------------------------
function TotemTender.MissingForUnlock(totem)
  local totemState = TotemTender.State
  local needLevel   = math.max(0, (totem.unlockLevel or 1) - (totemState.level or 1))
  local needHarmony = math.max(0, (totem.unlock or 0) - (totemState.harmony or 0))
  return needLevel, needHarmony
end

-- ------------------------------------------
-- Persist immediately on unlock
-- ------------------------------------------
-- local _oldUnlock = TotemTender.UnlockTotem
-- function TotemTender.UnlockTotem(totem)
--   _oldUnlock(totem)
--   TotemTenderDB.state = TotemTender.State
-- end

-- ------------------------------------------
-- Start a cooldown for a totem id and remember the end time for smooth UI countdowns
-- ------------------------------------------
function TotemTender._StartCooldown(id, seconds)
  local totemState = TotemTender.State
  if not (totemState and id and seconds and seconds > 0) then return end
  totemState.cooldowns    = totemState.cooldowns    or {}
  totemState.cooldownEndAt = totemState.cooldownEndAt or {}

  -- game logic gate (decrements per Tick)
  totemState.cooldowns[id] = seconds
  -- wall-clock expiry for UI
  totemState.cooldownEndAt[id] = GetTime() + seconds

  -- mark that this totem has truly been summoned before
  totemState._hadEverSummoned = totemState._hadEverSummoned or {}
  totemState._hadEverSummoned[id] = true
end


-- ------------------------------------------
-- Clean expired totems
-- ------------------------------------------
function TotemTender._CleanupExpiredActiveTotems()
  local totemState = TotemTender.State
  if not (totemState and totemState.activeTotems) then return end

  local HAS_DURATION = (TotemTender.CONST and TotemTender.CONST.TOTEM_DURATION ~= nil)
  if not HAS_DURATION then return end

  local defaultDur = TotemTender.CONST.TOTEM_DURATION or 0
  local cdLen = TotemTender.CONST.TOTEM_COOLDOWN or 0
  local now = GetTime()

  for i = #totemState.activeTotems, 1, -1 do
    local inst = totemState.activeTotems[i]
    local start = inst.startedAt or now
    local dur = inst._initDuration or defaultDur
    local endAt = start + (dur or 0)

    if now >= endAt then
      if TotemTender.UI and TotemTender.UI.RemoveTotemWidget then
        TotemTender.UI:RemoveTotemWidget(inst)
      end
      table.remove(totemState.activeTotems, i)

      -- start the proper remaining cooldown, even if we’re late
      if (cdLen > 0) and inst.id then
        local late = math.max(0, now - endAt)
        local remaining = math.max(0, cdLen - math.floor(late))
        TotemTender._StartCooldown(inst.id, remaining)
      end

      if TotemTender.Debug and TotemTender.Debug.State then
        TotemTender.Debug:State(("Expired (wall-clock) %s"):format(inst.name))
      end
    end
  end
end
