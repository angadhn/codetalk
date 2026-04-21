---
title: "Mapping the Spaceship Design Space"
scripts:
  - file: codetalk-1/spaceship-region.py
    label: spaceship-region.py
  - file: codetalk-1/plot-config.yaml
    label: plot-config.yaml
---

## spaceship-region.py

This script builds a scatter plot mapping the design space for crewed spacecraft and
space stations. Starting from real historical data — Salyut, Skylab, Mir, the ISS —
it adds hypothetical designs and carves the resulting landscape into regions, making
a visual case for what an ideal long-duration spacecraft might look like.

### Lines 7-15

Every entry in `SPACE_STATIONS` carries the same shape: total volume, pressurised
volume, habitable volume, crew size, and two boolean flags — `is_real` and
`has_gravity`. The real historical stations anchor the chart. Salyut-1 gave three
cosmonauts just 30 m³ each; the ISS, humanity's largest off-world structure, still
only offers about 55 m³ per person. These numbers set the baseline for everything
that follows.

### Lines 77-78

Buried near the end of the data list is the punchline: the "Ideal Spaceship." At
8,000 m³ total volume for a crew of 70, it offers 90 m³ of habitable space per
person — roughly the floor area of a comfortable studio apartment, replicated in
three dimensions. The `10 Ideal Spaceships` entry right below it tests whether the
concept scales to a fleet.

### Lines 102-107

The x-axis of the entire chart is born on line 107: habitable volume per astronaut.
Not total volume, not pressurised volume — *habitable* volume, the space a crew
member can actually use. This single derived metric is what separates cramped
capsules from genuine long-duration habitats.

### Lines 120-157

Four overlapping rectangles carve the plot into design regions. The green "Space
Stations" box covers small crews and modest per-person volumes — everything humanity
has built so far. The blue "Spaceships" region pushes crew capacity up toward 110.
The purple "Superstructures" envelope covers the mega-habitats. And the orange
"Desirable Spaceship Design Space" box marks the sweet spot: 80–110 m³ per person,
50–110 crew. The Ideal Spaceship lands squarely inside it.

## plot-config.yaml

The Python script reads its rendering parameters from this YAML companion file.
Separating configuration from code lets you tweak the chart's appearance — colours,
axis ranges, marker styles — without touching the plotting logic itself.

### Lines 7-12

The `canvas` block sets the physical chart to 14 by 8 inches at 300 DPI on a dark
navy background (`#1a1a2e`). At these dimensions the output image is large enough
for print but still renders quickly during iterative tweaking.

### Lines 22-31

Four entries under `regions` define the coloured rectangles that partition the design
space. Each maps a name to a fill colour and x/y bounds, matching the rectangles
drawn by `add_region_rect()` in the Python script. The `desirable` region — orange,
80–110 m³ per person, 50–110 crew — is the tightest box: the sweet spot the Ideal
Spaceship was designed to hit.
