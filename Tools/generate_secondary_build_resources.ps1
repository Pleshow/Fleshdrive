$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resourceDir = Join-Path $root 'Resources\Upgrades\BuildItems'
New-Item -ItemType Directory -Force -Path $resourceDir | Out-Null

$items = @(
 @{id='linear_inductor'; affinity='electric'; build='rail_predator'; rarity='specialized'; max=1; min=5; weapon='arc_spear'; tags=@('line','piercing','precision','keystone'); weight=0.40},
 @{id='polarized_scar'; affinity='electric'; build='rail_predator'; rarity='common'; max=5; min=3; weapon='arc_spear'; tags=@('line','mark','burst'); weight=1.00},
 @{id='rail_synapses'; affinity='electric'; build='rail_predator'; rarity='rare'; max=5; min=4; weapon='arc_spear'; tags=@('line','range','cooldown'); weight=0.65},
 @{id='corona_follicles'; affinity='electric'; build='quill_tempest'; rarity='specialized'; max=1; min=5; weapon='quill_burst'; tags=@('projectile','split','swarm','keystone'); weight=0.40},
 @{id='ionic_marrow'; affinity='electric'; build='quill_tempest'; rarity='common'; max=5; min=2; weapon='quill_burst'; tags=@('projectile','count','tradeoff'); weight=1.00},
 @{id='storm_plumage'; affinity='electric'; build='quill_tempest'; rarity='rare'; max=5; min=4; weapon='quill_burst'; tags=@('projectile','burst','area'); weight=0.65},
 @{id='furnace_carapace'; affinity='fire'; build='furnace_halo'; rarity='specialized'; max=1; min=4; weapon='inferno_ring'; tags=@('close_range','defense','ring','keystone'); weight=0.40},
 @{id='cautery_valves'; affinity='fire'; build='furnace_halo'; rarity='common'; max=5; min=2; weapon='inferno_ring'; tags=@('ring','healing','sustain'); weight=1.00},
 @{id='thermal_pulse_gland'; affinity='fire'; build='furnace_halo'; rarity='rare'; max=5; min=3; weapon='inferno_ring'; tags=@('ring','pull','burn'); weight=0.65},
 @{id='obsidian_throat'; affinity='fire'; build='magma_artillery'; rarity='specialized'; max=1; min=5; weapon='magma_spear'; tags=@('magma','line','artillery','keystone'); weight=0.40},
 @{id='kiln_chamber'; affinity='fire'; build='magma_artillery'; rarity='common'; max=5; min=3; weapon='magma_spear'; tags=@('range','damage','tradeoff'); weight=1.00},
 @{id='pressure_crucible'; affinity='fire'; build='magma_artillery'; rarity='rare'; max=5; min=4; weapon='magma_spear'; tags=@('charge','burst','cadence'); weight=0.65},
 @{id='orbit_brood_sac'; affinity='telekinetic'; build='captive_moon'; rarity='specialized'; max=1; min=5; weapon='orbiting_debris'; tags=@('orbit','capacity','control','keystone'); weight=0.40},
 @{id='collision_nucleus'; affinity='telekinetic'; build='captive_moon'; rarity='common'; max=5; min=3; weapon='orbiting_debris'; tags=@('orbit','collision','tradeoff'); weight=1.00},
 @{id='execution_fold'; affinity='telekinetic'; build='captive_moon'; rarity='rare'; max=5; min=4; weapon='orbiting_debris'; tags=@('orbit','execute','explosion'); weight=0.65},
 @{id='synaptic_rail'; affinity='telekinetic'; build='neural_executioner'; rarity='specialized'; max=1; min=6; weapon='neural_lance'; tags=@('lance','precision','burst','keystone'); weight=0.40},
 @{id='psychic_parallax'; affinity='telekinetic'; build='neural_executioner'; rarity='common'; max=5; min=3; weapon='neural_lance'; tags=@('distance','projectile','damage'); weight=1.00},
 @{id='thought_echo'; affinity='telekinetic'; build='neural_executioner'; rarity='rare'; max=5; min=5; weapon='neural_lance'; tags=@('line','multihit','repeat'); weight=0.65}
)

foreach ($item in $items) {
    $tags = ($item.tags | ForEach-Object { '&"' + $_ + '"' }) -join ', '
    $upper = $item.id.ToUpperInvariant()
    $keystone = if ($item.max -eq 1) { 'true' } else { 'false' }
    $content = @"
[gd_resource type="Resource" script_class="UpgradeData" format=3]

[ext_resource type="Script" path="res://Scripts/upgrade_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://Assets/ui/cards/build_items/$($item.affinity).svg" id="2"]

[resource]
script = ExtResource("1")
upgrade_id = &"$($item.id)"
display_name = "CARD_${upper}_NAME"
description = "CARD_${upper}_DESC"
card_texture = ExtResource("2")
fleshdrive_affinity = "$($item.affinity)"
synergy_tags = Array[StringName]([$tags])
rarity = "$($item.rarity)"
max_level = $($item.max)
minimum_player_level = $($item.min)
build_archetype = &"$($item.build)"
keystone = $keystone
required_weapons = Array[StringName]([&"$($item.weapon)"])
offer_weight = $($item.weight.ToString([Globalization.CultureInfo]::InvariantCulture))
excluded_upgrades = Array[StringName]([])
"@
    # The authoritative numeric table lives in BuildItemCatalog.
    [IO.File]::WriteAllText(
        (Join-Path $resourceDir "$($item.id).tres"),
        $content,
        [Text.UTF8Encoding]::new($false)
    )
}
