# Offene Assets zum Ersetzen (skriptgenerierte Modelle & Sounds)

Diese Liste erfasst alle aktuell skriptgenerierten 3D-Modelle (`assets/models/modules/`, `assets/models/enemies/`) und generierten Soundeffekte (`assets/audio/sfx/`), die durch kuratierte CC0-/CC-BY-4.0-Fremdassets ersetzt werden sollen.

## 1. Module (`assets/models/modules/`)

| Dateiname | Verwendung im Spiel | Sockel | Gewünschte Größe (m) |
| --- | --- | --- | --- |
| `armor.glb` | Basis-Panzerungsmodul (Chassis-Kern) | `torso` / `left_shoulder` / `right_shoulder` | ca. 0,45 × 0,45 × 0,30 m |
| `armor_plate.glb` | Zusatz-Panzerplatte (Panzerung St. 2+, Minigun/Turm/Flamer/Sensor) | `torso`, `left_arm`, `left_shoulder`, `right_shoulder`, `head` | ca. 0,40 × 0,35 × 0,14 m |
| `cooldown.glb` | Kühler-Basismodul | `back` | ca. 0,45 × 0,50 × 0,30 m |
| `cooldown_tank.glb` | Kühltank-Paar (Kühler St. 2+) | `back` | ca. 0,22 × 0,42 × 0,22 m |
| `drone_dock.glb` | Drohnen-Schwarm-Dock (`hive_drone` Evolution) | `back` / `left_shoulder` | ca. 0,55 × 0,45 × 0,45 m |
| `flamethrower.glb` | Flammenwerfer & Inferno-Hauptrohr | `left_arm` / `right_arm` | ca. 0,35 × 0,35 × 0,85 m |
| `flamethrower_tank.glb` | Treibstofftank (Flammenwerfer St. 1+) | `left_arm` / `right_arm` | ca. 0,18 × 0,32 × 0,18 m |
| `gun_drum.glb` | Munitionstrommel (Minigun/Vulcan/Schulterturm) | `right_arm` / `left_shoulder` | ca. 0,28 × 0,28 × 0,32 m |
| `laser_coil.glb` | Fokussierspule (Laser/Prisma-Laser/Flammenwerfer) | `left_arm` / `right_arm` | ca. 0,26 × 0,26 × 0,30 m |
| `magnet.glb` | Magnetfeld-Kern Basis | `back` / `torso` | ca. 0,42 × 0,42 × 0,28 m |
| `magnet_coil.glb` | Induktionsspule (Magnet St. 2+, Drohnen-Dock) | `back` / `left_shoulder` | ca. 0,18 × 0,26 × 0,18 m |
| `mount_bracket.glb` | Waffen-Montagehalterung (Laser, Minigun, Flamer, Plasma) | `left_arm` / `right_arm` | ca. 0,30 × 0,28 × 0,24 m |
| `plasma.glb` | Plasmawerfer / Singularität-Basis | `left_arm` / `right_arm` | ca. 0,36 × 0,34 × 0,78 m |
| `plasma_coil.glb` | Plasma-Ringkühler (Plasma St. 2+) | `left_arm` / `right_arm` | ca. 0,24 × 0,24 × 0,22 m |
| `radar_array.glb` | Radar-Antennenarray (Radar St. 2+, Sensor St. 3+) | `head` / `back` | ca. 0,32 × 0,22 × 0,28 m |
| `rocket_pod_2.glb` | Raketenwerfer-Pod 2-fach (St. 1–2) | `right_shoulder` | ca. 0,52 × 0,38 × 0,58 m |
| `rocket_pod_4.glb` | Raketenwerfer-Pod 4-fach (St. 3–4) | `right_shoulder` | ca. 0,60 × 0,44 × 0,62 m |
| `rocket_pod_6.glb` | Raketenwerfer-Pod 6-fach (St. 5+) | `right_shoulder` | ca. 0,68 × 0,50 × 0,66 m |
| `sensor_pod.glb` | Seitenoptik-Pod (Sensor St. 2+) | `head` | ca. 0,16 × 0,16 × 0,22 m |
| `shield_emitter.glb` | Schildgenerator-Emitter (`shield` & `bastion`) | `back` | ca. 0,48 × 0,48 × 0,28 m |
| `shield_pylon.glb` | Schild-Pylonring (`shield` pro Stufe) | `back` | ca. 0,14 × 0,14 × 0,22 m |
| `swarm_pod.glb` | Schwarm-Werfer Evolution (`swarm`) | `right_shoulder` | ca. 0,72 × 0,52 × 0,68 m |
| `thruster.glb` | Schubdüsen-Basismodul | `back` / `legs` | ca. 0,44 × 0,42 × 0,36 m |
| `thruster_fin.glb` | Schubdüsen-Stabilisatorfinnen (St. 3+) | `back` / `legs` | ca. 0,52 × 0,32 × 0,24 m |
| `turret_pod.glb` | Schultergeschütz-Pod (`turret`) | `left_shoulder` | ca. 0,46 × 0,38 × 0,58 m |

## 2. Gegner-Anbauten (`assets/models/enemies/`)

| Dateiname | Verwendung im Spiel | Sockel | Gewünschte Größe (m) |
| --- | --- | --- | --- |
| `brute_armor.glb` | Zusatzpanzerung auf Gepanzerten Gegnern (Kind 1) | `brute_armor` (auf `brute` MultiMesh) | ca. 0,95 × 0,55 × 0,90 m |
| `ranged_cannon.glb` | Geschützlauf auf Fernkämpfer-Gegnern (Kind 2) | `ranged_cannon` (auf `ranged` MultiMesh) | ca. 0,42 × 0,34 × 0,72 m |
| `boss_turret.glb` | Rückengeschütz des Spinnen-Bosses (Kind 3 & 5) | `boss_rig` oben (`(0, 1.98, 0.05)`) | ca. 1,10 × 0,65 × 1,35 m |
| `boss_weakspot.glb` | Schwachstellen-Kerne an Flanken & Heck des Bosses | `boss_rig` Flanken & Heck (`(±0.92, 1.05, 0.05)`, `(0, 1.38, -1.02)`) | ca. 0,50 × 0,45 × 0,45 m |
| `boss_armor_plate.glb` | Absprengbare Flankenpanzerung des Bosses | `boss_rig` links/rechts (`(±1.12, 1.05, 0.05)`) | ca. 0,36 × 0,65 × 0,85 m |

## 3. Soundeffekte (`assets/audio/sfx/`)

| Dateiname | Verwendung im Spiel | Auslöser | Hinweise |
| --- | --- | --- | --- |
| `minigun_0.ogg` | Minigun / Vulcan Schuss (Variante 1) | `weapon_logic.gd` (`&"minigun"`) beim Feuern | Kurzer mechanischer Schuss-Impuls |
| `minigun_1.ogg` | Minigun / Vulcan Schuss (Variante 2) | `weapon_logic.gd` (`&"minigun"`) beim Feuern | Variation gegen Wiederholungs-Ermüdung |
| `rocket.ogg` | Raketenwerfer / Schwarm-Werfer Abschuss | `weapon_logic.gd` (`&"rocket"`) beim Abschuss | Tiefer Zisch-/Startimpuls |
| `laser.ogg` | Laser / Prisma-Laser Schuss | `AudioManager` (`&"laser"`) beim Laser-Impuls | Präziser Energie-Impuls |
| `flame_loop.ogg` | Flammenwerfer / Inferno Dauerfeuer | `AudioManager` (`&"flame"`) während Flammenstrahl aktiv | Nahtlos loopbar |
| `plasma.ogg` | Plasmawerfer / Singularität Schuss | `AudioManager` (`&"plasma"`) beim Abschuss | Schwerer Plasma-Impuls |
| `turret.ogg` | Schultergeschütz Schuss | `AudioManager` (`&"turret"`) beim Feuern | Kompakter Auto-Geschütz-Schuss |
| `drone.ogg` | Drohnen-Schwarm Angriff | `AudioManager` (`&"drone"`) bei Drohnen-Schuss | Leichter Energie-/Summ-Impuls |
| `mech_step_0.ogg` | Mech-Schritt (Variante 1) | `robot_3d.gd` (`&"mech_step"`) bei Schrittbewegung | Schwerer Metallschritt |
| `mech_step_1.ogg` | Mech-Schritt (Variante 2) | `robot_3d.gd` (`&"mech_step"`) bei Schrittbewegung | Zweiter Fuß / Variation |
| `level_up.ogg` | Aufstieg & Beutekisten-Fund | `weapon_logic.gd` (`&"level_up"`) | Klarer positiver Fanfaren-/Synth-Akzent |
| `boss_spawn.ogg` | Boss-Ankunft | `run_simulation.gd` (`&"boss"`) beim Boss-Spawn | Tiefes Warnsignal / Horn |
