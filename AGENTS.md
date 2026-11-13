# Hinweise für Coding-Agenten

Vor jeder Aufgabe lesen:

- [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md): verbindliche Regeln für
  Grafik, Effekte, UI und Audio.
- [docs/ROADMAP.md](docs/ROADMAP.md): Phasen, Reihenfolge und Abnahme.

Regeln:

- Immer nur eine Phase aus der Roadmap bearbeiten, danach stoppen und
  Screenshots zeigen.
- Hauptplattform ist der PC (Forward+). Der Android-Pfad
  (`OS.has_feature("mobile")`) muss lauffähig bleiben, bekommt aber keine
  neuen Grafikeffekte.
- Keine sichtbaren Primitive (Würfel, Zylinder, Kugeln, flache Scheiben) als
  Spielobjekte.
- Fremdassets nur unter CC0 oder CC BY 4.0, abgelegt unter
  `assets/third_party/<quelle>/<name>/` und im selben Commit in `CREDITS.md`
  eingetragen.
- Godot 4.7.2. Tests vor dem Commit ausführen:

```sh
godot --headless --editor --path . --quit
for t in tests/test_*.gd; do godot --headless --path . --script "res://$t" || exit 1; done
```

- Nach abgeschlossener Phase den Status in der Tabelle in `docs/ROADMAP.md`
  aktualisieren.
- Antworten und Commit-Beschreibungen kurz halten. Bei Unklarheit nachfragen
  statt raten.
