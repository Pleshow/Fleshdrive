class_name FireWeaponController
extends FleshdriveWeaponController


func initialize(system: PlayerWeaponSystem) -> void:
	setup(system, FleshdriveCatalog.FIRE, {
		&"cinder_volley": &"_fire_cinder_volley",
		&"inferno_ring": &"_fire_inferno_ring",
		&"magma_spear": &"_fire_magma_spear",
		&"ashen_eruption": &"_fire_ashen_eruption",
	})
