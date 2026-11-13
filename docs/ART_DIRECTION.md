# Scrapforge – Art Direction

Verbindlich für jede Änderung an Grafik, Effekten, UI und Audio. Wer ein Asset
hinzufügt oder ändert, prüft es gegen die Checkliste am Ende. Bei Widerspruch
zwischen diesem Dokument und einer Einzelaufgabe gilt dieses Dokument, außer
die Aufgabe hebt eine Regel ausdrücklich auf.

## 1. Leitsatz

**Ein schwerer Kampfmech wühlt sich nachts durch eine verlassene
Schrott-Industriehalle, während Maschinenschwärme aus dem Dunkel kommen.**

Alles ist aus Metall, benutzt, schwer und dreckig. Licht kommt von wenigen
Quellen: kaltes Hallenlicht von oben, warmes Feuer und Mündungsblitze, dazu
gezielte Neonakzente. Nichts ist sauber, bunt oder verspielt.

Stimmungsreferenz für Kamera, Lesbarkeit und Effektdichte: Top-down-Mech-Action
wie *The Riftbreaker*. Referenz heißt Zielniveau und Stimmung, nicht Kopie:
keine Assets, Logos, Figuren oder Layouts aus anderen Spielen übernehmen.

## 2. Drei Regeln, die immer gelten

1. **Lesbarkeit vor Schönheit.** Spieler, Gegner, Projektile und Sammelbares
   sind in der Draufsicht in unter einer halben Sekunde zu unterscheiden.
2. **Keine Primitive.** Kein sichtbares Objekt besteht aus nackten Würfeln,
   Zylindern, Kugeln oder flachen Scheiben. Ausnahme: Partikel und kurzlebige
   Effekte.
3. **Ein Stil.** Realistisches PBR. Keine Low-Poly-, Cartoon-, Pixel- oder
   Chiptune-Elemente.

## 3. Farben

Farbe ist Information. Jede Rolle hat genau eine Farbe; sie wird nicht für
etwas anderes verwendet.

| Rolle | Farbe | Hex | Verwendung |
|---|---|---|---|
| Spieler / eigene Waffen | Orange | `ff7a1a` | Mündungsfeuer, Reaktor, eigene Projektile, UI-Hauptakzent |
| Technik / Nutzen / Sammelbares | Cyan | `33f5ff` | Schrott, Schild, Radar, Magnet, EP, UI-Zweitakzent |
| Gegner / Gefahr | Rot | `ff2a2a` | Gegneraugen, Gegnerprojektile, Warnzonen, Boss-Leiste |
| Selten / Evolution | Violett | `c65cff` | Nur Evolutionen und seltene Aufstiege |
| Heilung | Grün | `5dff8a` | Nur Reparatur |
| Umgebung | Stahlgrau, Rost, Ölschwarz | `4f647d`, `7a4a2e`, `0b111a` | Boden, Wände, Props |

Regeln:

- Die Umgebung ist entsättigt. Gesättigte Farbe gibt es nur als Licht oder
  Emission, nie als großflächiger Lack auf Props.
- Gegner haben nie Orange oder Cyan, der Spieler nie Rot.
- Maximal etwa 10 % der Bildfläche sind gesättigt.
- UI-Farben stehen in `scripts/ui/ui_theme.gd` (`ORANGE`, `CYAN`) und werden
  von dort verwendet, nicht neu definiert.

## 4. Licht und Rendering (PC, Forward+)

- Himmel/HDRI als Ambient- und Reflexionsquelle. Metall muss immer etwas zu
  spiegeln haben.
- Lichtaufbau: kühles Hauptlicht mit Schatten von oben, warmes Gegenlicht ohne
  Schatten für die Silhouetten, lokale Lichter an Props und Effekten.
- SSAO, SSIL, Glow und leichter volumetrischer Nebel sind auf "Hoch" aktiv.
- Glow kommt nur von emissiven Flächen und Effekten. Kein Schleier über dem
  ganzen Bild.
- Tonemapping filmisch (ACES oder AgX). Schwarz bleibt Schwarz, aber der Boden
  ist nie reines Schwarz: Bodendetails sind überall erkennbar.
- Jede Lichtquelle hat eine sichtbare Ursache (Lampe, Feuer, Reaktor, Schuss).
- Android nutzt den Mobile-Renderer und bekommt keine dieser Effekte. Der
  bestehende Mobile-Pfad darf nicht brechen.

## 5. Materialien

- Ausschließlich PBR mit Farb-, Normal- und Rauheits-/Metallkarte.
- Unbeleuchtete (unshaded) Materialien nur für Effekte und UI.
- Abnutzung ist Pflicht: Kratzer an Kanten, Ruß an Mündungen und Düsen, Rost
  in Vertiefungen, Öl am Boden. Kein Objekt sieht fabrikneu aus.
- Rauheit variiert innerhalb eines Objekts. Einheitlich glänzend oder
  einheitlich matt wirkt künstlich.
- Emissive Flächen sind klein und haben eine Funktion (Auge, Anzeige, Düse,
  Lauf).
- Skins sind Lack: Sie färben nur lackierte Panzerflächen. Blankes Metall,
  Gelenke, Kabel und Abnutzung bleiben unverändert und liegen über dem Lack.

## 6. Modelle

Richtwerte, keine harten Grenzen. Bei Überschreitung FPS-Report prüfen.

| Typ | Dreiecke | Texturen |
|---|---|---|
| Spieler-Mech (gesamt, ohne Module) | bis 80.000 | 2K |
| Waffen- und Zusatzmodul | bis 15.000 | 1K |
| Schwarmgegner (instanziert) | bis 5.000 | 512–1K |
| Elite- / Fernkampfgegner | bis 15.000 | 1K |
| Boss | bis 60.000 | 2K |
| Prop | bis 10.000 | 1K |
| Boden / große Flächen | – | 2K, kachelbar, mit Variation |

- Maßstab: 1 Einheit = 1 Meter. Der Spieler-Mech ist rund 4–5 m hoch.
- Silhouette zuerst: Jeder Gegnertyp ist aus der Kameraperspektive
  (`scripts/world_3d.gd`, FOV 40, schräg von oben) allein an der Form
  erkennbar. Größe allein reicht nicht als Unterschied.
- Module sitzen sichtbar befestigt an einem Sockel. Nichts schwebt lose am
  Mech, außer es ist spielmechanisch ein umkreisendes Objekt; dann kreist es
  auch in Hangar und Ergebnisbildschirm.
- Die Optik eines Moduls zeigt, was es spielmechanisch tut.
- Aufbereitung über die Skripte in `tools/blender/`, damit sie wiederholbar
  bleibt.

## 7. Umgebung

- Boden: Industrieboden mit Platten, Rosten, Markierungen, Ölflecken, Pfützen
  und Brandspuren. Keine sichtbar wiederholte Kachel im Bildausschnitt.
- Props: Schrott, Container, Fässer, Wracks, Kräne, Rohre. Entsättigt, rostig,
  mit Warnstreifen als einziger Farbe. Keine leuchtend orangen oder gelben
  Großflächen.
- Arena-Grenzen sind Teil der Welt (Wände, Zäune, Schrottberge), keine
  leuchtenden Linien.
- Tiefe durch Nebel und abgedunkelten Hintergrund, nie durch harte Schwärze.

## 8. Effekte

- Waffen haben Wucht: Mündungsblitz mit kurzem Licht, Leuchtspur, Einschlag
  mit Funken, Rauch. Projektile sind gestreckte Leuchtspuren oder Modelle,
  keine Kugeln.
- Treffer: kurzer heller Flash am Gegner plus Funken. Tod: Explosion, Trümmer,
  Brandfleck auf dem Boden.
- Gegnerprojektile und Gefahrenzonen sind rot und heller als alles andere im
  Bild.
- Effekte sind kurz (meist unter 0,5 s) und verdecken den Spieler nie
  dauerhaft.
- Schadenszahlen: groß genug zum Lesen, Orange für normal, Weiß-Gelb für
  kritisch.
- Bildschirmwackeln nur bei schweren Ereignissen und abschaltbar (Einstellung
  existiert).

## 9. UI

- Bestehender Stil bleibt: dunkle Stahlpaneele, abgeschrägte Ecken, Orange und
  Cyan, klare Großbuchstaben.
- Das HUD belegt nur die Bildränder. Die Bildmitte bleibt frei.
- Icons sind einfarbige Piktogramme im selben Strichstil.
- Jede Animation unter 0,25 s. Kein Element blinkt dauerhaft.

## 10. Audio

- Sound gehört zur Art Direction: schwer, metallisch, mechanisch.
- Musik: düsterer Industrial-/Synth-Soundtrack. Keine Chiptune-Musik.
- Jede Waffe hat einen eigenen, tiefen Schuss-Sound. Schritte des Mechs sind
  hörbar.

## 11. Quellen und Lizenzen

- Erlaubt: CC0 und CC BY 4.0. Bevorzugte Quellen: Poly Haven (HDRI, Texturen,
  Modelle), ambientCG (Texturen), Sketchfab (nur Modelle mit Download und
  passender Lizenz), OpenGameArt und Freesound (nur CC0 / CC BY).
- Verboten: NC, ND, "Editorial", unklare Lizenz, Modelle aus anderen Spielen,
  KI-generierte Assets ohne geklärte Rechte.
- Jedes Fremdasset wird im selben Commit in `CREDITS.md` eingetragen: Titel,
  Autor, Link, Lizenz, Art der Bearbeitung.
- Fremdassets liegen unter `assets/third_party/<quelle>/<name>/`.

## 12. Checkliste vor jedem Commit mit sichtbarer Änderung

- [ ] Passt zum Leitsatz (Abschnitt 1)?
- [ ] Keine sichtbaren Primitive, kein Stilbruch?
- [ ] Farben nach Rollentabelle, Umgebung entsättigt?
- [ ] Spieler und Gegner in der Draufsicht sofort unterscheidbar?
- [ ] PBR-Material mit Abnutzung, Emission nur mit Funktion?
- [ ] Lizenz erlaubt und in `CREDITS.md` eingetragen?
- [ ] Tests grün, FPS-Report vorher/nachher verglichen?
- [ ] Vorher/Nachher-Screenshot aus der Spielkamera erstellt?
