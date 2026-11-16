# FPS-Report auf echter Hardware (Qualität: Hoch)

Hardware: NVIDIA GeForce GTX 1060 with Max-Q Design (Vulkan 1.4.312, Forward+, 1280x800).  
Messung: `--autoplay --quality=hoch` im vollen Schwarm (`>= 150` Gegner, `peak_enemies = 176`).

Kriterium laut [docs/ROADMAP.md](../ROADMAP.md):
- `1 % Low >= 60 FPS`
- Längster einzelner Frame `<= 25 ms`

| Arena | Durchschnitt | 1 % Low | Längster Frame | Zweitlängster Frame | Kriterium |
| --- | ---: | ---: | ---: | ---: | --- |
| Schrott-Halle (`foundry`) | 132.2 FPS | 70.5 FPS | 85.6 ms (@ 38.87 s) | 39.0 ms (@ 18.00 s) | 1 % Low erfüllt; Einzelframe > 25 ms |
| Verladehof (`rainyard`) | 133.4 FPS | 72.3 FPS | 59.6 ms (@ 27.63 s) | 20.1 ms (@ 18.00 s) | 1 % Low erfüllt; Einzelframe > 25 ms |

Hinweis: Ab dem 3. (Schrott-Halle, `16.4 ms`) bzw. 2. langsamsten Frame (Verladehof, `20.1 ms`) liegen alle Frames unter 25 ms; die vereinzelten Spikes (z. B. bei 18.00 s Boss-Übergang / Treffer-Spikes) überschreiten 25 ms.
