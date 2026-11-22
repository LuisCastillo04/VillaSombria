"""Composiciones originales de Villa Sombría.

Todas comparten un leitmotiv, «el reloj detenido»: Fa - Mi - Re - La, seguido de Si bemol - La.
Aparece completo en el tema del menú, en la caja de música de la mansión, fragmentado en la calle
y transformado en mayor en el epílogo, cuando el misterio ya se entiende.

Cada pieza devuelve sus capas («base» y, si la tiene, «tension») con la misma longitud exacta, de
modo que el juego las reproduce sincronizadas y sube o baja la tensión sin cortar la música.
"""

from __future__ import annotations

import numpy as np

from . import instrumentos as ins
from .dsp import (SR, chorus, db, highpass, impulse_response, lowpass, noise, normalize_rms, peaking,
                  rms, rng_for, samples, shelf, soft_limit, stereo)
from .teoria import Score, chord_root, note, parse_chord, voicing


def _melody(score: Score, bus: str, line: list, start: float, play, gain: float = 1.0, position: float = 0.0,
            jitter: float = 0.006, legato: float = 1.0) -> None:
    """Coloca una melodía: `line` es una lista de (nota o None, pulsos)."""
    beat = start
    for pitch, length in line:
        if pitch is not None:
            sound = play(note(pitch), score.seconds(length) * legato)
            score.place(bus, sound, beat, gain, position, jitter)
        beat += length


def _strings_fx(width: float = 0.35):
    rng = np.random.default_rng(7)

    def fx(x: np.ndarray) -> np.ndarray:
        return chorus(x, rng, depth_ms=5.0, rate=0.21, mix=width)
    return fx


def _eq(*steps):
    def fx(x: np.ndarray) -> np.ndarray:
        for step in steps:
            x = step(x)
        return x
    return fx


def _finish(score: Score, layers: dict[str, list[str]], ir: np.ndarray, wet: float, target_db: float,
            tension_offset_db: float = -3.0) -> dict[str, np.ndarray]:
    """Mezcla cada capa por separado con la misma reverberación. La base se lleva a `target_db` RMS y
    la capa de tensión, a `tension_offset_db` por debajo: a intensidad máxima acompaña sin tapar."""
    rendered = {name: stereo(score.session.render(ir, wet, only=buses)) for name, buses in layers.items()}
    out = {"base": soft_limit(rendered["base"] * (db(target_db) / rms(rendered["base"])), -1.5)}
    if "tension" in rendered:
        level = db(target_db + tension_offset_db) / rms(rendered["tension"])
        out["tension"] = soft_limit(rendered["tension"] * level, -1.5)
    return out


# --- Menú principal: «Villa Sombría» ---

def tema_menu() -> dict:
    """Balada noir en re menor, 72 BPM, 24 compases (80 s). Piano de fieltro con el leitmotiv,
    cuerdas, contrabajo, escobillas y vibráfono."""
    rng = rng_for("tema_menu")
    score = Score(72, 96, seed=rng)
    ir = impulse_response("sala_noir", 4.0, 2.9, predelay=0.02, damping=0.5)
    score.bus("piano", send=0.32, fx=[_eq(lambda x: shelf(x, 220, 2.0), lambda x: lowpass(x, 7000, 1))])
    score.bus("cuerdas", send=0.45, fx=[_strings_fx(0.45), _eq(lambda x: highpass(x, 110, 2))], gain=0.9)
    score.bus("bajo", send=0.12, fx=[_eq(lambda x: lowpass(x, 1800, 2))])
    score.bus("escobillas", send=0.2, fx=[_eq(lambda x: lowpass(x, 6500, 2))], gain=0.45)
    score.bus("vibrafono", send=0.45, gain=0.9)
    score.bus("armonicos", send=0.6)

    chords = (["Dm9", "Bbmaj7#11", "Gm9", ("A7sus4", "A7b9")] +
              ["Dm9", "Bbmaj7#11", "Gm9", "A7b9"] +
              ["Dm9", "Bbmaj7", "Em7b5", "A7b9"] +
              ["Fmaj7", ("Cm7", "F7"), "Bbmaj7", ("Em7b5", "A7b9")] +
              ["Dm9", "Bbmaj7#11", "Gm9", "A7b9"] +
              ["Dm9", "Bbmaj7#11", "Gm9", "A7sus4"])
    previous = None
    for bar, entry in enumerate(chords):
        halves = entry if isinstance(entry, tuple) else (entry,)
        span = 4 / len(halves)
        for index, symbol in enumerate(halves):
            beat = bar * 4 + index * span
            voices = voicing(symbol, 53, 72, previous, size=4, rootless=True)
            previous = voices
            pad_vel = 0.34 if bar < 4 or bar >= 20 else 0.42
            for pitch in voices:
                score.place("cuerdas", ins.strings(pitch, score.seconds(span) + 0.4, pad_vel, voices=4,
                                                    attack=1.3, release=1.6, seed=symbol), beat)
            root = chord_root(symbol, 2)
            if 8 <= bar < 20:
                score.place("bajo", ins.upright_bass(root, 0.55, score.seconds(span * 0.75)), beat, jitter=0.004)
                if span == 4:
                    fifth = root + 7 if root + 7 <= 50 else root - 5
                    score.place("bajo", ins.upright_bass(fifth, 0.45, score.seconds(0.9)), beat + 3, jitter=0.004)
            # Mano izquierda: fundamental grave y acorde quebrado, con pedal.
            score.place("piano", ins.piano(root - 12 if root > 40 else root, 0.3, score.seconds(span), pedal=True,
                                           tone=0.75), beat, position=-0.2, jitter=0.004)
            arpeggio = [voices[0], voices[1], voices[2], voices[-1]]
            step = 0.5 if bar < 4 or bar >= 20 else 1.0
            for k in range(int(span / step)):
                pitch = arpeggio[k % len(arpeggio)]
                vel = 0.2 + 0.05 * (k % 2 == 0)
                score.place("piano", ins.piano(pitch, vel, score.seconds(step * 1.5), pedal=True, tone=0.7),
                            beat + 0.5 + k * step if step == 1.0 else beat + k * step, position=-0.1, jitter=0.008)

    motif_a = [("F5", 1), ("E5", 1), ("D5", 1), ("A4", 1), ("Bb4", 1.5), ("A4", 0.5), ("E5", 2),
               ("D5", 1), ("C5", 0.5), ("Bb4", 0.5), ("A4", 1), ("G4", 1), ("C#5", 2), ("Bb4", 1), ("A4", 1)]
    motif_a2 = [("F5", 1), ("E5", 1), ("D5", 1), ("A5", 1), ("G5", 1.5), ("F5", 0.5), ("E5", 1), ("D5", 1),
                ("D5", 1), ("C5", 1), ("Bb4", 1), ("G4", 1), ("A4", 3), (None, 1)]
    bridge = [("A5", 2), ("G5", 1), ("F5", 1), ("Eb5", 1), ("D5", 1), ("C5", 1), ("A4", 1),
              ("D5", 2), ("F5", 1), ("A5", 1), ("G5", 1.5), ("F5", 0.5), ("E5", 1), ("C#5", 1)]
    outro = [("F5", 1), ("E5", 1), ("D5", 2), (None, 4), ("Bb4", 2), ("A4", 2), (None, 4)]

    def lead(pitch: int, length: float) -> np.ndarray:
        return ins.piano(pitch, 0.55 + 0.04 * ((pitch * 7) % 3), length + 0.6, pedal=True, tone=0.85)

    _melody(score, "piano", motif_a, 16, lead, 1.0, 0.1)
    _melody(score, "piano", motif_a2, 32, lead, 1.0, 0.1)
    _melody(score, "piano", bridge, 48, lead, 0.95, 0.1)
    _melody(score, "piano", motif_a, 64, lead, 0.9, 0.1)
    _melody(score, "vibrafono", [(p if p is None else p[:-1] + str(int(p[-1]) + 1), d) for p, d in motif_a], 64,
            lambda m, length: ins.vibraphone(m, 0.4, length + 0.8), 0.6, 0.3)
    _melody(score, "piano", outro, 80, lead, 0.8, 0.1)
    _melody(score, "vibrafono", [("A5", 1), ("E6", 3)], 4, lambda m, length: ins.vibraphone(m, 0.3, length + 1), 0.5, 0.35)
    score.place("armonicos", ins.glass_harmonic(note("A5"), score.seconds(7), 0.35, "menu"), 84)
    score.place("armonicos", ins.glass_harmonic(note("E6"), score.seconds(6), 0.3, "menu2"), 88)

    for beat in range(48, 80):
        score.place("escobillas", ins.brush_sweep(score.seconds(0.9), 0.32, str(beat % 4)), beat, position=0.3, jitter=0.004)
        if beat % 2 == 1:
            score.place("escobillas", ins.brush_tap(0.35, str(beat)), beat, position=0.3, jitter=0.003)
    for beat in range(48, 80, 4):
        score.place("escobillas", ins.soft_kick(0.25), beat)

    return _finish(score, {"base": list(score.session.buses)}, ir, 0.9, -20.0)


# --- Calle y estación: «Calle lluviosa» ---

def calle_lluviosa() -> dict:
    """Exploración del pueblo, la menor, 63 BPM, 20 compases (76 s). Mucho espacio: acordes
    rodados, fragmentos del leitmotiv y silencios. Capa de tensión con trémolo, latido y armónicos."""
    rng = rng_for("calle_lluviosa")
    score = Score(63, 80, seed=rng)
    ir = impulse_response("calle", 4.0, 3.2, predelay=0.025, damping=0.55)
    score.bus("piano", send=0.42, fx=[_eq(lambda x: shelf(x, 250, 2.5), lambda x: lowpass(x, 6000, 1))])
    score.bus("pad", send=0.5, fx=[_strings_fx(0.5), _eq(lambda x: highpass(x, 120, 2))], gain=0.75)
    score.bus("bajo", send=0.18, fx=[_eq(lambda x: lowpass(x, 1500, 2))], gain=0.9)
    score.bus("vibrafono", send=0.55, gain=0.7)
    score.bus("t_tremolo", send=0.35, fx=[_eq(lambda x: highpass(x, 60, 2))])
    score.bus("t_latido", send=0.1)
    score.bus("t_armonicos", send=0.6)
    score.bus("t_cluster", send=0.5)

    plan = [("Am9", 8), ("Fmaj7#11", 8), ("Dm9", 8), ("E7sus4", 4), ("E7b9", 4), ("Am9", 8), ("Fmaj7", 8),
            ("Dm9", 4), ("G7", 4), ("Cmaj7", 4), ("Bm7b5", 2), ("E7b9", 2), ("Fmaj7#11", 8), ("E7sus4", 4),
            ("E7b9", 4)]
    beat = 0.0
    previous = None
    for symbol, length in plan:
        voices = voicing(symbol, 52, 71, previous, size=4, rootless=True)
        previous = voices
        for pitch in voices:
            score.place("pad", ins.strings(pitch, score.seconds(length) + 0.5, 0.3, voices=4, attack=2.2,
                                            release=2.4, brightness=0.7, seed="calle" + symbol), beat)
        # Acorde rodado del piano al cambiar de armonía.
        for k, pitch in enumerate(voices):
            score.place("piano", ins.piano(pitch, 0.27 + 0.03 * k, score.seconds(length), pedal=True, tone=0.7),
                        beat + 0.09 * k, position=-0.15, jitter=0.004)
        root = chord_root(symbol, 2)
        score.place("bajo", ins.upright_bass(root if root <= 45 else root - 12, 0.5, score.seconds(min(length, 4) * 0.9)), beat)
        score.place("piano", ins.piano((root if root <= 45 else root - 12) - 12, 0.25, score.seconds(length), pedal=True,
                                       tone=0.6), beat, position=-0.3)
        # Tensión: trémolo grave sobre la fundamental y la quinta.
        for pitch in (root, root + 7):
            score.place("t_tremolo", ins.strings(pitch, score.seconds(length) + 0.3, 0.42, voices=4, attack=1.0,
                                                  release=1.0, brightness=0.6, tremolo=10.0, seed="trem" + symbol), beat)
        beat += length

    def lead(pitch: int, length: float) -> np.ndarray:
        return ins.piano(pitch, 0.45, length + 1.0, pedal=True, tone=0.8)

    _melody(score, "piano", [("A5", 1), ("G5", 1), ("F5", 1), ("E5", 1), ("D5", 3), (None, 1)], 16, lead, 0.9, 0.15)
    _melody(score, "piano", [("E5", 1.5), ("D5", 0.5), ("A5", 2), ("G5", 1), ("E5", 1), ("C5", 2)], 44, lead, 0.9, 0.15)
    _melody(score, "piano", [("C6", 1), ("B5", 1), ("A5", 1), ("E5", 1), ("F5", 1.5), ("E5", 0.5), ("B4", 2)], 64, lead, 0.85, 0.15)
    _melody(score, "piano", [("F5", 1), ("E5", 1), ("G#4", 2)], 76, lead, 0.75, 0.15)
    for start, pitch in [(36, "A5"), (58, "E6"), (70, "B5")]:
        score.place("vibrafono", ins.vibraphone(note(pitch), 0.35, score.seconds(3)), start, position=0.35)

    for b in range(80):
        score.place("t_latido", ins.heartbeat(0.55 if b % 2 == 0 else 0.35), b)
    for start, length in [(24, 8), (56, 8), (72, 8)]:
        for pitch in ("E6", "F6"):
            score.place("t_armonicos", ins.glass_harmonic(note(pitch), score.seconds(length - 1), 0.4, "calle" + pitch),
                        start, position=0.4 if pitch == "F6" else -0.4)
    for start in (28, 60):
        for pitch in ("A1", "Bb1", "E2"):
            score.place("t_cluster", ins.piano(note(pitch), 0.45, score.seconds(4), pedal=True, tone=0.6), start)

    base = ["piano", "pad", "bajo", "vibrafono"]
    tension = ["t_tremolo", "t_latido", "t_armonicos", "t_cluster"]
    return _finish(score, {"base": base, "tension": tension}, ir, 0.9, -21.0)


# --- Café La Luna: «Medianoche en La Luna» ---

def _walking_bass(chords: list[str], rng: np.random.Generator) -> list[int]:
    """Bajo caminante: fundamental en la parte fuerte, notas del acorde y aproximación cromática al
    acorde siguiente en el cuarto pulso."""
    line = []
    for index, symbol in enumerate(chords):
        root = chord_root(symbol, 1)
        if root < note("E1"):
            root += 12
        nxt = chord_root(chords[(index + 1) % len(chords)], 1)
        if nxt < note("E1"):
            nxt += 12
        _, intervals = parse_chord(symbol)
        third, fifth = root + intervals[1], root + intervals[2]
        choices = [[third, fifth], [fifth, root + 12], [root + 12 - 2, fifth], [third, root + intervals[3] if len(intervals) > 3 else fifth]]
        middle = choices[rng.integers(len(choices))]
        approach = nxt + (1 if rng.random() < 0.5 else -1)
        bar = [root, middle[0], middle[1], approach]
        line.extend([p if p <= note("C3") else p - 12 for p in bar])
    return line


def jazz_cafe() -> dict:
    """Trío de swing suave en do menor, 105 BPM, forma AABA de 32 compases (73 s), con el color de un
    gramófono lejano. Capa de tensión: bordón grave y armónicos disonantes."""
    rng = rng_for("jazz_cafe")
    score = Score(105, 128, seed=rng)
    ir = impulse_response("cafe", 1.6, 0.9, predelay=0.008, damping=0.6, room=0.6)
    radio = _eq(lambda x: highpass(x, 110, 2), lambda x: lowpass(x, 5200, 2), lambda x: peaking(x, 1400, 2.5, 0.8))
    score.bus("piano", send=0.18, fx=[radio])
    score.bus("bajo", send=0.1, fx=[radio], gain=1.1)
    score.bus("bateria", send=0.15, fx=[radio], gain=0.9)
    score.bus("vibrafono", send=0.22, fx=[radio], gain=1.0)
    score.bus("crujido", send=0.0)
    score.bus("t_bordon", send=0.4, fx=[_eq(lambda x: highpass(x, 50, 2))])
    score.bus("t_armonicos", send=0.5)

    section_a = ["Cm9", "Cm9", "Fm9", "Fm9", "Dm7b5", "G7b9", "Cm9", ("Dm7b5", "G7b9")]
    section_b = ["Ebmaj7", "Ebmaj7", "Abmaj7", "Abmaj7", "Fm9", "Bb7", "Ebmaj7", ("Dm7b5", "G7b9")]
    form = section_a + section_a + section_b + section_a
    beat_chords: list[str] = []
    for entry in form:
        if isinstance(entry, tuple):
            beat_chords += [entry[0]] * 2 + [entry[1]] * 2
        else:
            beat_chords += [entry] * 4
    # Bajo caminante pulso a pulso (un acorde por pulso, con su aproximación).
    bar_chords = [beat_chords[i] for i in range(0, len(beat_chords), 4)]
    walking = _walking_bass(bar_chords, rng)
    for b, pitch in enumerate(walking):
        chord_now = beat_chords[b]
        if b % 4 == 2 and beat_chords[b] != beat_chords[b - 2]:
            pitch = chord_root(chord_now, 1) + (12 if chord_root(chord_now, 1) < note("E1") else 0)
        score.place("bajo", ins.upright_bass(pitch, 0.7 if b % 2 == 0 else 0.6, score.seconds(0.95)), b, jitter=0.005)

    previous = None
    for bar in range(32):
        symbols = [beat_chords[bar * 4], beat_chords[bar * 4 + 2]]
        voices = voicing(symbols[0], 52, 69, previous, size=4, rootless=True)
        previous = voices
        pattern = [[(0, 0.6), (1.64, 0.5)], [(0.64, 0.5), (2.64, 0.6)], [(0, 0.5), (2.0, 0.4), (3.64, 0.4)],
                   [(1.64, 0.6)]][rng.integers(4)]
        for offset, length in pattern:
            symbol = symbols[1] if offset >= 2 else symbols[0]
            chord_voices = voices if symbol == symbols[0] else voicing(symbol, 52, 69, voices, size=4, rootless=True)
            for k, pitch in enumerate(chord_voices):
                score.place("piano", ins.piano(pitch, 0.36 + 0.03 * k, score.seconds(length), tone=0.8),
                            bar * 4 + offset + 0.012 * k, position=-0.25, jitter=0.004)

    for b in range(128):
        score.place("bateria", ins.brush_sweep(score.seconds(0.95), 0.3, str(b % 3)), b, position=0.2, jitter=0.003)
        if b % 2 == 1:
            score.place("bateria", ins.brush_tap(0.45, str(b % 5)), b, position=0.2, jitter=0.003)
        score.place("bateria", ins.ride(0.4 if b % 2 == 0 else 0.3), b, position=0.35, jitter=0.002)
        if b % 2 == 1:
            score.place("bateria", ins.ride(0.22), b + 0.64, position=0.35, jitter=0.002)

    a1 = [("G4", 1), ("Bb4", 0.64), ("C5", 0.36), ("D5", 1), ("Eb5", 1), ("D5", 2), (None, 1), ("C5", 0.64), ("Bb4", 0.36),
          ("Ab4", 1), ("C5", 1), ("Eb5", 1), ("G5", 1), ("F5", 3), (None, 1),
          ("Ab5", 1), ("G5", 0.64), ("F5", 0.36), ("D5", 1), ("F5", 1), ("Eb5", 1), ("D5", 1), ("B4", 1), ("Ab4", 1),
          ("G4", 2), ("Bb4", 1), ("D5", 1), ("C5", 2), ("B4", 2)]
    a_end = a1[:-2] + [("C5", 3), (None, 1)]
    b_line = [("G5", 1.5), ("F5", 0.5), ("Eb5", 1), ("D5", 1), ("Bb4", 4),
              ("C5", 1), ("Eb5", 1), ("G5", 1), ("Ab5", 1), ("G5", 3), (None, 1),
              ("Ab5", 1), ("G5", 1), ("F5", 1), ("Eb5", 1), ("D5", 1), ("F5", 1), ("Ab5", 2),
              ("G5", 4), ("F5", 1), ("Eb5", 1), ("D5", 1), ("B4", 1)]
    a_last = a1[:-2] + [("C5", 2), (None, 2)]

    def vibes(pitch: int, length: float) -> np.ndarray:
        return ins.vibraphone(pitch, 0.5, length + 0.3, motor=True)

    def lead_piano(pitch: int, length: float) -> np.ndarray:
        return ins.piano(pitch, 0.5, length + 0.1, tone=0.9)

    _melody(score, "vibrafono", a1, 0, vibes, 1.0, 0.25, legato=0.95)
    _melody(score, "vibrafono", a_end, 32, vibes, 1.0, 0.25, legato=0.95)
    _melody(score, "vibrafono", b_line, 64, vibes, 1.0, 0.25, legato=0.95)
    _melody(score, "piano", a_last, 96, lead_piano, 1.0, -0.1, legato=0.9)

    # Crujido muy suave de gramófono, repartido por todo el bucle.
    n = score.samples
    clicks = np.zeros(n)
    for position in rng.integers(0, n, 260):
        clicks[position] += rng.uniform(-1, 1) * rng.uniform(0.2, 1.0)
    crackle = highpass(lowpass(clicks, 6000, 1), 1500, 2) * 0.02 + highpass(noise(n, rng, "pink"), 300, 1) * 0.0012
    score.session.buses["crujido"].add(stereo(crackle), 0)

    # Tensión: bordón de do y sol, y armónicos agudos que rozan la tonalidad.
    for start in range(0, 128, 32):
        for pitch in ("C2", "G2"):
            score.place("t_bordon", ins.strings(note(pitch), score.seconds(32) + 0.5, 0.5, voices=3, attack=3.0,
                                                 release=3.0, brightness=0.55, vibrato=6.0, seed="cafe" + pitch), start)
    for start in (24, 56, 88, 120):
        for pitch in ("B5", "C6"):
            score.place("t_armonicos", ins.glass_harmonic(note(pitch), score.seconds(6), 0.35, "cafe" + pitch), start,
                        position=0.3 if pitch == "C6" else -0.3)

    base = ["piano", "bajo", "bateria", "vibrafono", "crujido"]
    return _finish(score, {"base": base, "tension": ["t_bordon", "t_armonicos"]}, ir, 0.8, -22.0)


# --- Mansión Valdés: «Ecos de la casa Valdés» ---

def ecos_mansion() -> dict:
    """Minimalismo inquietante, 60 BPM, 20 compases (80 s). Bordones de violonchelo, una caja de
    música que recuerda el leitmotiv y notas sueltas de piano. Tensión: latido, trémolo disonante y
    racimos graves."""
    rng = rng_for("ecos_mansion")
    score = Score(60, 80, seed=rng)
    ir = impulse_response("mansion", 5.0, 4.2, predelay=0.03, damping=0.55, room=1.6)
    score.bus("chelos", send=0.45, fx=[_strings_fx(0.3), _eq(lambda x: lowpass(x, 2200, 2))])
    score.bus("pad", send=0.55, fx=[_strings_fx(0.5)], gain=0.6)
    score.bus("caja", send=0.65, fx=[_eq(lambda x: highpass(x, 300, 1))], gain=0.85)
    score.bus("piano", send=0.55, fx=[_eq(lambda x: lowpass(x, 5000, 1))])
    score.bus("armonicos", send=0.7, gain=0.8)
    score.bus("t_latido", send=0.15)
    score.bus("t_tremolo", send=0.45)
    score.bus("t_racimo", send=0.6)

    drones = [(0, 32, ("D2", "A2")), (32, 16, ("Bb1", "F2")), (48, 16, ("G1", "D2")), (64, 16, ("A1", "E2"))]
    for start, length, pitches in drones:
        for pitch in pitches:
            score.place("chelos", ins.strings(note(pitch), score.seconds(length) + 1.0, 0.5, voices=3, attack=3.5,
                                               release=3.5, brightness=0.55, vibrato=7.0, seed="mansion" + pitch), start - 1.5 if start else 0)
    for start, length, pitches in [(16, 16, ("F4", "A4", "E5")), (48, 16, ("Bb3", "D4", "A4")), (64, 16, ("C#4", "G4", "Bb4"))]:
        for pitch in pitches:
            score.place("pad", ins.strings(note(pitch), score.seconds(length), 0.22, voices=4, attack=4.0, release=3.0,
                                            brightness=0.6, seed="mpad" + pitch), start)

    def box(pitch: int, _length: float) -> np.ndarray:
        return ins.music_box(pitch, 0.55)

    _melody(score, "caja", [("F6", 1), ("E6", 1), ("D6", 1), ("A5", 1), ("Bb5", 2), ("A5", 2)], 8, box, 1.0, 0.25, jitter=0.03)
    _melody(score, "caja", [("D6", 1), ("C6", 1), ("Bb5", 1), ("G5", 1), ("A5", 4)], 40, box, 0.9, -0.2, jitter=0.03)
    _melody(score, "caja", [("F6", 1.2), ("E6", 1.2), ("D6", 2.5)], 70, box, 0.8, 0.2, jitter=0.04)
    for beat_, pitch, vel in [(0, "D2", 0.38), (32, "Bb1", 0.38), (48, "G1", 0.36), (64, "A1", 0.38),
                              (26, "Eb5", 0.24), (58, "G#4", 0.24), (77, "C#5", 0.22)]:
        score.place("piano", ins.piano(note(pitch), vel, score.seconds(6), pedal=True, tone=0.65), beat_, position=-0.15)
    score.place("armonicos", ins.glass_harmonic(note("A5"), score.seconds(14), 0.3, "m1"), 34, position=-0.3)
    score.place("armonicos", ins.glass_harmonic(note("E6"), score.seconds(12), 0.25, "m2"), 66, position=0.3)

    for b in range(80):
        score.place("t_latido", ins.heartbeat(0.6 if b % 2 == 0 else 0.3), b)
    for start in range(0, 80, 16):
        for pitch in ("D4", "Eb4", "A4"):
            score.place("t_tremolo", ins.strings(note(pitch), score.seconds(14), 0.3, voices=4, attack=4.0, release=2.5,
                                                  brightness=0.7, tremolo=11.0, seed="mtrem" + pitch + str(start)), start)
    for start in (15, 31, 47, 63, 79):
        for pitch in ("D1", "Eb1", "A1"):
            score.place("t_racimo", ins.piano(note(pitch), 0.42, score.seconds(5), pedal=True, tone=0.55), start)

    base = ["chelos", "pad", "caja", "piano", "armonicos"]
    return _finish(score, {"base": base, "tension": ["t_latido", "t_tremolo", "t_racimo"]}, ir, 0.95, -23.0)


# --- Archivo municipal: «Legajos» ---

def legajos_archivo() -> dict:
    """Investigación en sol menor, 90 BPM, 24 compases (64 s). Pizzicato que marca el tiempo como un
    reloj, piano curioso y cuerdas suaves. Tensión: pedal grave en trémolo y timbal."""
    rng = rng_for("legajos")
    score = Score(90, 96, seed=rng)
    ir = impulse_response("archivo", 3.0, 1.8, predelay=0.012, damping=0.5, room=0.9)
    score.bus("pizz", send=0.25, fx=[_eq(lambda x: highpass(x, 180, 2))], gain=0.75)
    score.bus("bajo", send=0.15, fx=[_eq(lambda x: lowpass(x, 1500, 2))])
    score.bus("piano", send=0.3, fx=[_eq(lambda x: lowpass(x, 6500, 1))])
    score.bus("pad", send=0.4, fx=[_strings_fx(0.4), _eq(lambda x: highpass(x, 140, 2))], gain=0.55)
    score.bus("t_tremolo", send=0.4)
    score.bus("t_timbal", send=0.3)
    score.bus("t_armonicos", send=0.6)

    plan = ["Gm9", "Ebmaj7", "Cm9", ("D7sus4", "D7b9"), "Gm9", "Bbmaj7", "Cm9", ("Am7b5", "D7b9"),
            "Ebmaj7", "Cm9", "Gm9", ("D7sus4", "D7b9")]
    previous = None
    for slot, entry in enumerate(plan):
        halves = entry if isinstance(entry, tuple) else (entry,)
        span = 8 / len(halves)
        for index, symbol in enumerate(halves):
            beat = slot * 8 + index * span
            voices = voicing(symbol, 55, 74, previous, size=4, rootless=True)
            previous = voices
            for pitch in voices:
                score.place("pad", ins.strings(pitch, score.seconds(span), 0.25, voices=4, attack=1.5, release=1.5,
                                                brightness=0.65, seed="arch" + symbol), beat)
            root = chord_root(symbol, 2)
            for k in range(int(span / 2)):
                score.place("bajo", ins.upright_bass(root if root <= 47 else root - 12, 0.5, score.seconds(1.6)),
                            beat + 2 * k, jitter=0.004)
            ostinato = [voices[0], voices[2], voices[1], voices[2]]
            for k in range(int(span * 2)):
                pitch = ostinato[k % 4] + (12 if k % 8 >= 4 else 0)
                score.place("pizz", ins.upright_bass(pitch, 0.42 if k % 2 == 0 else 0.3, score.seconds(0.3)),
                            beat + 0.5 * k, position=0.3 if k % 2 else -0.3, jitter=0.004)
            for pitch in (root, root + 7):
                score.place("t_tremolo", ins.strings(pitch, score.seconds(span) + 0.3, 0.38, voices=4, attack=0.8,
                                                      release=1.0, brightness=0.6, tremolo=9.0, seed="atrem" + symbol), beat)

    def lead(pitch: int, length: float) -> np.ndarray:
        return ins.piano(pitch, 0.48, length + 0.4, pedal=True, tone=0.85)

    phrases = {16: [("Eb5", 0.5), ("D5", 0.5), ("C5", 1), ("G5", 1.5), ("F5", 0.5), ("Eb5", 2), ("D5", 1), (None, 1),
                    ("C5", 1), ("D5", 1), ("G5", 2), ("F#5", 1), ("Eb5", 1), ("D5", 2)],
               48: [("G5", 0.5), ("F5", 0.5), ("Eb5", 1), ("Bb5", 1.5), ("A5", 0.5), ("G5", 2), ("F5", 1), (None, 1),
                    ("Eb5", 1), ("C5", 1), ("A4", 1), ("G4", 1), ("F#4", 1), ("Eb5", 1), ("D5", 2)],
               80: [("D5", 1), ("F5", 1), ("A5", 1), ("Bb5", 1), ("A5", 2), ("F5", 2),
                    ("G5", 1), ("F5", 1), ("C5", 2), ("F#5", 1), ("Eb5", 1), ("D5", 2)]}
    for start, line in phrases.items():
        _melody(score, "piano", line, start, lead, 0.95, -0.1)

    for bar in range(24):
        score.place("t_timbal", ins.timpani(note("D2") if bar % 2 else note("G1"), 0.35, str(bar % 3)), bar * 4)
    for start in (28, 60, 92):
        for pitch in ("C#6", "D6"):
            score.place("t_armonicos", ins.glass_harmonic(note(pitch), score.seconds(3), 0.35, "ar" + pitch), start - 4,
                        position=0.3 if pitch == "D6" else -0.3)

    return _finish(score, {"base": ["pizz", "bajo", "piano", "pad"], "tension": ["t_tremolo", "t_timbal", "t_armonicos"]},
                   ir, 0.85, -21.0)


# --- Acusación y confrontación: «La acusación» ---

def la_acusacion() -> dict:
    """Tensión dramática en re menor, 100 BPM, 24 compases (58 s): ostinato grave de piano, cuerdas y
    timbal. La capa «tension» añade el lamento de los violines, el trémolo y los redobles para la
    confrontación final."""
    rng = rng_for("la_acusacion")
    score = Score(100, 96, seed=rng)
    ir = impulse_response("tension", 3.5, 2.4, predelay=0.02, damping=0.5)
    score.bus("ostinato", send=0.2, fx=[_eq(lambda x: lowpass(x, 3500, 2), lambda x: shelf(x, 150, 2.0))])
    score.bus("cuerdas", send=0.4, fx=[_strings_fx(0.4), _eq(lambda x: highpass(x, 80, 2))], gain=0.9)
    score.bus("timbal", send=0.3, gain=0.9)
    score.bus("t_violines", send=0.5, fx=[_strings_fx(0.35)], gain=0.85)
    score.bus("t_tremolo", send=0.4, gain=0.8)
    score.bus("t_redoble", send=0.35)

    roots = ["D2"] * 4 + ["Bb1"] * 4 + ["G1"] * 4 + ["A1"] * 4 + ["D2"] * 4 + ["A1"] * 4
    chords = ["Dm", "Dm", "Dm", "Dm", "Bbmaj7", "Bbmaj7", "Gm", "Gm", "Gm", "Gm", "Em7b5", "Em7b5",
              "A7b9", "A7b9", "A7b9", "A7b9", "Dm", "Dm", "Bbmaj7", "Bbmaj7", "Gm", "Em7b5", "A7b9", "A7b9"]
    pattern = [0, 0, 12, 0, 3, 0, 1, 0]
    for bar in range(24):
        root = note(roots[bar])
        for k, step in enumerate(pattern):
            vel = 0.62 if k in (0, 4) else 0.42
            score.place("ostinato", ins.piano(root + step, vel, score.seconds(0.45), tone=0.7), bar * 4 + 0.5 * k,
                        position=-0.1, jitter=0.003)
        if bar % 2 == 0:
            voices = voicing(chords[bar], 50, 69, None, size=4)
            for pitch in voices:
                score.place("cuerdas", ins.strings(pitch, score.seconds(8) - 0.2, 0.45, voices=5, attack=1.0, release=1.2,
                                                    brightness=0.8, seed="ac" + chords[bar]), bar * 4)
        score.place("timbal", ins.timpani(root + 12 if root < note("C2") else root, 0.6, str(bar % 4)), bar * 4)
        if bar % 4 == 3:
            score.place("timbal", ins.timpani(root + 12 if root < note("C2") else root, 0.4, "b"), bar * 4 + 3)
            score.place("timbal", ins.timpani(root + 12 if root < note("C2") else root, 0.45, "c"), bar * 4 + 3.5)

    def violins(pitch: int, length: float) -> np.ndarray:
        return ins.strings(pitch, length, 0.6, voices=6, attack=0.4, release=1.0, vibrato=12.0, brightness=1.0,
                           seed=f"vl{pitch}")

    lament = [("D5", 2), ("E5", 1), ("F5", 1), ("E5", 3), ("C#5", 1), ("D5", 2), ("Bb4", 2), ("A4", 4),
              ("F5", 2), ("G5", 1), ("A5", 1), ("Bb5", 3), ("A5", 1), ("G5", 2), ("E5", 2), ("C#5", 2), ("E5", 2)]
    _melody(score, "t_violines", lament, 32, violins, 1.0, 0.15, legato=1.02)
    _melody(score, "t_violines", lament[:8], 64, violins, 1.0, 0.15, legato=1.02)
    for bar in range(16, 24):
        voices = voicing(chords[bar], 62, 81, None, size=3)
        for pitch in voices:
            score.place("t_tremolo", ins.strings(pitch, score.seconds(4), 0.4, voices=4, attack=0.3, release=0.6,
                                                  brightness=0.9, tremolo=12.0, seed=f"actr{bar}"), bar * 4)
    for k in range(16):
        score.place("t_redoble", ins.timpani(note("A2"), 0.15 + 0.03 * k, f"r{k}"), 88 + 0.25 * k + 4)

    return _finish(score, {"base": ["ostinato", "cuerdas", "timbal"],
                           "tension": ["t_violines", "t_tremolo", "t_redoble"]}, ir, 0.9, -19.0)


# --- Epílogo: «Lo que el reloj calló» ---

def epilogo() -> dict:
    """Resolución en fa mayor, 70 BPM, 16 compases (55 s). El leitmotiv suena por fin en mayor; el
    acorde de si bemol menor deja el regusto amargo del caso."""
    rng = rng_for("epilogo")
    score = Score(70, 64, seed=rng)
    ir = impulse_response("epilogo", 4.0, 2.8, predelay=0.02, damping=0.45)
    score.bus("piano", send=0.33, fx=[_eq(lambda x: shelf(x, 220, 1.5), lambda x: lowpass(x, 7500, 1))])
    score.bus("cuerdas", send=0.45, fx=[_strings_fx(0.45), _eq(lambda x: highpass(x, 100, 2))], gain=0.85)
    score.bus("bajo", send=0.15, fx=[_eq(lambda x: lowpass(x, 1500, 2))], gain=0.85)
    score.bus("vibrafono", send=0.45, gain=0.7)

    chords = ["Fmaj7", "Dm9", "Bbmaj7", ("C7sus4", "C7"), "Am7", "Dm9", "Gm9", "C7sus4",
              "Fmaj7", "Am7", "Bbmaj7", "Bbm6", "Am7", "Dm9", "Gm9", "C7sus4"]
    previous = None
    for bar, entry in enumerate(chords):
        halves = entry if isinstance(entry, tuple) else (entry,)
        span = 4 / len(halves)
        for index, symbol in enumerate(halves):
            beat = bar * 4 + index * span
            voices = voicing(symbol, 53, 72, previous, size=4, rootless=True)
            previous = voices
            for pitch in voices:
                score.place("cuerdas", ins.strings(pitch, score.seconds(span) + 0.3, 0.4, voices=4, attack=1.0,
                                                    release=1.4, brightness=0.8, seed="ep" + symbol), beat)
            root = chord_root(symbol, 2)
            score.place("bajo", ins.upright_bass(root if root <= 45 else root - 12, 0.45, score.seconds(span * 0.9)), beat)
            broken = [root - 12 if root > 40 else root, voices[0], voices[1], voices[2]]
            for k in range(int(span)):
                score.place("piano", ins.piano(broken[k % 4], 0.24 if k else 0.3,
                                               score.seconds(1.5), pedal=True, tone=0.75),
                            beat + k, position=-0.15, jitter=0.006)

    melody = [("F5", 1), ("E5", 1), ("D5", 1), ("A4", 1), ("C5", 1.5), ("A4", 0.5), ("E5", 2),
              ("D5", 1), ("C5", 1), ("Bb4", 1), ("A4", 1), ("G4", 2), ("F4", 1), ("E4", 1),
              ("C5", 2), ("E5", 1), ("G5", 1), ("F5", 2), ("E5", 1), ("D5", 1),
              ("Bb4", 1), ("A4", 1), ("G4", 1), ("F4", 1), ("G4", 4),
              ("A5", 1), ("G5", 1), ("F5", 1), ("C5", 1), ("E5", 2), ("G5", 1), ("A5", 1),
              ("F5", 2), ("D5", 1), ("A4", 1), ("Db5", 2), ("C5", 1), ("Bb4", 1),
              ("C5", 2), ("A4", 2), ("F5", 1), ("E5", 1), ("D5", 1), ("A4", 1),
              ("Bb4", 2), ("A4", 1), ("G4", 1), ("G4", 2), (None, 2)]

    def lead(pitch: int, length: float) -> np.ndarray:
        return ins.piano(pitch, 0.52, length + 0.5, pedal=True, tone=0.85)

    _melody(score, "piano", melody, 0, lead, 1.0, 0.1)
    _melody(score, "vibrafono", [(p if p is None else p[:-1] + str(int(p[-1]) + 1), d) for p, d in melody[25:38]], 32,
            lambda m, length: ins.vibraphone(m, 0.3, length + 0.6), 0.6, 0.3)
    return _finish(score, {"base": list(score.session.buses)}, ir, 0.9, -20.0)


# --- Fragmentos musicales (no se repiten) ---

def _stinger(name: str, build, ir_name: str = "sala_noir", t60: float = 2.6, target_db: float = -20.0) -> np.ndarray:
    score = Score(60, 6, loop=False, seed=rng_for(name))
    ir = impulse_response(ir_name, 3.5, t60, predelay=0.015, damping=0.5)
    build(score)
    out = score.session.render(ir, 0.9, tail=0.5)
    out = stereo(out) * (db(target_db) / rms(stereo(out)[: samples(2.5)]))
    return soft_limit(out, -2.0)


def stinger_pista() -> np.ndarray:
    """Descubrimiento de una pista: arpegio ascendente de re menor con novena que queda en el aire."""
    def build(score: Score) -> None:
        score.bus("vib", send=0.5)
        score.bus("piano", send=0.4)
        score.bus("cuerdas", send=0.5, fx=[_strings_fx(0.4)], gain=0.6)
        for k, (pitch, at) in enumerate([("A4", 0.0), ("D5", 0.13), ("F5", 0.26), ("E6", 0.5)]):
            length = 2.2 if pitch == "E6" else 1.2
            score.place("vib", ins.vibraphone(note(pitch), 0.55 + 0.1 * (pitch == "E6"), length), at, position=0.2 * k - 0.2)
            score.place("piano", ins.piano(note(pitch), 0.3, length, pedal=True, tone=0.9), at)
        for pitch in ("D4", "A4", "E5"):
            score.place("cuerdas", ins.strings(note(pitch), 1.6, 0.35, voices=4, attack=0.5, release=1.5, seed="pista"), 0.0)
    return _stinger("stinger_pista", build, target_db=-19.0)


def stinger_deduccion() -> np.ndarray:
    """Una deducción encaja: crescendo de cuerdas que resuelve en re menor con el arpegio del hallazgo."""
    def build(score: Score) -> None:
        score.bus("cuerdas", send=0.5, fx=[_strings_fx(0.45)])
        score.bus("piano", send=0.4)
        score.bus("vib", send=0.5)
        score.bus("timbal", send=0.3)
        for pitch in ("Bb2", "F3", "D4", "A4", "E5"):
            score.place("cuerdas", ins.strings(note(pitch), 1.35, 0.45, voices=5, attack=1.2, release=0.4, seed="ded1"), 0.0)
        for pitch in ("D3", "A3", "F4", "A4", "E5"):
            score.place("cuerdas", ins.strings(note(pitch), 2.2, 0.55, voices=5, attack=0.15, release=2.2, seed="ded2"), 1.4)
        score.place("piano", ins.piano(note("D2"), 0.6, 3.0, pedal=True), 1.4)
        score.place("piano", ins.piano(note("D3"), 0.5, 3.0, pedal=True), 1.4)
        score.place("timbal", ins.timpani(note("D2"), 0.55), 1.4)
        for k, pitch in enumerate(["D5", "F5", "A5", "E6"]):
            score.place("vib", ins.vibraphone(note(pitch), 0.5, 2.0), 1.4 + 0.14 * k, position=0.15 * k)
    return _stinger("stinger_deduccion", build, target_db=-18.0)


def stinger_suceso() -> np.ndarray:
    """Noticia inquietante (un aviso de la historia): racimo grave, campana lejana y un armónico."""
    def build(score: Score) -> None:
        score.bus("piano", send=0.55)
        score.bus("campana", send=0.6, fx=[_eq(lambda x: lowpass(x, 2500, 2))])
        score.bus("arm", send=0.6)
        for pitch in ("D2", "Eb2", "A2"):
            score.place("piano", ins.piano(note(pitch), 0.45, 3.5, pedal=True, tone=0.6), 0.0)
        score.place("campana", ins.bell(330.0, 6.0, 0.6, "suceso", 0.6), 0.25)
        score.place("arm", ins.glass_harmonic(note("Eb6"), 2.2, 0.4, "suceso"), 0.5)
    return _stinger("stinger_suceso", build, t60=3.2, target_db=-21.0)


def stinger_nuevo_dia() -> np.ndarray:
    """Amanece otro día del caso: frase de piano en fa mayor y la campana de la torre a lo lejos."""
    def build(score: Score) -> None:
        score.bus("piano", send=0.4)
        score.bus("cuerdas", send=0.5, fx=[_strings_fx(0.45)], gain=0.6)
        score.bus("campana", send=0.7, fx=[_eq(lambda x: lowpass(x, 2200, 2))], gain=0.6)
        for k, (pitch, at) in enumerate([("F4", 0.0), ("C5", 0.3), ("A5", 0.6), ("F5", 1.1), ("E5", 1.6), ("D5", 2.1),
                                         ("A4", 2.6)]):
            score.place("piano", ins.piano(note(pitch), 0.45, 2.0, pedal=True, tone=0.85), at)
        for pitch in ("F3", "C4", "A4", "E5"):
            score.place("cuerdas", ins.strings(note(pitch), 3.4, 0.35, voices=4, attack=1.2, release=2.0, seed="dia"), 0.2)
        score.place("campana", ins.bell(392.0, 7.0, 0.5, "dia", 0.7), 0.0)
    return _stinger("stinger_nuevo_dia", build, target_db=-20.0)


def stinger_acusacion_fallida() -> np.ndarray:
    """La acusación no se sostiene: racimo de cuerdas que se apaga y un golpe de timbal."""
    def build(score: Score) -> None:
        score.bus("cuerdas", send=0.45, fx=[_strings_fx(0.3)])
        score.bus("timbal", send=0.35)
        for pitch in ("D3", "Eb3", "A3", "Bb3"):
            score.place("cuerdas", ins.strings(note(pitch), 0.6, 0.6, voices=5, attack=0.03, release=1.8, brightness=0.9,
                                                seed="fallo"), 0.0)
        score.place("timbal", ins.timpani(note("D2"), 0.7, "fallo"), 0.0)
    return _stinger("stinger_acusacion_fallida", build, target_db=-19.0)


TRACKS = {
    "menu/tema_villa_sombria": (tema_menu, "Tema principal: balada noir en re menor (72 BPM)."),
    "exploracion/calle_lluviosa": (calle_lluviosa, "Exploración de la plaza y la estación (63 BPM)."),
    "cafe/medianoche_en_la_luna": (jazz_cafe, "Swing suave de gramófono para el Café La Luna (105 BPM)."),
    "misterio/ecos_de_la_casa_valdes": (ecos_mansion, "Minimalismo inquietante para la mansión (60 BPM)."),
    "misterio/legajos": (legajos_archivo, "Investigación en el archivo municipal (90 BPM)."),
    "tension/la_acusacion": (la_acusacion, "Acusación y confrontación final (100 BPM)."),
    "resolucion/lo_que_el_reloj_callo": (epilogo, "Epílogo en fa mayor (70 BPM)."),
}

STINGERS = {
    "investigacion/pista_descubierta": (stinger_pista, "Fragmento al descubrir una pista."),
    "investigacion/deduccion": (stinger_deduccion, "Fragmento al establecer una deducción."),
    "investigacion/suceso": (stinger_suceso, "Fragmento para los avisos inquietantes de la historia."),
    "investigacion/nuevo_dia": (stinger_nuevo_dia, "Fragmento al empezar un día nuevo."),
    "investigacion/acusacion_fallida": (stinger_acusacion_fallida, "Fragmento cuando la acusación no se sostiene."),
}
