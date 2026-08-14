class_name ElectricWeaponController
extends FleshdriveWeaponController


func initialize(system: PlayerWeaponSystem) -> void:
	setup(system, FleshdriveCatalog.ELECTRIC, {
		&"quill_burst": &"_fire_quill_burst",
		&"tail_lash": &"_fire_tail_lash",
		&"arc_spear": &"_fire_arc_spear",
		&"bone_shard_volley": &"_fire_bone_shard_volley",
	})
