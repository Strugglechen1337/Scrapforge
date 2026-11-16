import math
import os
import random
import struct
import subprocess
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "audio", "sfx")


def write_ogg(name: str, samples: list[float]) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    wav_path = os.path.join(OUT_DIR, f"{name}.wav")
    ogg_path = os.path.join(OUT_DIR, f"{name}.ogg")
    peak = max((abs(s) for s in samples), default=1.0)
    scale = 0.88 / max(peak, 1e-6)
    with wave.open(wav_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * scale))
            frames.extend(struct.pack("<h", int(v * 32767)))
        wf.writeframes(bytes(frames))
    subprocess.run(
        ["ffmpeg", "-y", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4", "-ar", str(SAMPLE_RATE), ogg_path],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    os.remove(wav_path)


def synth_minigun(seed: int, base_hz: float) -> list[float]:
    rng = random.Random(seed)
    dur = 0.095
    n = int(SAMPLE_RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 36.0)
        freq = base_hz + 140.0 * math.exp(-t * 85.0)
        body = math.sin(2.0 * math.pi * freq * t) * 0.85
        sub = math.sin(2.0 * math.pi * (base_hz * 0.55) * t) * 0.55
        noise = rng.uniform(-1.0, 1.0)
        lp = lp * 0.72 + noise * 0.28
        click = math.exp(-t * 160.0) * math.sin(2.0 * math.pi * 1150.0 * t) * 0.35
        s = math.tanh((body + sub + lp * 0.85) * env * 1.6) + click
        out.append(s)
    return out


def synth_rocket() -> list[float]:
    rng = random.Random(201)
    dur = 0.34
    n = int(SAMPLE_RATE * dur)
    out = []
    lp1 = 0.0
    lp2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        punch_env = math.exp(-t * 20.0)
        whoosh_env = min(1.0, t / 0.03) * math.exp(-t * 6.5)
        f = 55.0 + 130.0 * math.exp(-t * 45.0)
        punch = math.sin(2.0 * math.pi * f * t) * punch_env * 0.9
        noise = rng.uniform(-1.0, 1.0)
        lp1 = lp1 * 0.86 + noise * 0.14
        lp2 = lp2 * 0.94 + lp1 * 0.06
        roar = (lp1 * 0.65 + lp2 * 0.75) * whoosh_env * 1.4
        out.append(math.tanh(punch + roar))
    return out


def synth_laser() -> list[float]:
    rng = random.Random(303)
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    out = []
    phase_main = 0.0
    phase_sub = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.008) * math.exp(-t * 9.5)
        f_main = 72.0 + 240.0 * math.exp(-t * 22.0)
        f_sub = 48.0 + 90.0 * math.exp(-t * 18.0)
        phase_main += 2.0 * math.pi * f_main / SAMPLE_RATE
        phase_sub += 2.0 * math.pi * f_sub / SAMPLE_RATE
        fm = math.sin(phase_main + 1.8 * math.sin(phase_main * 2.5) * math.exp(-t * 14.0))
        sub = math.sin(phase_sub) * 0.75
        ring = math.sin(2.0 * math.pi * 420.0 * t) * math.exp(-t * 26.0) * 0.28
        grit = rng.uniform(-1.0, 1.0) * math.exp(-t * 35.0) * 0.22
        out.append(math.tanh((fm * 0.75 + sub + ring + grit) * env * 1.5))
    return out


def synth_plasma() -> list[float]:
    dur = 0.24
    n = int(SAMPLE_RATE * dur)
    out = []
    p1 = 0.0
    p2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.01) * math.exp(-t * 11.0)
        f1 = 52.0 + 160.0 * math.exp(-t * 28.0)
        f2 = 104.0 + 210.0 * math.exp(-t * 30.0)
        p1 += 2.0 * math.pi * f1 / SAMPLE_RATE
        p2 += 2.0 * math.pi * f2 / SAMPLE_RATE
        core = math.sin(p1 + 2.4 * math.sin(p2) * math.exp(-t * 10.0))
        sub = math.sin(p1 * 0.5) * 0.8
        out.append(math.tanh((core * 0.8 + sub) * env * 1.6))
    return out


def synth_turret() -> list[float]:
    rng = random.Random(404)
    dur = 0.13
    n = int(SAMPLE_RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 28.0)
        f = 78.0 + 150.0 * math.exp(-t * 65.0)
        body = math.sin(2.0 * math.pi * f * t) * 0.9
        clank = math.sin(2.0 * math.pi * 620.0 * t) * math.exp(-t * 55.0) * 0.35
        lp = lp * 0.78 + rng.uniform(-1.0, 1.0) * 0.22
        out.append(math.tanh((body + lp * 0.75 + clank) * env * 1.5))
    return out


def synth_drone() -> list[float]:
    rng = random.Random(505)
    dur = 0.10
    n = int(SAMPLE_RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 34.0)
        f = 95.0 + 125.0 * math.exp(-t * 70.0)
        body = math.sin(2.0 * math.pi * f * t) * 0.85
        lp = lp * 0.70 + rng.uniform(-1.0, 1.0) * 0.30
        out.append(math.tanh((body + lp * 0.55) * env * 1.45))
    return out


def synth_flame_loop() -> list[float]:
    rng = random.Random(606)
    dur = 1.2
    n = int(SAMPLE_RATE * dur)
    raw = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    out = []
    lp1 = 0.0
    lp2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        x = raw[i]
        lp1 = lp1 * 0.89 + x * 0.11
        lp2 = lp2 * 0.96 + lp1 * 0.04
        rumble = math.sin(2.0 * math.pi * 48.0 * t) * 0.25 + math.sin(2.0 * math.pi * 73.0 * t) * 0.18
        out.append(math.tanh((lp1 * 0.85 + lp2 * 1.15 + rumble) * 1.3))
    # Crossfade last 0.1s with start for seamless looping.
    fade = int(SAMPLE_RATE * 0.1)
    for i in range(fade):
        alpha = i / fade
        out[i] = out[i] * alpha + out[n - fade + i] * (1.0 - alpha)
    return out[: n - fade]


def synth_mech_step(seed: int, base_hz: float) -> list[float]:
    rng = random.Random(seed)
    dur = 0.19
    n = int(SAMPLE_RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        thud_env = math.exp(-t * 18.0)
        f = base_hz + 55.0 * math.exp(-t * 45.0)
        thud = math.sin(2.0 * math.pi * f * t) * thud_env * 0.95
        servo = math.sin(2.0 * math.pi * 195.0 * t) * math.exp(-t * 32.0) * 0.22
        lp = lp * 0.85 + rng.uniform(-1.0, 1.0) * 0.15
        grit = lp * math.exp(-t * 25.0) * 0.65
        out.append(math.tanh((thud + servo + grit) * 1.5))
    return out


def synth_boss_spawn() -> list[float]:
    dur = 0.95
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.05) * math.exp(-t * 2.6)
        horn1 = math.sin(2.0 * math.pi * 65.4 * t + 0.7 * math.sin(2.0 * math.pi * 130.8 * t))
        horn2 = math.sin(2.0 * math.pi * 98.0 * t) * 0.55
        sub = math.sin(2.0 * math.pi * 38.0 * t) * math.exp(-t * 3.5) * 0.85
        out.append(math.tanh((horn1 * 0.75 + horn2 + sub) * env * 1.6))
    return out


def synth_level_up() -> list[float]:
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    out = []
    notes = [110.0, 164.81, 220.0, 329.63]
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.02) * math.exp(-t * 5.2)
        s = 0.0
        for idx, hz in enumerate(notes):
            onset = idx * 0.055
            if t >= onset:
                lt = t - onset
                s += math.sin(2.0 * math.pi * hz * lt) * math.exp(-lt * 6.5) * 0.45
        out.append(math.tanh(s * env * 1.5))
    return out


def main() -> None:
    write_ogg("minigun_0", synth_minigun(101, 108.0))
    write_ogg("minigun_1", synth_minigun(102, 102.0))
    write_ogg("rocket", synth_rocket())
    write_ogg("laser", synth_laser())
    write_ogg("plasma", synth_plasma())
    write_ogg("turret", synth_turret())
    write_ogg("drone", synth_drone())
    write_ogg("flame_loop", synth_flame_loop())
    write_ogg("mech_step_0", synth_mech_step(701, 46.0))
    write_ogg("mech_step_1", synth_mech_step(702, 42.0))
    write_ogg("boss_spawn", synth_boss_spawn())
    write_ogg("level_up", synth_level_up())
    print("Generated 12 SFX OGG files in", OUT_DIR)


if __name__ == "__main__":
    main()
