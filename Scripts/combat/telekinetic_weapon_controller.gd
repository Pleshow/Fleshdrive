class_name TelekineticWeaponController
extends FleshdriveWeaponController


func initialize(system: PlayerWeaponSystem) -> void:
	setup(system, FleshdriveCatalog.TELEKINETIC, {
		&"kinetic_shard": &"_fire_kinetic_shard",
		&"gravity_well": &"_fire_gravity_well",
		&"repulse_wave": &"_fire_repulse_wave",
		&"orbiting_debris": &"_fire_orbiting_debris_proxy",
		&"neural_lance": &"_fire_neural_lance",
	})
