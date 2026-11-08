# Scrapforge

Ein origineller Survivor-Prototyp: Der Roboter bewegt sich durch eine Arena und schießt automatisch auf Gegner. Kristalle erhöhen die Stufe; beim Aufstieg wird ein Upgrade gewählt.

## Entwicklung

Godot 4.7.2 (Standard-Build) installieren, `project.godot` öffnen und das Projekt starten. Pfeiltasten oder linker Controller-Stick bewegen den Roboter; auf Touch-Geräten zieht man den virtuellen Stick über den Bildschirm. Menüs und Auswahl sind mit Tastatur oder Controller bedienbar.

Headless-Prüfung:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_upgrades.gd
godot --headless --path . --script res://tests/test_game.gd
```

## Spielrunde

Kristalle sammeln und beim Stufenaufstieg eines von drei Bauteilen auswählen. Raketenwerfer und Radar auf Stufe 5 können zum Schwarm-Werfer verschmelzen. Nach fünf Minuten erscheint der Boss; sein Abschuss oder zehn Minuten Überleben bedeuten den Sieg. Der Ergebnisbildschirm zeigt den fertigen Roboter und speichert auf Knopfdruck ein PNG im Godot-Benutzerordner (der vollständige Pfad wird angezeigt).

Im Hauptmenü lassen sich Lautstärke, Bildschirmwackeln und Vollbild einstellen. Die aktuelle Version enthält noch keine Soundeffekte; der Regler ist für spätere Sounds vorgesehen.

## Status

Spielbarer Prototyp. Update-Funktion, Release-Automatisierung und Android-Export sind für eine spätere Etappe vorgesehen. Bitte Issues oder Pull Requests mit reproduzierbaren Schritten und Tests einreichen; keine fremden Assets ohne passende Lizenz hinzufügen.
