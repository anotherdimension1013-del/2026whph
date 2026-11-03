function A_mean = spot_area(Image_dB,x_axis,y_axis,peaks,n_top)
%SPOT_AREA  平均光斑面积（清晰度指标）：最强n_top个散射中心各自-3 dB连通区域面积的平均，m^2
%   干净的点约为一个分辨单元的面积；镜面闪光留下的长条拖影面积大得多。
%   连通区域用3×3膨胀反复扩张求得（不依赖工具箱）。
dx = mean(diff(x_axis)); dy = mean(diff(y_axis));
n_top = min(n_top,size(peaks,1));
A = zeros(n_top,1);
for k = 1:n_top
    [~,ix] = min(abs(x_axis-peaks(k,1))); [~,iy] = min(abs(y_axis-peaks(k,2)));
    w = round(1.5/dx); % 只在峰值周围±1.5 m内搜索
    jx = max(1,ix-w):min(numel(x_axis),ix+w); jy = max(1,iy-w):min(numel(y_axis),iy+w);
    mask = Image_dB(jy,jx) >= Image_dB(iy,ix)-3;
    region = false(size(mask)); region(iy-jy(1)+1,ix-jx(1)+1) = true;
    while true
        grown = mask & conv2(double(region),ones(3),'same')>0;
        if isequal(grown,region); break; end
        region = grown;
    end
    A(k) = sum(region(:))*dx*dy;
end
A_mean = mean(A);
end
