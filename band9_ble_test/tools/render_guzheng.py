"""Renderiza el banco de notas de Guzheng a partir del análisis espectral de UNA nota
real (tools/data/E5_Guzheng.json, "Audio Partial Analyzer", transpose_mode=fully_scaled).

Herramienta de desarrollo: se ejecuta UNA vez (no en el juego). El juego reproduce
los WAV resultantes como samples (sin síntesis en tiempo real).

    python3 tools/render_guzheng.py                 # notas que usa la canción
    python3 tools/render_guzheng.py C#2 D2 ...      # notas concretas

Salida: assets/audio/guzheng/<Nota>.wav con '#' escrito 's' (F#3 -> Fs3.wav),
mono 16 bit 44100 Hz. Si consigues grabaciones reales de una nota, guárdalas con el
mismo nombre: el juego usará el archivo que haya.
"""
import json, os, sys, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "data", "E5_Guzheng.json")
OUT = os.path.join(HERE, "..", "assets", "audio", "guzheng")
SR = 44100
LENGTH = 2.6          # s por nota (cola natural incluida)
# La grabación original tiene resonancias simpáticas fuertes (~219 y ~438 Hz, un La)
# que el análisis marca como "resonant". Transpuestas con cada nota quedarían una
# quinta por debajo y dominarían la altura percibida, así que se atenúan.
RESONANT_GAIN = 0.12
SONG_NOTES = ["F#3", "D#3", "C#3", "A#2", "C#2", "G#2", "F#2", "D#2",
              "C#5", "A#4", "D#5", "G#4", "F#4", "F#5", "D#4"]
NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
rng = np.random.default_rng(3)


def note_hz(n):
    name, octv = n[:-1], int(n[-1])
    midi = 12 * (octv + 1) + NAMES[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


def file_name(n):
    return n.replace("#", "s") + ".wav"


def shaped_noise(times, band_edges, psd_db, t0, n, scale=1.0):
    """Ruido con la envolvente espectral por bandas del análisis (STFT overlap-add)."""
    out = np.zeros(n)
    frame, hop = 512, 256
    win = np.hanning(frame)
    freqs = np.fft.rfftfreq(frame, 1 / SR)
    edges = np.array(band_edges) * scale
    psd = np.array(psd_db)
    times = np.array(times)
    for start in range(0, n - frame, hop):
        t = t0 + start / SR
        if t < times[0] - 0.02 or t > times[-1] + 0.02:
            continue
        k = int(np.clip(np.searchsorted(times, t), 0, len(times) - 1))
        gains_db = psd[k]
        g = np.zeros_like(freqs)
        for b in range(len(edges) - 1):
            m = (freqs >= edges[b]) & (freqs < edges[b + 1])
            g[m] = 10 ** (gains_db[b] / 20)
        spec = np.fft.rfft(rng.standard_normal(frame) * win) * g
        out[start:start + frame] += np.fft.irfft(spec) * win
    return out


def render(d, target_hz):
    f0 = d["fundamental"]["frequency_hz"]
    ratio = target_hz / f0
    # Las cuerdas graves resuenan algo más: estiramos levemente la envolvente.
    stretch = float(np.clip((1.0 / ratio) ** 0.22, 0.9, 1.7))
    n = int(LENGTH * SR)
    t = np.arange(n) / SR
    tonal = np.zeros(n)
    for p in d["partials"]:
        tr = p["amplitude_track"]
        tt = np.array(tr["time"]) * stretch
        amp = np.interp(t, tt, np.array(tr["amplitude"]), right=0.0)
        fr = np.interp(t, tt, np.array(tr["frequency_hz"])) * ratio
        if fr.max() >= SR / 2 * 0.95:
            continue
        # cola: decae suave en vez de cortarse donde terminó el análisis
        tail = t > tt[-1]
        if tail.any():
            last = np.interp(tt[-1], tt, np.array(tr["amplitude"]))
            amp[tail] = last * np.exp(-(t[tail] - tt[-1]) * 4.0)
        phase = 2 * np.pi * np.cumsum(fr) / SR + p.get("phase", {}).get("value", 0.0)
        gain = RESONANT_GAIN if p.get("type") == "resonant" else 1.0
        tonal += gain * amp * np.sin(phase)
    # transitorio (ataque del plectro) y residual: poco escalados
    tr_ = d["transient"]
    trans = shaped_noise(tr_["times"], tr_["band_edges_hz"], tr_["band_psd_db"], 0.0, n, min(ratio, 1.5) ** 0.5)
    res = d["residual"]
    resid = shaped_noise(res["times"], res["band_edges_hz"], res["band_psd_db"], 0.0, n, ratio ** 0.5)
    e_t = np.sum(tonal ** 2) + 1e-12

    def mix(x, ratio_e):
        e = np.sum(x ** 2)
        return x * np.sqrt(ratio_e * e_t / e) if e > 0 else x
    y = tonal + mix(trans, tr_["energy_ratio"]) + mix(resid, res["energy_ratio"])
    # fundido final corto: sin clic al terminar el sample
    fade = int(0.08 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)
    y[:16] *= np.linspace(0, 1, 16)
    return y / (np.max(np.abs(y)) + 1e-9) * 0.85


def save(path, y):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    d = json.load(open(SRC))
    notes = sys.argv[1:] or SONG_NOTES
    os.makedirs(OUT, exist_ok=True)
    for nt in notes:
        save(os.path.join(OUT, file_name(nt)), render(d, note_hz(nt)))
        print(f"{nt:4s} {note_hz(nt):8.2f} Hz -> {file_name(nt)}")
