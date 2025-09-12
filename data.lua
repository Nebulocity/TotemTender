print("TotemTender: loading data.lua")

local ADDON, TotemTender = ...

-- ------------------------------
-- Constants that control pacing
-- ------------------------------
TotemTender.CONST = {
	TICK_SECONDS      = 5, -- game updates every N seconds
	START_LEVEL       = 1,
	MAX_LEVEL         = 60,
	START_HARMONY     = 50,
	START_ENV_HEALTH  = 70,
	TARGET_BALANCE    = 50, -- desired midpoint for each element
	BALANCE_TOLERANCE = 10, -- range around TARGET_BALANCE considered "good"
	HARMONY_GAIN_BASE = 3, -- base harmony gain when within tolerance
	HARMONY_LOSS_BASE = 2, -- base harmony loss when outside tolerance
	SUMMON_LIMIT      = 6, -- simultaneous totems allowed
	TOTEM_DURATION    = 45, -- seconds per summon (game ticks handle it)
	TOTEM_COOLDOWN    = 30, -- seconds before that totem ID can be re-summoned
	TOTEM_UPKEEP      = 1, -- harmony per tick per active totem
}

-- Alias when this file is required directly
local CONST = TotemTender.CONST

-- ------------------------------
-- Level definitions
-- ------------------------------
-- NOTE: key = "mulgor" kept to match existing assets (mulgor.png)
TotemTender.LEVELS = {
	{
		levelId     = 1,
		key         = "mulgor",
		name        = "Mulgor",
		environment = "Grasslands",
		art         = "Interface\\AddOns\\TotemTender\\resources\\mulgor",
		difficulty  = 1,
		base        = { earth = 55, air = 45, fire = 40, water = 60 },
	},
	{
		levelId     = 2,
		key         = "durotar",
		name        = "Durotar",
		environment = "Arid",
		art         = "Interface\\AddOns\\TotemTender\\resources\\durotar",
		difficulty  = 2,
		base        = { earth = 60, air = 40, fire = 55, water = 35 },
	},
	{
		levelId     = 3,
		key         = "barrens",
		name        = "The Barrens",
		environment = "Savanna",
		art         = "Interface\\AddOns\\TotemTender\\resources\\wailing_caverns",
		difficulty  = 3,
		base        = { earth = 50, air = 50, fire = 50, water = 40 },
	},
}


-- ------------------------------
-- Icon texture map (by shorthand)
-- ------------------------------
local ICON = {
	-- Earth
	STONESKIN = "Spell_Nature_StoneSkinTotem",
	EARTHBIND = "Spell_Nature_EarthBindTotem",
	STRENGTH  = "Spell_Nature_StrengthOfEarthTotem02",
	TREMOR    = "Spell_Nature_TremorTotem",

	-- Fire
	SEARING   = "Spell_Fire_SearingTotem",
	MAGMA     = "Spell_Fire_SelfDestruct",
	FIRENOVA  = "Spell_Fire_SealOfFire",

	-- Water
	HEALSTRM  = "INV_Spear_04",
	CLEANSING = "Spell_Nature_DiseaseCleansingTotem",
	MANA      = "Spell_Nature_ManaRegenTotem",

	-- Air
	WINDFURY  = "Spell_Nature_Windfury",
	GRACE     = "Spell_Nature_InvisibilityTotem",
	SENTRY    = "Ability_EyeOfTheOwl",
	GROUNDS   = "Spell_Nature_GroundingTotem",
}

-- ------------------------------
-- Totem catalog
-- ------------------------------
TotemTender.TOTEMS = {
	-- Earth
	{
		id = 1,
		name = "Stoneskin",
		element = "earth",
		icon = ICON.STONESKIN,
		unlockLevel = 1,
		unlock = 0,
		summon = 5,
		duration = 60,
		affnity = { earth = 6 }
	},
	{
		id = 2,
		name = "Earthbind",
		element = "earth",
		icon = ICON.EARTHBIND,
		unlockLevel = 8,
		unlock = 120,
		summon = 60,
		duration = 45,
		affnity = { earth = 9 }
	},
	{
		id = 3,
		name = "Strength of Earth",
		element = "earth",
		icon = ICON.STRENGTH,
		unlockLevel = 10,
		unlock = 150,
		summon = 75,
		duration = 60,
		affnity = { earth = 10 }
	},
	{
		id = 4,
		name = "Tremor",
		element = "earth",
		icon = ICON.TREMOR,
		unlockLevel = 18,
		unlock = 270,
		summon = 135,
		duration = 60,
		affnity = { earth = 9 }
	},

	-- Fire
	{
		id = 21,
		name = "Searing",
		element = "fire",
		icon = ICON.SEARING,
		unlockLevel = 10,
		unlock = 150,
		summon = 75,
		duration = 60,
		affnity = { fire = 7 }
	},
	{
		id = 22,
		name = "Magma",
		element = "fire",
		icon = ICON.MAGMA,
		unlockLevel = 26,
		unlock = 390,
		summon = 195,
		duration = 20,
		affnity = { fire = 12, water = 2 }
	},
	{
		id = 23,
		name = "Fire Nova",
		element = "fire",
		icon = ICON.FIRENOVA,
		unlockLevel = 12,
		unlock = 180,
		summon = 90,
		duration = 5,
		affnity = { fire = 10 }
	},

	-- Water
	{
		id = 41,
		name = "Healing Stream",
		element = "water",
		icon = ICON.HEALSTRM,
		unlockLevel = 20,
		unlock = 300,
		summon = 150,
		duration = 60,
		affnity = { water = 6, env = 2 }
	},
	{
		id = 42,
		name = "Cleansing",
		element = "water",
		icon = ICON.CLEANSING,
		unlockLevel = 22,
		unlock = 330,
		summon = 165,
		duration = 60,
		affnity = { water = 8, fire = -2 }
	},
	{
		id = 43,
		name = "Mana Tide",
		element = "water",
		icon = ICON.MANA,
		unlockLevel = 40,
		unlock = 600,
		summon = 300,
		duration = 60,
		affnity = { water = 10 }
	},

	-- Air
	{
		id = 61,
		name = "Windfury",
		element = "air",
		icon = ICON.WINDFURY,
		unlockLevel = 32,
		unlock = 480,
		summon = 240,
		duration = 60,
		affnity = { air = 8 }
	},
	{
		id = 62,
		name = "Grace of Air",
		element = "air",
		icon = ICON.GRACE,
		unlockLevel = 42,
		unlock = 630,
		summon = 315,
		duration = 60,
		affnity = { air = 11 }
	},
	{
		id = 63,
		name = "Sentry",
		element = "air",
		icon = ICON.SENTRY,
		unlockLevel = 34,
		unlock = 510,
		summon = 255,
		duration = 300,
		affnity = { air = 9 }
	},
	{
		id = 64,
		name = "Grounding",
		element = "air",
		icon = ICON.GROUNDS,
		unlockLevel = 30,
		unlock = 450,
		summon = 225,
		duration = 45,
		affnity = { air = 8 }
	},
}
