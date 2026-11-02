# 由STL生成xy平面投影轮廓（俯视图），供MATLAB叠加到ISAR图像
# 输出：每行 "x y"，不同多边形之间用 "NaN NaN" 分隔，MATLAB可直接 plot(xy(:,1),xy(:,2))
# 用法：python3 make_outline.py model.stl outline.txt
import sys, numpy as np, trimesh
from shapely.geometry import Polygon
from shapely.ops import unary_union
m = trimesh.load(sys.argv[1], force='mesh')
polys = []
for t in m.vertices[m.faces][:, :, :2]:
    p = Polygon(t)
    if p.area > 1e-8:
        polys.append(p.buffer(1e-4))
u = unary_union(polys).simplify(0.01)
geoms = getattr(u, 'geoms', [u])
rows = []
for g in geoms:
    for ring in [g.exterior, *g.interiors]:
        if ring.length < 0.2:   # 去掉很小的碎片
            continue
        rows += list(ring.coords) + [(np.nan, np.nan)]
np.savetxt(sys.argv[2], np.array(rows), fmt='%.4f')
r = np.hypot(m.vertices[:, 0], m.vertices[:, 1]).max()
print(f'多边形数={len(geoms)}，轮廓点数={len(rows)}，xy平面最大半径={r:.3f} m，转动直径L={2*r:.3f} m')
