"""Notas, acordes, conducción de voces y una partitura sencilla medida en pulsos."""

from __future__ import annotations

import itertools

import numpy as np

from .dsp import SR, Session

_LETTERS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

CHORDS = {
    "m9": [0, 3, 7, 10, 14], "m7": [0, 3, 7, 10], "m6": [0, 3, 7, 9], "madd9": [0, 3, 7, 14],
    "mmaj7": [0, 3, 7, 11], "maj7": [0, 4, 7, 11], "maj9": [0, 4, 7, 11, 14], "maj7#11": [0, 4, 7, 11, 18],
    "6": [0, 4, 7, 9], "69": [0, 4, 7, 9, 14], "7": [0, 4, 7, 10], "9": [0, 4, 7, 10, 14],
    "13": [0, 4, 10, 14, 21], "7b9": [0, 4, 7, 10, 13], "7sus4": [0, 5, 7, 10], "m7b5": [0, 3, 6, 10],
    "dim7": [0, 3, 6, 9], "": [0, 4, 7], "m": [0, 3, 7],
}


def note(name: str) -> int:
    """'C#4', 'Bb2' o 'F5' a número MIDI (C4 = 60)."""
    letter = name[0].upper()
    rest = name[1:]
    accidental = 0
    while rest and rest[0] in "#b":
        accidental += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + _LETTERS[letter] + accidental


def parse_chord(symbol: str) -> tuple[int, list[int]]:
    """'Dm9' a (clase de la fundamental, intervalos)."""
    root = symbol[0]
    index = 1
    if len(symbol) > 1 and symbol[1] in "#b":
        root += symbol[1]
        index = 2
    quality = symbol[index:]
    return note(root + "0") % 12, CHORDS[quality]


def chord_root(symbol: str, octave: int) -> int:
    pitch_class, _ = parse_chord(symbol)
    return 12 * (octave + 1) + pitch_class


def voicing(symbol: str, low: int, high: int, previous: list[int] | None = None, size: int = 4,
            rootless: bool = False) -> list[int]:
    """Voz del acorde dentro de [low, high] que menos se mueve respecto a la anterior. Sin
    fundamental si `rootless` (el contrabajo ya la toca)."""
    pitch_class, intervals = parse_chord(symbol)
    tones = [(pitch_class + i) % 12 for i in intervals]
    if rootless and len(tones) > 3:
        tones = tones[1:]
    # Prioridad: tercera, séptima, novena o color y quinta.
    tones = tones[:size] if len(tones) > size else tones
    candidates = []
    options = [[p for p in range(low, high + 1) if p % 12 == tone] for tone in tones]
    for combo in itertools.product(*options):
        chord = sorted(combo)
        if chord[-1] - chord[0] > 16 or len(set(chord)) < len(chord):
            continue
        candidates.append(chord)
    if not candidates:
        return sorted(low + (t - low) % 12 for t in tones)
    if previous is None:
        center = (low + high) / 2
        return min(candidates, key=lambda c: abs(np.mean(c) - center))
    return min(candidates, key=lambda c: sum(abs(a - b) for a, b in zip(c, sorted(previous))) +
               0.3 * abs(np.mean(c) - np.mean(previous)))


class Score:
    """Partitura medida en pulsos. `bpm` debe dar un número entero de muestras por pulso para que
    el bucle cierre exacto."""

    def __init__(self, bpm: float, beats: int, loop: bool = True, seed: np.random.Generator | None = None):
        self.bpm = bpm
        self.spb = SR * 60.0 / bpm
        if abs(self.spb - round(self.spb)) > 1e-9:
            raise ValueError(f"{bpm} BPM no da muestras enteras por pulso")
        self.spb = int(round(self.spb))
        self.beats = beats
        self.session = Session(beats * self.spb, loop)
        self.rng = seed if seed is not None else np.random.default_rng(0)

    @property
    def samples(self) -> int:
        return self.beats * self.spb

    def seconds(self, beats: float) -> float:
        return beats * 60.0 / self.bpm

    def place(self, bus: str, sound: np.ndarray, beat: float, gain: float = 1.0, position: float = 0.0,
              jitter: float = 0.0) -> None:
        offset = 0
        if jitter > 0:
            offset = int(self.rng.normal(0.0, jitter) * SR)
        self.session.buses[bus].add(sound, int(round(beat * self.spb)) + offset, gain, position)

    def bus(self, name: str, **kwargs):
        return self.session.bus(name, **kwargs)


def swing(position: float, ratio: float = 0.64) -> float:
    """Desplaza las corcheas a contratiempo hacia el swing (2:1 aproximado)."""
    whole = np.floor(position)
    frac = position - whole
    if abs(frac - 0.5) < 1e-6:
        return whole + ratio
    return position
