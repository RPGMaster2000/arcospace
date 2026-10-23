"""Offline Arcospace placeholder palette. Requires Python + NumPy only; never exported/runtime.

Deterministic synthesis, 48 kHz mono signed PCM16. No samples or external services.
Run from any directory: python3 tools/generate_sfx.py. --check validates committed files.
"""
import argparse
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

RATE = 48000
OUT = Path(__file__).resolve().parents[1] / 'assets/sound/sfx'
# Event: duration, design family, start/end pitch. Variants are deliberately subtle.
PALETTE = {
    'card_select': (.095, 'soft', 650, 940),
    'card_play': (.22, 'deploy', 210, 620),
    'card_discard': (.28, 'siphon', 1350, 210),
    'materials_gain': (.28, 'metal', 380, 550),
    'energy_gain': (.28, 'electric', 680, 1420),
    'crew_gain': (.26, 'warm', 440, 660),
    'resource_drain': (.33, 'siphon', 950, 120),
    'production_gain': (.40, 'startup', 120, 520),
    'production_loss': (.42, 'shutdown', 480, 65),
    'shield_hit': (.30, 'shield', 190, 115),
    'shield_break': (.53, 'fracture', 1200, 100),
    'hull_hit': (.38, 'impact', 110, 42),
    'hull_repair': (.52, 'repair', 190, 620),
    'ship_destroyed': (1.35, 'destroy', 95, 30),
    'systems_failure_warning': (.72, 'alarm', 680, 520),
    'systems_failure_defeat': (1.05, 'critical', 360, 42),
    'emp_charge': (.42, 'charge', 140, 1400),
    'emp_ready': (.65, 'chime', 620, 1240),
    'emp_fire': (.85, 'discharge', 1450, 65),
    'ship_departure': (1.2, 'engine', 65, 310),
    'ui_select': (.065, 'click', 1150, 850),
    'ui_confirm': (.17, 'soft', 520, 1040),
    'upgrade_acquired': (.70, 'flourish', 440, 880),
    'result_reveal': (.40, 'chime', 440, 660),
}
VARIANTS = {'card_play', 'shield_hit', 'hull_hit', 'ui_select',
            'materials_gain', 'energy_gain', 'crew_gain'}


def synth(event, variant):
    duration, family, low, high = PALETTE[event]
    seed = int.from_bytes(hashlib.sha256(f'{event}:{variant}'.encode()).digest()[:8], 'little')
    rng = np.random.default_rng(seed)
    t = np.arange(round(duration * RATE)) / RATE
    p = t / duration
    detune = 1 + (variant - 1) * .018
    f = (low + (high - low) * p) * detune
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase)
    noise = rng.normal(0, 1, len(t))
    # Cheap offline FIR low-pass; no SciPy dependency.
    low_noise = np.convolve(noise, np.ones(45) / 45, mode='same') * 3
    air = noise - np.convolve(noise, np.ones(9) / 9, mode='same')
    x = tone * .65 + np.sin(phase * 2) * .12
    if family in ('soft', 'warm', 'click'):
        x = tone * np.exp(-p * 4) + .15 * np.sin(phase * (1.5 if family == 'warm' else 2))
        if family == 'click': x += .12 * air * np.exp(-p * 24)
    elif family == 'metal':
        x = sum(np.sin(phase * r) * a * np.exp(-p * d)
                for r, a, d in [(1, .6, 4), (2.76, .28, 8), (4.13, .16, 12)])
    elif family in ('electric', 'charge', 'deploy', 'startup'):
        x = .65 * tone + .20 * np.sin(phase * 2.01) + .14 * air
        x *= (.3 + .7 * p) if family == 'charge' else np.exp(-p * 2.8)
        if family == 'startup': x *= .7 + .3 * np.sin(2 * np.pi * 34 * t)
    elif family in ('siphon', 'shutdown', 'critical'):
        x = .7 * tone + .25 * low_noise + .13 * np.sin(phase * .5)
        x *= (1 - p) * (.8 + .2 * np.sin(2 * np.pi * (18 * t + 20 * t*t)))
    elif family == 'shield':
        x = (.7 * tone + .25 * np.sin(phase * 1.49)) * np.exp(-p * 4)
        x += .24 * air * np.exp(-p * 35)
    elif family == 'fracture':
        x = air * .22 + .30 * np.sin(phase * (1 + .15 * np.sin(2 * np.pi * 41 * t)))
        x += .4 * low_noise
        x *= np.exp(-p * 4)
    elif family in ('impact', 'destroy', 'discharge'):
        x = .8 * tone * np.exp(-p * 5) + .65 * low_noise + .13 * air
        x = np.tanh(x * 1.8) * np.exp(-p * 4)
        if family == 'destroy':
            for when in [.10, .24, .43]:
                pulse = np.maximum(t - when, 0)
                x += .28 * low_noise * np.exp(-pulse * 12) * (t >= when)
        if family == 'discharge': x += .35 * air * np.exp(-p * 12)
    elif family == 'repair':
        x = (.6 * tone + .23 * np.sin(phase * 1.5)) * np.sin(np.pi * p)
        x += .12 * low_noise * (1 - p)
    elif family in ('chime', 'flourish'):
        x = np.zeros_like(t)
        ratios = [1, 1.25, 1.5, 2] if family == 'flourish' else [1, 1.5, 2]
        for i, ratio in enumerate(ratios):
            local = t - i * duration * .16
            x += .45 * np.sin(2 * np.pi * low * ratio * local) * np.exp(-np.maximum(local, 0) * 9) * (local >= 0)
    elif family == 'alarm':
        # Fixed recognizable double pulse; never pitch-randomized at runtime.
        pulse = np.exp(-np.mod(t, .34) * 14)
        x = (.7 * np.sin(2 * np.pi * 680 * t) + .22 * np.sin(2 * np.pi * 1020 * t)) * pulse
    elif family == 'engine':
        x = (.6 * tone + .22 * np.sin(phase * .5) + .45 * low_noise) * np.sin(np.pi * p) ** .7
    # One quiet reflection, then tapered endpoints. No long silent tail.
    delay = round(.043 * RATE)
    if len(x) > delay and duration > .25:
        x[delay:] += .10 * x[:-delay].copy()
    fade_in = min(round(.004 * RATE), len(x) // 4)
    fade_out = min(round(.025 * RATE), len(x) // 4)
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    x[-fade_out:] *= np.linspace(1, 0, fade_out)
    # RMS target -22 dBFS, peak ceiling -7 dBFS; per-event catalog trims follow.
    rms = np.sqrt(np.mean(x*x))
    x *= min(10 ** (-22 / 20) / max(rms, 1e-9), 10 ** (-7 / 20) / max(np.max(np.abs(x)), 1e-9))
    return np.rint(x * 32767).astype('<i2')


def inspect(path):
    with wave.open(str(path), 'rb') as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, RATE), path
        x = np.frombuffer(wav.readframes(wav.getnframes()), dtype='<i2') / 32768
    assert len(x) > 0 and np.max(np.abs(x)) < .45, path
    assert abs(x[0]) < .001 and abs(x[-1]) < .001, path
    assert np.sqrt(np.mean(x*x)) > .025, path
    return {'file': path.name, 'seconds': round(len(x) / RATE, 3), 'bytes': path.stat().st_size,
            'peak_dbfs': round(20*np.log10(np.max(np.abs(x))), 2),
            'rms_dbfs': round(20*np.log10(np.sqrt(np.mean(x*x))), 2),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    report = []
    for event in PALETTE:
        for variant in range(1, 4 if event in VARIANTS else 2):
            path = OUT / f'{event}_{variant:02}.wav'
            if not args.check:
                with wave.open(str(path), 'wb') as wav:
                    wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
                    wav.writeframes(synth(event, variant).tobytes())
            report.append(inspect(path))
    manifest = {'events': len(PALETTE), 'files': len(report), 'sample_rate': RATE,
                'format': 'mono PCM16 WAV', 'total_bytes': sum(r['bytes'] for r in report), 'assets': report}
    if args.check:
        assert json.loads((OUT / 'manifest.json').read_text()) == manifest, 'Manifest differs; regenerate intentionally.'
    else:
        (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f"Validated {manifest['events']} events, {len(report)} files, {manifest['total_bytes']} bytes")


if __name__ == '__main__': main()
