print("TotemTender: loading data.lua")

local ADDON, TotemTender = ...

-- ----------------------------------------------
-- Constants
-- ----------------------------------------------
TotemTender.CONST = {
	TICK_SECONDS      = 5, -- game updates every N seconds
	START_LEVEL       = 1,
	MAX_LEVEL         = 10,
	START_HARMONY     = 0,
	START_ENV_HEALTH  = 100,
	TARGET_BALANCE    = 50, -- desired midpoint for each element
	BALANCE_TOLERANCE = 10, -- range around TARGET_BALANCE considered "good"
	HARMONY_GAIN_BASE = 3, -- base harmony gain when within tolerance
	HARMONY_LOSS_BASE = 2, -- base harmony loss when outside tolerance
	SUMMON_LIMIT      = 4, -- simultaneous totems allowed
	TOTEM_DURATION    = 45, -- seconds per summon (game ticks handle it)
	TOTEM_COOLDOWN    = 30, -- seconds before that totem ID can be re-summoned
	TOTEM_UPKEEP      = 1, -- harmony per tick per active totem
}

local CONST = TotemTender.CONST

-- ----------------------------------------------
-- Level data
-- ----------------------------------------------
TotemTender.LEVELS = {
	{
		levelId = 1,
		key = "mulgor",
		name = "Mulgor",
		environment = "Grasslands",
		difficulty = 1,
		startingHealth = 80,
		targetHealth = 100,
		targetHarmony = 200,
		currentHarmony = 0,
		elements_base = { earth = 50, air = 50, fire = 25, water = 50 },
		elements_multi = { earth = 2, air = 2, fire = 1, water = 2 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 100, air = 75, fire = 50, water = 100 }
		art = "Interface\\AddOns\\TotemTender\\resources\\mulgor",
		events = { 
			
		} 
	},
	{
		levelId = 2,
		key = "durotar",
		name = "Durotar",
		environment = "Arid",
		difficulty = 2,
		startingHealth = 70,
		targetHealth = 100,
		targetHarmony = 400,
		currentHarmony = 0,
		elements_base = { earth = 50, air = 25, fire = 50, water = 25 },
		elements_multi = { earth = 2, air = 1, fire = 2, water = 1 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 100, air = 50, fire = 100, water = 50 }
		art = "Interface\\AddOns\\TotemTender\\resources\\durotar",
		events = { 
			
		} 
	},
	{
		levelId = 3,
		key = "wailingcaverns",
		name = "Wailing Caverns",
		environment = "Damp Cave",
		difficulty = 3,
		startingHealth = 60,
		targetHealth = 100,
		targetHarmony = 600,
		currentHarmony = 0,
		elements_base = { earth = 80, air = 10, fire = 10, water = 80 },
		elements_multi = { earth = 2, air = 1, fire = 1, water = 2 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 100, air = 50, fire = 50, water = 100 }
		art = "Interface\\AddOns\\TotemTender\\resources\\wailing_caverns",
		events = { 
			
		} 
	},
	{
		levelId = 4,
		key = "swampofsorrows",
		name = "Swamp of Sorrows",
		environment = "Swamp",
		difficulty = 4,
		startingHealth = 50,
		targetHealth = 100,
		targetHarmony = 8000,
		currentHarmony = 0,
		elements_base = { earth = 50, air = 10, fire = 10, water = 80 },
		elements_multi = { earth = 1, air = 1, fire = 1, water = 3 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 20, air = 50, fire = 20, water = 50 }
		art = "Interface\\AddOns\\TotemTender\\resources\\swamp_of_sorrows",
		events = { 
			
		} 
	},
	{
		levelId = 5,
		key = "badlands",
		name = "Badlands",
		environment = "Arid",
		difficulty = 5,
		startingHealth = 40,
		targetHealth = 100,
		targetHarmony = 1000,
		currentHarmony = 0,
		elements_base = { earth = 50, air = 80, fire = 90, water = 10 },
		elements_multi = { earth = 2, air = 2, fire = 2, water = 1 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 40, air = 50, fire = 60, water = 20 }
		art = "Interface\\AddOns\\TotemTender\\resources\\badlands",
		events = { 
			
		} 
	},
	{
		levelId = 6,
		key = "tanaris",
		name = "Tanaris",
		environment = "Desert",
		difficulty = 6,
		startingHealth = 30,
		targetHealth = 100,
		targetHarmony = 1200,
		currentHarmony = 0,
		elements_base = { earth = 50, air = 50, fire = 90, water = 10 },
		elements_multi = { earth = 1, air = 1, fire = 3, water = 2 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 25, air = 25, fire = 75, water = 30 }
		art = "Interface\\AddOns\\TotemTender\\resources\\tanaris",
		events = { 
			
		} 
	},
	{
		levelId = 7,
		key = "winterspring",
		name = "Winterspring",
		environment = "Arctic",
		difficulty = 7,
		startingHealth = 20,
		targetHealth = 100,
		targetHarmony = 1400,
		currentHarmony = 0,
		elements_base = { earth = 20, air = 100, fire = 5, water = 100 },
		elements_multi = { earth = 1, air = 1, fire = 3, water = 2 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 50, air = 50, fire = 30, water = 60 }
		art = "Interface\\AddOns\\TotemTender\\resources\\winterspring",
		events = { 
			
		} 
	},
	{
		levelId = 8,
		key = "blastedlands",
		name = "Blasted Lands",
		environment = "Hellscape",
		difficulty = 8,
		startingHealth = 15,
		targetHealth = 100,
		targetHarmony = 1600,
		currentHarmony = 0,
		elements_base = { earth = 100, air = 10, fire = 150, water = 10 },
		elements_multi = { earth = 3, air = 1, fire = 4, water = 1 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 70, air = 25, fire = 100, water = 30 }
		art = "Interface\\AddOns\\TotemTender\\resources\\blasted_lands",
		events = { 
			
		} 
	},
	{
		levelId = 9,
		key = "silithus",
		name = "Silithus",
		environment = "Infestation",
		difficulty = 9,
		startingHealth = 10,
		targetHealth = 100,
		targetHarmony = 1800,
		currentHarmony = 0,
		elements_base = { earth = 10, air = 10, fire = 10, water = 10 },
		elements_multi = { earth = 3, air = 1, fire = 4, water = 1 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 25, air = 50, fire = 25, water = 25 }
		art = "Interface\\AddOns\\TotemTender\\resources\\silithus",
		events = { 
			
		} 
	},
	{
		levelId = 10,
		key = "cavernsoftime",
		name = "Caverns of Time",
		environment = "Space",
		difficulty = 10,
		startingHealth = 5,
		targetHealth = 100,
		targetHarmony = 2000,
		currentHarmony = 0,
		elements_base = { earth = 10, air = 10, fire = 10, water = 10 },
		elements_multi = { earth = 3, air = 1, fire = 4, water = 1 },
		elements_temp = { earth = 0, air = 0, fire = 0, water = 0 },
		elements_target = { earth = 50, air = 25, fire = 15, water = 25 }
		art = "Interface\\AddOns\\TotemTender\\resources\\caverns_of_time",
		events = { 
			
		} 
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
		affnity = { 
			earth = 1,
			fire = 0,
			water = 0,
			air = 0
		}
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
		affnity = { 
			earth = 1,
			fire = 0,
			water = 1,
			air = 0
		}
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
		affnity = { 
			earth = 4,
			fire = 0,
			water = 0,
			air = 0
		}
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
		affnity = { 
			earth = 3,
			fire = 0,
			water = 0,
			air = 2
		}
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
		affnity = { 
			earth = 0,
			fire = 2,
			water = 0,
			air = 0
		}
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
		affnity = { 
			earth = 1,
			fire = 4,
			water = 2,
			air = 0
		}
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
		affnity = { 
			earth = 0,
			fire = 4,
			water = 0,
			air = 4
		}
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
		affnity = { 
			earth = 1,
			fire = 0,
			water = 3,
			air = 0
		}
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
		affnity = { 
			earth = 1,
			fire = 0,
			water = 2,
			air = 1
		}
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
		affnity = { 
			earth = 0,
			fire = 0,
			water = 4,
			air = 0
		}
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
		affnity = { 
			earth = 1,
			fire = 0,
			water = 0,
			air = 3
		}
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
		affnity = { 
			earth = 0,
			fire = 0,
			water = 0,
			air = 4
		}
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
		affnity = { 
			earth = 2,
			fire = 0,
			water = 2,
			air = 2
		}
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
		affnity = { 
			earth = 4,
			fire = 0,
			water = 0,
			air = 4
		}
	},
}

