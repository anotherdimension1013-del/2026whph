function Image_dB_q = bin_power(Image_dB,x_axis,y_axis,x_q,y_q)
%BIN_POWER  把细网格图像的功率按块平均到粗网格（用于在同一网格上计算图像熵）
P = 10.^(Image_dB/10);
dx = mean(diff(x_q)); dy = mean(diff(y_q));
[X,Y] = meshgrid(x_axis,y_axis);
ix = round((X-x_q(1))/dx)+1; iy = round((Y-y_q(1))/dy)+1;
ok = ix>=1 & ix<=numel(x_q) & iy>=1 & iy<=numel(y_q);
Pq = accumarray([iy(ok),ix(ok)],P(ok),[numel(y_q),numel(x_q)],@mean,0);
Image_dB_q = 10*log10(Pq/max(Pq(:))+eps);
end
