----------------------------------------------------------------
-- Data for the game
----------------------------------------------------------------

local ADDON, TotemTender = ...

----------------------------------------------------------------
-- Game constants
----------------------------------------------------------------
TotemTender.CONST = {
  TICK_SECONDS = 5,
  START_LEVEL = 1,
  MAX_LEVEL = 60,
  START_HARMONY = 50,
  START_ENV_HEALTH = 70,
  TARGET_BALANCE = 50,
  BALANCE_TOLERANCE = 10,
  HARMONY_GAIN_BASE = 3,
  HARMONY_LOSS_BASE = 2,
  SUMMON_LIMIT = 6,
}

----------------------------------------------------------------
-- List of levels
----------------------------------------------------------------
TotemTender.LEVELS = {
  {
	levelId = 1,
    key = "mulgor",
    name = "Mulgore",
	environment = "Grasslands",
    art = "Interface\\AddOns\\TotemTender\\resources\\mulgor.png",
    difficulty = 1,
    base = { earth = 55, air = 45, fire = 40, water = 60 },
  },
}

-- Mirror for compatibility
TotemTender.ENVIRONMENTS = TotemTender.LEVELS

----------------------------------------------------------------
-- Maps totem names to game textures
----------------------------------------------------------------
local totemTextures = {
  -- Earth Totems
  STONESKIN = "Spell_Nature_StoneSkinTotem",
  STRENGTH = "Spell_Nature_StrengthOfEarthTotem02",
  EARTHBIND = "Spell_Nature_Spell_Nature_EarthBindTotem",  
  STONECLAW = "Spell_Nature_StoneClawTotem",
  TREMOR = "Spell_Nature_TremorTotem",
  
  -- Fire Totems
  SEARING = "Spell_Fire_SearingTotem",
  MAGMA = "Spell_Fire_SelfDestruct",
  FIRENOVA = "Spell_Fire_SealOfFire",
  
  -- Water Totems
  RESISTF = "Spell_FireResistanceTotem",
  HEALSTRM = "INV_Spear_04",
  MANA = "Spell_Nature_ManaRegenTotem",
  CLEANSING = "Spell_Nature_DiseaseCleansingTotem",
  RESISTC = "Spell_Nature_NatureResistanceTotem",
  
  -- Air Totems
  WINDFURY = "Spell_Nature_Windfury",
  SENTRY = "Ability_EyeOfTheOwl",
  GRACE = "Spell_Nature_InvisibilityTotem",
  GROUNDS = "Spell_Nature_GroundingTotem",
}

----------------------------------------------------------------
-- Totem catalog
----------------------------------------------------------------
TotemTender.TOTEMS = {
  -- Earth Totems
  { id=1, name="Stoneskin Totem", element="earth", icon=I.STONESKIN, unlockLevel=1, unlock=0, summon=5, influence={ earth=+6 } },
  { id=2, name="Stoneclaw Totem", element="earth", icon=I.STONECLAW, unlockLevel=8, unlock=120, summon=60, influence={ earth=+9 } },
  { id=3, name="Strength of Earth", element="earth", icon=I.STRENGTH, unlockLevel=10, unlock=150, summon=75, influence={ earth=+10 } },
  { id=4, name="Tremor Totem", element="earth", icon=I.STONECLAW, unlockLevel=18, unlock=270, summon=135, influence={ earth=+9 } },

  -- Fire Totems
  { id=21, name="Searing Totem", element="fire", icon=I.SEARING, unlockLevel=10, unlock=150, summon=75, influence={ fire=+7 } },
  { id=22, name="Magma Totem", element="fire", icon=I.MAGMA, unlockLevel=26, unlock=390, summon=195, influence={ fire=+12, water=-2 } },
  { id=23, name="Fire Nova Totem", element="fire", icon=I.FIRENOVA, unlockLevel=12, unlock=180, summon=90, influence={ fire=+10 } },
  { id=24, name="Frost Resist", element="fire", icon=I.RESISTF, unlockLevel=24, unlock=360, summon=180, influence={ fire=+8 } },

  -- Water Totems
  { id=41, name="Healing Stream", element="water", icon=I.HEALSTRM, unlockLevel=20, unlock=300, summon=150, influence={ water=+6, env=+2 } },
  { id=42, name="Cleansing", element="water", icon=I.CLEANSING, unlockLevel=22, unlock=330, summon=165, influence={ water=+8, fire=-2 } },
  { id=43, name="Fire Resist", element="fire", icon=I.RESISTF, unlockLevel=28, unlock=420, summon=210, influence={ fire=+8 } },
  { id=44, name="Mana Tide", element="water", icon=I.MANA, unlockLevel=40, unlock=600, summon=300, influence={ water=+10 } },

  -- Air Totems
  { id=61, name="Windfury", element="air", icon=I.WINDFURY, unlockLevel=32, unlock=480, summon=240, influence={ air=+8 } },
  { id=62, name="Grace of Air", element="air", icon=I.GRACE, unlockLevel=42, unlock=630, summon=315, influence={ air=+11 } },
  { id=63, name="Sentry", element="air", icon=I.SENTRY, unlockLevel=34, unlock=510, summon=255, influence={ air=+9 } },
  { id=64, name="Grounding", element="air", icon=I.GROUNDS, unlockLevel=30, unlock=450, summon=225, influence={ air=+8 } },
}