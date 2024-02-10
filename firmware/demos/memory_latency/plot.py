import matplotlib.pyplot as plt
import numpy as np

import matplotlib as mpl
mpl.rcParams['figure.dpi'] = 100

datasets = [
    dict(path="results.csv", label="load 32-bit cached", color="C0"),
]

f, ax = plt.subplots(figsize=(10, 6.5))

line_opts = dict(ls="--", c="k")
text_opts = dict(weight="bold")

h_lines = [3, 18, 149]

for y in h_lines:
    ax.axhline(y, **line_opts)

for i, d in enumerate(datasets):
    data = np.loadtxt(d["path"], delimiter=",", skiprows=1)

    ax.plot(data[:,0], data[:,1],
            lw=2,
            zorder=100 - i,
            label=d["label"],
            color=d["color"],
            marker=".")

ax.axhline(18.72, lw=2, label="load 16-bit uncached", color="C1")
ax.axhline(18.72, lw=2, label="load 32-bit uncached", color="C2")
ax.axhline(7.70, lw=2, label="store 16-bit", color="C3")
ax.axhline(14.24, lw=2, label="store 32-bit", color="C4")

ax.set_xlim(2, 2**15)
ax.set_xlabel("Test size")
ax.set_xscale('log')
ax.set_xticks([2**n for n in range(1, 16)], [f"{2**n}k" if n < 10 else f"{2**(n-10)}M" for n in range(1, 16)])
ax.set_xticks([], minor=True)

ax.set_ylabel("Average latency [cycles]")
ax.set_yscale('log')
ax.set_yticks([2**n for n in range(1, 9)], [str(2**n) for n in range(1, 9)])
ax.set_yticks(h_lines, [str(y) for y in h_lines], minor=True)

ax.grid(which="major")
ax.legend()
ax.set_title("Memory access latency")
f.savefig("../../../doc/memory-latency.png", bbox_inches="tight")
