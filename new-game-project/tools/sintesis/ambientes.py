"""Ambientes en bucle de cada escenario.

Todos son periódicos por construcción: el ruido se filtra en el dominio de la frecuencia (filtrado
circular), las modulaciones lentas completan un número entero de ciclos y los sucesos que pasan del
final se pliegan al principio. Por eso se repiten sin costura ni salto de volumen.
"""

from __future__ import annotations

import numpy as np

from .dsp import (SR, Bus, band_gain, bandpass, convolve_reverb, db, fold, highpass, impulse_response,
                  lowpass, noise, normalize_rms, resonator, rms, rng_for, samples, smooth_random, soft_limit,
                  spectral_shape, stereo, time_axis)
from . import instrumentos as ins


def _kernel_bank(rng: np.random.Generator, count: int, f_low: float, f_high: float, tau_low: float,
                 tau_high: float, length: float = 0.03) -> list[np.ndarray]:
    """Gotas: sinusoides breves que suben un poco de tono (burbuja de Minnaert)."""
    kernels = []
    n = samples(length)
    t = time_axis(n)
    for _ in range(count):
        f = np.exp(rng.uniform(np.log(f_low), np.log(f_high)))
        tau = rng.uniform(tau_low, tau_high)
        rise = rng.uniform(0.05, 0.35)
        phase = 2 * np.pi * f * (t + rise * t * t / (2 * tau * 3))
        kernels.append(np.sin(phase) * np.exp(-t / tau) * np.clip(t / 0.0004, 0, 1))
    return kernels


def _scatter(n: int, rate: float, kernels: list[np.ndarray], rng: np.random.Generator,
             amp_sigma: float = 0.6) -> np.ndarray:
    """Reparte `rate` sucesos por segundo con amplitud aleatoria, en un bucle circular."""
    out = np.zeros(n)
    count = int(rate * n / SR)
    groups = rng.integers(0, len(kernels), count)
    positions = rng.integers(0, n, count)
    amps = rng.lognormal(0.0, amp_sigma, count) * rng.choice([-1.0, 1.0], count)
    for k, kernel in enumerate(kernels):
        impulses = np.zeros(n)
        mask = groups == k
        np.add.at(impulses, positions[mask], amps[mask])
        spectrum = np.fft.rfft(impulses) * np.fft.rfft(np.concatenate([kernel, np.zeros(n - len(kernel))]))
        out += np.fft.irfft(spectrum, n)
    return out


def _add_circular(track: np.ndarray, sound: np.ndarray, start: int) -> None:
    """Suma un sonido en un bucle: lo que pasa del final continúa al principio."""
    index = (start + np.arange(len(sound))) % len(track)
    np.add.at(track, index, sound)


def _periodic_env(n: int, rng: np.random.Generator, rate: float, depth_db: float) -> np.ndarray:
    curve = smooth_random(n, rate, rng)
    return 10 ** (curve * depth_db / 20)


def level(x: np.ndarray, target_rms_db: float, max_peak_db: float = -3.0) -> np.ndarray:
    """Lleva un ambiente a su RMS sin que ningún pico pase de `max_peak_db` (los sonidos muy
    impulsivos, como un tic tac, quedan entonces algo más bajos de RMS)."""
    gain = min(db(target_rms_db) / rms(x), db(max_peak_db) / (np.max(np.abs(x)) + 1e-12))
    return x * gain


def _reverb_loop(x: np.ndarray, ir: np.ndarray, wet: float) -> np.ndarray:
    n = len(x)
    wet_signal = fold(convolve_reverb(x, ir), n)
    return stereo(x) + wet_signal * wet


# --- Exteriores ---

def lluvia_calle() -> np.ndarray:
    """Lluvia sobre el empedrado y los tejados: siseo, repiqueteo, salpicaduras, goteo de canalones
    y el rumor grave de la lluvia lejana. Estéreo, 48 s."""
    rng = rng_for("lluvia_calle")
    n = samples(48.0)
    hiss = spectral_shape(noise(n, rng, "pink", 2), band_gain(500, 9000, 1.2)) * 0.5
    rumble = spectral_shape(noise(n, rng, "brown", 2), band_gain(40, 260, 1.5)) * 0.35
    out = hiss + rumble
    for channel in range(2):
        drops = _scatter(n, 1300, _kernel_bank(rng, 10, 2200, 7000, 0.0008, 0.003), rng)
        splashes = _scatter(n, 70, _kernel_bank(rng, 6, 700, 2400, 0.002, 0.007, 0.04), rng, 0.8)
        out[:, channel] += drops * 0.035 + splashes * 0.05
    # Canalones: gotas gruesas con su propio ritmo, una a cada lado.
    for side, period in [(0, 0.83), (1, 1.27)]:
        kernels = _kernel_bank(rng, 3, 650, 1300, 0.006, 0.014, 0.08)
        track = np.zeros(n)
        position = rng.uniform(0, period)
        while position < seconds_of(n):
            kernel = kernels[rng.integers(3)]
            _add_circular(track, kernel * rng.uniform(0.5, 1.0), samples(position))
            position += period * rng.uniform(0.85, 1.15)
        out[:, side] += track * 0.06
    out *= _periodic_env(n, rng, 0.05, 1.5)[:, None]
    return level(out, -24.0)


def seconds_of(n: int) -> float:
    return n / SR


def lluvia_ventanas() -> np.ndarray:
    """La misma lluvia oída desde dentro: apagada, con gotas en los cristales y el tamborileo del
    tejado. Estéreo, 48 s."""
    rng = rng_for("lluvia_ventanas")
    n = samples(48.0)
    hiss = spectral_shape(noise(n, rng, "pink", 2), band_gain(150, 1800, 1.5)) * 0.55
    roof = spectral_shape(noise(n, rng, "brown", 2), band_gain(60, 500, 1.5)) * 0.4
    out = hiss + roof
    for channel in range(2):
        taps = _scatter(n, 45, _kernel_bank(rng, 6, 1800, 4200, 0.0006, 0.002), rng, 0.7)
        drum = _scatter(n, 160, _kernel_bank(rng, 5, 300, 800, 0.002, 0.006, 0.03), rng)
        out[:, channel] += taps * 0.05 + drum * 0.03
    out *= _periodic_env(n, rng, 0.04, 1.5)[:, None]
    return level(out, -26.0)


def _wind_bands(n: int, rng: np.random.Generator, centers: list[float], q: float, rate: float) -> np.ndarray:
    out = np.zeros((n, 2))
    for center in centers:
        band = spectral_shape(noise(n, rng, "white", 2), band_gain(center / (1 + 1 / q), center * (1 + 1 / q), 3.0))
        band /= rms(band)
        env = np.clip(smooth_random(n, rate * rng.uniform(0.7, 1.3), rng) * 0.8 + 0.25, 0.0, None) ** 2
        out += band * env[:, None]
    return out


def viento() -> np.ndarray:
    """Viento nocturno entre los tejados: ráfagas graves y silbidos que cambian despacio. 60 s."""
    rng = rng_for("viento")
    n = samples(60.0)
    gusts = spectral_shape(noise(n, rng, "pink", 2), band_gain(80, 700, 1.5))
    gusts *= (np.clip(smooth_random(n, 0.12, rng) * 0.9 + 0.4, 0.05, None) ** 1.5)[:, None]
    howl = _wind_bands(n, rng, [310.0, 420.0, 560.0, 760.0], 9.0, 0.09) * 0.12
    return level(gusts + howl, -27.0)


def fuente_plaza() -> np.ndarray:
    """La fuente de la plaza: chorro que cae en el pilón (burbujas y salpicaduras). Mono, 30 s,
    para un emisor 3D."""
    rng = rng_for("fuente")
    n = samples(30.0)
    bubbles = _scatter(n, 420, _kernel_bank(rng, 14, 350, 2600, 0.003, 0.02, 0.06), rng, 0.7)
    splash = spectral_shape(noise(n, rng, "white"), band_gain(900, 8000, 1.0))
    splash *= _periodic_env(n, rng, 1.5, 4.0)
    slosh = spectral_shape(noise(n, rng, "brown"), band_gain(60, 400, 1.5))
    out = bubbles * 0.05 + splash * 0.25 + slosh * 0.2
    return level(out, -22.0)


def vapor_locomotora() -> np.ndarray:
    """Locomotora parada en el andén: siseo de vapor, bombeo de la bomba de aire y la caldera.
    Mono, 32 s, para un emisor 3D."""
    rng = rng_for("locomotora")
    n = samples(32.0)
    t = time_axis(n)
    hiss = spectral_shape(noise(n, rng), band_gain(1500, 9000, 1.2))
    hiss *= 0.35 + 0.1 * np.sin(2 * np.pi * (13 / 32.0) * t)
    boiler = spectral_shape(noise(n, rng, "brown"), band_gain(30, 150, 2.0)) * 0.8
    pump = Bus(n)
    position = 0.3
    while position < 32.0:
        length = rng.uniform(0.35, 0.6)
        m = samples(length)
        puff = bandpass(noise(m, rng), 600, 4500, 2) * np.sin(np.pi * np.linspace(0, 1, m)) ** 2
        pump.add(stereo(puff), samples(position), rng.uniform(0.5, 0.9))
        position += rng.uniform(1.3, 2.1)
    ticks = _scatter(n, 0.7, _kernel_bank(rng, 4, 2500, 5200, 0.004, 0.012, 0.05), rng)
    out = hiss * 0.5 + boiler * 0.5 + fold(pump.data, n)[:, 0] * 0.6 + ticks * 0.15
    return level(out, -22.0)


# --- Interiores ---

_VOWELS = {"a": (800, 1250, 2600), "e": (480, 1850, 2550), "i": (310, 2250, 2950), "o": (520, 920, 2450),
           "u": (360, 800, 2300)}


def _voice(n: int, rng: np.random.Generator, f0: float, scale: float) -> np.ndarray:
    """Una voz lejana e ininteligible: fuente glotal con entonación, vocales que cambian por sílaba y
    consonantes de ruido. Sólo debe sonar a «gente hablando», nunca a palabras."""
    total = n + samples(4.0)
    freq = np.zeros(total)
    segments = []
    position = rng.uniform(0.0, 3.0)
    while position < seconds_of(n):
        phrase = rng.uniform(1.0, 3.6)
        start = position
        syllable_start = start
        while syllable_start < start + phrase:
            length = rng.uniform(0.11, 0.24)
            progress = (syllable_start - start) / phrase
            pitch = f0 * (1.12 - 0.22 * progress) * rng.uniform(0.94, 1.08)
            segments.append((syllable_start, length, rng.choice(list(_VOWELS)), pitch, rng.random() < 0.55))
            syllable_start += length
        position = start + phrase + rng.uniform(0.4, 2.8)
    for start, length, _vowel, pitch, _consonant in segments:
        a, b = samples(start), min(total, samples(start + length + 0.03))
        freq[a:b] = pitch
    # La fuente sigue sonando donde hay sílabas; el resto lo apagan las envolventes.
    freq = np.where(freq > 0, freq, f0)
    table = ins._saw_table(24)
    source = ins._table_osc(freq * (1 + 0.01 * np.sin(2 * np.pi * 5.5 * time_axis(total))), table, 0.0)
    source = lowpass(source, 900, 1)
    out = np.zeros(total)
    for start, length, vowel, _pitch, consonant in segments:
        a = samples(start)
        m = samples(length + 0.03)
        if a + m > total:
            continue
        piece = source[a:a + m]
        voiced = np.zeros(m)
        for k, formant in enumerate(_VOWELS[vowel]):
            voiced += resonator(piece, formant * scale, 6.0 + 2 * k) * (1.0, 0.6, 0.25)[k]
        env = np.sin(np.pi * np.linspace(0, 1, m)) ** 1.2
        out[a:a + m] += voiced * env * rng.uniform(0.6, 1.0)
        if consonant:
            c = samples(rng.uniform(0.02, 0.05))
            burst = bandpass(noise(c, rng), 2500, 7000, 1) * np.hanning(c) * 0.25
            out[a:a + c] += burst
    return fold(out, n)


def sala_cafe() -> np.ndarray:
    """Café La Luna con gente: murmullo de varias mesas a distancias distintas, el tono de la sala y
    algún tintineo de fondo. Estéreo, 64 s."""
    rng = rng_for("sala_cafe")
    n = samples(64.0)
    room = spectral_shape(noise(n, rng, "pink", 2), band_gain(60, 1400, 1.5)) * 0.05
    babble = np.zeros((n, 2))
    for k in range(9):
        male = k % 3 != 0
        voice = _voice(n, rng, rng.uniform(95, 135) if male else rng.uniform(175, 235), 1.0 if male else 1.17)
        voice = lowpass(voice, rng.uniform(1500, 2600), 2)
        voice /= rms(voice) + 1e-9
        position = rng.uniform(-0.8, 0.8)
        angle = (position + 1) * np.pi / 4
        babble[:, 0] += voice * np.cos(angle) * rng.uniform(0.35, 1.0)
        babble[:, 1] += voice * np.sin(angle) * rng.uniform(0.35, 1.0)
    babble = highpass(babble, 160, 2)
    ir = impulse_response("cafe_sala", 1.4, 0.85, predelay=0.006, damping=0.6, room=0.7)
    babble = _reverb_loop(babble, ir, 0.7)
    clinks = Bus(n)
    for _ in range(7):
        clinks.add(stereo(_ceramic(rng, rng.uniform(0.3, 0.7))), samples(rng.uniform(0, 64.0)), 0.25,
                   rng.uniform(-0.6, 0.6))
    out = normalize_rms(babble, -30.0) + room + _reverb_loop(fold(clinks.data, n), ir, 0.6)
    return level(out, -28.0)


def _ceramic(rng: np.random.Generator, velocity: float) -> np.ndarray:
    """Taza contra el plato: modos agudos e inarmónicos de la loza, con uno o dos rebotes."""
    n = samples(0.5)
    t = time_axis(n)
    out = np.zeros(n)
    hits = [0.0] + ([rng.uniform(0.04, 0.09)] if rng.random() < 0.7 else [])
    base = rng.uniform(2400, 3400)
    for index, hit in enumerate(hits):
        local = np.clip(t - hit, 0, None)
        gate = t >= hit
        for ratio, amp, tau in [(1.0, 1.0, 0.09), (1.57, 0.6, 0.06), (2.31, 0.4, 0.04), (3.1, 0.2, 0.025)]:
            out += np.sin(2 * np.pi * base * ratio * local) * np.exp(-local / tau) * amp * gate * (0.45 ** index)
        click_n = samples(0.003)
        start = samples(hit)
        out[start:start + click_n] += highpass(noise(click_n, rng), 3000, 1) * 0.3 * (0.45 ** index)
    return out * velocity * 0.25


def casa_grande() -> np.ndarray:
    """Mansión Valdés: el silencio grave de una casa grande, el aire que se cuela por las ventanas y
    el lamento lejano del viento. Estéreo, 64 s."""
    rng = rng_for("casa_grande")
    n = samples(64.0)
    room = spectral_shape(noise(n, rng, "brown", 2), band_gain(25, 220, 1.5)) * 0.6
    air = spectral_shape(noise(n, rng, "pink", 2), band_gain(200, 2500, 1.2)) * 0.06
    moan = _wind_bands(n, rng, [190.0, 240.0, 330.0], 14.0, 0.06) * 0.25
    out = room + air + moan
    ir = impulse_response("mansion_amb", 4.0, 3.5, predelay=0.03, damping=0.6, room=1.6)
    return level(_reverb_loop(out, ir, 0.4), -29.0)


def archivo_sala() -> np.ndarray:
    """Archivo municipal: sala silenciosa de papel y madera bajo la torre del reloj, cuyo mecanismo se
    oye a través del techo, lento y apagado. Estéreo, 60 s (el tic cae cada 2 s exactos)."""
    rng = rng_for("archivo_sala")
    n = samples(60.0)
    room = spectral_shape(noise(n, rng, "pink", 2), band_gain(70, 1800, 1.5)) * 0.08
    hum = spectral_shape(noise(n, rng, "brown", 2), band_gain(30, 160, 2.0)) * 0.25
    mechanism = Bus(n)
    for k in range(30):
        tick = _tower_tick(rng, k % 2 == 0)
        mechanism.add(stereo(tick), samples(k * 2.0 + 0.4), 1.0)
    ir = impulse_response("archivo_amb", 2.5, 1.6, predelay=0.015, damping=0.6)
    mech = _reverb_loop(fold(mechanism.data, n), ir, 0.8)
    out = room + hum + lowpass(mech, 900, 2) * 0.5
    return level(out, -31.0)


def _tower_tick(rng: np.random.Generator, heavy: bool) -> np.ndarray:
    n = samples(0.5)
    t = time_axis(n)
    thud = np.sin(2 * np.pi * (95 if heavy else 120) * t) * np.exp(-t / 0.06)
    knock = resonator(noise(n, rng) * np.exp(-t / 0.01), 420 if heavy else 520, 8) * 0.6
    return (thud * 0.5 + knock) * (1.0 if heavy else 0.75) * 0.3


def reloj_pie() -> np.ndarray:
    """Reloj de pie del vestíbulo: péndulo de segundos (tic y tac) con la caja de madera resonando.
    Mono, 8 s, para un emisor 3D."""
    rng = rng_for("reloj_pie")
    n = samples(8.0)
    bus = Bus(n)
    for k in range(8):
        bus.add(stereo(_clock_tick(rng, k % 2 == 0, rng.uniform(0.9, 1.0))), samples(k * 1.0 + 0.1), 1.0)
    out = fold(bus.data, n)[:, 0]
    return level(out, -24.0)


def _clock_tick(rng: np.random.Generator, tick: bool, velocity: float) -> np.ndarray:
    n = samples(0.25)
    t = time_axis(n)
    click = highpass(noise(n, rng), 1800, 2) * np.exp(-t / 0.0025)
    ring = np.sin(2 * np.pi * (2350 if tick else 2080) * t) * np.exp(-t / 0.018) * 0.5
    case = resonator(noise(n, rng) * np.exp(-t / 0.004), 480 if tick else 410, 6) * 1.2
    return (click * 0.6 + ring + case) * velocity * 0.3


def chimenea() -> np.ndarray:
    """Chimenea del salón: el rumor del fuego, chasquidos de la leña y algún estallido. Mono, 30 s,
    para un emisor 3D."""
    rng = rng_for("chimenea")
    n = samples(30.0)
    roar = spectral_shape(noise(n, rng, "brown"), band_gain(40, 500, 1.5))
    roar *= _periodic_env(n, rng, 2.0, 4.0)
    crackle_kernels = []
    for _ in range(8):
        m = samples(rng.uniform(0.002, 0.008))
        crackle_kernels.append(highpass(noise(m, rng), rng.uniform(1500, 4000), 1) * np.hanning(m))
    density = np.clip(smooth_random(n, 0.4, rng) + 0.3, 0.05, None)
    crackles = np.zeros(n)
    for kernel in crackle_kernels:
        count = int(9 * n / SR)
        positions = rng.integers(0, n, count)
        keep = rng.random(count) < density[positions] / density.max()
        for position in positions[keep]:
            _add_circular(crackles, kernel * min(rng.lognormal(0, 0.4), 2.5), int(position))
    pops = _scatter(n, 0.25, _kernel_bank(rng, 3, 120, 300, 0.01, 0.03, 0.12), rng)
    out = roar * 0.45 + crackles * 0.25 + pops * 0.3
    return level(out, -23.0)


BEDS = {
    "exteriores/lluvia_calle": (lluvia_calle, 2, "Lluvia sobre el empedrado y los tejados."),
    "exteriores/viento_noche": (viento, 2, "Viento nocturno entre los tejados."),
    "exteriores/fuente_plaza": (fuente_plaza, 1, "Fuente de la plaza (emisor 3D)."),
    "exteriores/locomotora_vapor": (vapor_locomotora, 1, "Locomotora parada en el andén (emisor 3D)."),
    "interiores/lluvia_ventanas": (lluvia_ventanas, 2, "Lluvia oída desde dentro, en cristales y tejado."),
    "interiores/archivo_sala": (archivo_sala, 2, "Sala del archivo con el mecanismo de la torre del reloj."),
    "cafe/sala_cafe": (sala_cafe, 2, "Murmullo de las mesas y tono de la sala del café."),
    "mansion/casa_grande": (casa_grande, 2, "Silencio grave y viento lejano de la mansión."),
    "mansion/reloj_pie": (reloj_pie, 1, "Tic tac del reloj de pie del vestíbulo (emisor 3D)."),
    "mansion/chimenea": (chimenea, 1, "Fuego de la chimenea del salón (emisor 3D)."),
}
