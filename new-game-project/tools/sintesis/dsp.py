"""Primitivas de procesamiento de señal: filtros, ruido, envolventes, reverberación y mezcla.

Convenciones:
- Frecuencia de muestreo `SR` (44,1 kHz). Las señales mono son vectores `(n,)` y las estéreo,
  matrices `(n, 2)`, siempre en coma flotante entre -1 y 1.
- Los bucles se construyen como señales periódicas: lo que suena más allá del final (colas de
  notas y de reverberación) se suma al principio con `fold`, igual que se oiría al repetirse. Así
  el punto de unión no tiene ni corte ni silencio.
"""

from __future__ import annotations

import subprocess
import zlib
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100


# --- Utilidades básicas ---

def rng_for(name: str) -> np.random.Generator:
    """Generador aleatorio con semilla fija derivada del nombre: cada recurso es reproducible."""
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")))


def seconds(n: int) -> float:
    return n / SR


def samples(sec: float) -> int:
    return int(round(sec * SR))


def db(value: float) -> float:
    """Decibelios a factor lineal."""
    return float(10.0 ** (value / 20.0))


def to_db(value: float) -> float:
    return float(20.0 * np.log10(max(value, 1e-12)))


def midi_hz(midi: float) -> float:
    return float(440.0 * 2.0 ** ((midi - 69.0) / 12.0))


def time_axis(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def stereo(x: np.ndarray) -> np.ndarray:
    if x.ndim == 2:
        return x
    return np.stack([x, x], axis=1)


def mono(x: np.ndarray) -> np.ndarray:
    if x.ndim == 1:
        return x
    return x.mean(axis=1)


def pan(x: np.ndarray, position: float) -> np.ndarray:
    """Panorama de potencia constante: -1 izquierda, 0 centro, 1 derecha."""
    if x.ndim == 2:
        left = np.cos((position + 1.0) * np.pi / 4.0) * np.sqrt(2.0)
        right = np.sin((position + 1.0) * np.pi / 4.0) * np.sqrt(2.0)
        out = x.copy()
        out[:, 0] *= min(left, 1.0)
        out[:, 1] *= min(right, 1.0)
        return out
    angle = (position + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(angle), x * np.sin(angle)], axis=1) * np.sqrt(2.0) * 0.7071


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x)) + 1e-20))


def peak(x: np.ndarray) -> float:
    return float(np.max(np.abs(x)) + 1e-20)


def normalize_rms(x: np.ndarray, target_db: float) -> np.ndarray:
    return x * (db(target_db) / rms(x))


def normalize_peak(x: np.ndarray, target_db: float) -> np.ndarray:
    return x * (db(target_db) / peak(x))


def soft_limit(x: np.ndarray, ceiling_db: float = -1.0) -> np.ndarray:
    """Limitador suave sin memoria (no rompe la periodicidad de un bucle). Por debajo del 70 % del
    techo la señal no cambia; por encima se curva con tanh hasta el techo."""
    ceiling = db(ceiling_db)
    knee = 0.7 * ceiling
    out = x.copy()
    over = np.abs(out) > knee
    if np.any(over):
        excess = (np.abs(out[over]) - knee) / (ceiling - knee)
        out[over] = np.sign(out[over]) * (knee + (ceiling - knee) * np.tanh(excess))
    return out


# --- Envolventes ---

def adsr(n: int, attack: float, decay: float, sustain: float, release_at: float, release: float,
         curve: float = 1.0) -> np.ndarray:
    """Envolvente ADSR de `n` muestras. `release_at` es el segundo en que se suelta la nota."""
    t = time_axis(n)
    env = np.ones(n)
    if attack > 0:
        a = np.clip(t / attack, 0.0, 1.0)
        env = np.where(t < attack, (0.5 - 0.5 * np.cos(np.pi * a)) ** curve, env)
    if decay > 0:
        d = np.clip((t - attack) / decay, 0.0, 1.0)
        env = np.where(t >= attack, 1.0 - (1.0 - sustain) * d, env)
    r = np.clip((t - release_at) / max(release, 1e-4), 0.0, 1.0)
    level_at_release = env.copy()
    env = np.where(t >= release_at, level_at_release * (1.0 - r) ** 2, env)
    return env


def exp_decay(n: int, tau: float) -> np.ndarray:
    return np.exp(-time_axis(n) / max(tau, 1e-5))


def attack_ramp(n: int, seconds_: float = 0.002) -> np.ndarray:
    t = time_axis(n)
    return np.clip(t / max(seconds_, 1e-5), 0.0, 1.0) ** 0.7


def fade(x: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    out = x.copy()
    n = len(out)
    if fade_in > 0:
        k = min(samples(fade_in), n)
        ramp = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
        out[:k] *= ramp if out.ndim == 1 else ramp[:, None]
    if fade_out > 0:
        k = min(samples(fade_out), n)
        ramp = np.cos(np.linspace(0, np.pi / 2, k)) ** 2
        out[n - k:] *= ramp if out.ndim == 1 else ramp[:, None]
    return out


def smooth_random(n: int, rate_hz: float, rng: np.random.Generator, periodic: bool = True) -> np.ndarray:
    """Curva aleatoria suave entre -1 y 1 que cambia unas `rate_hz` veces por segundo. Si es
    periódica, empieza y acaba igual (sirve para modular un bucle)."""
    noise = rng.standard_normal(n)
    spectrum = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    spectrum *= 1.0 / (1.0 + (freqs / max(rate_hz, 1e-3)) ** 4)
    spectrum[0] = 0.0
    curve = np.fft.irfft(spectrum, n)
    if not periodic:
        curve = curve.copy()
    return curve / (np.max(np.abs(curve)) + 1e-12)


# --- Filtros ---

def _sos(kind: str, cutoff, order: int):
    return signal.butter(order, cutoff, kind, fs=SR, output="sos")


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("lowpass", min(cutoff, SR * 0.49), order), x, axis=0)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("highpass", cutoff, order), x, axis=0)


def bandpass(x: np.ndarray, low: float, high: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("bandpass", [low, min(high, SR * 0.49)], order), x, axis=0)


def resonator(x: np.ndarray, freq: float, q: float) -> np.ndarray:
    """Pico resonante estrecho (filtro de paso de banda de segundo orden RBJ, ganancia 0 dB)."""
    w0 = 2 * np.pi * freq / SR
    alpha = np.sin(w0) / (2 * q)
    b = np.array([alpha, 0.0, -alpha])
    a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
    return signal.lfilter(b / a[0], a / a[0], x, axis=0)


def peaking(x: np.ndarray, freq: float, gain_db: float, q: float = 1.0) -> np.ndarray:
    """Ecualizador paramétrico de una banda (RBJ)."""
    amp = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * freq / SR
    alpha = np.sin(w0) / (2 * q)
    b = np.array([1 + alpha * amp, -2 * np.cos(w0), 1 - alpha * amp])
    a = np.array([1 + alpha / amp, -2 * np.cos(w0), 1 - alpha / amp])
    return signal.lfilter(b / a[0], a / a[0], x, axis=0)


def shelf(x: np.ndarray, freq: float, gain_db: float, high: bool = False) -> np.ndarray:
    """Filtro de estantería (RBJ, pendiente 1). `high` para la de agudos."""
    amp = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * freq / SR
    cos_w, alpha = np.cos(w0), np.sin(w0) / 2 * np.sqrt(2)
    sq = 2 * np.sqrt(amp) * alpha
    if high:
        b = amp * np.array([(amp + 1) + (amp - 1) * cos_w + sq, -2 * ((amp - 1) + (amp + 1) * cos_w),
                            (amp + 1) + (amp - 1) * cos_w - sq])
        a = np.array([(amp + 1) - (amp - 1) * cos_w + sq, 2 * ((amp - 1) - (amp + 1) * cos_w),
                      (amp + 1) - (amp - 1) * cos_w - sq])
    else:
        b = amp * np.array([(amp + 1) - (amp - 1) * cos_w + sq, 2 * ((amp - 1) - (amp + 1) * cos_w),
                            (amp + 1) - (amp - 1) * cos_w - sq])
        a = np.array([(amp + 1) + (amp - 1) * cos_w + sq, -2 * ((amp - 1) + (amp + 1) * cos_w),
                      (amp + 1) + (amp - 1) * cos_w - sq])
    return signal.lfilter(b / a[0], a / a[0], x, axis=0)


def spectral_shape(x: np.ndarray, gain_fn) -> np.ndarray:
    """Filtrado en el dominio de la frecuencia: multiplica el espectro por `gain_fn(freqs)`. Es un
    filtrado circular, así que una señal periódica sigue siéndolo (ideal para bucles de ruido)."""
    n = len(x)
    spectrum = np.fft.rfft(x, axis=0)
    gains = gain_fn(np.fft.rfftfreq(n, 1.0 / SR))
    if spectrum.ndim == 2:
        gains = gains[:, None]
    return np.fft.irfft(spectrum * gains, n, axis=0)


def band_gain(low: float, high: float, slope: float = 2.0):
    """Ganancia de paso de banda suave para `spectral_shape`."""
    def gain(freqs: np.ndarray) -> np.ndarray:
        f = np.maximum(freqs, 1e-3)
        g = 1.0 / (1.0 + (low / f) ** (2 * slope)) if low > 0 else np.ones_like(f)
        if high > 0:
            g = g / (1.0 + (f / high) ** (2 * slope))
        return g
    return gain


# --- Ruido ---

def noise(n: int, rng: np.random.Generator, color: str = "white", channels: int = 1) -> np.ndarray:
    """Ruido periódico (de longitud `n`) blanco, rosa o marrón, normalizado a RMS 1."""
    shape = (n,) if channels == 1 else (n, channels)
    white = rng.standard_normal(shape)
    if color == "white":
        out = white
    else:
        exponent = {"pink": 0.5, "brown": 1.0, "blue": -0.5}[color]
        out = spectral_shape(white, lambda f: 1.0 / np.maximum(f, 20.0) ** exponent)
    return out / rms(out)


# --- Reverberación por convolución con una respuesta sintética ---

_IR_CACHE: dict = {}


def impulse_response(name: str, length: float, t60: float, predelay: float = 0.012,
                     damping: float = 0.45, early: int = 10, room: float = 1.0,
                     brightness: float = 9000.0) -> np.ndarray:
    """Respuesta al impulso estéreo: reflexiones tempranas y una cola de ruido que decae más deprisa
    en los agudos. `damping` acorta la cola aguda (0 = brillante, 1 = muy apagada); `room` escala
    los tiempos de las primeras reflexiones."""
    key = (name, length, t60, predelay, damping, early, room, brightness)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    rng = rng_for("ir-" + name)
    n = samples(length)
    t = time_axis(n)
    ir = np.zeros((n, 2))
    bands = [(0, 300, 1.15), (300, 1200, 1.0), (1200, 4000, 1.0 - 0.45 * damping),
             (4000, brightness, 1.0 - 0.8 * damping)]
    for low, high, factor in bands:
        band = spectral_shape(rng.standard_normal((n, 2)), band_gain(low, high, 1.5))
        band /= rms(band)
        ir += band * np.exp(-6.91 * t / max(t60 * factor, 0.05))[:, None]
    # Las reflexiones tempranas dan la sensación de tamaño de la sala.
    for index in range(early):
        delay = predelay + room * rng.uniform(0.004, 0.045) * (1 + index * 0.25)
        tap = samples(delay)
        if tap < n:
            ir[tap, 0] += rng.uniform(0.3, 1.0) * (0.85 ** index) * rng.choice([-1, 1]) * 6
            ir[min(tap + samples(rng.uniform(0.0, 0.004)), n - 1), 1] += (
                rng.uniform(0.3, 1.0) * (0.85 ** index) * rng.choice([-1, 1]) * 6)
    onset = samples(predelay)
    ir[:onset] = 0.0
    ramp = np.clip((t - predelay) / 0.008, 0.0, 1.0)
    ir *= ramp[:, None]
    ir = lowpass(ir, brightness, 1)
    ir /= np.sqrt(np.sum(np.square(ir), axis=0, keepdims=True)) + 1e-12
    _IR_CACHE[key] = ir
    return ir


def convolve_reverb(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """Convolución estéreo. Devuelve la señal con su cola completa (len(x) + len(ir) - 1)."""
    x2 = stereo(x)
    left = signal.oaconvolve(x2[:, 0], ir[:, 0])
    right = signal.oaconvolve(x2[:, 1], ir[:, 1])
    return np.stack([left, right], axis=1)


def fold(x: np.ndarray, n: int) -> np.ndarray:
    """Pliega en un bucle de `n` muestras todo lo que sobresale del final."""
    out = x[:n].copy() if len(x) >= n else np.concatenate([x, np.zeros((n - len(x),) + x.shape[1:])])
    start = n
    while start < len(x):
        chunk = x[start:start + n]
        out[:len(chunk)] += chunk
        start += n
    return out


def chorus(x: np.ndarray, rng: np.random.Generator, depth_ms: float = 4.0, rate: float = 0.25,
           mix: float = 0.35) -> np.ndarray:
    """Coro estéreo con retardo modulado. Da anchura a pads y cuerdas."""
    x_mono = mono(x)
    n = len(x_mono)
    t = time_axis(n)
    base = samples(0.012)
    out = np.zeros((n, 2))
    for channel in range(2):
        mod = base + samples(depth_ms / 1000) * 0.5 * (1 + np.sin(2 * np.pi * rate * t + rng.uniform(0, 2 * np.pi)))
        idx = np.arange(n) - mod
        delayed = np.interp(idx, np.arange(n), x_mono, left=0.0, right=0.0)
        out[:, channel] = delayed
    return stereo(x) * (1 - mix) + out * mix


# --- Línea de tiempo y mezcla ---

class Bus:
    """Pista estéreo de una mezcla: se le añaden sonidos en posiciones concretas."""

    def __init__(self, length: int):
        self.length = length
        self.data = np.zeros((length, 2), dtype=np.float32)

    def add(self, sound: np.ndarray, start: int, gain: float = 1.0, position: float = 0.0) -> None:
        if start < 0:
            sound = sound[-start:]
            start = 0
        part = pan(sound, position) if sound.ndim == 1 else sound
        end = start + len(part)
        if end > self.length:
            self.data = np.concatenate([self.data, np.zeros((end - self.length, 2), dtype=np.float32)])
            self.length = end
        self.data[start:end] += part * gain


class Session:
    """Mezcla de una pieza: varios buses con su procesamiento y envío a reverberación.

    `loop_samples` es la longitud del bucle; con `loop=True` el resultado se pliega para que se
    repita sin costura. Sin bucle, la pieza conserva su cola (para los fragmentos cortos)."""

    def __init__(self, loop_samples: int, loop: bool = True):
        self.n = loop_samples
        self.loop = loop
        self.buses: dict[str, Bus] = {}
        self.sends: dict[str, float] = {}
        self.fx: dict[str, list] = {}
        self.gains: dict[str, float] = {}

    def bus(self, name: str, send: float = 0.25, fx: list | None = None, gain: float = 1.0) -> Bus:
        if name not in self.buses:
            self.buses[name] = Bus(self.n)
            self.sends[name] = send
            self.fx[name] = fx or []
            self.gains[name] = gain
        return self.buses[name]

    def render(self, ir: np.ndarray | None, wet: float = 1.0, tail: float = 1.0,
               only: list[str] | None = None) -> np.ndarray:
        """Procesa los buses (filtros antes de plegar, para que el bucle sea exacto), los suma con la
        reverberación y pliega el resultado. `only` limita la mezcla a algunos buses (capas)."""
        longest = max((bus.length for bus in self.buses.values()), default=self.n)
        total = longest + samples(tail) + (len(ir) if ir is not None else 0)
        dry = np.zeros((total, 2))
        send = np.zeros((total, 2))
        for name, bus in self.buses.items():
            if only is not None and name not in only:
                continue
            data = np.concatenate([bus.data, np.zeros((total - bus.length, 2), dtype=np.float32)]).astype(np.float64)
            for effect in self.fx[name]:
                data = effect(data)
            data *= self.gains[name]
            dry += data
            send += data * self.sends[name]
        if ir is not None and np.any(send):
            wet_signal = convolve_reverb(send, ir)[:total] * wet
            dry += wet_signal
        if self.loop:
            return fold(dry, self.n)
        # Sin bucle se recorta el silencio final.
        level = np.max(np.abs(dry), axis=1)
        last = np.nonzero(level > 1e-4)[0]
        end = int(last[-1]) + samples(0.05) if len(last) else self.n
        return dry[:max(end, self.n)]


# --- Escritura ---

def write_wav(path: Path, x: np.ndarray, channels: int | None = None) -> None:
    """WAV de 16 bits con tramado triangular. Mono si se pide o si los canales son iguales."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = x
    if channels == 1:
        data = mono(data)
    clipped = np.clip(data, -1.0, 1.0)
    rng = np.random.default_rng(1)
    dither = (rng.random(clipped.shape) - rng.random(clipped.shape)) / 32768.0
    pcm = np.clip(np.round((clipped + dither) * 32767.0), -32768, 32767).astype(np.int16)
    wavfile.write(str(path), SR, pcm)


def encode_ogg(wav_path: Path, ogg_path: Path, quality: float) -> None:
    """Codifica en Ogg Vorbis con FFmpeg (libvorbis, calidad VBR)."""
    ogg_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis",
                    "-q:a", str(quality), "-map_metadata", "-1", str(ogg_path)], check=True)


def decode_ogg(ogg_path: Path) -> np.ndarray:
    """Decodifica un Ogg con FFmpeg para comprobar su duración y su unión."""
    result = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(ogg_path), "-f", "f32le",
                             "-acodec", "pcm_f32le", "-"], check=True, capture_output=True)
    raw = np.frombuffer(result.stdout, dtype=np.float32)
    channels = 2 if "stereo" in _probe_layout(ogg_path) else 1
    return raw.reshape(-1, channels)


def _probe_layout(path: Path) -> str:
    result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channel_layout,channels",
                             "-of", "default=nw=1", str(path)], capture_output=True, text=True)
    return result.stdout
