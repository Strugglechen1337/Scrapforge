# Scrapforge

Ein origineller Survivor-Prototyp: Der Roboter bewegt sich durch eine Arena und schießt automatisch auf Gegner. Kristalle erhöhen die Stufe; beim Aufstieg wird ein Upgrade gewählt.

## Entwicklung

Godot 4.7.2 (Standard-Build) installieren, `project.godot` öffnen und das Projekt starten. Pfeiltasten oder linker Controller-Stick bewegen den Roboter; auf Touch-Geräten zieht man den virtuellen Stick über den Bildschirm. Menüs und Auswahl sind mit Tastatur oder Controller bedienbar.

Headless-Prüfung:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_upgrades.gd
```

## Status

Frühes Grundgerüst, noch keine veröffentlichungsfähige Ausbaustufe: Entwicklung, Boss, vollständige Bauteile und Effekte, Update-Funktion, Einstellungen, Screenshot-Funktion und Export-Workflows fehlen. Android und Steam Deck sind noch nicht verifiziert. Bitte Issues oder Pull Requests mit reproduzierbaren Schritten und Tests einreichen; keine fremden Assets ohne passende Lizenz hinzufügen.
