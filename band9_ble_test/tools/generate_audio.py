"""Genera los audios placeholder del vertical slice (herramienta de desarrollo, NO forma
parte del juego ni de la cadena Band 9 → Godot).

Uso:  python3 tools/generate_audio.py      (requiere numpy)
Salida: assets/audio/gen/*.wav  (22050 Hz, mono, 16 bit)

Todas las capas musicales duran exactamente LOOP_SECONDS para que, arrancadas a la vez,
permanezcan sincronizadas en loop. Sustitúyelas por grabaciones reales con el mismo
nombre y duración cuando existan.
"""
import os
import wave
import numpy as np

SR = 22050
TEMPO = 75.0
BEAT = 60.0 / TEMPO
BEATS = 16
LOOP_SECONDS = BEAT * BEATS  # 12.8 s
N = int(round(LOOP_SECONDS * SR))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "gen")
rng = np.random.default_rng(7)

def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)

# Escala yo (pentatónica japonesa SIN semitonos) sobre D: D E G A B.
# Es consonante: el inicio debe sentirse seguro. La disonancia leve (Eb) solo
# aparece en la capa de tormenta.
INSEN = [62, 64, 67, 69, 71, 74, 76, 79]
DISSONANT = 63


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def place(buf, snd, t):
    """Suma snd en buf en el segundo t, envolviendo al inicio (loop perfecto)."""
    i = int(t * SR) % len(buf)
    end = i + len(snd)
    if end <= len(buf):
        buf[i:end] += snd
    else:
        k = len(buf) - i
        buf[i:] += snd[:k]
        buf[: end - len(buf)] += snd[k:]


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def pluck(freq, dur=2.2, bright=0.5):
    """Karplus-Strong: cuerda pulsada tipo koto."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p) * bright + rng.uniform(-1, 1, p) * (1 - bright) * 0.3
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.996 * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    env = np.exp(-np.linspace(0, 3.0, n))
    return out * env


def drum(f0, f1, dur, noise=0.1, decay=12.0):
    t = np.linspace(0, dur, int(dur * SR), endpoint=False)
    f = f1 + (f0 - f1) * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * decay)
    nz = rng.uniform(-1, 1, len(t)) * np.exp(-t * 60) * noise
    return body + nz


def shaker(dur=0.08):
    t = np.linspace(0, dur, int(dur * SR), endpoint=False)
    nz = rng.uniform(-1, 1, len(t))
    nz = nz - lowpass(nz, 0.3)  # paso alto rudimentario
    return nz * np.exp(-t * 70) * 0.5


# ---------- CAPA 0: agua / viento / pájaros ----------
def layer_ambient():
    buf = np.zeros(N)
    wind = lowpass(rng.uniform(-1, 1, N), 0.01)
    t = np.arange(N) / SR
    wind *= 0.6 + 0.4 * np.sin(2 * np.pi * t / LOOP_SECONDS)  # sube y baja una vez por loop
    buf += wind * 3.0
    water = lowpass(rng.uniform(-1, 1, N), 0.15) * 0.25
    buf += water
    for _ in range(26):  # pequeñas gotas/burbujas
        f = rng.uniform(900, 1700)
        d = 0.09
        tt = np.linspace(0, d, int(d * SR), endpoint=False)
        snd = np.sin(2 * np.pi * (f + 900 * tt / d) * tt) * np.exp(-tt * 45) * 0.12
        place(buf, snd, rng.uniform(0, LOOP_SECONDS))
    for _ in range(4):  # pájaros lejanos
        base = rng.uniform(2500, 3400)
        t0 = rng.uniform(0, LOOP_SECONDS)
        for k in range(3):
            d = 0.07
            tt = np.linspace(0, d, int(d * SR), endpoint=False)
            snd = np.sin(2 * np.pi * (base + 700 * np.sin(np.pi * tt / d)) * tt) * np.sin(np.pi * tt / d) * 0.05
            place(buf, snd, t0 + k * 0.12)
    # fundido de los extremos para un loop sin clics en el viento
    return buf


# ---------- CAPA 1: armonía koto ----------
def layer_harmony():
    buf = np.zeros(N)
    melody = [0, None, 2, None, 3, None, None, 2, 1, None, 0, None, 4, None, 3, None]
    for b, idx in enumerate(melody):
        if idx is None:
            continue
        place(buf, pluck(hz(INSEN[idx]), 2.5, 0.6) * 0.7, b * BEAT)
    for b in (0, 8):  # bajo suave
        place(buf, pluck(hz(INSEN[0] - 12), 4.0, 0.3) * 0.6, b * BEAT)
    for b in (4, 12):
        place(buf, pluck(hz(INSEN[2] - 12), 4.0, 0.3) * 0.5, b * BEAT)
    return buf


# ---------- CAPA 2: pulso (bongó discreto) ----------
def layer_pulse():
    buf = np.zeros(N)
    for b in range(BEATS):
        if b % 2 == 0:
            place(buf, drum(260, 180, 0.25, 0.15, 18) * 0.8, b * BEAT)
        if b % 4 == 3:
            place(buf, drum(340, 240, 0.18, 0.15, 22) * 0.5, b * BEAT + BEAT * 0.5)
    return buf


# ---------- CAPA 3: ritmo / ostinato ----------
def layer_rhythm():
    buf = np.zeros(N)
    for s in range(BEATS * 2):
        place(buf, shaker() * (0.8 if s % 2 == 0 else 0.45), s * BEAT / 2)
    pattern = [0, 1.5, 2, 3.5]
    for bar in range(BEATS // 4):
        for k, off in enumerate(pattern):
            place(buf, drum(300 if k % 2 else 200, 150, 0.22, 0.2, 16) * 0.6, (bar * 4 + off) * BEAT)
    for b in range(BEATS):  # ostinato de koto en corcheas
        place(buf, pluck(hz(INSEN[(b * 3) % 5 + 2]), 0.6, 0.8) * 0.25, b * BEAT + BEAT / 2)
    return buf


# ---------- CAPA 4: tempestad ----------
def layer_storm():
    buf = np.zeros(N)
    for b in range(0, BEATS, 2):  # taiko grave
        place(buf, drum(110, 55, 0.6, 0.3, 6) * 1.0, b * BEAT)
    for s in range(BEATS * 4):  # trémolo con una disonancia LEVE y ocasional
        note = DISSONANT if (s // 8) % 4 == 3 else INSEN[0]
        place(buf, pluck(hz(note + 12), 0.25, 0.9) * 0.08, s * BEAT / 4)
    t = np.arange(N) / SR
    gust = lowpass(rng.uniform(-1, 1, N), 0.04) * (0.5 + 0.5 * np.sin(2 * np.pi * t * 2 / LOOP_SECONDS) ** 2)
    buf += gust * 1.2
    return buf


# ---------- efectos sueltos ----------
def sfx_plim():
    d = 0.9
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    f = 1320 * (1 + 0.04 * np.exp(-t * 40))
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 6) + 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 14)
    x[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return x


def sfx_meow(pitch=1.0, dur=0.55):
    t = np.linspace(0, dur, int(dur * SR), endpoint=False)
    shape = np.sin(np.pi * t / dur)
    f0 = (420 + 280 * np.sin(np.pi * t / dur * 0.9)) * pitch
    ph = 2 * np.pi * np.cumsum(f0) / SR
    src = sum(np.sin(k * ph) / k for k in range(1, 9))
    formant = np.sin(2 * np.pi * (900 + 700 * shape) * t)
    x = src * (0.7 + 0.3 * formant) * shape ** 0.7
    return lowpass(x, 0.35)


def sfx_crash():
    d = 0.8
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    x = np.zeros_like(t)
    for f in (2100, 3170, 4480, 5230, 2730):
        x += np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t * rng.uniform(6, 12))
    x += rng.uniform(-1, 1, len(t)) * np.exp(-t * 40) * 1.5
    tk = drum(180, 90, 0.2, 0.4, 25)
    x[: len(tk)] += tk * 1.5
    return x


def sfx_coin():
    d = 0.5
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    x = np.sin(2 * np.pi * 1760 * t) * np.exp(-t * 9)
    h = int(0.07 * SR)
    x[h:] += np.sin(2 * np.pi * 2349 * t[: len(t) - h]) * np.exp(-t[: len(t) - h] * 8)
    return x


def sfx_pop():
    return drum(700, 400, 0.08, 0.05, 50)


def sfx_tuk():
    return drum(240, 160, 0.12, 0.2, 35)


def sfx_purr():
    d = 2.0
    n = int(d * SR)
    t = np.arange(n) / SR
    nz = lowpass(rng.uniform(-1, 1, n), 0.05)
    am = 0.5 + 0.5 * np.sin(2 * np.pi * 26 * t)
    breath = 0.6 + 0.4 * np.sin(2 * np.pi * t / d)
    return nz * am * breath


def sfx_chime():
    # fūrin: campanilla de viento, brillante y suave
    d = 2.2
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    x = np.zeros_like(t)
    for f, a, dec in ((2093, 1.0, 2.2), (3136, 0.5, 3.0), (4699, 0.3, 4.0), (2637, 0.4, 2.6)):
        x += a * np.sin(2 * np.pi * f * t) * np.exp(-t * dec)
    x += 0.6 * np.concatenate([np.zeros(int(0.18 * SR)), (np.sin(2 * np.pi * 2349 * t) * np.exp(-t * 2.5))[: len(t) - int(0.18 * SR)]])
    return x


def sfx_bell():
    d = 2.5
    t = np.linspace(0, d, int(d * SR), endpoint=False)
    x = np.zeros_like(t)
    for k, a in ((1, 1), (2.76, 0.5), (5.4, 0.25)):
        x += a * np.sin(2 * np.pi * 660 * k * t) * np.exp(-t * (1.5 + k))
    return x


if __name__ == "__main__":
    save("layer0_ambient.wav", layer_ambient(), 0.7)
    save("layer1_harmony.wav", layer_harmony(), 0.7)
    save("layer2_pulse.wav", layer_pulse(), 0.7)
    save("layer3_rhythm.wav", layer_rhythm(), 0.7)
    save("layer4_storm.wav", layer_storm(), 0.75)
    save("plim.wav", sfx_plim(), 0.6)
    save("meow.wav", sfx_meow(1.0), 0.6)
    save("meow_urgent.wav", np.concatenate([sfx_meow(1.35, 0.22), np.zeros(800), sfx_meow(1.45, 0.22), np.zeros(800), sfx_meow(1.4, 0.3)]), 0.7)
    save("crash.wav", sfx_crash(), 0.7)
    save("coin.wav", sfx_coin(), 0.5)
    save("pop.wav", sfx_pop(), 0.5)
    save("tuk.wav", sfx_tuk(), 0.5)
    save("purr.wav", sfx_purr(), 0.6)
    save("bell.wav", sfx_bell(), 0.5)
    save("chime.wav", sfx_chime(), 0.45)
    print("OK ->", os.path.normpath(OUT), "loop =", LOOP_SECONDS, "s")
