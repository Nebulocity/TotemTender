local ADDON, TotemTender = ...
local CONST, ENVS, TOTEMS = TotemTender.CONST, TotemTender.ENVIRONMENTS, TotemTender.TOTEMS

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function calcHarmonyDelta(state)
  local t = CONST.TARGET_BALANCE
  local tol = CONST.BALANCE_TOLERANCE
  local e = state.env
  local deltas = {
    math.abs(e.earth - t),
    math.abs(e.air - t),
    math.abs(e.fire - t),
    math.abs(e.water - t),
  }
  local worst = math.max(unpack(deltas))
  if worst <= tol then
    return CONST.HARMONY_GAIN_BASE + math.floor((tol - worst) / 2)
  else
    return - (CONST.HARMONY_LOSS_BASE + math.floor((worst - tol) / 5))
  end
end

local function applyTotemInfluences(state)
  for _, t in ipairs(state.activeTotems) do
    for k, v in pairs(t.influence) do
      if k == "env" then
        state.envHealth = clamp(state.envHealth + v, 0, 100)
      else
        state.env[k] = clamp(state.env[k] + v, 0, 100)
      end
    end
  end
end

local function applyEnvDrift(state)
  local base = state.baseEnv.base
  for k, baseV in pairs(base) do
    local cur = state.env[k]
    local step = (baseV - cur)
    local pull = math.max(1, state.baseEnv.difficulty) * 0.4
    state.env[k] = cur + math.floor(step * 0.05 * pull)
  end
end

local function handleLeveling(state, deltaHarmony)
  if deltaHarmony > 0 then
    state.xp = state.xp + deltaHarmony
    local need = 50 + (state.level * 10)
    while state.xp >= need and state.level < CONST.MAX_LEVEL do
      state.xp = state.xp - need
      state.level = state.level + 1
      TotemTender.UI:BannerToast("Shaman Level Up!", "Level "..state.level)
      need = 50 + (state.level * 10)
    end
  end
end

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

function TotemTender.Tick()
  local S = TotemTender.State
  if not S then return end
  applyTotemInfluences(S)
  applyEnvDrift(S)
  local delta = calcHarmonyDelta(S)
  S.harmony = clamp(S.harmony + delta, 0, 9999)
  handleLeveling(S, delta)

  local avg = (S.env.earth + S.env.air + S.env.fire + S.env.water) / 4
  if avg >= CONST.TARGET_BALANCE - 5 and avg <= CONST.TARGET_BALANCE + 5 then
    S.envHealth = clamp(S.envHealth + 2, 0, 100)
  else
    S.envHealth = clamp(S.envHealth - 1, 0, 100)
  end

  TotemTender.UI:ApplySceneMood(S.envHealth)

  local ended = checkEndConditions(S)
  if ended == "loss" then
    TotemTender.ResetLevel(1)
  elseif ended == "win" then
    local levelId = math.min(S.envIndex + 1, #ENVS)
    TotemTender.ResetLevel(levelId)
  end
  TotemTender.UI:Refresh()
end

function TotemTender.CanUnlock(totem)
  local S = TotemTender.State
  return S.level >= totem.unlockLevel and S.harmony >= totem.unlock and not S.unlocked[totem.id]
end

function TotemTender.CanSummon(totem)
  local S = TotemTender.State
  if not S.unlocked[totem.id] then return false end
  if #S.activeTotems >= CONST.SUMMON_LIMIT then return false end
  return S.harmony >= totem.summon
end

function TotemTender.UnlockTotem(totem)
  if TotemTender.CanUnlock(totem) then
    TotemTender.State.harmony = TotemTender.State.harmony - totem.unlock
    TotemTender.State.unlocked[totem.id] = true
    TotemTender.UI:BannerToast("Unlocked", totem.name)
    TotemTender.UI:Refresh()
  end
end

function TotemTender.SummonTotem(totem)
  if TotemTender.CanSummon(totem) then
    TotemTender.State.harmony = TotemTender.State.harmony - totem.summon
    local inst = { id = totem.id, name = totem.name, icon = totem.icon, influence = totem.influence }
    table.insert(TotemTender.State.activeTotems, inst)
    TotemTender.UI:AddTotemWidget(inst)
    TotemTender.UI:Refresh()
  end
end