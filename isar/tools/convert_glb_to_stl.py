# GLB -> STL（米）：缩放0.1，绕x轴转+90°（平板由水平变竖直，法向沿y），本体中心移到原点
import sys, trimesh, numpy as np
src, dst = sys.argv[1], sys.argv[2]
m = trimesh.load(src, force='mesh')
m.apply_scale(0.1)
m.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[1,0,0]))
# 本体：原模型中 |x|<=1.2 m 的部分（缩放后），取其包围盒中心作为旋转中心
v = m.vertices; bus = v[np.abs(v[:,0])<=1.2]
c = (bus.min(0)+bus.max(0))/2
m.apply_translation(-c)
m.export(dst)
print('tri', len(m.faces), 'extent', np.round(m.bounds[1]-m.bounds[0],2), 'min', np.round(m.bounds[0],2), 'max', np.round(m.bounds[1],2))
