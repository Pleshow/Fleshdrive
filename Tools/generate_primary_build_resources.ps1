$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$assetDir = Join-Path $root 'Assets\ui\cards\build_items'
$resourceDir = Join-Path $root 'Resources\Upgrades\BuildItems'
New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
New-Item -ItemType Directory -Force -Path $resourceDir | Out-Null

$affinities = @{
    electric = @{ color = '#22d9ff'; accent = '#0b657d'; glyph = 'ARC' }
    fire = @{ color = '#ff6738'; accent = '#8f2617'; glyph = 'PYRE' }
    telekinetic = @{ color = '#bf63ff'; accent = '#552879'; glyph = 'NOETIC' }
}
foreach ($affinity in $affinities.Keys) {
    $style = $affinities[$affinity]
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="720" viewBox="0 0 512 720">
 <rect width="512" height="720" rx="28" fill="#070a0f"/>
 <rect x="13" y="13" width="486" height="694" rx="22" fill="none" stroke="$($style.color)" stroke-width="7"/>
 <path d="M42 105H470M42 590H470" stroke="$($style.color)" stroke-width="4" opacity=".8"/>
 <circle cx="256" cy="340" r="123" fill="$($style.accent)" opacity=".35" stroke="$($style.color)" stroke-width="7"/>
 <circle cx="256" cy="340" r="76" fill="none" stroke="$($style.color)" stroke-width="10" stroke-dasharray="18 12"/>
 <circle cx="256" cy="340" r="24" fill="$($style.color)"/>
 <text x="256" y="76" fill="$($style.color)" font-size="30" font-family="monospace" font-weight="bold" text-anchor="middle">$($style.glyph)</text>
 <text x="256" y="656" fill="#e8f7f7" font-size="25" font-family="monospace" font-weight="bold" text-anchor="middle">BUILD ADAPTATION</text>
</svg>
"@
    [IO.File]::WriteAllText(
        (Join-Path $assetDir "$affinity.svg"),
        $svg,
        [Text.UTF8Encoding]::new($false)
    )
}

$items = @(
 @{id='forked_arc_node'; affinity='electric'; build='chainstorm'; rarity='specialized'; max=1; min=5; weapons=@('arc_heart','arc_spear'); tags=@('chain','fork','keystone')},
 @{id='static_reservoir'; affinity='electric'; build='chainstorm'; rarity='common'; max=5; min=2; weapons=@('arc_heart','arc_spear'); tags=@('chain','pulse')},
 @{id='grounding_filaments'; affinity='electric'; build='chainstorm'; rarity='rare'; max=5; min=3; weapons=@('arc_heart','arc_spear'); tags=@('chain','grounded')},
 @{id='thunder_gait'; affinity='electric'; build='thunder_ram'; rarity='specialized'; max=1; min=4; weapons=@('shock_ram'); tags=@('dash','impact','keystone')},
 @{id='kinetic_capacitor'; affinity='electric'; build='thunder_ram'; rarity='common'; max=5; min=2; weapons=@('shock_ram'); tags=@('dash','charge')},
 @{id='galvanic_tendons'; affinity='electric'; build='thunder_ram'; rarity='rare'; max=5; min=3; weapons=@('shock_ram'); tags=@('dash','movement')},
 @{id='spore_ember_sac'; affinity='fire'; build='wildfire_shepherd'; rarity='specialized'; max=1; min=4; weapons=@('cinder_volley','inferno_ring'); tags=@('burn','spread','keystone')},
 @{id='oxygen_thief'; affinity='fire'; build='wildfire_shepherd'; rarity='common'; max=5; min=2; weapons=@('cinder_volley','inferno_ring'); tags=@('burn','density')},
 @{id='smoldering_hide'; affinity='fire'; build='wildfire_shepherd'; rarity='rare'; max=5; min=3; weapons=@('cinder_volley','inferno_ring'); tags=@('burn','duration','defense')},
 @{id='rupture_vesicle'; affinity='fire'; build='flashpoint_bomber'; rarity='specialized'; max=1; min=5; weapons=@('combustion_sac','ashen_eruption'); tags=@('combustion','explosion','keystone')},
 @{id='ash_pressure_chamber'; affinity='fire'; build='flashpoint_bomber'; rarity='common'; max=5; min=3; weapons=@('combustion_sac','ashen_eruption'); tags=@('combustion','explosion')},
 @{id='chain_igniter'; affinity='fire'; build='flashpoint_bomber'; rarity='rare'; max=5; min=4; weapons=@('combustion_sac','ashen_eruption'); tags=@('combustion','chain')},
 @{id='event_horizon_membrane'; affinity='telekinetic'; build='gravity_architect'; rarity='specialized'; max=1; min=5; weapons=@('gravity_well'); tags=@('gravity','control','keystone')},
 @{id='compression_cortex'; affinity='telekinetic'; build='gravity_architect'; rarity='common'; max=5; min=3; weapons=@('gravity_well'); tags=@('gravity','compression')},
 @{id='tidal_ligaments'; affinity='telekinetic'; build='gravity_architect'; rarity='rare'; max=5; min=4; weapons=@('gravity_well'); tags=@('gravity','cooldown')},
 @{id='vector_mantle'; affinity='telekinetic'; build='repulse_bastion'; rarity='specialized'; max=1; min=5; weapons=@('repulse_wave'); tags=@('repulse','barrier','keystone')},
 @{id='reactive_cranium'; affinity='telekinetic'; build='repulse_bastion'; rarity='common'; max=5; min=2; weapons=@('repulse_wave'); tags=@('repulse','reactive')},
 @{id='mirror_prism'; affinity='telekinetic'; build='repulse_bastion'; rarity='rare'; max=5; min=6; weapons=@('projectile_reversal'); tags=@('reversal','projectile')}
)
foreach ($item in $items) {
    $requirements = ($item.weapons | ForEach-Object { '&"' + $_ + '"' }) -join ', '
    $tags = ($item.tags | ForEach-Object { '&"' + $_ + '"' }) -join ', '
    $upper = $item.id.ToUpperInvariant()
    $keystone = if ($item.max -eq 1) { 'true' } else { 'false' }
    $offerWeight = if ($item.rarity -eq 'rare') { '0.65' } elseif ($item.rarity -eq 'specialized') { '0.40' } else { '1.0' }
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
required_weapons = Array[StringName]([$requirements])
offer_weight = $offerWeight
excluded_upgrades = Array[StringName]([])
"@
    [IO.File]::WriteAllText(
        (Join-Path $resourceDir "$($item.id).tres"),
        $content,
        [Text.UTF8Encoding]::new($false)
    )
}
