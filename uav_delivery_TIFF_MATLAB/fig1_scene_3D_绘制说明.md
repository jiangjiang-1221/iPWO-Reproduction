# fig1_scene -- 3D delivery scenario figure · full redraw notes

> target file: figs/fig1_scene.tif (3795×2640 px @330 DPI, canvas 11.5×8 inch, 1150×800 px)
> data source: data/scene_and_solution.json (all coordinates exported from it, nothing dropped)
> font standard (2026-09-05 update): Times New Roman; title/axis/legend 28pt; depot label 12pt; launch-pad label 12pt (radial extrapolation 10 m, staggered heights, no scene occlusion); no top-view subplot

## 1. Canvas and global settings

| item | value |
|---|---|
| figure window | white background, 1150×800 px (position [150 150 1150 800]) |
| print | PaperSize 11.5×8 in, -dtiffn -r330 -> 3795×2640 px |
| font | Times New Roman (global) |
| font size | title 28pt bold; 3D axis ticks/labels 28pt; legend 28pt; depot text 12pt bold; P label 12pt bold |

## 2. 3D main coordinate system

- x/y/z axis range: **[0,100] / [0,100] / [0,60]**, axis labels x (m), y (m), z (m)
- DataAspectRatio = **[1, 1, 0.6]** (z squeezed by 0.6)
- view: **view(-60°, 25°)** (azimuth -60°, elevation 25°); grid on, box on

## 3. UAV color map (uniform color key for whole figure)

| UAV | RGB (0-1) | HEX | color |
|---|---|---|---|
| UAV-1 | [0.122 0.467 0.706] | #1F77B4 | blue |
| UAV-2 | [1.000 0.498 0.055] | #FF7F0E | orange |
| UAV-3 | [0.173 0.627 0.173] | #2CA02C | green |
| UAV-4 | [0.839 0.153 0.157] | #D62728 | red |
| UAV-5 | [0.580 0.400 0.750] | #9466BF | purple |
| UAV-6 | [0.200 0.600 0.700] | #3399B2 | cyan |

## 4. Depot (Warehouse)

- center **(50, 50, 0)**; cube base 10×10 (x: 45→55, y: 45→55), **height 12** (z: 0→12)
- color purple-blue [0.42 0.36 0.80], FaceAlpha 0.9, white edges (LineWidth 1)
- text label Warehouse: at (50, 50, 15) (above cube top, avoiding overlap with launch-pad labels), horizontally centered, black [0.1 0.1 0.1], 12pt bold, white background (opacity 0.7)

## 5. Launch pads P1-P6 (ground square platforms)

- size: side 7 m (center ±3.5), thickness 0.5 m (z: 0→0.5); color = corresponding UAV color, FaceAlpha 0.9, black edges (LineWidth 1.2)
- text labels P1...P6: extrapolated 10 m outward from each pad center along the radial direction away from the depot, staggered heights (P1 z=20, P4 z=15, P6 z=6, others z=10), horizontally centered, 12pt bold, color = corresponding UAV color (no scene occlusion)

| launch pad | x (m) | y (m) | z (m) |
|---|---|---|---|
| P1 | 59.90 | 59.90 | 0 |
| P2 | 46.38 | 63.52 | 0 |
| P3 | 36.48 | 53.62 | 0 |
| P4 | 40.10 | 40.10 | 0 |
| P5 | 53.62 | 36.48 | 0 |
| P6 | 63.52 | 46.38 | 0 |

## 6. Cruise points and UAV model

- each UAV cruise point = 35 m above its launch pad (cruise altitude CRUISE=35)
- vertical climb lines removed as requested (2026-09-05: the scenario figure contains no delivery routes / climb-line elements)
- draw a quadrotor UAV solid model at each cruise point (arm length 3.2 m):
  - body: solid dot (MarkerSize 160, black outline 1.4)
  - 4 arms: from body center toward diagonal directions (±45°), length 3.2 m, LineWidth 2.6
  - 4 rotor rings: radius 1.76 m (arm length × 0.55), 26-gon, LineWidth 1.8
  - 4 rotor hubs: small solid dots (MarkerSize 50)

| UAV | cruise point (x, y, z) |
|---|---|
| UAV-1 | (59.90, 59.90, 35) |
| UAV-2 | (46.38, 63.52, 35) |
| UAV-3 | (36.48, 53.62, 35) |
| UAV-4 | (40.10, 40.10, 35) |
| UAV-5 | (53.62, 36.48, 35) |
| UAV-6 | (63.52, 46.38, 35) |

## 7. Obstacles (gray, semi-transparent, no entry)

- cylinder: gray [0.5 0.5 0.5], FaceAlpha 0.35, no outline (40-sided subdivision)
- sphere: same color and opacity (24-face subdivision)

| type | params [x, y, radius r, height h / z-center] | geometric range |
|---|---|---|
| cylinder | [30.00, 30.00, r=7, h=40] | x∈[23.00,37.00], y∈[23.00,37.00], z∈[0,40] |
| cylinder | [70.00, 70.00, r=7, h=40] | x∈[63.00,77.00], y∈[63.00,77.00], z∈[0,40] |
| cylinder | [50.00, 20.00, r=6, h=35] | x∈[44.00,56.00], y∈[14.00,26.00], z∈[0,35] |
| sphere | [35.00, 60.00, z-center=25, r=7] | sphere center (35.00, 60.00, 25), radius 7 |
| sphere | [65.00, 35.00, z-center=25, r=7] | sphere center (65.00, 35.00, 25), radius 7 |

## 8. 30 customers (ground spheres, color = assigned UAV)

- sphere center = customer coordinate (x, y, 0); radius = 0.8 + 1.4×(package weight − 0.5)/2.5 (weight 0.5-3.0 kg -> radius 0.8-2.2 m)
- color = the UAV color assigned to that customer, FaceAlpha 0.95, no outline; no per-point text labels (avoids 30-label overlap; assignment shown by color encoding)

| # | x (m) | y (m) | weight (kg) | radius (m) | assign | color |
|---|---|---|---|---|---|---|
| C1 | 38.71 | 59.68 | 1.472 | 1.344 | UAV-3 | green #2CA02C |
| C2 | 90.56 | 20.35 | 1.178 | 1.180 | UAV-2 | orange #FF7F0E |
| C3 | 70.88 | 10.85 | 2.572 | 1.960 | UAV-2 | orange #FF7F0E |
| C4 | 58.88 | 90.40 | 1.392 | 1.299 | UAV-1 | blue #1F77B4 |
| C5 | 19.04 | 91.91 | 1.202 | 1.193 | UAV-1 | blue #1F77B4 |
| C6 | 19.04 | 77.76 | 1.857 | 1.560 | UAV-2 | orange #FF7F0E |
| C7 | 10.23 | 32.42 | 0.852 | 0.997 | UAV-6 | cyan #3399B2 |
| C8 | 82.96 | 13.79 | 2.505 | 1.923 | UAV-5 | purple #9466BF |
| C9 | 59.10 | 66.58 | 0.686 | 0.904 | UAV-5 | purple #9466BF |
| C10 | 68.73 | 44.61 | 2.967 | 2.182 | UAV-4 | red #D62728 |
| C11 | 6.85 | 15.98 | 2.431 | 1.881 | UAV-3 | green #2CA02C |
| C12 | 92.29 | 49.57 | 0.997 | 1.078 | UAV-4 | red #D62728 |
| C13 | 79.92 | 8.09 | 0.514 | 0.808 | UAV-3 | green #2CA02C |
| C14 | 24.11 | 86.84 | 2.539 | 1.942 | UAV-1 | blue #1F77B4 |
| C15 | 21.36 | 28.29 | 2.267 | 1.790 | UAV-6 | cyan #3399B2 |
| C16 | 21.51 | 64.63 | 2.323 | 1.821 | UAV-4 | red #D62728 |
| C17 | 32.38 | 33.05 | 2.428 | 1.880 | UAV-5 | purple #9466BF |
| C18 | 52.23 | 51.81 | 0.685 | 0.904 | UAV-6 | cyan #3399B2 |
| C19 | 43.88 | 54.20 | 1.396 | 1.302 | UAV-5 | purple #9466BF |
| C20 | 31.21 | 21.64 | 0.790 | 0.962 | UAV-6 | cyan #3399B2 |
| C21 | 60.07 | 92.26 | 2.658 | 2.008 | UAV-1 | blue #1F77B4 |
| C22 | 17.55 | 74.76 | 2.058 | 1.673 | UAV-4 | red #D62728 |
| C23 | 31.29 | 89.55 | 1.327 | 1.263 | UAV-6 | cyan #3399B2 |
| C24 | 37.97 | 85.53 | 0.659 | 0.889 | UAV-6 | cyan #3399B2 |
| C25 | 46.05 | 58.81 | 1.277 | 1.235 | UAV-3 | green #2CA02C |
| C26 | 75.67 | 87.97 | 1.313 | 1.255 | UAV-4 | red #D62728 |
| C27 | 22.97 | 12.96 | 2.324 | 1.821 | UAV-2 | orange #FF7F0E |
| C28 | 51.28 | 22.64 | 2.094 | 1.693 | UAV-1 | blue #1F77B4 |
| C29 | 58.32 | 9.07 | 2.718 | 2.042 | UAV-3 | green #2CA02C |
| C30 | 9.18 | 34.28 | 1.681 | 1.461 | UAV-2 | orange #FF7F0E |

## 9. Legend (outside 3D axis eastoutside, 28pt, icon MarkerSize 300)

| legend item | marker |
|---|---|
| Warehouse | purple-blue square (same as depot color) |
| Obstacle | gray dot |
| Customer | hollow dot with white fill and black edge (one legend entry for all customers; customer sphere color = assigned UAV) |
| UAV-1 | blue dot |
| UAV-2 | orange dot |
| UAV-3 | green dot |
| UAV-4 | red dot |
| UAV-5 | purple dot |
| UAV-6 | cyan dot |
| Launch pad | gray square |

## 10. Title

`3D Delivery Scenario (Nu=6 UAVs, Nc=30 customers, Q=10 kg)` -- 28pt bold, centered

## 11. Top-view inset subplot (removed as requested)

- since 2026-09-05 the bottom-right 2D top-view subplot is deleted, keeping the 3D axis fully visible and unoccluded;
- customer-UAV assignment is encoded by customer sphere color (see color table in section 8).

## 12. Appendix: best-solution route data (used by fig2_paths, for custom-draw extension)

- makespan = **196.82 s**, total distance L_total = **1576.21 m**
- penalty term: cap=0, obs=10.580, conf=0, kin=0.625

- **UAV-1** service sequence: C5 → C22 → C6 → C15 → C29
- **UAV-2** service sequence: C7 → C31 → C28 → C4 → C3
- **UAV-3** service sequence: C2 → C26 → C14 → C30 → C12
- **UAV-4** service sequence: C17 → C23 → C27 → C13 → C11
- **UAV-5** service sequence: C9 → C10 → C20 → C18
- **UAV-6** service sequence: C19 → C25 → C24 → C8 → C16 → C21

Waypoints of each route (first climb vertically to z=35, fly at cruise altitude, then descend vertically):


**UAV-1 waypoint list**:

| idx | x | y | z |
|---|---|---|---|
| 1 | 59.90 | 59.90 | 0.00 |
| 2 | 59.90 | 59.90 | 35.00 |
| 3 | 58.88 | 90.40 | 35.00 |
| 4 | 60.07 | 92.26 | 35.00 |
| 5 | 19.04 | 91.91 | 35.00 |
| 6 | 24.11 | 86.84 | 35.00 |
| 7 | 51.28 | 22.64 | 35.00 |
| 8 | 59.90 | 59.90 | 35.00 |
| 9 | 59.90 | 59.90 | 0.00 |

**UAV-2 waypoint list**:

| idx | x | y | z |
|---|---|---|---|
| 1 | 46.38 | 63.52 | 0.00 |
| 2 | 46.38 | 63.52 | 35.00 |
| 3 | 19.04 | 77.76 | 35.00 |
| 4 | 9.18 | 34.28 | 35.00 |
| 5 | 22.97 | 12.96 | 35.00 |
| 6 | 70.88 | 10.85 | 35.00 |
| 7 | 90.56 | 20.35 | 35.00 |
| 8 | 46.38 | 63.52 | 35.00 |
| 9 | 46.38 | 63.52 | 0.00 |

**UAV-3 waypoint list**:

| idx | x | y | z |
|---|---|---|---|
| 1 | 36.48 | 53.62 | 0.00 |
| 2 | 36.48 | 53.62 | 35.00 |
| 3 | 38.71 | 59.68 | 35.00 |
| 4 | 46.05 | 58.81 | 35.00 |
| 5 | 79.92 | 8.09 | 35.00 |
| 6 | 58.32 | 9.07 | 35.00 |
| 7 | 6.85 | 15.98 | 35.00 |
| 8 | 36.48 | 53.62 | 35.00 |
| 9 | 36.48 | 53.62 | 0.00 |

**UAV-4 waypoint list**:

| idx | x | y | z |
|---|---|---|---|
| 1 | 40.10 | 40.10 | 0.00 |
| 2 | 40.10 | 40.10 | 35.00 |
| 3 | 21.51 | 64.63 | 35.00 |
| 4 | 17.55 | 74.76 | 35.00 |
| 5 | 75.67 | 87.97 | 35.00 |
| 6 | 92.29 | 49.57 | 35.00 |
| 7 | 68.73 | 44.61 | 35.00 |
| 8 | 40.10 | 40.10 | 35.00 |
| 9 | 40.10 | 40.10 | 0.00 |

**UAV-5 waypoint list**:

| idx | x | y | z |
|---|---|---|---|
| 1 | 53.62 | 36.48 | 0.00 |
| 2 | 53.62 | 36.48 | 35.00 |
| 3 | 82.96 | 13.79 | 35.00 |
| 4 | 59.10 | 66.58 | 35.00 |
| 5 | 43.88 | 54.20 | 35.00 |
| 6 | 32.38 | 33.05 | 35.00 |
| 7 | 53.62 | 36.48 | 35.00 |
| 8 | 53.62 | 36.48 | 0.00 |

**UAV-6 waypoint list**:

| idx | x | y | z |
|---|---|---|---|
| 1 | 63.52 | 46.38 | 0.00 |
| 2 | 63.52 | 46.38 | 35.00 |
| 3 | 52.23 | 51.81 | 35.00 |
| 4 | 37.97 | 85.53 | 35.00 |
| 5 | 31.29 | 89.55 | 35.00 |
| 6 | 10.23 | 32.42 | 35.00 |
| 7 | 21.36 | 28.29 | 35.00 |
| 8 | 31.21 | 21.64 | 35.00 |
| 9 | 63.52 | 46.38 | 35.00 |
| 10 | 63.52 | 46.38 | 0.00 |

---

# Appendix: fig2_paths -- 3D route figure · redraw notes (also a 3D figure)

> canvas / view / axes / base objects are **identical** to fig1_scene (sections 1-7, 9-11 reused directly),
> with route and delivery elements added and customer spheres removed. Title changed to two lines 28pt bold:
> `Optimal Task Assignment and 3D Paths` + `(IPWO, Makespan=196.8s)`

## A1. Difference overview vs fig1_scene

| element | fig1_scene | fig2_paths |
|---|---|---|
| customer representation | large sphere (radius ∝ weight, FaceAlpha 0.95) | **small solid dot** (MarkerSize 60, black outline) |
| customer vertical line | none | **gray dotted line** (see A3) |
| route | none | **6 colored polylines** (see A2) |
| depot / launch pad / UAV model / obstacle / legend | yes | identical |
| top-view inset subplot | yes | none |

## A2. 6 routes (colored polylines)

- each route = the 3D polyline connecting that UAV's waypoint table (section 12) in order, color = corresponding UAV color, LineWidth 2.6
- polyline start/end = launch pad (z=0), first climb vertically to z=35, fly horizontally, then descend vertically

## A3. Customer delivery points and hover vertical lines (30 groups)

- delivery drop point: solid small dot at customer coordinate (x, y, 0) (MarkerSize 60), fill color = assigned UAV color, black outline
- hover vertical line: drawn vertically upward from customer ground point (x, y, 0) to cruise altitude (x, y, 35):
  gray [0.30 0.30 0.30] dotted line (':'), LineWidth 1.0 -- indicates UAV hovering at cruise altitude for delivery

## A4. Per-customer vertical-line coordinates (x=y=customer coordinate, z from 0 to 35)

| # | x (m) | y (m) | vertical-line z range |
|---|---|---|---|
| C1 | 38.71 | 59.68 | 0 → 35 |
| C2 | 90.56 | 20.35 | 0 → 35 |
| C3 | 70.88 | 10.85 | 0 → 35 |
| C4 | 58.88 | 90.40 | 0 → 35 |
| C5 | 19.04 | 91.91 | 0 → 35 |
| C6 | 19.04 | 77.76 | 0 → 35 |
| C7 | 10.23 | 32.42 | 0 → 35 |
| C8 | 82.96 | 13.79 | 0 → 35 |
| C9 | 59.10 | 66.58 | 0 → 35 |
| C10 | 68.73 | 44.61 | 0 → 35 |
| C11 | 6.85 | 15.98 | 0 → 35 |
| C12 | 92.29 | 49.57 | 0 → 35 |
| C13 | 79.92 | 8.09 | 0 → 35 |
| C14 | 24.11 | 86.84 | 0 → 35 |
| C15 | 21.36 | 28.29 | 0 → 35 |
| C16 | 21.51 | 64.63 | 0 → 35 |
| C17 | 32.38 | 33.05 | 0 → 35 |
| C18 | 52.23 | 51.81 | 0 → 35 |
| C19 | 43.88 | 54.20 | 0 → 35 |
| C20 | 31.21 | 21.64 | 0 → 35 |
| C21 | 60.07 | 92.26 | 0 → 35 |
| C22 | 17.55 | 74.76 | 0 → 35 |
| C23 | 31.29 | 89.55 | 0 → 35 |
| C24 | 37.97 | 85.53 | 0 → 35 |
| C25 | 46.05 | 58.81 | 0 → 35 |
| C26 | 75.67 | 87.97 | 0 → 35 |
| C27 | 22.97 | 12.96 | 0 → 35 |
| C28 | 51.28 | 22.64 | 0 → 35 |
| C29 | 58.32 | 9.07 | 0 → 35 |
| C30 | 9.18 | 34.28 | 0 → 35 |
