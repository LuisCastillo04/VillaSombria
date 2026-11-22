"""Genera toda la música, los ambientes y los efectos de Villa Sombría en `assets/audio/`.

Uso (desde `new-game-project/`):

    python tools/generar_audio.py                 # todo
    python tools/generar_audio.py --solo efectos  # musica, fragmentos, ambientes o efectos
    python tools/generar_audio.py --espectrogramas <carpeta>   # además, imágenes para revisar

Requisitos: Python 3.10+, NumPy, SciPy y FFmpeg con libvorbis en el PATH (matplotlib sólo para los
espectrogramas). No usa muestras grabadas ni servicios externos: todo se sintetiza con
`tools/sintesis/`, con semillas fijas, así que cada ejecución produce el mismo resultado.

Formatos:
- Música, capas de tensión y ambientes en bucle: Ogg Vorbis (se reproducen en streaming).
- Fragmentos musicales y efectos largos o estéreo: Ogg Vorbis.
- Efectos cortos: WAV mono de 16 bits (Godot los comprime al importar).

Al terminar escribe `docs/AUDIO_INVENTARIO.md` y comprueba cada bucle: longitud exacta y unión
continua entre el final y el principio después de codificar.
"""

from __future__ import annotations

import argparse
import sys
import tempfile
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sintesis import ambientes, efectos, instrumentos, musica  # noqa: E402
from sintesis.dsp import SR, decode_ogg, encode_ogg, peak, rms, to_db, write_wav  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
OUTPUT = PROJECT / "assets" / "audio"
INVENTORY = PROJECT / "docs" / "AUDIO_INVENTARIO.md"
MUSIC_QUALITY = 3
AMBIENCE_QUALITY = 3
SHORT_EFFECT_SECONDS = 2.0


class Report:
    def __init__(self) -> None:
        self.rows: list[dict] = []

    def add(self, path: Path, kind: str, data: np.ndarray, loop: bool, text: str, generator: str,
            seam: float | None = None) -> None:
        channels = 1 if data.ndim == 1 else data.shape[1]
        self.rows.append({
            "path": path.relative_to(PROJECT).as_posix(), "kind": kind, "seconds": len(data) / SR,
            "channels": channels, "loop": loop, "bytes": path.stat().st_size, "text": text,
            "generator": generator, "rms": to_db(rms(data)), "peak": to_db(peak(data)), "seam": seam,
        })
        seam_text = f" unión {seam:.2f}" if seam is not None else ""
        print(f"  {path.relative_to(OUTPUT).as_posix():58s} {len(data) / SR:6.1f} s  {channels}c  "
              f"RMS {to_db(rms(data)):6.1f}  pico {to_db(peak(data)):5.1f}  {path.stat().st_size / 1024:7.0f} KB{seam_text}")


def seam_jump_db(decoded: np.ndarray) -> float:
    x = decoded if decoded.ndim == 1 else decoded.mean(axis=1)
    return to_db(abs(float(x[0]) - float(x[-1])))


def seam_ratio(decoded: np.ndarray) -> float:
    """Salto entre la última y la primera muestra frente al salto típico entre muestras vecinas.
    Cerca de 1 (o menos) significa que la unión del bucle es tan continua como el resto."""
    x = decoded if decoded.ndim == 1 else decoded.mean(axis=1)
    jump = abs(float(x[0]) - float(x[-1]))
    typical = float(np.percentile(np.abs(np.diff(x)), 99)) + 1e-9
    return jump / typical


LOOP_IMPORT = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[params]

loop=true
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
"""


def mark_loop_import(target: Path) -> None:
    """Marca el Ogg como bucle en su `.import`, para que el editor también lo reproduzca en bucle.
    Si Godot aún no lo ha importado, deja un `.import` mínimo que Godot completa al importar. (El
    juego fuerza el bucle de todos modos al cargarlo: ver `AudioCatalog.loop_stream`.)"""
    settings = target.with_name(target.name + ".import")
    if settings.exists():
        text = settings.read_text(encoding="utf-8")
        if "loop=false" in text:
            settings.write_text(text.replace("loop=false", "loop=true"), encoding="utf-8", newline="\n")
    else:
        settings.write_text(LOOP_IMPORT, encoding="utf-8", newline="\n")


def write_ogg(data: np.ndarray, target: Path, quality: float, loop: bool, temp: Path) -> float | None:
    wav = temp / (target.stem + ".wav")
    write_wav(wav, data, 1 if data.ndim == 1 else None)
    encode_ogg(wav, target, quality)
    wav.unlink()
    if not loop:
        return None
    mark_loop_import(target)
    decoded = decode_ogg(target)
    if abs(len(decoded) - len(data)) > 1:
        raise RuntimeError(f"{target.name}: el Ogg dura {len(decoded)} muestras y el bucle {len(data)}")
    print(f"    unión de {target.name}: salto {seam_jump_db(decoded):.0f} dBFS")
    return seam_ratio(decoded)


def generate_music(report: Report, temp: Path, spectrograms: Path | None) -> None:
    print("Música")
    for name, (builder, text) in musica.TRACKS.items():
        start = time.time()
        layers = builder()
        instrumentos.clear_cache()
        for layer, data in layers.items():
            suffix = "" if layer == "base" else "_" + layer
            target = OUTPUT / "musica" / f"{name}{suffix}.ogg"
            seam = write_ogg(data, target, MUSIC_QUALITY, True, temp)
            kind = "música" if layer == "base" else "capa de tensión"
            report.add(target, kind, data, True, text if layer == "base" else "Capa de tensión sincronizada de la pieza anterior.",
                       f"musica.{builder.__name__}", seam)
            _spectrogram(spectrograms, target.stem, data)
        print(f"    ({time.time() - start:.0f} s)")


def generate_stingers(report: Report, temp: Path, spectrograms: Path | None) -> None:
    print("Fragmentos")
    for name, (builder, text) in musica.STINGERS.items():
        data = builder()
        instrumentos.clear_cache()
        target = OUTPUT / "musica" / "fragmentos" / f"{name.split('/')[-1]}.ogg"
        write_ogg(data, target, MUSIC_QUALITY + 1, False, temp)
        report.add(target, "fragmento", data, False, text, f"musica.{builder.__name__}")
        _spectrogram(spectrograms, target.stem, data)


def generate_ambience(report: Report, temp: Path, spectrograms: Path | None) -> None:
    print("Ambientes")
    for name, (builder, channels, text) in ambientes.BEDS.items():
        data = builder()
        data = data.mean(axis=1) if channels == 1 and data.ndim == 2 else data
        target = OUTPUT / "ambiente" / f"{name}.ogg"
        seam = write_ogg(np.clip(data, -0.99, 0.99), target, AMBIENCE_QUALITY, True, temp)
        report.add(target, "ambiente en bucle", data, True, text, f"ambientes.{builder.__name__}", seam)
        _spectrogram(spectrograms, target.stem, data)


def generate_effects(report: Report, temp: Path, spectrograms: Path | None) -> None:
    print("Efectos")
    for name, (data, text) in efectos.build_all().items():
        data = np.asarray(data)
        # Los detalles de ambiente se colocan en el espacio 3D: tienen que ser mono.
        if data.ndim == 2 and name.startswith("ambiente/"):
            data = data.mean(axis=1)
        stereo = data.ndim == 2 and not np.allclose(data[:, 0], data[:, 1])
        if data.ndim == 2 and not stereo:
            data = data[:, 0]
        kind = "detalle de ambiente" if name.startswith("ambiente/") else "efecto"
        if len(data) / SR > SHORT_EFFECT_SECONDS or stereo:
            target = OUTPUT / f"{name}.ogg"
            write_ogg(np.clip(data, -0.99, 0.99), target, AMBIENCE_QUALITY + 1, False, temp)
        else:
            target = OUTPUT / f"{name}.wav"
            write_wav(target, data, 1)
        report.add(target, kind, data, False, text, "efectos")
        if name.endswith(("_1", "telefono", "campana_torre")):
            _spectrogram(spectrograms, target.stem, data)


def _spectrogram(folder: Path | None, name: str, data: np.ndarray) -> None:
    """Imagen del espectrograma y de la envolvente, para revisar a ojo la estructura de cada pieza."""
    if folder is None:
        return
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    x = data if data.ndim == 1 else data.mean(axis=1)
    folder.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(2, 1, figsize=(14, 6), sharex=True, gridspec_kw={"height_ratios": [3, 1]})
    nfft = int(min(4096, 2 ** np.floor(np.log2(max(len(x) // 4, 64)))))
    axes[0].specgram(x, NFFT=nfft, Fs=SR, noverlap=nfft // 2, cmap="magma", vmin=-130, vmax=-30)
    axes[0].set_ylim(0, 8000)
    axes[0].set_ylabel("Hz")
    hop = SR // 20
    frames = len(x) // hop
    level = [20 * np.log10(np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) + 1e-9) for i in range(frames)]
    axes[1].plot(np.arange(frames) * hop / SR, level, linewidth=0.6)
    axes[1].set_ylim(-70, 0)
    axes[1].set_ylabel("dB RMS")
    axes[1].set_xlabel("s")
    fig.suptitle(name)
    fig.tight_layout()
    fig.savefig(folder / f"{name}.png", dpi=70)
    plt.close(fig)


def write_inventory(report: Report) -> None:
    total = sum(row["bytes"] for row in report.rows)
    lines = [
        "# Inventario de audio",
        "",
        "Archivo generado por `tools/generar_audio.py`; no lo edites a mano. Todo es síntesis propia del",
        "proyecto (ver [AUDIO.md](AUDIO.md)). «Unión» compara el salto entre el final y el principio de un",
        "bucle, ya codificado, con el salto habitual entre muestras vecinas: 1 o menos es una unión continua.",
        "",
        f"Total: {len(report.rows)} archivos, {total / 1048576:.1f} MB.",
        "",
        "| Archivo | Tipo | Duración | Canales | Bucle | Tamaño | RMS / pico (dBFS) | Unión | Descripción | Generador |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in sorted(report.rows, key=lambda r: r["path"]):
        seam = f"{row['seam']:.2f}" if row["seam"] is not None else "—"
        lines.append(
            f"| `{row['path'].removeprefix('assets/audio/')}` | {row['kind']} | {row['seconds']:.1f} s | {row['channels']} | "
            f"{'sí' if row['loop'] else 'no'} | {row['bytes'] / 1024:.0f} KB | {row['rms']:.1f} / {row['peak']:.1f} | {seam} | "
            f"{row['text']} | `{row['generator']}` |")
    INVENTORY.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--solo", choices=["musica", "fragmentos", "ambientes", "efectos"], action="append")
    parser.add_argument("--espectrogramas", type=Path, default=None)
    args = parser.parse_args()
    parts = args.solo or ["musica", "fragmentos", "ambientes", "efectos"]
    report = Report()
    start = time.time()
    with tempfile.TemporaryDirectory() as temp_name:
        temp = Path(temp_name)
        if "efectos" in parts:
            generate_effects(report, temp, args.espectrogramas)
        if "ambientes" in parts:
            generate_ambience(report, temp, args.espectrogramas)
        if "fragmentos" in parts:
            generate_stingers(report, temp, args.espectrogramas)
        if "musica" in parts:
            generate_music(report, temp, args.espectrogramas)
    if args.solo is None:
        write_inventory(report)
    loops = [row for row in report.rows if row["seam"] is not None]
    worst = max(loops, key=lambda r: r["seam"]) if loops else None
    print(f"{len(report.rows)} archivos en {time.time() - start:.0f} s.")
    if worst is not None:
        print(f"Peor unión de bucle: {worst['path']} ({worst['seam']:.2f})")


if __name__ == "__main__":
    main()
