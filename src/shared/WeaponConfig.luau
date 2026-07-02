-- WeaponConfig.luau
-- Source de vérité unique pour la configuration de toutes les armes.
-- Requis côté client (WeaponController) ET serveur (WeaponService).

export type WeaponData = {
	Damage: number,
	Range: number,
	Cooldown: number,
	Type: "Distance" | "Melee",
}

local WeaponConfig: { [string]: WeaponData } = {
	["Pistolet"] = { Damage = 15, Range = 80, Cooldown = 0.3, Type = "Distance" },
	["Couteau"] = { Damage = 35, Range = 6, Cooldown = 0.7, Type = "Melee" },
	["FusilAssaut"] = { Damage = 20, Range = 120, Cooldown = 0.12, Type = "Distance" },
}

return WeaponConfig
