
include RBA

layout      = Layout.new
layout.dbu  = 0.001
cell        = layout.create_cell("GE_PD_OBAND")

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

def bx(cell, ly, x1, y1, x2, y2)
  cell.shapes(ly).insert(
    Box.new((x1*1000).round, (y1*1000).round, (x2*1000).round, (y2*1000).round)
  )
end

def pg(cell, ly, pts)
  cell.shapes(ly).insert(
    Polygon.new(pts.map { |x, y| Point.new((x*1000).round, (y*1000).round) })
  )
end

wg_W    = 0.5
Ge_L    = 8.0
Ge_W    = 5.0
Pp_ext  = 1.0
D1      = 1.6
D2      = 2.56
taper_L = 40.0
wg_in_L = 10.0
m1_w    = 0.8
m1_via  = 0.6
M2_L    = 195.0
M2_W    = 2.0

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

bx(cell, ly_box, slab_x0-1, slab_y0-1, slab_x1+1, slab_y1+1)

bx(cell, ly_si_slab, slab_x0, slab_y0, slab_x1, slab_y1)

bx(cell, ly_si_ridge, x_tap0-wg_in_L, -wg_W/2, x_tap0, wg_W/2)

pg(cell, ly_si_taper, [
  [x_tap0, -wg_W/2], [x_tap0, wg_W/2],
  [x_tap1,  y_Ge_p], [x_tap1, y_Ge_n]
])

bx(cell, ly_ge, x_Ge0, y_Ge_n, x_Ge1, y_Ge_p)

bx(cell, ly_ppp, x_Ge0, y_Pp_n, x_Ge1, y_Ge_n)
bx(cell, ly_ppp, x_Ge0, y_Ge_p, x_Ge1, y_Pp_p)
bx(cell, ly_ppp, x_Ge1-0.05, y_Ge_n, x_Ge1, y_Ge_p)

bx(cell, ly_npp, x_Ge0+0.3, y_Ge_n+0.3, x_Ge1-0.3, y_Ge_p-0.3)

n_via_n = 5
(0...n_via_n).each do |i|
  xv = x_Ge0 + 0.8 + i * (Ge_L - 1.6) / (n_via_n - 1)
  bx(cell, ly_via, xv-m1_via/2, -m1_via/2, xv+m1_via/2, m1_via/2)
end
[y_Pp_n + 0.3, y_Pp_p - 0.3].each do |yv|
  [x_Ge0+1.0, x_Ge0+4.0, x_Ge1-1.0].each do |xv|
    bx(cell, ly_via, xv-m1_via/2, yv-m1_via/2, xv+m1_via/2, yv+m1_via/2)
  end
end

bx(cell, ly_m1, x_Ge0+0.3, -m1_w/2, x_Ge1-0.3, m1_w/2)

bx(cell, ly_m1, x_Ge0-D1, y_Pp_n,         x_Ge1+D1, y_Pp_n+m1_w)
bx(cell, ly_m1, x_Ge0-D1, y_Pp_p-m1_w,    x_Ge1+D1, y_Pp_p)
bx(cell, ly_m1, x_Ge1+D1-m1_w, y_Pp_n,    x_Ge1+D1, y_Pp_p)

bx(cell, ly_m2, x_Ge0-wg_in_L-M2_L, -M2_W/2, x_Ge0, M2_W/2)

gds_path = File.join(Dir.pwd, "ge_pd_layout_oband.gds")
layout.write(gds_path)
puts "Layout written to #{gds_path}"
puts "  Layers: 1=Si_slab 2=Si_ridge 3=Si_taper 4=Ge 5=P++ 6=N++ 7=Via 8=M1 9=M2 10=BOX"
puts "  Cell:   GE_PD_OBAND"
puts "  Ge:     #{Ge_L} x #{Ge_W} um   Taper: #{taper_L} um   M2 induct: #{M2_L} um"
