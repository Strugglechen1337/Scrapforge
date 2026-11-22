# Animations-Bestandsaufnahme (Punkt 1)

## Bereits vorhanden
- **`scripts/robot_3d.gd`**: Laufzyklus (`thigh_l/r`, `shin_l/r`, `upper_arm_l/r`, leichtes Torso-Roll, vertikales Bobbing), pauschaler Arm-Rückstoß (`recoil` über `game.fire_clock`), Schritt-Audio (`mech_step`).
- **`scripts/weapons_3d.gd` & `scripts/combat_effects_3d.gd`**: Mündungsfeuer (`muzzle`), Flammenkegel (`flame`), Laserstrahl (`beam`), Hülsen/Rauch/Trefferfunken.
- **`scripts/module_visual_3d.gd`**: Konstante Eigenrotation (`animated`) für Radar/Säge sowie statische `exhaust()`-Partikel an Flammenwerfer und Schubdüsen.

## Was fehlt
1. **Waffenreaktionen beim Feuern je Modul (`module_visual_3d.gd` + Feuer-Trigger):**
   - **Minigun / Vulcan**: Läufe/Trommel drehen beim Feuern hoch und laufen gedämpft nach, leichter Lauf-Rückstoß.
   - **Raketenwerfer / Schwarm-Werfer**: deutlicher Pod-Rückstoß, leichtes Aufrichten/Kicken der Rohre, Rauchstoß am Pod.
   - **Schulterturm / Railgun**: starker Rückstoß am Turm-Sockel mit gedämpftem Rücklauf und kurzem Nachglühen.
   - **Flammenwerfer / Inferno**: Düsen-Vibration/Zittern und aktive Flamme am Rohr während des Feuerns.
   - **Säge / Shredder**: Sägeblatt dreht sichtbar und beschleunigt spürbar bei aktivem Einsatz / Gegnernähe.
   - **Laserkanone / Prisma-Laser**: kurzes Auflade-Pulsieren vor/beim Schuss und gedämpfter Rückstoß.
2. **Körperbewegung (`robot_3d.gd`):**
   - Torso und Hüfte/Kopf folgen leicht und gedämpft dem Zielen (Aim-Lead), zusätzlich zur Beinrichtung.
   - Dezentes Wippen/Gewichtsverlagerung (Pitch/Roll) beim Laufen für alle drei Chassis (Colossus, Vanguard, Bastion).
   - Ganzkörper-Rückstoß (kurzes Nachfedern auf Torso/Hüfte) beim Feuern schwerer Waffen.
   - Schubdüsen reagieren sichtbar auf Bewegungstempo (Skalierung/Intensität der Abgasfahne).
