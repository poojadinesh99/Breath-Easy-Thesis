import librosa
import librosa.display
import matplotlib.pyplot as plt
import numpy as np

# ---------- Load audio ----------
y, sr = librosa.load("sample_cough.wav", sr=16000)

# ---------- Preprocessing ----------
# Denoise-style trim
y_trim, _ = librosa.effects.trim(y, top_db=20)

# Normalize safely
y_norm = y_trim / (np.max(np.abs(y_trim)) + 1e-8)

# Pad both signals to equal length for plotting
max_len = max(len(y), len(y_norm))
y_padded = np.pad(y, (0, max_len - len(y)))
y_norm_padded = np.pad(y_norm, (0, max_len - len(y_norm)))

# ---------- Time axis ----------
t = np.linspace(0, len(y_padded)/sr, len(y_padded))

# ---------- Plot ----------
plt.figure(figsize=(14, 6))

plt.subplot(2,1,1)
plt.plot(t, y_padded, linewidth=1)
plt.title("Before Preprocessing", fontsize=16)
plt.ylabel("Amplitude")
plt.xlim(0, t[-1])

plt.subplot(2,1,2)
plt.plot(t, y_norm_padded, linewidth=1)
plt.title("After Preprocessing (Trimmed + Normalized)", fontsize=16)
plt.xlabel("Time (s)")
plt.ylabel("Amplitude")
plt.xlim(0, t[-1])

plt.tight_layout()
plt.savefig("fig_preprocessing_clean.png", dpi=400, bbox_inches="tight")
print("Saved: fig_preprocessing_clean.png")
 