import wave
import math
import struct
import os

sample_rate = 44100

def generate_tone(file_path, frequency_func, duration, amplitude_func=None):
    if amplitude_func is None:
        amplitude_func = lambda t: 16000 * (1 - t/duration) # simple fade out
        
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with wave.open(file_path, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        num_samples = int(sample_rate * duration)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            freq = frequency_func(t)
            value = int(amplitude_func(t) * math.sin(2.0 * math.pi * freq * t))
            # clamp to max short
            value = max(-32768, min(32767, value))
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

# 1. place.wav: A short click/thud
generate_tone('assets/audio/place.wav', lambda t: 150, 0.08, lambda t: 8000 * (1 - t/0.08))

# 2. break.wav: Descending tone
generate_tone('assets/audio/break.wav', lambda t: 300 - 300 * t, 0.5, lambda t: 14000 * (1 - t/0.5))

# 3. fix.wav: Ascending chime
generate_tone('assets/audio/fix.wav', lambda t: 400 + 800 * t, 0.5, lambda t: 12000 * (1 - t/0.5))

# 4. reveal.wav: Discovery sound 
generate_tone('assets/audio/reveal.wav', lambda t: 500 if t < 0.2 else 900, 0.6, lambda t: 10000 * (1 - t/0.6))

# 5. round_end.wav: Fanfare
generate_tone('assets/audio/round_end.wav', lambda t: 440 * (1 + int(t * 3)), 1.5, lambda t: 12000 * (1 - t/1.5))

print("Sounds generated successfully!")
