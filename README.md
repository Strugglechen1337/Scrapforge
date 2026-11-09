# Scrapforge

Ein origineller Survivor-Prototyp: Der Roboter bewegt sich durch eine Arena und schießt automatisch auf Gegner. Kristalle erhöhen die Stufe; beim Aufstieg wird ein Upgrade gewählt.

## Entwicklung

Godot 4.7.2 (Standard-Build) installieren, `project.godot` öffnen und das Projekt starten. Pfeiltasten oder linker Controller-Stick bewegen den Roboter; auf Touch-Geräten zieht man den virtuellen Stick über den Bildschirm. Menüs und Auswahl sind mit Tastatur oder Controller bedienbar.

Headless-Prüfung:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_upgrades.gd
godot --headless --path . --script res://tests/test_game.gd
# Alle weiteren tests/test_*.gd ebenfalls ausf?hren.
```

## Spielrunde

Kristalle sammeln und beim Stufenaufstieg eines von drei Bauteilen auswählen. Raketenwerfer und Radar auf Stufe 5 können zum Schwarm-Werfer verschmelzen. Nach fünf Minuten erscheint der Boss; sein Abschuss oder zehn Minuten Überleben bedeuten den Sieg. Der Ergebnisbildschirm zeigt den fertigen Roboter und speichert auf Knopfdruck ein PNG im Godot-Benutzerordner (der vollständige Pfad wird angezeigt).

Im Hauptmen? lassen sich Gesamtlautst?rke, Musik und Effekte getrennt einstellen; die Werte werden lokal gespeichert. Bildschirmwackeln und Vollbild lassen sich ebenfalls einstellen.

## Updates

Beim Start pr?ft Scrapforge anonym das neueste GitHub-Release. Unter ?Nach Updates suchen? im Hauptmen? l?sst sich die Suche manuell ausl?sen; bei Netzwerkfehlern oder wenn noch kein Release vorliegt, erscheint nur bei manueller Suche eine Meldung. Eine verf?gbare neue Version zeigt ihre Release-Notizen und die Schaltfl?chen ?Herunterladen? und ?Sp?ter?.

Unter Windows und Linux/Steam Deck ?ffnet ?Herunterladen? die Release-Seite im Browser. Unter Android ?ffnet es die APK-Downloadadresse im Browser; anschlie?end wird die heruntergeladene APK ?ber Android ge?ffnet. Eine direkte Installation aus dem App-Cache ist nicht implementiert: Android ben?tigt f?r die sichere Weitergabe an den Installer eine Content-URI ?ber einen konfigurierten FileProvider und gegebenenfalls die Berechtigung f?r Installationen aus unbekannten Quellen. Es wird kein automatischer Download oder Installationsfortschritt vorget?uscht.

## Release erstellen

Ein Push eines Tags wie `v0.2.0` startet den Release-Workflow. Er setzt daraus die Projektversion, installiert Godot 4.7.2 und die Exportvorlagen, exportiert Windows und Linux als ZIP sowie Android als APK und erstellt ein GitHub-Release mit automatischen Release-Notizen. Der Workflow erzeugt f?r die Android-APK einen **tempor?ren Debug-Keystore**; diese APK ist f?r Tests und nicht f?r einen Store-Release bestimmt. F?r Store-Releases muss ein eigener langlebiger Release-Keystore sicher verwahrt und als GitHub-Secret bereitgestellt werden; Signierung und Secrets m?ssen daf?r getrennt konfiguriert werden. Mit einem anderen Schl?ssel signierte APKs k?nnen nicht ?ber eine bestehende Installation aktualisiert werden.

## Touch-Steuerung

Im Spiel erscheint links beim Aufsetzen des Daumens ein virtueller Stick; ziehen bewegt den Mech, Loslassen h?lt ihn an. Der Stick beachtet die sicheren Bildschirmr?nder und verschwindet bei Tastatur- oder Controller-Eingabe. Men?s, Upgrade-Auswahl und Update-Dialog lassen sich antippen; Android verwendet das Querformat.

## Status

Spielbarer Prototyp. Bitte Issues oder Pull Requests mit reproduzierbaren Schritten und Tests einreichen; keine fremden Assets ohne passende Lizenz hinzuf?gen.
