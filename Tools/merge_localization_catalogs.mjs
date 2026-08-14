import fs from "node:fs";

const compiledPath = "tmp/progression_audit/compiled_translations.json";
const polishPath = "Localization/fleshdrive_polish.csv";
const outputPath = "Localization/fleshdrive_text.csv";

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (quoted) {
      if (char === '"' && text[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else if (char === '"') {
        quoted = false;
      } else {
        cell += char;
      }
      continue;
    }
    if (char === '"') {
      quoted = true;
    } else if (char === ",") {
      row.push(cell);
      cell = "";
    } else if (char === "\n") {
      row.push(cell.replace(/\r$/, ""));
      rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += char;
    }
  }
  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

function encodeCell(value) {
  const text = String(value ?? "");
  if (!/[",\r\n]/.test(text)) return text;
  return `"${text.replaceAll('"', '""')}"`;
}

const compiled = JSON.parse(fs.readFileSync(compiledPath, "utf8"));
const catalog = new Map();
for (const key of Object.keys(compiled.en)) {
	if (key.includes("�") || key.includes(',\"')) continue;
  catalog.set(key, {
    en: compiled.en[key] || key,
    hu: compiled.hu[key] || compiled.en[key] || key,
  });
}

const repairedLegacyMessages = {
  "A neural shield has a 35% chance to reverse an incoming projectile, amplifying it against enemies.":
    "Egy neurális pajzs 35% eséllyel visszafordít egy érkező lövedéket, amely felerősödve sebzi az ellenfeleket.",
  "Again? Hold still. You always twitch before the eyes are finished.":
    "Már megint? Maradj nyugton. Mindig rángatózol, mielőtt elkészülnek a szemeid.",
  "All telekinetic attacks recover 9% faster, deal 8% more damage and apply 8% stronger force, including Koda's auto-attack.":
    "Minden telekinetikus támadás 9%-kal gyorsabban töltődik, 8%-kal többet sebez és 8%-kal nagyobb erőt fejt ki, Koda automatikus támadását is beleértve.",
  "Battlefield control, forced positioning and projectile manipulation. Excels at shaping dense hordes.":
    "Csatatér-irányítás, kényszerített pozicionálás és lövedékmanipuláció. Sűrű hordák formálásában kiemelkedő.",
  "Damage over time, area denial and cascading explosions. Excels at controlling dense hordes.":
    "Folyamatos sebzés, területlezárás és láncolódó robbanások. Sűrű hordák irányításában kiemelkedő.",
  "Easy now. The imprint held. Most of you came back in the correct places.":
    "Nyugalom. A lenyomat megmaradt. A legtöbb részed a megfelelő helyre került vissza.",
  "Immediate burst damage, precise ranged pressure and lightning chains. Excels at deleting priority targets.":
    "Azonnali kitörő sebzés, precíz távolsági nyomás és láncvillámok. Elsődleges célpontok gyors megsemmisítésében kiemelkedő.",
  "Telekinetically captures living enemies and orbits them around Koda. Captives batter nearby targets, then collapse; higher levels hold more subjects.":
    "Telekinetikusan elfog élő ellenfeleket és Koda körül keringeti őket. A foglyok sebzik a közeli célpontokat, majd összeesnek; magasabb szinten több alany tartható fogva.",
  "The body is new. The memory is not. Your Blood Memory fragments are safe.":
    "A test új. Az emlék nem. A Vérmemória-töredékeid biztonságban vannak.",
  "The fabricator remembered your scars. I told it not to.":
    "A fabrikátor emlékezett a hegeidre. Pedig mondtam neki, hogy ne tegye.",
  "Was that the twenty-third? Never mind. I made another you.":
    "Ez volt a huszonharmadik? Mindegy. Készítettem belőled egy másikat.",
  "You are getting easier to print. I am not sure that is good.":
    "Egyre könnyebb kinyomtatni téged. Nem vagyok biztos benne, hogy ez jó.",
};
for (const [key, hu] of Object.entries(repairedLegacyMessages)) {
  catalog.set(key, { en: key, hu });
}

const polishRows = parseCsv(fs.readFileSync(polishPath, "utf8"));
for (const row of polishRows.slice(1)) {
  if (!row[0]) continue;
  catalog.set(row[0], {
    en: row[1] || row[0],
    hu: row[2] || row[1] || row[0],
  });
}

const lines = ["keys,en,hu"];
for (const [key, messages] of catalog) {
	if (`${key}${messages.en}${messages.hu}`.includes("�")) {
		throw new Error(`Invalid replacement character in localization key: ${key}`);
	}
  lines.push([
    encodeCell(key),
    encodeCell(messages.en),
    encodeCell(messages.hu),
  ].join(","));
}
fs.writeFileSync(outputPath, `${lines.join("\n")}\n`, "utf8");
console.log(`Wrote ${catalog.size} canonical localization entries.`);
