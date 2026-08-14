import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Workbook, SpreadsheetFile } from "@oai/artifact-tool";

const toolsDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(toolsDir, "..");
const outDir = path.join(root, "outputs", "019f8b25-progression-reference");
const outFile = path.join(outDir, "Fleshdrive_Progression_Reference.xlsx");
const previewsDir = path.join(outDir, "previews");

const C = {
  ink: "#E6F4F2", muted: "#91A7AA", bg: "#071014", panel: "#0B1C22",
  cyan: "#22D3EE", orange: "#FF6B35", purple: "#B26EFF", red: "#FF5364",
  gold: "#D8A657", line: "#27515B", green: "#6DD6A8",
};

function colName(n) {
  let s = "";
  for (let x = n; x > 0; x = Math.floor((x - 1) / 26)) s = String.fromCharCode(65 + ((x - 1) % 26)) + s;
  return s;
}

function addSheet(wb, name, title, subtitle, headers, rows, widths = []) {
  const sh = wb.worksheets.add(name);
  sh.showGridLines = false;
  const last = colName(Math.max(headers.length, 2));
  sh.getRange(`A1:${last}1`).merge();
  sh.getRange("A1").values = [[title]];
  sh.getRange("A1").format = { fill: C.bg, font: { bold: true, color: C.ink, size: 20 }, rowHeight: 34 };
  sh.getRange(`A2:${last}2`).merge();
  sh.getRange("A2").values = [[subtitle]];
  sh.getRange("A2").format = { fill: C.panel, font: { color: C.muted, italic: true, size: 10 }, wrapText: true, rowHeight: 30 };
  sh.getRange(`A4:${last}4`).values = [headers];
  sh.getRange(`A4:${last}4`).format = { fill: C.cyan, font: { bold: true, color: "#041014" }, borders: { preset: "all", style: "thin", color: C.line }, wrapText: true, rowHeight: 28 };
  if (rows.length) {
    sh.getRange(`A5:${last}${rows.length + 4}`).values = rows;
    sh.getRange(`A5:${last}${rows.length + 4}`).format = { fill: C.panel, font: { color: C.ink, size: 10 }, borders: { preset: "all", style: "thin", color: C.line }, wrapText: true, verticalAlignment: "center" };
  }
  widths.forEach((w, i) => { sh.getRange(`${colName(i + 1)}:${colName(i + 1)}`).format.columnWidth = w; });
  sh.freezePanes.freezeRows(4);
  return sh;
}

const fleshdrives = [
  ["Electric", "VOLTAIC HEART", "Unlocked at start", "Burst / mobility / chain lightning", "Base Arc (15 base damage, 0.80s interval)", "Chain, burst, mobility", "Arc Heart; Pulse Capacitor; Overload Vent", "Core levels 1-5: +3% base damage/level; electric chain scaling"],
  ["Fire", "PYRE HEART", "Unlocked at start", "Burn / area denial / attrition", "Base Flame (72% direct + 18% burn application)", "Burn, area, death explosion", "Combustion Sac; Thermal Lattice; Flashpoint Nodes", "Core levels 1-5: +3% base damage/level; burn multiplier scaling"],
  ["Telekinetic", "NOETIC HEART", "First boss victory blueprint", "Control / positioning / reversal", "Kinetic Shard (90% base damage + force)", "Gravity, force, piercing", "Gravity Well; Kinetic Captivity; Projectile Reversal", "Core levels 1-5: +3% base damage/level; telekinetic multiplier scaling"],
];

const weaponProfiles = [
  ["Electric", "Ion Quill", "quill_burst", 1.65, -0.10, 1.20, 8, 3, "", "Multi-target seeking quills"],
  ["Electric", "Tesla Lash", "tail_lash", 2.80, -0.16, 2.10, 18, 6, 175, "Close sweep; +20 force/level"],
  ["Electric", "Arc Spear", "arc_spear", 2.35, -0.13, 1.80, 22, 7, "", "Piercing line attack"],
  ["Electric", "Volt Shard Volley", "bone_shard_volley", 2.10, -0.12, 1.60, 12, 4, "", "Wide conductive shard cone"],
  ["Fire", "Cinder Volley", "cinder_volley", 1.80, -0.10, 1.32, 5, 2, "", "Multi-target burn stacks"],
  ["Fire", "Inferno Ring", "inferno_ring", 3.20, -0.16, 2.35, 7, 3, "", "Close area control"],
  ["Fire", "Magma Spear", "magma_spear", 2.70, -0.13, 2.00, 18, 6, "", "Slow piercing heavy burn"],
  ["Fire", "Ashen Eruption", "ashen_eruption", 3.80, -0.18, 2.80, 12, 5, "", "Targeted area detonation"],
  ["Telekinetic", "Kinetic Shard", "kinetic_shard", 1.45, -0.08, 1.05, 9, 3, 125, "Piercing projectile"],
  ["Telekinetic", "Gravity Well", "gravity_well", 4.10, -0.20, 3.15, 8, 3, 220, "Pulls clustered enemies"],
  ["Telekinetic", "Repulse Wave", "repulse_wave", 3.00, -0.14, 2.35, 10, 3.5, 540, "Strong radial push"],
  ["Telekinetic", "Kinetic Captivity", "orbiting_debris", 999, 0, 999, "2 HP/sec", "capacity by level", "physical pull", "Captures nearby non-boss enemies; 5s cooldown after collapse"],
  ["Telekinetic", "Neural Lance", "neural_lance", 3.35, -0.15, 2.55, 25, 7, 185, "Slow strong piercing attack"],
];

const enemies = [
  ["Crawler", 30, 88, "10 contact", "0.50s", 10, 0, "Melee encirclement", "Threat cost 1.0"],
  ["Flying Spitter", 45, 78, "9 projectile", "2.35s + 0.78s windup", 14, 0.05, "Keeps 390±65 range; projectile 224 px/s", "Threat cost 2.3"],
  ["Charger", 85, 88, "22 charge", "3.4s", 20, 0.20, "650 charge speed; 0.88s telegraph", "Threat cost 3.4"],
  ["Visceral Warden", 1500, "92 / 122", "Boss patterns", "1.65s / 1.05s", "Blueprint/core", 1.0, "Phase 2 at 50% HP; 5/7 projectiles", "Boss; displacement immune"],
];

const tree = [
  ["vitality", "HARDENED HEART", "+5 max HP", 5, 2, 2, "None"],
  ["power", "PREDATOR CORE", "+1 attack damage", 5, 3, 3, "None"],
  ["mobility", "QUICKENED TENDONS", "+4 move speed", 5, 2, 2, "None"],
  ["reflex", "RAPID SYNAPSES", "3% faster attack rate", 5, 3, 2, "Predator Core"],
  ["harvester", "BIOMASS RECEPTORS", "+5% biomass gain", 5, 2, 2, "Predator Core"],
  ["magnetism", "MAGNETIC TISSUE", "+10 pickup range", 5, 2, 2, "Hardened Heart"],
  ["reach", "PREDATORY REACH", "+8 attack range", 5, 3, 2, "Hardened Heart"],
  ["conduction", "CONDUCTIVE NERVES", "+4% chain damage", 5, 3, 3, "Quickened Tendons"],
  ["dash_recovery", "DASH METABOLISM", "4% shorter dash cooldown", 5, 2, 2, "Quickened Tendons"],
  ["weapon_metabolism", "WEAPON METABOLISM", "3% faster secondary weapons", 5, 4, 3, "Predator Core"],
  ["early_growth", "EARLY GROWTH", "2% less biomass for level 2", 5, 2, 2, "Hardened Heart"],
  ["targeting", "HUNTER SENSE", "+8 target radius", 5, 3, 2, "Quickened Tendons"],
  ["nerve_drive", "NERVE DRIVE", "+60 acceleration", 5, 2, 2, "Quickened Tendons"],
];

async function parseUpgrades() {
  const dir = `${root}/Resources/Upgrades`;
  const files = (await fs.readdir(dir)).filter(f => f.endsWith(".tres")).sort();
  const kinds = ["Item", "Organ", "Weapon"], slots = ["None", "Brain", "Maw", "Heart", "Lung", "Legs", "Claws", "Tail"];
  const result = [];
  for (const file of files) {
    const t = await fs.readFile(path.join(dir, file), "utf8");
    const get = (re, fallback = "") => (t.match(re)?.[1] ?? fallback);
    const id = get(/upgrade_id = &"([^"]+)"/, file.replace(".tres", ""));
    const title = get(/display_name = "([^"]+)"/, id.replaceAll("_", " ").toUpperCase());
    const desc = get(/description = "([^"]+)"/, "Effect implemented in Koda/weapon system; no card copy set.");
    const kind = Number(get(/upgrade_kind = (\d+)/, "0"));
    const slot = Number(get(/organ_slot = (\d+)/, "0"));
    const affinity = get(/fleshdrive_affinity = "([^"]+)"/, "universal");
    const rarity = get(/rarity = "([^"]+)"/, "common");
    const maxLevel = Number(get(/max_level = (\d+)/, "5"));
    const minLevel = Number(get(/minimum_player_level = (\d+)/, "1"));
    const tagsRaw = get(/synergy_tags = Array\[StringName\]\(\[([^\]]*)\]\)/, "");
    const tags = [...tagsRaw.matchAll(/&"([^"]+)"/g)].map(m => m[1]).join(", ");
    result.push([id, title, kinds[kind] ?? kind, slots[slot] ?? slot, affinity, rarity, maxLevel, minLevel, tags, desc, `Resources/Upgrades/${file}`]);
  }
  return result;
}

const phases = [
  ["Awakening", "0:00", "2:00", 18, 1.08, "Swarm, mixed", 0, 0, 0],
  ["Adaptation", "2:00", "4:00", 28, 1.00, "Mixed, crossfire", 0.10, 0.24, 0.08],
  ["System Stress", "4:00", "6:00", 39, 0.90, "Swarm, assault, mixed", 0.13, 0.26, 0.15],
  ["Compound Pressure", "6:00", "9:00", 52, 0.82, "Crossfire, assault, mixed", 0.17, 0.29, 0.18],
  ["Containment Failure", "9:00", "11:00", 62, 0.76, "Assault, crossfire, mixed", 0.20, 0.30, 0.20],
  ["Warden Protocol", "11:00", "12:00", 0, 2.00, "Boss preparation", 0, 0, 0],
];

const playerStats = [
  ["Move speed", 210, "px/s", "Quickened Tendons +4/level"], ["Acceleration", 1800, "px/s²", "Nerve Drive +60/level"],
  ["Deceleration", 2200, "px/s²", "Fixed"], ["Max health", 100, "HP", "Hardened Heart +5/level"],
  ["Attack damage", 15, "damage", "Predator Core +1/level; core +3%/level after level 1"], ["Attack interval", 0.8, "seconds", "Rapid Synapses 3% faster/level"],
  ["Attack range", 220, "px", "Predatory Reach +8/level"], ["Chain range", 150, "px", "Pulse Capacitor +20%/level"],
  ["Chain multiplier", 0.60, "x damage", "Conductive Nerves +4%/level"], ["Starting biomass needed", 50, "biomass", "Early Growth lowers level-2 need 2%/level"],
  ["Biomass requirement multiplier", 1.35, "x/level", "Progressive XP curve"], ["Biomass pickup radius", 120, "px", "Magnetic Tissue +10/level"],
  ["Dash speed", 760, "px/s", "Dash must be unlocked"], ["Dash duration", 0.16, "seconds", "Fixed"], ["Dash cooldown", 1.0, "seconds", "Dash Metabolism -4%/level; floor by runtime upgrades"],
];

async function build() {
  await fs.mkdir(previewsDir, { recursive: true });
  const wb = Workbook.create();
  const overview = addSheet(wb, "Overview", "FLESHDRIVE — PROGRESSION REFERENCE", "Current prototype balance snapshot. Values are extracted from the active project configuration; runtime synergies can multiply them further.", ["System", "Current rule", "Design purpose", "Primary source"], [
    ["Run", "12:00 + boss", "Survivor run ending in Warden encounter", "CombatBalanceData encounter phases"],
    ["Build choice", "Voltaic / Pyre / Noetic Heart", "Three distinct combat identities", "FleshdriveCatalog"],
    ["Weapons", "Base weapon + max 3 additional", "Readable build scope", "HUD/player weapon system"],
    ["Card unlock pacing", "Minimum 3 level-ups between new weapons", "Avoid weapon dilution", "RunManager/card offer logic"],
    ["Meta currency", "Blood Memory fragments (red gems)", "Persistent Flesh Tree progression", "MetaProgression"],
    ["Boss reward", "First victory unlocks Noetic; later victories level active core", "Blueprint and core loop", "MetaProgression"],
    ["Core cap", "5", "Persistent Fleshdrive mastery", "FleshdriveCatalog.MAX_CORE_LEVEL"],
  ], [20, 34, 44, 36]);
  overview.getRange("A5:A11").format.font = { bold: true, color: C.cyan };

  const fd = addSheet(wb, "Fleshdrives", "THE THREE FLESHDRIVES", "Class-defining implants selected before each run.", ["Affinity", "Implant", "Unlock", "Playstyle", "Base attack", "Tags", "Key synergies", "Core scaling"], fleshdrives, [15, 22, 24, 34, 42, 25, 44, 46]);
  fd.getRange("A5:A7").format.font = { bold: true, color: C.ink };
  fd.getRange("A5:H5").format.borders = { preset: "outside", style: "medium", color: C.cyan };
  fd.getRange("A6:H6").format.borders = { preset: "outside", style: "medium", color: C.orange };
  fd.getRange("A7:H7").format.borders = { preset: "outside", style: "medium", color: C.purple };

  addSheet(wb, "Player Stats", "KODA — BASE STATISTICS", "Starting values before Flesh Tree, cards, organs and core-level modifiers.", ["Statistic", "Base value", "Unit", "Progression / modifier"], playerStats, [28, 16, 18, 62]);

  const weapons = addSheet(wb, "Weapons", "WEAPONS & ATTACK PROFILES", "Cooldown(level) = max(minimum, base + (level−1) × step). Damage(level) = base + (level−1) × damage step.", ["Affinity", "Attack", "ID", "Base cooldown", "Cooldown step", "Minimum", "Base damage", "Damage step", "Base force", "Behavior"], weaponProfiles, [16, 24, 24, 16, 16, 14, 16, 15, 16, 42]);
  weapons.getRange(`D5:I${weaponProfiles.length + 4}`).format.numberFormat = "0.00";

  const scalingRows = [];
  weaponProfiles.forEach((w, wi) => { for (let lvl = 1; lvl <= 5; lvl++) scalingRows.push([w[0], w[1], lvl, null, null, w[8] === "" ? "" : Number(w[8]) + (w[2] === "tail_lash" ? (lvl - 1) * 20 : 0)]); });
  const sc = addSheet(wb, "Weapon Scaling", "WEAPON LEVEL SCALING", "Formula-driven level table using the active base, step and minimum values from Weapons.", ["Affinity", "Attack", "Level", "Cooldown", "Damage", "Force"], scalingRows, [16, 24, 10, 16, 16, 16]);
  for (let r = 5; r <= scalingRows.length + 4; r++) {
    const src = 5 + Math.floor((r - 5) / 5);
    sc.getRange(`D${r}`).formulas = [[`=MAX(Weapons!$F$${src},Weapons!$D$${src}+(C${r}-1)*Weapons!$E$${src})`]];
    if (typeof weaponProfiles[src - 5][6] === "number") sc.getRange(`E${r}`).formulas = [[`=Weapons!$G$${src}+(C${r}-1)*Weapons!$H$${src}`]];
  }
  sc.getRange(`D5:F${scalingRows.length + 4}`).format.numberFormat = "0.00";

  const upgradeRows = await parseUpgrades();
  addSheet(wb, "Cards", "CARDS, ORGANS & ITEMS", "Every active UpgradeData resource, including affinity filtering, rarity, offer level and maximum rank.", ["ID", "Display name", "Kind", "Organ slot", "Affinity", "Rarity", "Max level", "Min player level", "Synergy tags", "Effect", "Source"], upgradeRows, [25, 28, 12, 14, 16, 14, 12, 16, 32, 68, 42]);

  const ft = addSheet(wb, "Flesh Tree", "FLESH TREE — PERSISTENT UPGRADES", "Upgrade cost at the next rank is base cost + current rank × cost step. Total column shows the full 0→5 investment.", ["ID", "Skill", "Per-level effect", "Max level", "Base cost", "Cost step", "Requires", "Total cost to max"], tree.map(x => [...x, null]), [22, 28, 42, 12, 14, 14, 24, 20]);
  for (let r = 5; r < tree.length + 5; r++) ft.getRange(`H${r}`).formulas = [[`=D${r}*E${r}+F${r}*D${r}*(D${r}-1)/2`]];
  ft.getRange(`D5:H${tree.length + 4}`).format.numberFormat = "0";

  addSheet(wb, "Enemies", "ENEMY & BOSS STATISTICS", "Base profiles before elite modifiers and encounter scaling.", ["Type", "HP", "Move speed", "Damage", "Attack timing", "Biomass / reward", "Knockback resistance", "Behavior", "Threat / notes"], enemies, [24, 12, 16, 18, 24, 20, 20, 48, 30]);
  addSheet(wb, "Encounters", "ENCOUNTER DIRECTOR", "Threat-budget phases across the 12-minute run. Caps are maximum ratios of the active population.", ["Phase", "Start", "End", "Threat budget", "Spawn interval", "Profiles", "Elite cap", "Spitter cap", "Charger cap"], phases, [28, 12, 12, 18, 18, 34, 14, 14, 14]);
  addSheet(wb, "Budgets", "PERFORMANCE & SPAWN BUDGETS", "Hard caps used to keep rushes and the boss readable and stable.", ["Category", "Value", "Meaning"], [
    ["Enemies", 73, "Maximum active enemy budget"], ["Enemy projectiles", 84, "Maximum active hostile projectiles"], ["Player projectiles", 72, "Maximum active player projectiles"], ["VFX", 72, "Maximum active effects"], ["Damage numbers", 28, "Maximum active floating numbers"], ["Pool per scene", 48, "Pooled instances per scene"], ["Target frame", 16.67, "Milliseconds"], ["Degrade threshold", 25.0, "Milliseconds before quality reduction"], ["Arena bounds", "96,176 — 2368×1110", "Spawnable gameplay rectangle"], ["Minimum spawn distance", 610, "Pixels from Koda"], ["Max enemies start/end", "24 / 55", "Run population curve"], ["Spitter/Charger caps", "30% / 20%", "Global composition limit"],
  ], [28, 24, 60]);

  for (let i = 0; i < wb.worksheets.items.length; i++) {
    const sh = wb.worksheets.getItemAt(i);
    const used = sh.getUsedRange();
    used.format.autofitRows();
    const preview = await wb.render({ sheetName: sh.name, autoCrop: "all", scale: 0.85, format: "png" });
    await fs.writeFile(`${previewsDir}/${String(i + 1).padStart(2, "0")}_${sh.name.replaceAll(" ", "_")}.png`, new Uint8Array(await preview.arrayBuffer()));
  }
  const report = await wb.inspect({ kind: "workbook,sheet,formula", maxChars: 10000, tableMaxRows: 8, tableMaxCols: 12, options: { maxResults: 250 } });
  await fs.writeFile(`${outDir}/inspection.txt`, report.ndjson ?? String(report), "utf8");
  const errors = await wb.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 200 }, maxChars: 8000 });
  await fs.writeFile(`${outDir}/formula_errors.txt`, errors.ndjson ?? String(errors), "utf8");
  const blob = await SpreadsheetFile.exportXlsx(wb);
  await blob.save(outFile);
  console.log(outFile);
}

await build();
