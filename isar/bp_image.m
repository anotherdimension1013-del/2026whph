function Image_BP = bp_image(S_f_phi,f_axis,phi_axis_deg,epsilon_deg,idx_az,x_axis,y_axis)
%BP_IMAGE  后向投影（BP）成像：在目标坐标系的水平面(z=0)网格上直接成像
%   Image_BP = bp_image(S_f_phi,f_axis,phi_axis_deg,epsilon_deg,idx_az,x_axis,y_axis)
%   S_f_phi      : Nf×Naz 单站散射场（行=频率，列=方位角），FEKO的e^{jwt}约定
%   f_axis       : 1×Nf 频率，Hz（等间隔）
%   phi_axis_deg : 1×Naz 方位角，deg
%   epsilon_deg  : 雷达俯仰角ε，deg（FEKO中θ=90°-ε）
%   idx_az       : 参与成像的方位角序号（一个子孔径或整段宽角）
%   x_axis,y_axis: 目标坐标系（FEKO全局坐标）的成像网格，m
%   Image_BP     : numel(y_axis)×numel(x_axis) 复图像
%
%   原理：雷达方向u=(cosε·cosφ, cosε·sinφ, sinε)，散射点r的回波 E=A·exp(-j4πf·ΔR/c)，ΔR=-u·r。
%   1) 每个方位角的频率维加窗IFFT得到一维距离像（补零8倍，线性插值）；
%   2) 对每个像素计算它在该方位角下的ΔR，从距离像中取值并补偿载频相位exp(+j4πf_1ΔR/c)；
%   3) 对所有方位角加Hann窗累加。BP不需要小转角近似，宽角、有俯仰时同样适用。
c = 3e8;
Nf = numel(f_axis);
delta_f = mean(diff(f_axis));
c_el = cos(epsilon_deg*pi/180);
Naz_use = numel(idx_az);

% 距离压缩：频率维Hann窗 + 补零IFFT
Nfft_r = 2^nextpow2(8*Nf);
Wr = (0.5-0.5*cos(2*pi*(0:Nf-1)/(Nf-1))).';
S1_r = ifft(bsxfun(@times,S_f_phi(:,idx_az),Wr),Nfft_r,1); % 第m个点对应ΔR=m*dR（循环）
dR = c/(2*Nfft_r*delta_f); % 距离像采样间隔，m

% 方位维Hann窗
if Naz_use>1
    Wa = 0.5-0.5*cos(2*pi*(0:Naz_use-1)/(Naz_use-1));
else
    Wa = 1;
end

[X,Y] = meshgrid(x_axis,y_axis);
Image_BP = complex(zeros(size(X)));
for k = 1:Naz_use
    phi = phi_axis_deg(idx_az(k))*pi/180;
    R_pix = -c_el*(X*cos(phi)+Y*sin(phi)); % 像素的ΔR，m
    m = R_pix/dR;
    m0 = floor(m); a = m-m0;
    i0 = mod(m0,Nfft_r)+1; i1 = mod(m0+1,Nfft_r)+1;
    p = S1_r(:,k);
    v = (1-a).*p(i0)+a.*p(i1);
    Image_BP = Image_BP+Wa(k)*v.*exp(1j*4*pi*f_axis(1)*R_pix/c);
end
end
