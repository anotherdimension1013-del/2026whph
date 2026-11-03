function width_xy = peak_width(Image_dB,x_axis,y_axis,pk_xy)
%PEAK_WIDTH  测量一个散射中心沿x、y方向的-3 dB宽度，m
%   从峰值像素出发，向两侧搜索到低于（峰值-3 dB）为止
[~,ix] = min(abs(x_axis-pk_xy(1)));
[~,iy] = min(abs(y_axis-pk_xy(2)));
v0 = Image_dB(iy,ix);
row = Image_dB(iy,:) >= v0-3;
col = Image_dB(:,ix) >= v0-3;
width_xy = [run_length(row,ix)*mean(diff(x_axis)), run_length(col,iy)*mean(diff(y_axis))];
end

function n = run_length(mask,i0)
% 包含位置i0的连续true段长度
i1 = i0; while i1>1 && mask(i1-1); i1 = i1-1; end
i2 = i0; while i2<numel(mask) && mask(i2+1); i2 = i2+1; end
n = i2-i1+1;
end
