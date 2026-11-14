# Scrapforge – Fahrplan zum realistischen Look

Ziel: Das Spiel sieht modern und realistisch aus und fühlt sich wuchtig an.
Hauptplattform ist der PC (Windows/Linux, Forward+). Android muss weiter
starten und laufen, bekommt aber keine neuen Grafikeffekte.

Die Art Direction steht in [ART_DIRECTION.md](ART_DIRECTION.md) und ist für
alle Phasen verbindlich.

## Zielbild

- **Optik:** realistisches PBR, Schrott-Industriehalle bei Nacht, düster und
  dreckig, Orange und Cyan als Akzente. Stimmungsreferenz für Kamera,
  Lesbarkeit und Effektdichte: *The Riftbreaker*.
- **Mechanik:** klassische Survivors-Formel, wie sie aktuell *Warhammer
  Survivors* umsetzt.
- Referenz heißt Struktur und Niveau. Keine Namen, Figuren, Waffen, Stages,
  Texte, Assets oder Optik aus anderen Spielen übernehmen.
- Hauptplattform ist der PC (Forward+). Android bleibt lauffähig, bekommt aber
  keine neuen Grafikeffekte.

## Alleinstellungsmerkmale

Diese beiden Punkte gehen in keiner Phase verloren:

1. **Sichtbar modularer Mech.** Jedes Bauteil sitzt am Modell, der Build ist am
   Mech ablesbar, der Abschluss ist ein Screenshot im Ergebnisbildschirm.
2. **Realistische 3D-Grafik** statt Pixel-Look.

## Arbeitsweise

- Immer genau eine Phase bearbeiten, danach stoppen und Screenshots zeigen.
- Die Reihenfolge ist Absicht: Erst Licht, dann Welt, dann Effekte, dann
  Modelle. Neue Modelle sehen ohne Licht-Pass genauso flach aus wie die alten.
- Jede Phase endet mit der Abnahme unten.

## Abnahme (gilt für jede Phase)

1. Alle `tests/test_*.gd` laufen grün, CI bleibt grün. Geänderte Logik bekommt
   angepasste oder neue Tests.
2. Autoplay-FPS-Report vor und nach der Phase ausführen und beide Werte nennen
   (Durchschnitt, 1 % Low). Auf Qualitätsstufe "Hoch" liegt das 1 % Low im
   vollen Schwarm bei mindestens 60 FPS und kein einzelner Frame dauert länger
   als 25 ms. Das Einzelframe-Minimum allein ist kein Kriterium, es schwankt
   auch im Ausgangsstand zwischen etwa 52 und 70 FPS.
3. Vorher/Nachher-Screenshots aus der Spielkamera: Schwarm, Boss, Hangar,
   Ergebnis. Die Bilder in `docs/screenshots/` erst nach Freigabe ersetzen.
4. Checkliste aus `ART_DIRECTION.md` Abschnitt 12 abgehakt.
5. Neue Fremdassets stehen in `CREDITS.md`.
6. Android-Pfad (`OS.has_feature("mobile")`) unverändert lauffähig.

## Stand der Phasen

| Phase | Inhalt | Status |
|---|---|---|
| 1 | Licht und Rendering | fertig |
| 2 | Arena und Boden | fertig |
| 3 | Effekte und Trefferfeedback | fertig |
| 4 | Module und Säge: Primitive ersetzen | offen |
| 5 | Gegner und Boss vereinheitlichen | offen |
| 6 | Skins als Lack | offen |
| 7 | Audio | offen |
| 8 | Code-Aufräumen (`main.gd`) | offen |
| 9 | Inhalt und Tiefe | offen |

---

## Phase 1 – Licht und Rendering

Problem: `scripts/world_3d.gd` (ab ca. Zeile 109) nutzt eine feste
Hintergrund- und Ambient-Farbe. Ohne Himmel und Reflexionen wirken die
PBR-Metallmodelle flach, die Szene ist fast schwarz, Gegner sind kaum lesbar.

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 1.

1. HDRI-Himmel (Industrie/Hangar, Poly Haven, CC0, 2K) als Sky einbinden.
   Ambient- und Reflexionsquelle auf Sky stellen. Der sichtbare Hintergrund
   bleibt dunkel (Energie getrennt regeln), aber Metall muss sichtbar spiegeln.
2. SSAO und SSIL aktivieren und dezent einstellen.
3. Glow abstimmen: nur emissive Flächen und Effekte leuchten.
4. Lichtaufbau: kühles Hauptlicht mit Schatten, warmes Gegenlicht ohne
   Schatten, damit sich Silhouetten vom Boden lösen. Schattenqualität und
   -reichweite prüfen.
5. Leichter volumetrischer Nebel. Tonemapping, Belichtung und Color Grading
   (Kontrast, Sättigung) neu einstellen. Der Boden ist nirgends reines Schwarz.
6. Lesbarkeit: Spieler-Mech im Schwarm sofort erkennbar, Gegner heben sich
   klar vom Boden ab. Keine Gameplay-Änderungen.
7. Qualitätsstufe Hoch/Mittel/Niedrig im Einstellungsmenü. Sie schaltet SSAO,
   SSIL, volumetrischen Nebel und Schattenqualität und wird wie die anderen
   Einstellungen gespeichert.

Nicht in dieser Phase: neue Modelle, Umbau von main.gd.
Abnahme laut docs/ROADMAP.md. Danach stoppen und Screenshots zeigen.
```

## Phase 2 – Arena und Boden

Problem: Eine einzelne 1K-Textur (`MetalPlates001`) wird sichtbar gekachelt.
Props sind leuchtend orange und gelb. Die Arena-Grenze ist eine Leuchtlinie.

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 2.

1. Boden: Industrieboden in 2K (ambientCG oder Poly Haven, CC0) mit
   Variation, damit im Bildausschnitt keine Kachel erkennbar ist (zweite
   Textur per Maske mischen, Detail-Normalmap oder Stochastic Tiling).
2. Decals auf dem Boden: Ölflecken, Markierungen, Warnstreifen, Kratzer,
   Brandspuren, einzelne Pfützen mit Spiegelung.
3. Props (scripts/arena_props.gd): entsättigen und verschmutzen oder durch
   passende Modelle ersetzen. Farbe nur als Warnstreifen. Zusätzlich Schrott,
   Wracks, Rohre.
4. Arena-Grenze als Teil der Welt: Wände, Zäune oder Schrottberge statt
   Leuchtlinie. Die Kollisionsgrenze bleibt unverändert.
5. Lichtquellen in der Welt mit sichtbarer Ursache: Hallenstrahler,
   Warnleuchten, brennende Fässer.
6. Hintergrund außerhalb der Arena: angedeutete Halle, im Nebel verschwindend.

Abnahme laut docs/ROADMAP.md. Danach stoppen und Screenshots zeigen.
```

## Phase 3 – Effekte und Trefferfeedback

Problem: Projektile sind unbeleuchtete Kugeln, Treffer und Explosionen sind
sehr einfach (`scripts/combat_effects_3d.gd`, `scripts/weapons_3d.gd`).
Schadenszahlen sind zu klein.

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 3.

1. Projektile: gestreckte Leuchtspuren oder Modelle statt Kugeln. Eigene
   Schüsse orange, Gegnerschüsse rot und heller als alles andere im Bild.
2. Mündungsblitz mit kurzem Licht pro Waffe, Hülsen und Rauch bei der Minigun,
   Rauchspur bei Raketen, durchgehender Strahl mit Einschlagglühen beim Laser.
3. Treffer: kurzer heller Flash am Gegner plus Funken.
4. Tod: Explosion, Trümmerteile, Brandfleck als Decal, das ausblendet.
5. Schadenszahlen größer und lesbar: Orange normal, Weiß-Gelb kritisch.
6. Kamera: dezentes Wackeln nur bei schweren Ereignissen, bestehende
   Einstellung "Bildschirmwackeln" beachten. Kurzer Hit-Stop beim Boss-Treffer
   und beim Tod großer Gegner.
7. GPU-Partikel verwenden und Obergrenzen setzen, damit der Schwarm die
   Framerate nicht kippt. Auf Mobile bleibt der bisherige einfache Pfad.

Abnahme laut docs/ROADMAP.md. Danach stoppen und ein kurzes Video oder eine
Bildfolge zeigen.
```

## Phase 4 – Module und Säge

Problem: `scripts/module_visual_3d.gd` baut viele Teile aus Würfeln,
Zylindern und flachen Scheiben. Neben dem Colossus-Modell wirkt das angeklebt.
Die Säge hängt als flache Scheiben am Arm, obwohl sie spielmechanisch den Mech
umkreist (`scripts/main.gd`, Säge-Schaden mit Radius 78).

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 4.

1. Säge: Die flachen Scheiben am Arm (module_visual_3d.gd, Fall "saw")
   entfernen. Pro Stufe ein echtes 3D-Sägeblatt-Mesh mit Metallmaterial, das
   im Spiel an der Position der bestehenden Schadenslogik um den Mech kreist
   und um die eigene Achse rotiert. Funken bei Treffern. In Hangar und
   Ergebnisbildschirm kreisen die Blätter ebenfalls.
2. Die Säge belegt keinen Arm-Sockel mehr (upgrade_state.gd ARM_WEAPONS und
   data/saw.tres anpassen). Tests aktualisieren.
3. Alle übrigen Module durchgehen (Liste IDS in main.gd). Jedes Teil, das noch
   aus Primitiven besteht, durch ein passendes Modell ersetzen: Flammenwerfer,
   Plasma, Schubdüsen, Panzerung, Magnet, Kühlung, Radar, Sensor, Schwarm.
4. Stufen-Anzeige: Höhere Stufe zeigt sich am Modell selbst (mehr Läufe,
   zusätzliche Panzerplatten, größere Düse), nicht durch aufgesetzte
   Leuchtwürfel.
5. Jedes Modul sitzt sichtbar befestigt am Sockel. Aufbereitung über
   tools/blender/.

Abnahme laut docs/ROADMAP.md. Zusätzlich ein Hangar-Screenshot mit allen
Modulen auf höchster Stufe. Danach stoppen.
```

Hinweis: Punkt 2 ändert das Balancing, weil die Säge dann zusätzlich zu einer
Armwaffe wählbar ist. Wenn das nicht gewünscht ist, Punkt 2 streichen.

## Phase 5 – Gegner und Boss

Problem: Der Boss ist hell und rostig, der Schwarm dunkelgrau. Die
Gegnertypen unterscheiden sich in der Draufsicht kaum.

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 5.

1. Alle Gegner auf eine Materialsprache bringen (gleiches Metall, gleiche
   Abnutzung, rote Emission an Augen und Waffen).
2. Jeder Typ ist an der Silhouette erkennbar: Schwarm klein und flach, Brute
   breit und gepanzert, Fernkämpfer mit deutlich sichtbarer Waffe, Boss mit
   eigener Form und klaren Schwachstellen.
3. Fernkämpfer kündigen den Schuss sichtbar an (Aufladen, rotes Leuchten).
4. Boss: Auftritt mit kurzer Inszenierung, sichtbare Schadenszustände
   (Funken, Rauch, abfallende Teile).
5. Instanzierung und VAT-Animation des Schwarms beibehalten.

Abnahme laut docs/ROADMAP.md. Danach stoppen und Screenshots zeigen.
```

## Phase 6 – Skins als Lack

Problem: Die Skins färben das ganze Modell ein und wirken wie ein Farbfilter
(`scripts/colossus_paint.gdshader`, `data/skins/`).

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 6.

1. Lackmaske für den Colossus erzeugen (tools/blender/): Nur Panzerflächen
   sind lackierbar. Metall, Gelenke, Kabel bleiben unverändert.
2. Shader: Lackfarbe nur in der Maske, eigene Rauheit für Lack, Abnutzung an
   Kanten und Kratzer liegen über dem Lack.
3. Skins sind mehr als eine Farbe: Zweitfarbe, Streifen oder Nummern als
   Decal. Mindestens ein Skin mit Tarnmuster, einer mit Warnstreifen.
4. Bestehende fünf Skins bleiben wählbar und gespeichert.

Abnahme laut docs/ROADMAP.md. Hangar-Screenshot aller Skins. Danach stoppen.
```

## Phase 7 – Audio

Problem: Die Kampfmusik ist ein Chiptune-Stück und passt nicht zum
realistischen Stil. Waffen klingen dünn.

```text
Lies docs/ART_DIRECTION.md und docs/ROADMAP.md. Bearbeite NUR Phase 7.

1. Menü- und Kampfmusik durch düstere Industrial-/Synth-Stücke ersetzen
   (CC0 oder CC BY). Eigenes Stück für den Boss.
2. Eigener, tiefer Schuss-Sound pro Waffe. Leichte Tonhöhen-Variation gegen
   Wiederholung.
3. Schritte des Mechs, Einschläge, Explosionen, Aufstieg, Boss-Auftritt.
4. Begrenzung gleichzeitiger Stimmen pro Soundtyp, damit der Schwarm nicht
   übersteuert.
5. tests/test_audio.gd anpassen.

Abnahme laut docs/ROADMAP.md (ohne Screenshots). Danach stoppen.
```

## Phase 8 – Code-Aufräumen

Problem: `scripts/main.gd` hat rund 1460 Zeilen und mischt Spiellogik, UI,
Menüs und Zustände. Teile des Codes sind mit Leerzeichen, andere mit Tabs
eingerückt.

```text
Lies docs/ROADMAP.md. Bearbeite NUR Phase 8. Keine sichtbaren Änderungen.

1. main.gd in getrennte Skripte aufteilen: Spielzustand/Run, Waffenlogik,
   HUD, Menüs (Hauptmenü, Hangar, Einstellungen, Ergebnis), Aufstiegsauswahl.
2. Verhalten bleibt identisch. Bestehende Tests müssen ohne inhaltliche
   Änderung grün bleiben; nur Pfade und Zugriffe anpassen.
3. Einrückung im ganzen Projekt auf Tabs vereinheitlichen.
4. Platzhaltertexte in CREDITS.md bereinigen ("nur falls tatsächlich
   bearbeitet" durch die tatsächliche Bearbeitung ersetzen).

Abnahme: Tests und CI grün, FPS-Report unverändert, Screenshots identisch.
```

## Phase 9 – Inhalt und Tiefe

Erst angehen, wenn Phase 1 bis 5 abgenommen sind. Hier entscheidet sich der
Wiederspielwert. Dieser Abschnitt beschreibt das Mechanik-Zielbild. Er ist
noch keine Aufgabe: Vor dem Start wird daraus eine Phasenplanung mit
Abnahmekriterien gemacht.

### Mechanik-Zielbild

- **Evolutionen:** Jede Basiswaffe hat eine Evolution. Sie entsteht aus der
  Waffe auf Maximalstufe, einem passenden Zusatzmodul und einer Kiste (bisher
  nur Raketenwerfer + Radar = Schwarm-Werfer).
- **Elitegegner und Kisten:** Elitegegner lassen Kisten fallen. Die Kiste
  löst die Evolution aus, wenn die Bedingungen erfüllt sind.
- **Dauerhafter Fortschritt:** Schrott aus Runs kauft im Hangar Chassis und
  dauerhafte Werte.
- **Chassis:** Mehrere Chassis, jedes mit eigener Startwaffe und eigenem
  Spielstil.
- **Arenen:** Mehrere Arenen mit eigenen Gegnertypen und eigenem Licht (z. B.
  Außengelände bei Regen).
- **Bosse:** Mehrere Bosse. Einzelne haben eine Bedingung, etwa dass eine
  bestimmte Evolution nötig ist.
- **Freischalt-Ziele** für Chassis, Arenen, Waffen und Skins.

### Bewusst besser machen als die Vorlage

- Jede Waffenstufe ist spürbar: mehr Schaden, mehr Fläche oder neues
  Verhalten, nicht nur eine kleine Zahl.
- Dauerhafter Fortschritt ist Bonus und nie Pflicht zum Weiterkommen. Ein Run
  ist auch ohne Hangar-Käufe schaffbar.
- Keine reinen Grind-Ziele bei den Freischaltungen.
- Evolutionseffekte bleiben lesbar (Art Direction, Regel 1) und
  verdecken weder Spieler noch Gegner.
