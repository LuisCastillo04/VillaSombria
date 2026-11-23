"""Instrumentos sintetizados. Cada función devuelve una nota mono (vector NumPy) a `SR`.

Modelos:
- Piano: síntesis aditiva con inarmonicidad de cuerda rígida, dos cuerdas ligeramente
  desafinadas (batimiento), decaimiento en dos etapas por parcial y ruido de macillo.
- Contrabajo: cuerda pulsada aditiva con posición de pulsación, ligero glissando de ataque y golpe
  del dedo.
- Cuerdas: conjunto de osciladores de diente de sierra limitados en banda (tabla de ondas) con
  desafinación, vibrato retardado y ruido de arco.
- Vibráfono, caja de música, campanas y gongs: modelos modales (parciales inarmónicos con su
  propio decaimiento).
- Percusión: escobillas, plato ride, bombo suave, timbal y latido, a partir de ruido filtrado y
  modos de membrana.
"""

from __future__ import annotations

import numpy as np

from .dsp import (SR, attack_ramp, bandpass, exp_decay, highpass, lowpass, midi_hz, noise, resonator,
                  rng_for, samples, time_axis)

_CACHE: dict = {}


def clear_cache() -> None:
    """Libera las notas guardadas (se llama entre una pieza y la siguiente)."""
    _CACHE.clear()


def _cached(key, builder):
    if key not in _CACHE:
        _CACHE[key] = builder()
    return _CACHE[key]


# --- Piano ---

def piano(midi: int, velocity: float, duration: float, pedal: bool = False, tone: float = 1.0) -> np.ndarray:
    """Nota de piano. `velocity` de 0 a 1; `tone` < 1 la oscurece (piano de fieltro)."""
    vel = round(float(np.clip(velocity, 0.05, 1.0)), 2)
    dur = round(duration, 2)
    return _cached(("piano", midi, vel, dur, pedal, round(tone, 2)), lambda: _piano(midi, vel, dur, pedal, tone))


def _piano(midi: int, vel: float, dur: float, pedal: bool, tone: float) -> np.ndarray:
    rng = rng_for(f"piano-{midi}-{vel}-{dur}")
    f0 = midi_hz(midi)
    inharmonicity = 7e-5 * np.exp(0.045 * (midi - 21))
    tau_long = float(np.clip(14.0 * 2 ** (-(midi - 36) / 16), 0.9, 16.0))
    tau_short = tau_long * 0.16
    release = 0.22 if not pedal else min(tau_long * 0.9, 5.0)
    sounding = min(dur, tau_long * 3.5)
    n = samples(sounding + release + 0.05)
    t = time_axis(n)
    fmax = min(8500.0, 2500.0 + 6000.0 * vel) * tone
    hammer = 0.16 + 0.6 * (1.0 - vel) + 0.25 * (1.0 - tone)
    out = np.zeros(n)
    for k in range(1, 30):
        fk = k * f0 * np.sqrt(1 + inharmonicity * k * k)
        if fk > fmax:
            break
        amp = np.exp(-hammer * (k - 1)) / k ** 0.45 * (0.35 + 0.65 * abs(np.sin(np.pi * k / 7.3)))
        speed = 1 + 0.11 * (k - 1) + 0.00035 * fk
        env = 0.7 * np.exp(-t / (tau_short / speed)) + 0.3 * np.exp(-t / (tau_long / speed))
        phase = rng.uniform(0, 2 * np.pi)
        if midi >= 40:
            detune = 2 ** (rng.uniform(0.6, 1.6) / 1200)
            wave = np.sin(2 * np.pi * fk * t + phase) + 0.85 * np.sin(2 * np.pi * fk * detune * t + phase * 1.7)
            wave /= 1.85
        else:
            wave = np.sin(2 * np.pi * fk * t + phase)
        out += amp * env * wave
    out *= attack_ramp(n, 0.0015 + 0.004 * (1 - vel))
    # Golpe del macillo: ruido breve alrededor del registro de la nota.
    thump_n = samples(0.03)
    burst = bandpass(noise(thump_n, rng), min(f0 * 1.5, 3000.0), min(f0 * 6 + 1500, 9000.0), 1)
    burst *= exp_decay(thump_n, 0.006 + 0.006 * (1 - vel)) * 0.05 * vel
    out[:thump_n] += burst
    # Apagador (o pedal) al soltar la nota.
    release_start = samples(sounding)
    damp = np.ones(n)
    damp[release_start:] = np.exp(-(t[release_start:] - sounding) / (release / 3.0))
    out *= damp
    return out * (vel ** 1.4) * 0.5


# --- Contrabajo ---

def upright_bass(midi: int, velocity: float, duration: float) -> np.ndarray:
    vel = round(float(np.clip(velocity, 0.05, 1.0)), 2)
    dur = round(duration, 2)
    return _cached(("bajo", midi, vel, dur), lambda: _bass(midi, vel, dur))


def _bass(midi: int, vel: float, dur: float) -> np.ndarray:
    rng = rng_for(f"bajo-{midi}-{vel}-{dur}")
    f0 = midi_hz(midi)
    tau0 = float(np.clip(1.5 * 2 ** (-(midi - 28) / 24), 0.5, 2.0))
    n = samples(dur + 0.12)
    t = time_axis(n)
    # Glissando de ataque: la cuerda empieza un poco alta al pulsarla.
    phase_base = 2 * np.pi * f0 * (t + 0.012 * 0.04 * (1 - np.exp(-t / 0.04)))
    out = np.zeros(n)
    for k in range(1, 18):
        if k * f0 > 3200:
            break
        amp = abs(np.sin(np.pi * k * 0.19)) / k ** 1.15
        env = np.exp(-t / (tau0 / (1 + 0.32 * (k - 1))))
        out += amp * env * np.sin(k * phase_base + rng.uniform(0, 2 * np.pi))
    out *= attack_ramp(n, 0.004)
    thump_n = samples(0.04)
    out[:thump_n] += lowpass(noise(thump_n, rng), 400.0, 2) * exp_decay(thump_n, 0.01) * 0.08 * vel
    release_start = samples(dur)
    out[release_start:] *= np.exp(-(t[release_start:] - dur) / 0.03)
    out = resonator(out, 105.0, 1.4) * 0.6 + out * 0.7
    return out * vel * 0.55


# --- Cuerdas (tabla de ondas limitada en banda) ---

_TABLE_SIZE = 4096


def _saw_table(harmonics: int) -> np.ndarray:
    def build() -> np.ndarray:
        x = np.arange(_TABLE_SIZE) / _TABLE_SIZE
        table = np.zeros(_TABLE_SIZE)
        for k in range(1, harmonics + 1):
            sigma = np.sinc(k / (harmonics + 1))  # factores de Lanczos: menos aspereza
            table += sigma * np.sin(2 * np.pi * k * x) / k
        return table / np.max(np.abs(table))
    return _cached(("saw", harmonics), build)


def _table_osc(freq: np.ndarray, table: np.ndarray, phase0: float) -> np.ndarray:
    phase = (np.cumsum(freq) / SR + phase0) % 1.0
    idx = phase * _TABLE_SIZE
    return np.interp(idx, np.arange(_TABLE_SIZE + 1), np.append(table, table[0]))


def strings(midi: int, duration: float, velocity: float = 0.7, voices: int = 5, attack: float = 0.7,
            release: float = 1.2, vibrato: float = 9.0, brightness: float = 1.0, tremolo: float = 0.0,
            seed: str = "") -> np.ndarray:
    """Sección de cuerda (o una sola con `voices=1`). `vibrato` en centésimas; `tremolo` es la
    frecuencia del trémolo de arco (0 = sin trémolo)."""
    key = ("cuerdas", midi, round(duration, 2), round(velocity, 2), voices, attack, release, vibrato,
           brightness, tremolo, seed)
    return _cached(key, lambda: _strings(midi, duration, velocity, voices, attack, release, vibrato,
                                         brightness, tremolo, seed))


def _strings(midi, duration, velocity, voices, attack, release, vibrato, brightness, tremolo, seed):
    rng = rng_for(f"cuerdas-{midi}-{duration}-{seed}")
    f0 = midi_hz(midi)
    n = samples(duration + release + 0.1)
    t = time_axis(n)
    harmonics = int(max(3, min(40, 6500.0 * brightness / f0)))
    table = _saw_table(harmonics)
    out = np.zeros(n)
    vib_onset = np.clip((t - 0.35) / 0.6, 0.0, 1.0)
    for voice in range(voices):
        detune = rng.normal(0.0, 6.0 if voices > 1 else 0.0)
        rate = 4.9 + rng.uniform(-0.7, 0.7)
        vib = vibrato * vib_onset * np.sin(2 * np.pi * rate * t + rng.uniform(0, 2 * np.pi))
        drift = 2.0 * np.sin(2 * np.pi * rng.uniform(0.05, 0.2) * t + rng.uniform(0, 2 * np.pi))
        freq = f0 * 2 ** ((detune + vib + drift) / 1200)
        wave = _table_osc(freq, table, rng.uniform())
        wave *= 1.0 + 0.12 * np.sin(2 * np.pi * rng.uniform(0.2, 0.5) * t + rng.uniform(0, 2 * np.pi))
        if tremolo > 0:
            rate_t = tremolo * rng.uniform(0.85, 1.15)
            wave *= 0.55 + 0.45 * np.abs(np.sin(np.pi * rate_t * t + rng.uniform(0, np.pi))) ** 0.6
        out += wave
    out /= np.sqrt(voices)
    env = np.clip(t / max(attack, 1e-3), 0, 1)
    env = 0.5 - 0.5 * np.cos(np.pi * env)
    rel = np.clip((t - duration) / release, 0, 1)
    env *= (1 - rel) ** 2
    bow = highpass(noise(n, rng), 2500.0, 2) * 0.02 * brightness
    out = (out + bow) * env
    out = lowpass(out, min(1800.0 + 2200.0 * brightness + f0, 9000.0), 2)
    return highpass(out, 70.0, 1) * velocity * 0.28


def glass_harmonic(midi: int, duration: float, velocity: float = 0.5, seed: str = "") -> np.ndarray:
    """Armónico agudo de violín (flautando): casi una sinusoide, frágil e inquietante."""
    def build() -> np.ndarray:
        rng = rng_for(f"armonico-{midi}-{duration}-{seed}")
        f0 = midi_hz(midi)
        n = samples(duration + 1.5)
        t = time_axis(n)
        out = np.zeros(n)
        for voice in range(3):
            detune = 2 ** (rng.normal(0, 4.0) / 1200)
            vib = 2 ** (5.0 * np.sin(2 * np.pi * (5.2 + voice * 0.3) * t) * np.clip(t / 1.2, 0, 1) / 1200)
            phase = np.cumsum(f0 * detune * vib) / SR * 2 * np.pi
            out += np.sin(phase) + 0.08 * np.sin(2 * phase)
        env = np.clip(t / 1.1, 0, 1) ** 2 * (1 - np.clip((t - duration) / 1.4, 0, 1)) ** 2
        breath = bandpass(noise(n, rng), f0 * 0.9, f0 * 1.6, 1) * 0.04
        return (out / 3 + breath) * env * velocity * 0.2
    return _cached(("armonico", midi, round(duration, 2), round(velocity, 2), seed), build)


# --- Láminas y campanas (modelos modales) ---

def _modal(f0: float, modes: list[tuple[float, float, float]], duration: float, rng: np.random.Generator,
           detune_cents: float = 0.0, doublet: float = 0.0) -> np.ndarray:
    n = samples(duration)
    t = time_axis(n)
    out = np.zeros(n)
    for ratio, amp, tau in modes:
        f = f0 * ratio * 2 ** (rng.normal(0, detune_cents) / 1200)
        if f > SR * 0.45:
            continue
        env = np.exp(-t / tau)
        if doublet > 0:
            wave = 0.5 * (np.sin(2 * np.pi * f * (1 - doublet) * t) + np.sin(2 * np.pi * f * (1 + doublet) * t + 0.4))
        else:
            wave = np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
        out += amp * env * wave
    return out * attack_ramp(n, 0.0008)


def vibraphone(midi: int, velocity: float, duration: float, motor: bool = True) -> np.ndarray:
    vel = round(float(velocity), 2)
    dur = round(duration, 2)

    def build() -> np.ndarray:
        rng = rng_for(f"vibrafono-{midi}-{vel}-{dur}")
        f0 = midi_hz(midi)
        ring = float(np.clip(4.5 * 2 ** (-(midi - 60) / 24), 1.2, 6.0))
        total = min(dur, ring * 2.5) + 0.4
        out = _modal(f0, [(1.0, 1.0, ring), (3.984, 0.22 * vel, 0.5), (9.9, 0.05 * vel, 0.14)], total, rng)
        n = len(out)
        t = time_axis(n)
        if motor:
            out *= 1 - 0.32 * (0.5 - 0.5 * np.cos(2 * np.pi * 5.3 * t))
        click_n = samples(0.006)
        out[:click_n] += lowpass(noise(click_n, rng), 3500.0, 1) * 0.04 * vel
        release_start = samples(min(dur, total - 0.4))
        out[release_start:] *= np.exp(-(t[release_start:] - t[release_start]) / 0.12)
        return out * vel * 0.32
    return _cached(("vibrafono", midi, vel, dur, motor), build)


def music_box(midi: int, velocity: float = 0.6) -> np.ndarray:
    """Caja de música algo gastada: púas con modos de barra libre-empotrada y leve desafinación."""
    vel = round(float(velocity), 2)

    def build() -> np.ndarray:
        rng = rng_for(f"caja-{midi}-{vel}")
        f0 = midi_hz(midi)
        ring = float(np.clip(2.6 * 2 ** (-(midi - 72) / 24), 0.8, 3.5))
        out = _modal(f0, [(1.0, 1.0, ring), (2.756, 0.3, ring * 0.25), (5.404, 0.1, ring * 0.1),
                          (8.933, 0.04, 0.05)], ring * 3.0, rng, detune_cents=5.0)
        tick_n = samples(0.004)
        out[:tick_n] += highpass(noise(tick_n, rng), 3000.0, 1) * 0.05
        return out * vel * 0.3
    return _cached(("caja", midi, vel), build)


def marimba(midi: int, velocity: float = 0.6) -> np.ndarray:
    """Lámina de palisandro: tono cálido y corto, para la interfaz."""
    rng = rng_for(f"marimba-{midi}-{velocity}")
    f0 = midi_hz(midi)
    out = _modal(f0, [(1.0, 1.0, 0.35), (3.93, 0.25, 0.07), (9.2, 0.05, 0.02)], 0.9, rng)
    click_n = samples(0.003)
    out[:click_n] += lowpass(noise(click_n, rng), 2500.0, 1) * 0.05
    return out * velocity * 0.4


def bell(nominal_hz: float, duration: float, strike: float = 1.0, seed: str = "campana",
         brightness: float = 1.0) -> np.ndarray:
    """Campana de bronce (modelo de parciales de una campana de iglesia con su tercera menor)."""
    rng = rng_for("campana-" + seed)
    modes = [(0.5, 0.55, duration * 0.42), (1.0, 0.65, duration * 0.3), (1.183, 0.45, duration * 0.22),
             (1.506, 0.28, duration * 0.18), (2.0, 0.6 * brightness, duration * 0.14),
             (2.514, 0.22 * brightness, duration * 0.09), (2.662, 0.2 * brightness, duration * 0.08),
             (3.011, 0.15 * brightness, duration * 0.06), (4.166, 0.08 * brightness, duration * 0.04),
             (5.433, 0.05 * brightness, duration * 0.03)]
    out = _modal(nominal_hz, modes, duration, rng, doublet=0.0011)
    hit_n = samples(0.012)
    out[:hit_n] += bandpass(noise(hit_n, rng), 2000.0, 7000.0, 1) * exp_decay(hit_n, 0.003) * 0.3 * strike
    return out * strike * 0.3


def rod_gong(f0: float, duration: float = 6.0, strike: float = 1.0, seed: str = "gong") -> np.ndarray:
    """Varilla de reloj de pie: modos de barra libre, grave y larga."""
    rng = rng_for("varilla-" + seed)
    out = _modal(f0, [(1.0, 1.0, duration * 0.35), (2.756, 0.5, duration * 0.16),
                      (5.404, 0.22, duration * 0.07), (8.933, 0.08, duration * 0.03)], duration, rng,
                 doublet=0.0007)
    hit_n = samples(0.01)
    out[:hit_n] += lowpass(noise(hit_n, rng), 2500.0, 1) * 0.15 * strike
    return out * strike * 0.32


# --- Percusión ---

def brush_sweep(duration: float = 0.32, velocity: float = 0.5, seed: str = "") -> np.ndarray:
    rng = rng_for(f"barrido-{duration}-{velocity}-{seed}")
    n = samples(duration)
    t = time_axis(n)
    env = np.sin(np.pi * np.clip(t / duration, 0, 1)) ** 1.5
    swish = bandpass(noise(n, rng), 900.0, 7000.0, 2)
    swish *= 1 + 0.4 * np.sin(2 * np.pi * rng.uniform(9, 14) * t)
    return swish * env * velocity * 0.05


def brush_tap(velocity: float = 0.6, seed: str = "") -> np.ndarray:
    rng = rng_for(f"toque-{velocity}-{seed}")
    n = samples(0.18)
    t = time_axis(n)
    hiss = bandpass(noise(n, rng), 1200.0, 8000.0, 2) * exp_decay(n, 0.035)
    body = np.sin(2 * np.pi * 190.0 * t) * exp_decay(n, 0.05) * 0.4
    return (hiss * 0.12 + body * 0.06) * velocity * attack_ramp(n, 0.001)


def ride(velocity: float = 0.5, seed: str = "ride") -> np.ndarray:
    def build() -> np.ndarray:
        rng = rng_for("ride-" + seed)
        n = samples(2.4)
        t = time_axis(n)
        out = np.zeros(n)
        for _ in range(14):
            f = rng.uniform(2800, 9000)
            out += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / rng.uniform(0.5, 1.6)) * rng.uniform(0.3, 1.0)
        wash = highpass(noise(n, rng), 5000.0, 2) * np.exp(-t / 0.7) * 0.8
        ping = np.sin(2 * np.pi * 5200 * t) * np.exp(-t / 0.03) * 1.5
        out = highpass((out / 14 + wash * 0.25 + ping * 0.2), 2500.0, 2)
        return out * attack_ramp(n, 0.0005)
    return _cached(("ride", seed), build) * velocity * 0.06


def soft_kick(velocity: float = 0.5) -> np.ndarray:
    n = samples(0.5)
    t = time_axis(n)
    freq = 48 + 42 * np.exp(-t / 0.05)
    phase = np.cumsum(freq) / SR * 2 * np.pi
    return np.sin(phase) * np.exp(-t / 0.18) * attack_ramp(n, 0.002) * velocity * 0.35


def timpani(midi: int, velocity: float = 0.7, seed: str = "") -> np.ndarray:
    rng = rng_for(f"timbal-{midi}-{velocity}-{seed}")
    f0 = midi_hz(midi)
    out = _modal(f0, [(1.0, 1.0, 1.4), (1.504, 0.55, 0.9), (1.742, 0.32, 0.6), (2.0, 0.25, 0.5),
                      (2.245, 0.14, 0.35), (2.494, 0.1, 0.3)], 3.0, rng)
    hit_n = samples(0.05)
    out[:hit_n] += lowpass(noise(hit_n, rng), 900.0, 2) * exp_decay(hit_n, 0.012) * 0.5
    return out * velocity * 0.4


def heartbeat(velocity: float = 0.6) -> np.ndarray:
    """Latido grave (lub-dub) para las capas de tensión."""
    n = samples(0.9)
    t = time_axis(n)
    out = np.zeros(n)
    for offset, gain in [(0.0, 1.0), (0.26, 0.7)]:
        local = np.clip(t - offset, 0, None)
        freq = 38 + 22 * np.exp(-local / 0.04)
        phase = np.cumsum(freq * (t >= offset)) / SR * 2 * np.pi
        out += np.sin(phase) * np.exp(-local / 0.11) * (t >= offset) * gain
    return lowpass(out, 160.0, 2) * velocity * 0.6
