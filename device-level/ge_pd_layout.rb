# ge_pd_layout_klayout.rb
# Ge-on-Si PD — KLayout mask layout script
# Yang Shi et al., Photonics Research 12, 1 (2024)
# Run via: KLayout IDE (Macros > Run Script) or  klayout -r ge_pd_layout_klayout.rb
# Output : ge_pd_layout_oband.gds

include RBA

# ── Layout setup ───────────────────────────────────────────────────────────────
layout      = Layout.new
layout.dbu  = 0.001          # 1 nm resolution (0.001 um per dbu)
cell        = layout.create_cell("GE_PD_OBAND")

# ── GDS layer definitions ──────────────────────────────────────────────────────
# Layer  1 : Si slab (90 nm, full extent)
# Layer  2 : Si ridge waveguide (220 nm)
# Layer  3 : Si taper (220 nm)
# Layer  4 : Ge mesa (400 nm: 350 nm i-Ge + 50 nm N++)
# Layer  5 : P++ implant (boron, Si platform and arms, ~1e20 cm^-3)
# Layer  6 : N++ implant (phosphorus, Ge top 50 nm, ~1e19 cm^-3)
# Layer  7 : Via / contact opening in SiO2 cladding
# Layer  8 : Metal 1 — local contacts (Al)
# Layer  9 : Metal 2 — inductance strip (Al, U-shaped PD + inductive match)
# Layer 10 : BOX / SiO2 (reference only)
ly_si_slab  = layout.layer(LayerInfo.new(1,  0))
ly_si_ridge = layout.layer(LayerInfo.new(2,  0))
ly_si_taper = layout.layer(LayerInfo.new(3,  0))
ly_ge       = layout.layer(LayerInfo.new(4,  0))
ly_ppp      = layout.layer(LayerInfo.new(5,  0))
ly_npp      = layout.layer(LayerInfo.new(6,  0))
ly_via      = layout.layer(LayerInfo.new(7,  0))
ly_m1       = layout.layer(LayerInfo.new(8,  0))
ly_m2       = layout.layer(LayerInfo.new(9,  0))
ly_box      = layout.layer(LayerInfo.new(10, 0))

# ── Helper: insert box [µm → dbu] ─────────────────────────────────────────────
def bx(cell, ly, x1, y1, x2, y2)
  cell.shapes(ly).insert(
    Box.new((x1*1000).round, (y1*1000).round, (x2*1000).round, (y2*1000).round)
  )
end

# ── Helper: insert polygon [[x,y], ...] µm ────────────────────────────────────
def pg(cell, ly, pts)
  cell.shapes(ly).insert(
    Polygon.new(pts.map { |x, y| Point.new((x*1000).round, (y*1000).round) })
  )
end

# ── Device parameters (µm) ────────────────────────────────────────────────────
wg_W    = 0.5
Ge_L    = 8.0
Ge_W    = 5.0
Pp_ext  = 1.0        # P++ arm width beyond Ge edge (y-direction)
D1      = 1.6        # gap: Ge x-edge to back U-leg
D2      = 2.56       # gap: Ge y-edge to lateral U-leg
taper_L = 40.0
wg_in_L = 10.0       # shown input waveguide length
m1_w    = 0.8        # Metal-1 trace width
m1_via  = 0.6        # via/contact opening size
M2_L    = 195.0      # Metal-2 inductance strip length (220 pH target)
M2_W    = 2.0        # Metal-2 strip width

# Derived coordinates (origin: taper input)
x_tap0  =  0.0
x_tap1  =  taper_L
x_Ge0   =  taper_L
x_Ge1   =  taper_L + Ge_L
y_Ge_n  = -Ge_W / 2.0
y_Ge_p  =  Ge_W / 2.0
y_Pp_n  = -(Ge_W / 2.0 + Pp_ext)
y_Pp_p  =   Ge_W / 2.0 + Pp_ext
slab_x0 =  x_tap0 - wg_in_L - 1.0
slab_x1 =  x_Ge1 + 3.0
slab_y0 =  y_Pp_n - 2.0
slab_y1 =  y_Pp_p + 2.0

# ── BOX (reference, full extent) ──────────────────────────────────────────────
bx(cell, ly_box, slab_x0-1, slab_y0-1, slab_x1+1, slab_y1+1)

# ── Si slab (layer 1) ─────────────────────────────────────────────────────────
bx(cell, ly_si_slab, slab_x0, slab_y0, slab_x1, slab_y1)

# ── Input Si waveguide ridge (layer 2) ────────────────────────────────────────
bx(cell, ly_si_ridge, x_tap0-wg_in_L, -wg_W/2, x_tap0, wg_W/2)

# ── Si taper 500 nm → 5 µm over 40 µm (layer 3) ──────────────────────────────
pg(cell, ly_si_taper, [
  [x_tap0, -wg_W/2], [x_tap0, wg_W/2],
  [x_tap1,  y_Ge_p], [x_tap1, y_Ge_n]
])

# ── Ge mesa (layer 4) ─────────────────────────────────────────────────────────
bx(cell, ly_ge, x_Ge0, y_Ge_n, x_Ge1, y_Ge_p)

# ── P++ Si implant: left arm, right arm, back closure (layer 5) ───────────────
bx(cell, ly_ppp, x_Ge0, y_Pp_n, x_Ge1, y_Ge_n)   # left arm
bx(cell, ly_ppp, x_Ge0, y_Ge_p, x_Ge1, y_Pp_p)   # right arm
bx(cell, ly_ppp, x_Ge1-0.05, y_Ge_n, x_Ge1, y_Ge_p) # back closure (thin)

# ── N++ Ge top implant (layer 6, same footprint as Ge) ────────────────────────
bx(cell, ly_npp, x_Ge0+0.3, y_Ge_n+0.3, x_Ge1-0.3, y_Ge_p-0.3)

# ── Via openings (layer 7) ─────────────────────────────────────────────────────
# N-contact vias: row along Ge centre (cathode)
n_via_n = 5
(0...n_via_n).each do |i|
  xv = x_Ge0 + 0.8 + i * (Ge_L - 1.6) / (n_via_n - 1)
  bx(cell, ly_via, xv-m1_via/2, -m1_via/2, xv+m1_via/2, m1_via/2)
end
# P-contact vias: one row per arm
[y_Pp_n + 0.3, y_Pp_p - 0.3].each do |yv|
  [x_Ge0+1.0, x_Ge0+4.0, x_Ge1-1.0].each do |xv|
    bx(cell, ly_via, xv-m1_via/2, yv-m1_via/2, xv+m1_via/2, yv+m1_via/2)
  end
end

# ── Metal 1: N-contact strip on Ge (cathode, layer 8) ─────────────────────────
bx(cell, ly_m1, x_Ge0+0.3, -m1_w/2, x_Ge1-0.3, m1_w/2)

# ── Metal 1: U-shaped P-contact (anode, layer 8) ──────────────────────────────
# Left arm
bx(cell, ly_m1, x_Ge0-D1, y_Pp_n,         x_Ge1+D1, y_Pp_n+m1_w)
# Right arm
bx(cell, ly_m1, x_Ge0-D1, y_Pp_p-m1_w,    x_Ge1+D1, y_Pp_p)
# Back connecting leg (closes the U)
bx(cell, ly_m1, x_Ge1+D1-m1_w, y_Pp_n,    x_Ge1+D1, y_Pp_p)

# ── Metal 2: inductance strip for impedance matching (220 pH, layer 9) ─────────
# Runs from N-contact outward (negative x direction)
bx(cell, ly_m2, x_Ge0-wg_in_L-M2_L, -M2_W/2, x_Ge0, M2_W/2)

# ── Write GDS ──────────────────────────────────────────────────────────────────
gds_path = File.join(Dir.pwd, "ge_pd_layout_oband.gds")
layout.write(gds_path)
puts "Layout written to #{gds_path}"
puts "  Layers: 1=Si_slab 2=Si_ridge 3=Si_taper 4=Ge 5=P++ 6=N++ 7=Via 8=M1 9=M2 10=BOX"
puts "  Cell:   GE_PD_OBAND"
puts "  Ge:     #{Ge_L} x #{Ge_W} um   Taper: #{taper_L} um   M2 induct: #{M2_L} um"
