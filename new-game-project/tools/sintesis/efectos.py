"""Efectos de sonido: detalles ocasionales de cada lugar, interfaz e interacciones.

Cada generador recibe la variante (`k`) para que las repeticiones no suenen idénticas. Los sonidos
lejanos llevan ya su reverberación y su filtrado de distancia; los de interfaz son secos y suaves.
"""

from __future__ import annotations

import numpy as np

from . import instrumentos as ins
from .ambientes import _ceramic, _clock_tick
from .dsp import (SR, Bus, bandpass, convolve_reverb, db, fade, highpass, impulse_response, lowpass, noise,
                  normalize_peak, resonator, rng_for, samples, stereo, time_axis)


def _env(n: int, attack: float, decay: float) -> np.ndarray:
    t = time_axis(n)
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.exp(-np.clip(t - attack, 0, None) / max(decay, 1e-4))


def _room(x: np.ndarray, name: str, t60: float, wet: float, damping: float = 0.55, room: float = 1.0) -> np.ndarray:
    ir = impulse_response(name, max(1.0, t60 * 1.4), t60, predelay=0.01, damping=damping, room=room)
    out = convolve_reverb(x, ir)
    dry = np.concatenate([stereo(x), np.zeros((len(out) - len(x), 2))])
    return _trim(dry + out * wet)


def _trim(x: np.ndarray, floor: float = 3e-5) -> np.ndarray:
    level = np.max(np.abs(stereo(x)), axis=1)
    last = np.nonzero(level > floor)[0]
    end = int(last[-1]) + samples(0.02) if len(last) else len(x)
    return fade(x[:end], 0.0, min(0.05, end / SR / 4))


def _creak(rng: np.random.Generator, length: float, rate: tuple[float, float], modes: list[float],
           q: float = 12.0) -> np.ndarray:
    """Crujido de madera por rozamiento: un tren de impulsos de ritmo cambiante (adherencia y
    deslizamiento) que excita los modos de la tabla."""
    n = samples(length)
    t = time_axis(n)
    curve = np.interp(t, [0, length * rng.uniform(0.3, 0.7), length], [rate[0], rate[1], rate[0] * rng.uniform(0.8, 1.2)])
    curve *= 1 + 0.15 * np.sin(2 * np.pi * rng.uniform(3, 7) * t)
    phase = np.cumsum(curve) / SR
    impulses = np.zeros(n)
    ticks = np.nonzero(np.diff(np.floor(phase)) > 0)[0]
    impulses[ticks] = rng.uniform(0.4, 1.0, len(ticks))
    out = np.zeros(n)
    for k, mode in enumerate(modes):
        out += resonator(impulses, mode * rng.uniform(0.95, 1.05), q) * (0.8 ** k)
    out += highpass(impulses, 2000, 1) * 0.15
    env = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 0.8
    return out * env


def _thud(rng: np.random.Generator, freq: float, decay: float, knock: float = 0.5) -> np.ndarray:
    n = samples(decay * 6 + 0.05)
    t = time_axis(n)
    body = np.sin(2 * np.pi * freq * (t + 0.02 * (1 - np.exp(-t / 0.02)))) * np.exp(-t / decay)
    hit = lowpass(noise(n, rng), 900, 2) * np.exp(-t / 0.015) * knock
    return (body + hit) * np.clip(t / 0.001, 0, 1)


def _latch(rng: np.random.Generator) -> np.ndarray:
    n = samples(0.25)
    out = np.zeros(n)
    for offset in [0.0, rng.uniform(0.03, 0.06), rng.uniform(0.09, 0.14)]:
        start = samples(offset)
        m = samples(0.04)
        t = time_axis(m)
        click = highpass(noise(m, rng), 2200, 2) * np.exp(-t / 0.003)
        ring = np.sin(2 * np.pi * rng.uniform(2400, 3600) * t) * np.exp(-t / 0.012) * 0.4
        out[start:start + m] += (click + ring) * rng.uniform(0.5, 1.0)
    return out


def _rustle(rng: np.random.Generator, length: float, density: float = 400.0, low: float = 1200.0,
            high: float = 9000.0) -> np.ndarray:
    """Papel: muchos microchasquidos con una envolvente de gesto."""
    n = samples(length)
    t = time_axis(n)
    grains = np.zeros(n)
    count = int(density * length)
    positions = rng.integers(0, n, count)
    np.add.at(grains, positions, np.clip(rng.lognormal(0, 0.45, count), 0, 2.5) * rng.choice([-1, 1], count))
    crackle = bandpass(grains, low, high, 2)
    air = bandpass(noise(n, rng), 400, 3000, 1) * 0.15
    env = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.5 * (1 + 0.5 * np.sin(2 * np.pi * rng.uniform(6, 11) * t))
    return (crackle * 0.5 + air) * env


def _whoosh(rng: np.random.Generator, length: float, start_hz: float, end_hz: float) -> np.ndarray:
    n = samples(length)
    t = time_axis(n)
    source = noise(n, rng, "pink")
    centers = np.geomspace(start_hz, end_hz, 16)
    out = np.zeros(n)
    edges = np.linspace(0, n, 17).astype(int)
    for k, center in enumerate(centers):
        a, b = max(0, edges[k] - samples(0.02)), min(n, edges[k + 1] + samples(0.02))
        piece = bandpass(source[a:b], center * 0.7, min(center * 1.4, SR * 0.45), 1)
        out[a:b] += piece * np.hanning(b - a)
    return out * np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.2


def _overlay(*parts: np.ndarray) -> np.ndarray:
    """Suma sonidos mono de distinta duración, todos desde el principio."""
    out = np.zeros(max(len(part) for part in parts))
    for part in parts:
        out[: len(part)] += part
    return out


def _finish(x: np.ndarray, peak_db: float) -> np.ndarray:
    return normalize_peak(_trim(x), peak_db)


# --- Café ---

def taza_plato(k: int) -> np.ndarray:
    rng = rng_for(f"taza{k}")
    return _finish(_room(_ceramic(rng, 1.0), "cafe_sfx", 0.8, 0.35, room=0.6), -8.0)


def cucharilla(k: int) -> np.ndarray:
    rng = rng_for(f"cucharilla{k}")
    bus = Bus(samples(1.2))
    position = 0.0
    base = rng.uniform(4200, 5600)
    for hit in range(rng.integers(3, 6)):
        n = samples(0.12)
        t = time_axis(n)
        tone = sum(np.sin(2 * np.pi * base * r * t) * np.exp(-t / tau) * a for r, a, tau in
                   [(1.0, 1.0, 0.035), (1.48, 0.5, 0.025), (2.2, 0.3, 0.015)])
        bus.add(stereo(tone * rng.uniform(0.4, 1.0)), samples(position))
        position += rng.uniform(0.11, 0.19)
    return _finish(_room(bus.data[:, 0], "cafe_sfx", 0.8, 0.3, room=0.6), -12.0)


def silla(k: int) -> np.ndarray:
    rng = rng_for(f"silla{k}")
    length = rng.uniform(0.35, 0.7)
    scrape = _creak(rng, length, (rng.uniform(60, 90), rng.uniform(110, 170)), [180, 420, 900, 1700], q=5)
    scrape += bandpass(noise(len(scrape), rng), 300, 2500, 1) * np.hanning(len(scrape)) * 0.2
    scrape = lowpass(scrape, 3500, 2)
    tail = _thud(rng, 140, 0.05, 0.4) * 0.5
    out = np.concatenate([scrape, tail])
    return _finish(_room(out, "cafe_sfx", 0.8, 0.4, room=0.6), -10.0)


def cafetera(k: int) -> np.ndarray:
    """Vaporizador de la cafetera exprés de la barra."""
    rng = rng_for(f"cafetera{k}")
    n = samples(2.2)
    t = time_axis(n)
    hiss = bandpass(noise(n, rng), 2000, 9000, 2) * (1 + 0.3 * np.sin(2 * np.pi * 23 * t))
    gurgle = bandpass(noise(n, rng), 200, 900, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t) ** 2) * 0.5
    env = np.clip(t / 0.15, 0, 1) * np.clip((2.2 - t) / 0.5, 0, 1)
    return _finish(_room((hiss * 0.4 + gurgle) * env, "cafe_sfx", 0.8, 0.3, room=0.6), -14.0)


def caja_registradora(k: int) -> np.ndarray:
    rng = rng_for(f"caja{k}")
    bus = Bus(samples(1.6))
    for offset in (0.0, 0.07, 0.13, 0.2):
        bus.add(stereo(_latch(rng) * 0.6), samples(offset))
    bell_sound = ins.bell(1650.0, 1.8, 0.8, f"caja{k}", 1.0)
    bus.add(stereo(bell_sound), samples(0.24), 1.2)
    drawer = lowpass(noise(samples(0.35), rng), 1800, 2) * np.hanning(samples(0.35)) * 0.3
    bus.add(stereo(drawer), samples(0.3))
    bus.add(stereo(_thud(rng, 110, 0.05) * 0.6), samples(0.62))
    return _finish(_room(bus.data[:, 0], "cafe_sfx", 0.8, 0.3, room=0.6), -10.0)


# --- Interiores (mansión y archivo) ---

def crujido(k: int) -> np.ndarray:
    rng = rng_for(f"crujido{k}")
    length = rng.uniform(0.5, 1.4)
    creak = _creak(rng, length, (rng.uniform(25, 45), rng.uniform(70, 140)), [rng.uniform(230, 380), rng.uniform(600, 900), 1500], q=14)
    creak = lowpass(creak, 3000, 2)
    return _finish(_room(creak, "mansion_sfx", 2.6, 0.55, room=1.5), -9.0)


def puerta_lejana(k: int) -> np.ndarray:
    rng = rng_for(f"puerta_lejana{k}")
    out = np.concatenate([_creak(rng, 0.6, (40, 90), [300, 700], q=10) * 0.4, _thud(rng, 75, 0.12, 0.6)])
    out = lowpass(out, 1200, 2)
    return _finish(_room(out, "mansion_sfx", 2.6, 0.8, room=1.5), -10.0)


def rafaga_ventana(k: int) -> np.ndarray:
    """Una ráfaga sacude los ventanales: viento que crece y el cristal vibrando en su marco."""
    rng = rng_for(f"rafaga{k}")
    n = samples(3.0)
    t = time_axis(n)
    wind = bandpass(noise(n, rng, "pink"), 150, 1200, 2) * np.sin(np.pi * t / 3.0) ** 2
    rattle = np.zeros(n)
    for position in np.sort(rng.uniform(0.8, 2.2, 14)):
        start = samples(position)
        m = samples(0.03)
        rattle[start:start + m] += resonator(noise(m, rng), rng.uniform(600, 1200), 10) * np.exp(-time_axis(m) / 0.008)
    out = wind * 0.6 + rattle * 0.5
    return _finish(_room(out, "mansion_sfx", 2.6, 0.5, room=1.5), -11.0)


def pagina(k: int) -> np.ndarray:
    rng = rng_for(f"pagina{k}")
    return _finish(_room(_rustle(rng, rng.uniform(0.35, 0.6), 500), "archivo_sfx", 1.4, 0.35), -14.0)


def sello_lejano(k: int) -> np.ndarray:
    rng = rng_for(f"sello_lejano{k}")
    bus = Bus(samples(1.4))
    for offset in (0.0, rng.uniform(0.45, 0.7)):
        bus.add(stereo(_thud(rng, 120, 0.03, 0.8)), samples(offset), rng.uniform(0.7, 1.0))
    return _finish(_room(lowpass(bus.data[:, 0], 2500, 2), "archivo_sfx", 1.4, 0.5), -12.0)


def reloj_campanada() -> np.ndarray:
    """Una campanada del reloj de pie (varilla grave). El juego da tantas como marque la hora."""
    rng = rng_for("campanada")
    out = ins.rod_gong(174.6, 6.5, 1.0, "reloj_pie")
    octave = ins.rod_gong(349.2, 3.0, 0.25, "reloj_pie2")
    out[: len(octave)] += octave
    out[: samples(0.02)] += _clock_tick(rng, True, 0.6)[: samples(0.02)]
    return _finish(_room(out, "mansion_sfx", 2.6, 0.35, room=1.5), -6.0)


# --- Exteriores ---

def trueno_lejano(k: int) -> np.ndarray:
    """Trueno lejano: varios retumbos graves que se encadenan y una cola larga."""
    rng = rng_for(f"trueno{k}")
    length = rng.uniform(7.0, 9.5)
    n = samples(length)
    t = time_axis(n)
    out = np.zeros(n)
    for _ in range(rng.integers(6, 11)):
        start = rng.uniform(0.0, length * 0.45)
        attack = rng.uniform(0.05, 0.4)
        decay = rng.uniform(0.6, 2.4)
        local = np.clip(t - start, 0, None)
        env = np.where(t >= start, np.clip(local / attack, 0, 1) * np.exp(-np.clip(local - attack, 0, None) / decay), 0)
        out += env * rng.uniform(0.3, 1.0)
    rumble = lowpass(noise(n, rng, "brown"), rng.uniform(220, 420), 2) * out
    crack = bandpass(noise(n, rng), 300, 1400, 2) * np.exp(-t / 0.25) * 0.15
    result = fade(rumble + crack, 0.02, 1.5)
    return _finish(_room(result, "exterior_sfx", 3.0, 0.5, damping=0.7, room=2.0), -5.0)


def contraventana(k: int) -> np.ndarray:
    """Una contraventana golpea con el viento en alguna calle cercana."""
    rng = rng_for(f"contraventana{k}")
    bus = Bus(samples(1.2))
    position = 0.0
    for hit in range(rng.integers(2, 4)):
        bus.add(stereo(_thud(rng, rng.uniform(140, 200), 0.05, 0.9) * (0.65 ** hit)), samples(position))
        position += rng.uniform(0.12, 0.25)
    out = lowpass(bus.data[:, 0], 1800, 2)
    return _finish(_room(out, "exterior_sfx", 3.0, 0.7, damping=0.7, room=2.0), -10.0)


def buho(k: int) -> np.ndarray:
    """Cárabo en la noche: «juu… ju-juuuu», con el temblor de la nota larga."""
    rng = rng_for(f"buho{k}")
    f0 = rng.uniform(380, 440)
    bus = Bus(samples(3.2))
    for start, length, glide, quaver in [(0.0, 0.45, 0.94, 0.0), (1.05, 0.14, 0.97, 0.0), (1.3, 1.25, 0.9, 1.0)]:
        n = samples(length)
        t = time_axis(n)
        freq = f0 * np.interp(t, [0, length * 0.2, length], [0.97, 1.0, glide])
        freq *= 1 + 0.02 * quaver * np.sin(2 * np.pi * 24 * t) * np.clip(t / 0.3, 0, 1)
        phase = np.cumsum(freq) / SR * 2 * np.pi
        tone = np.sin(phase) + 0.15 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
        breath = bandpass(noise(n, rng), f0 * 0.8, f0 * 2.5, 1) * 0.15
        env = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.6
        bus.add(stereo((tone + breath * 0.6) * env), samples(start))
    out = lowpass(bus.data[:, 0], 1800, 2)
    return _finish(_room(out, "exterior_sfx", 3.0, 0.65, damping=0.7, room=2.0), -12.0)


def campana_torre(muffled: bool = False) -> np.ndarray:
    """Una campanada de la torre del reloj (el juego repite tantas como la hora). Con `muffled`, la
    misma oída desde dentro de un edificio."""
    out = ins.bell(392.0, 7.5, 1.0, "torre", 0.9)
    if muffled:
        out = lowpass(out, 700, 2) * 0.8
        return _finish(_room(out, "interior_campana", 1.5, 0.4), -10.0)
    return _finish(_room(lowpass(out, 3500, 1), "exterior_sfx", 3.0, 0.5, damping=0.7, room=2.0), -6.0)


def silbato_tren(k: int) -> np.ndarray:
    """Silbato de vapor lejano: tres tubos afinados en acorde, con soplo y entrada en glissando."""
    rng = rng_for(f"silbato{k}")
    pattern = [(0.0, 1.8)] if k == 0 else [(0.0, 0.45), (0.65, 1.3)]
    bus = Bus(samples(3.2))
    for start, length in pattern:
        n = samples(length)
        t = time_axis(n)
        tone = np.zeros(n)
        for ratio in (1.0, 1.26, 1.5):
            f = 330.0 * ratio * np.interp(t, [0, 0.12, length], [0.93, 1.0, 0.99])
            phase = np.cumsum(f) / SR * 2 * np.pi
            tone += np.sin(phase) + 0.3 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
        steam = bandpass(noise(n, rng), 1500, 6000, 1) * 0.25
        env = np.clip(t / 0.1, 0, 1) * np.clip((length - t) / 0.25, 0, 1)
        bus.add(stereo((tone / 3 + steam) * env), samples(start))
    out = lowpass(bus.data[:, 0], 2200, 2)
    return _finish(_room(out, "exterior_sfx", 3.0, 0.8, damping=0.7, room=2.0), -12.0)


def golpe_metal(k: int) -> np.ndarray:
    """Golpe metálico en las vías o en el material del andén."""
    rng = rng_for(f"metal{k}")
    n = samples(1.6)
    t = time_axis(n)
    out = np.zeros(n)
    for _ in range(7):
        f = rng.uniform(300, 2600)
        out += np.sin(2 * np.pi * f * t) * np.exp(-t / rng.uniform(0.08, 0.6)) * rng.uniform(0.2, 1.0)
    out += lowpass(noise(n, rng), 1500, 1) * np.exp(-t / 0.01) * 2
    return _finish(_room(lowpass(out, 3000, 2), "exterior_sfx", 3.0, 0.6, damping=0.7, room=2.0), -11.0)


def campana_anden() -> np.ndarray:
    """La campana de mano del jefe de estación."""
    rng = rng_for("campana_anden")
    bus = Bus(samples(3.5))
    for k in range(6):
        bus.add(stereo(ins.bell(1180.0, 1.6, rng.uniform(0.6, 1.0), f"anden{k % 2}", 1.0)), samples(0.32 * k))
    return _finish(_room(lowpass(bus.data[:, 0], 3500, 2), "exterior_sfx", 3.0, 0.6, damping=0.7, room=2.0), -12.0)


# --- Interfaz ---

def ui_mover(k: int) -> np.ndarray:
    rng = rng_for(f"mover{k}")
    tone = ins.marimba(84 + (0, 2, -1)[k % 3], 0.35)[: samples(0.08)]
    tick = highpass(noise(samples(0.01), rng), 2500, 2) * np.hanning(samples(0.01)) * 0.08
    tone[: len(tick)] += tick
    return normalize_peak(fade(tone, 0, 0.03), -14.0)


def ui_aceptar() -> np.ndarray:
    bus = Bus(samples(0.5))
    bus.add(stereo(ins.marimba(69, 0.6)), 0)
    bus.add(stereo(ins.marimba(76, 0.5)), samples(0.045))
    return normalize_peak(_trim(bus.data[:, 0]), -10.0)


def ui_cancelar() -> np.ndarray:
    bus = Bus(samples(0.5))
    bus.add(stereo(ins.marimba(64, 0.5)), 0)
    bus.add(stereo(ins.marimba(57, 0.45)), samples(0.06))
    return normalize_peak(_trim(bus.data[:, 0]), -12.0)


def ui_abrir() -> np.ndarray:
    rng = rng_for("ui_abrir")
    return normalize_peak(_overlay(_whoosh(rng, 0.28, 700, 3200), _rustle(rng, 0.25, 250) * 0.3), -15.0)


def ui_cerrar() -> np.ndarray:
    rng = rng_for("ui_cerrar")
    return normalize_peak(_overlay(_whoosh(rng, 0.25, 2800, 600), _rustle(rng, 0.2, 200) * 0.3), -16.0)


def pausa(opening: bool) -> np.ndarray:
    """Abrir la pausa: el mundo se apaga (barrido hacia los graves) y un golpe sordo. Cerrarla hace
    lo contrario."""
    rng = rng_for("pausa" + str(opening))
    sweep = _whoosh(rng, 0.45, 3000 if opening else 400, 400 if opening else 3000)
    thump = _thud(rng, 90, 0.08, 0.3)
    out = np.zeros(max(len(sweep), len(thump) + samples(0.05)))
    out[: len(sweep)] += sweep
    start = 0 if opening else samples(0.3)
    end = min(len(out), start + len(thump))
    out[start:end] += thump[: end - start] * 0.6
    return normalize_peak(_trim(out), -12.0)


def notificacion() -> np.ndarray:
    bus = Bus(samples(1.6))
    bus.add(stereo(ins.vibraphone(74, 0.45, 0.9)), 0)
    bus.add(stereo(ins.vibraphone(81, 0.4, 1.1)), samples(0.12))
    return normalize_peak(_trim(bus.data[:, 0]), -14.0)


def guardado() -> np.ndarray:
    """Timbre del carro de una máquina de escribir y el papel que se desliza."""
    rng = rng_for("guardado")
    bus = Bus(samples(1.5))
    bus.add(stereo(_rustle(rng, 0.3, 200) * 0.4), 0)
    bus.add(stereo(ins.bell(2300.0, 1.2, 0.7, "guardado", 0.8)), samples(0.18))
    return normalize_peak(_trim(bus.data[:, 0]), -13.0)


def tecla(k: int) -> np.ndarray:
    """Tecleo apagado de la máquina de escribir para el texto de los diálogos."""
    rng = rng_for(f"tecla{k}")
    n = samples(0.05)
    t = time_axis(n)
    click = highpass(noise(n, rng), 2000 + 300 * k, 2) * np.exp(-t / 0.003)
    body = np.sin(2 * np.pi * (620 + 40 * k) * t) * np.exp(-t / 0.008) * 0.5
    ping = np.sin(2 * np.pi * (3300 + 150 * k) * t) * np.exp(-t / 0.01) * 0.15
    return normalize_peak(fade(click + body + ping, 0, 0.01), -16.0)


# --- Interacciones ---

def _door(rng: np.random.Generator, creak_length: float, creak_modes: list[float], thud_hz: float,
          close_at: float) -> Bus:
    bus = Bus(samples(close_at + 1.0))
    bus.add(stereo(_latch(rng)), 0)
    bus.add(stereo(_creak(rng, creak_length, (35, 80), creak_modes, q=10) * 0.5), samples(0.06))
    bus.add(stereo(_thud(rng, thud_hz, 0.09, 0.7)), samples(close_at))
    bus.add(stereo(_latch(rng) * 0.5), samples(close_at + 0.03))
    return bus


def puerta_cafe() -> np.ndarray:
    """La puerta del café con su campanilla."""
    rng = rng_for("puerta_cafe")
    bus = _door(rng, 0.45, [320, 750, 1400], 120, 0.95)
    for k, offset in enumerate((0.12, 0.19, 0.28, 0.41, 0.55)):
        bus.add(stereo(ins.bell(2100.0 + 40 * (k % 2), 0.9, 0.55 * 0.8 ** k, f"campanilla{k % 2}", 1.0)), samples(offset))
    return _finish(_room(bus.data[:, 0], "cafe_sfx", 0.8, 0.3, room=0.6), -6.0)


def puerta_mansion() -> np.ndarray:
    rng = rng_for("puerta_mansion")
    bus = _door(rng, 1.3, [190, 430, 980], 70, 1.55)
    return _finish(_room(bus.data[:, 0], "mansion_sfx", 2.6, 0.45, room=1.5), -6.0)


def puerta_archivo() -> np.ndarray:
    rng = rng_for("puerta_archivo")
    bus = _door(rng, 0.7, [260, 620, 1300], 95, 1.1)
    return _finish(_room(bus.data[:, 0], "archivo_sfx", 1.4, 0.35), -6.0)


def puerta_salida() -> np.ndarray:
    """Salir a la calle: la puerta se abre, entra el rumor de la lluvia y se cierra detrás."""
    rng = rng_for("puerta_salida")
    bus = _door(rng, 0.5, [300, 700, 1500], 110, 1.0)
    n = samples(1.6)
    t = time_axis(n)
    rain = bandpass(noise(n, rng, "pink"), 500, 7000, 1) * np.clip(t / 0.25, 0, 1) * np.clip((1.6 - t) / 0.6, 0, 1)
    bus.add(stereo(rain * 0.25), samples(0.1))
    return _finish(_room(bus.data[:, 0], "exterior_sfx", 3.0, 0.3, damping=0.7, room=2.0), -6.0)


def puerta_cerrada() -> np.ndarray:
    """Pomo que no cede: dos sacudidas del picaporte."""
    rng = rng_for("puerta_cerrada")
    bus = Bus(samples(1.0))
    for offset in (0.0, 0.32):
        bus.add(stereo(_latch(rng)), samples(offset))
        bus.add(stereo(_thud(rng, 130, 0.03, 0.4) * 0.5), samples(offset + 0.05))
    return _finish(_room(bus.data[:, 0], "cafe_sfx", 0.8, 0.3, room=0.6), -8.0)


def _step(rng: np.random.Generator, surface: str, velocity: float) -> np.ndarray:
    n = samples(0.25)
    t = time_axis(n)
    heel = lowpass(noise(n, rng), {"piedra": 500, "madera": 350, "baldosa": 700}[surface], 2) * np.exp(-t / 0.02)
    scuff = bandpass(noise(n, rng), 900, 4500, 1) * np.exp(-np.clip(t - 0.03, 0, None) / 0.03) * (t > 0.02) * 0.3
    out = heel + scuff
    if surface == "piedra":
        drops = np.zeros(n)
        for position in rng.integers(samples(0.01), samples(0.08), 25):
            m = samples(0.006)
            drops[position:position + m] += np.sin(2 * np.pi * rng.uniform(2500, 6000) * time_axis(m)) * np.exp(-time_axis(m) / 0.0015)
        out += drops * 0.5 + highpass(noise(n, rng), 3000, 1) * np.exp(-t / 0.04) * 0.2
    elif surface == "madera":
        out += resonator(noise(n, rng) * np.exp(-t / 0.005), rng.uniform(180, 260), 8) * 0.6
    else:
        out += resonator(noise(n, rng) * np.exp(-t / 0.003), rng.uniform(900, 1300), 10) * 0.3
    return out * velocity


def pasos_calle() -> np.ndarray:
    """Unos pasos por el empedrado mojado que se alejan (para cambiar de calle)."""
    rng = rng_for("pasos_calle")
    bus = Bus(samples(2.6))
    for k in range(5):
        bus.add(stereo(_step(rng, "piedra", 1.0 - 0.15 * k)), samples(0.1 + 0.48 * k))
    return _finish(_room(bus.data[:, 0], "exterior_sfx", 3.0, 0.3, damping=0.7, room=2.0), -9.0)


def cama() -> np.ndarray:
    """Acostarse: la ropa de cama y el muelle del somier."""
    rng = rng_for("cama")
    bus = Bus(samples(2.0))
    bus.add(stereo(lowpass(_rustle(rng, 0.9, 300, 300, 4000), 3000, 2)), 0)
    bus.add(stereo(_creak(rng, 0.5, (70, 140), [900, 1900, 3100], q=18) * 0.25), samples(0.45))
    bus.add(stereo(_thud(rng, 85, 0.07, 0.3) * 0.7), samples(0.5))
    return _finish(_room(bus.data[:, 0], "cafe_sfx", 0.8, 0.3, room=0.6), -9.0)


def reloj_avanza() -> np.ndarray:
    """Dejar pasar el tiempo: tic tac que se acelera y una campanada suave."""
    rng = rng_for("reloj_avanza")
    bus = Bus(samples(3.5))
    position = 0.0
    gap = 0.3
    for k in range(12):
        bus.add(stereo(_clock_tick(rng, k % 2 == 0, 0.8)), samples(position))
        position += gap
        gap = max(0.06, gap * 0.8)
    bus.add(stereo(ins.rod_gong(349.2, 2.5, 0.4, "avanza")), samples(position + 0.1))
    return _finish(_room(bus.data[:, 0], "cafe_sfx", 0.8, 0.25, room=0.6), -10.0)


def telefono() -> np.ndarray:
    """Timbre de un teléfono de los años cuarenta: dos campanas golpeadas veinte veces por segundo,
    dos tandas."""
    rng = rng_for("telefono")
    total = samples(5.2)
    impulses = np.zeros(total)
    for burst_start in (0.0, 3.0):
        for k in range(int(1.4 * 20)):
            index = samples(burst_start + k / 20.0 + rng.uniform(-0.002, 0.002))
            impulses[index] += rng.uniform(0.7, 1.0) * (1 if k % 2 == 0 else -1)
    n = samples(0.35)
    t = time_axis(n)
    gong = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / tau) * a for f, a, tau in
               [(1120, 1.0, 0.12), (1355, 0.8, 0.1), (2610, 0.35, 0.05), (3480, 0.2, 0.03)])
    ring = np.convolve(impulses, gong)[:total]
    ring = bandpass(ring, 400, 6000, 2)
    return _finish(_room(ring, "cafe_sfx", 0.8, 0.3, room=0.6), -8.0)


# --- Investigación ---

def expediente(opening: bool) -> np.ndarray:
    """La carpeta de cuero del expediente: solapa, golpe suave y hojas."""
    rng = rng_for("expediente" + str(opening))
    bus = Bus(samples(1.0))
    if opening:
        bus.add(stereo(_thud(rng, 120, 0.04, 0.3) * 0.5), 0)
        bus.add(stereo(_rustle(rng, 0.45, 350)), samples(0.06))
    else:
        bus.add(stereo(_rustle(rng, 0.3, 300)), 0)
        bus.add(stereo(_thud(rng, 105, 0.05, 0.5) * 0.7), samples(0.22))
    return normalize_peak(_trim(bus.data[:, 0]), -12.0)


def tablero(opening: bool) -> np.ndarray:
    """El tablero de corcho: papel que se coloca y una chincheta."""
    rng = rng_for("tablero" + str(opening))
    bus = Bus(samples(1.0))
    bus.add(stereo(_rustle(rng, 0.35, 300)), 0)
    m = samples(0.02)
    t = time_axis(m)
    pin = highpass(noise(m, rng), 3000, 1) * np.exp(-t / 0.003)
    pin += np.sin(2 * np.pi * 3900 * t) * np.exp(-t / 0.006) * 0.3
    pin += _thud(rng, 210, 0.02, 0.5)[:m]
    bus.add(stereo(pin), samples(0.3 if opening else 0.05))
    return normalize_peak(_trim(bus.data[:, 0]), -13.0)


def mapa() -> np.ndarray:
    rng = rng_for("mapa")
    bus = Bus(samples(1.2))
    for k, offset in enumerate((0.0, 0.25, 0.5)):
        bus.add(stereo(_rustle(rng, 0.4, 350, 900, 7000) * (1 - 0.2 * k)), samples(offset))
    return normalize_peak(_trim(bus.data[:, 0]), -13.0)


def evidencia(opening: bool) -> np.ndarray:
    rng = rng_for("evidencia" + str(opening))
    out = _rustle(rng, 0.3 if opening else 0.25, 320)
    if not opening:
        out = np.concatenate([out, _thud(rng, 150, 0.02, 0.3) * 0.3])
    return normalize_peak(_trim(out), -13.0)


def testimonio() -> np.ndarray:
    """Anotar un testimonio: trazos de pluma sobre el papel."""
    rng = rng_for("testimonio")
    bus = Bus(samples(1.0))
    position = 0.0
    for _ in range(5):
        length = rng.uniform(0.06, 0.13)
        n = samples(length)
        stroke = bandpass(noise(n, rng), 2500, 7500, 2) * np.sin(np.pi * np.linspace(0, 1, n)) ** 2
        bus.add(stereo(stroke), samples(position), rng.uniform(0.5, 1.0))
        position += length + rng.uniform(0.02, 0.07)
    return normalize_peak(_trim(bus.data[:, 0]), -15.0)


def sello() -> np.ndarray:
    """Un sello de goma sobre el papel: el expediente queda cerrado."""
    rng = rng_for("sello")
    out = _thud(rng, 95, 0.06, 1.0)
    paper = _rustle(rng, 0.15, 300)
    start = samples(0.01)
    out[start:start + len(paper)] += paper[: len(out) - start] * 0.2
    return _finish(_room(out, "archivo_sfx", 1.4, 0.25), -6.0)


def pasos(surface: str, k: int) -> np.ndarray:
    """Un paso del detective sobre piedra mojada, madera o baldosa."""
    rng = rng_for(f"paso_{surface}{k}")
    return normalize_peak(_trim(_step(rng, surface, 1.0)), -12.0)


def build_all() -> dict[str, tuple[np.ndarray, str]]:
    """Todos los efectos: ruta relativa (sin extensión) → (señal, descripción)."""
    out: dict[str, tuple[np.ndarray, str]] = {}

    def put(path: str, data: np.ndarray, text: str) -> None:
        out[path] = (data, text)

    for k in range(4):
        put(f"ambiente/cafe/taza_plato_{k + 1}", taza_plato(k), "Taza dejada sobre su plato.")
    for k in range(3):
        put(f"ambiente/cafe/cucharilla_{k + 1}", cucharilla(k), "Cucharilla removiendo el café.")
        put(f"ambiente/cafe/silla_{k + 1}", silla(k), "Silla que se arrastra sobre la baldosa.")
    put("ambiente/cafe/cafetera_1", cafetera(0), "Vaporizador de la cafetera exprés.")
    put("ambiente/cafe/caja_registradora_1", caja_registradora(0), "Caja registradora de la barra.")
    for k in range(5):
        put(f"ambiente/interiores/crujido_{k + 1}", crujido(k), "Crujido de la madera de la casa.")
    for k in range(4):
        put(f"ambiente/interiores/pagina_{k + 1}", pagina(k), "Página que se pasa en la sala de lectura.")
    for k in range(2):
        put(f"ambiente/interiores/sello_lejano_{k + 1}", sello_lejano(k), "Don Hilario sellando legajos.")
        put(f"ambiente/mansion/puerta_lejana_{k + 1}", puerta_lejana(k), "Una puerta se cierra en otra ala.")
        put(f"ambiente/mansion/rafaga_ventana_{k + 1}", rafaga_ventana(k), "Ráfaga que sacude los ventanales.")
    put("ambiente/mansion/reloj_campanada", reloj_campanada(), "Campanada del reloj de pie (una por hora).")
    put("ambiente/interiores/campana_torre_amortiguada", campana_torre(True), "Campana de la torre oída desde dentro.")
    for k in range(3):
        put(f"ambiente/exteriores/trueno_lejano_{k + 1}", trueno_lejano(k), "Trueno lejano.")
        put(f"ambiente/exteriores/golpe_metal_{k + 1}", golpe_metal(k), "Golpe metálico en las vías.")
    for k in range(2):
        put(f"ambiente/exteriores/contraventana_{k + 1}", contraventana(k), "Contraventana golpeada por el viento.")
        put(f"ambiente/exteriores/buho_{k + 1}", buho(k), "Cárabo nocturno.")
        put(f"ambiente/exteriores/silbato_tren_{k + 1}", silbato_tren(k), "Silbato de vapor lejano.")
    put("ambiente/exteriores/campana_torre", campana_torre(False), "Campanada de la torre del reloj.")
    put("ambiente/exteriores/campana_anden", campana_anden(), "Campana de mano del jefe de estación.")

    for k in range(3):
        put(f"efectos/interfaz/mover_{k + 1}", ui_mover(k), "Cambio de opción en un menú.")
    put("efectos/interfaz/aceptar", ui_aceptar(), "Confirmar una opción.")
    put("efectos/interfaz/cancelar", ui_cancelar(), "Volver o cancelar.")
    put("efectos/interfaz/abrir", ui_abrir(), "Abrir una pantalla.")
    put("efectos/interfaz/cerrar", ui_cerrar(), "Cerrar una pantalla.")
    put("efectos/interfaz/pausa_abrir", pausa(True), "Abrir la pausa.")
    put("efectos/interfaz/pausa_cerrar", pausa(False), "Cerrar la pausa.")
    put("efectos/interfaz/notificacion", notificacion(), "Aviso informativo del HUD.")
    put("efectos/interfaz/guardado", guardado(), "Partida guardada.")
    for k in range(4):
        put(f"efectos/interfaz/tecla_{k + 1}", tecla(k), "Tecleo del texto de los diálogos.")
    put("efectos/interaccion/puerta_cafe", puerta_cafe(), "Puerta del café con su campanilla.")
    put("efectos/interaccion/puerta_mansion", puerta_mansion(), "Puerta pesada de la mansión.")
    put("efectos/interaccion/puerta_archivo", puerta_archivo(), "Puerta del archivo municipal.")
    put("efectos/interaccion/puerta_salida", puerta_salida(), "Salir a la calle bajo la lluvia.")
    put("efectos/interaccion/puerta_cerrada", puerta_cerrada(), "Puerta que no se abre.")
    put("efectos/interaccion/pasos_calle", pasos_calle(), "Pasos por el empedrado mojado.")
    put("efectos/interaccion/cama", cama(), "Acostarse en la pensión.")
    put("efectos/interaccion/reloj_avanza", reloj_avanza(), "Dejar pasar una hora.")
    put("efectos/interaccion/telefono", telefono(), "Teléfono del café sonando.")
    put("efectos/investigacion/expediente_abrir", expediente(True), "Abrir el expediente.")
    put("efectos/investigacion/expediente_cerrar", expediente(False), "Cerrar el expediente.")
    put("efectos/investigacion/tablero_abrir", tablero(True), "Abrir el tablero de corcho.")
    put("efectos/investigacion/tablero_cerrar", tablero(False), "Cerrar el tablero.")
    put("efectos/investigacion/mapa_abrir", mapa(), "Desplegar el mapa del pueblo.")
    put("efectos/investigacion/evidencia_abrir", evidencia(True), "Tomar una evidencia para examinarla.")
    put("efectos/investigacion/evidencia_cerrar", evidencia(False), "Dejar la evidencia.")
    put("efectos/investigacion/testimonio", testimonio(), "Anotar un testimonio.")
    put("efectos/investigacion/sello", sello(), "Sello del caso cerrado.")
    for surface in ("piedra", "madera", "baldosa"):
        for k in range(4):
            put(f"efectos/pasos/{surface}_{k + 1}", pasos(surface, k), f"Paso sobre {surface}.")
    return out
