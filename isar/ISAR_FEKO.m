%{
%      基于FEKO单站散射数据的ISAR转台成像：RD与PFA
%      流程：读取E(f,phi) -> 频率维加窗IFFT（距离像） -> 方位维加窗FFT（RD图像）
%            -> 可选PFA（极坐标->直角坐标插值后二维FFT） -> 与模型轮廓叠加
%      矩阵约定：与ISAR_RD.m相同，距离向（频率）为行，方位/横向为列。
%      坐标约定：与ISAR_RD.m相同，x为横向（向右为正），y为距离向（远离雷达为正）。
%      FEKO中 phi=270°+theta：phi增大 <=> 目标绕z轴顺时针转动（ISAR_RD.m的约定）。
%      FEKO采用e^{jwt}约定，单站场 E=A*exp(-j*4*pi*f*(R-R0)/c)，与ISAR_RD.m的
%      Phase_a同号，因此无需取共轭；若误取共轭，图像会绕原点翻转180°（见图5）。
%}
clc; clear; close all;

%% 选项
ffe_file = 'data/synthetic.ffe'; % FEKO导出的远场文件；真实数据改为自己的文件名
truth_file = 'data/synthetic_truth.mat'; % 假数据的真实散射点；真实FEKO数据时设为''
E_comp = 'Etheta'; % 'Etheta'：VV；'Ephi'：HH
use_window = true; % true：距离、方位都加Hann窗，降低旁瓣但主瓣变宽
pad_factor = 4; % 补零倍数：只加密显示网格，不提高分辨率
dynamic_range_dB = 35; % 图像显示动态范围，不改变成像结果
enable_pfa = true; % 是否做PFA并与RD对比
if ~exist('figures','dir'); mkdir('figures'); end

%% 读取数据与基本参数
c = 3e8; % 光速，m/s
[S_f_phi,f_axis,phi_axis_deg] = read_ffe(ffe_file,E_comp);
[Nf,Naz] = size(S_f_phi);
delta_f = mean(diff(f_axis)); % 频率步进，Hz
f0 = (f_axis(1)+f_axis(end))/2; % 中心频率，Hz
lambda = c/f0; % 中心波长，m
Br = Nf*delta_f; % 等效带宽（步进频：Nf个频点×步进），Hz
delta_phi = mean(diff(phi_axis_deg))*pi/180; % 角度步进，rad
idx0 = floor(Naz/2)+1; % 参考（中心）方位角所在列，对应ISAR_RD.m中的eta=0
phi_c_deg = phi_axis_deg(idx0); % 中心方位角，deg
theta_c = (phi_c_deg-270)*pi/180; % 中心视角相对-y方向的转角，rad
theta_axis = (phi_axis_deg-phi_c_deg)*pi/180; % 相对转角，rad，对应ISAR_RD.m中的theta
theta_m = Naz*delta_phi; % 总转角（等效孔径），rad

rho_r = c/(2*Br); % 距离向理论分辨率（矩形窗），m
rho_a = lambda/(2*theta_m); % 横向理论分辨率（矩形窗，课件公式），m
R_ua = c/(2*delta_f); % 不模糊距离窗，m
X_ua = c/f_axis(end)/(2*delta_phi); % 横向不模糊窗（最高频，最保守），m

% 卫星模型轮廓（design_params.m保存）：用于叠加核对
has_model = exist('design_params.mat','file')==2;
if has_model
    D = load('design_params.mat','Model','L');
    Model = D.Model; L = D.L;
else
    L = min(R_ua,X_ua)/1.5;
end
% 顺时针转动（同ISAR_RD.m）：x'=x*cos+y*sin, y'=-x*sin+y*cos
rot_x = @(xy,th) xy(:,1)*cos(th)+xy(:,2)*sin(th);
rot_y = @(xy,th) -xy(:,1)*sin(th)+xy(:,2)*cos(th);

%% 窗函数（无需工具箱的Hann窗，与ISAR_RD.m相同写法）
Wr = ones(Nf,1); Wa = ones(1,Naz);
if use_window
    Wr = (0.5-0.5*cos(2*pi*(0:Nf-1)/(Nf-1))).';
    Wa = 0.5-0.5*cos(2*pi*(0:Naz-1)/(Naz-1));
end

%% 图1：原始数据与RCS曲线
RCS_dBsm = 10*log10(4*pi*abs(S_f_phi).^2+eps); % 入射场1 V/m时的RCS，dBsm
[~,idx_f0] = min(abs(f_axis-f0));
figure('Name','原始数据与RCS','Color','w','Position',[100,100,900,650]);
subplot(2,2,1);
imagesc(phi_axis_deg,f_axis/1e9,RCS_dBsm); axis xy; colorbar;
xlabel('方位角\phi / deg'); ylabel('频率 / GHz'); title('单站RCS幅度 / dBsm');
subplot(2,2,2);
imagesc(phi_axis_deg,f_axis/1e9,angle(S_f_phi)); axis xy; colorbar;
xlabel('方位角\phi / deg'); ylabel('频率 / GHz'); title('散射场相位 / rad');
subplot(2,2,3);
plot(phi_axis_deg,RCS_dBsm(idx_f0,:),'LineWidth',1.2); grid on;
xlabel('方位角\phi / deg'); ylabel('RCS / dBsm');
title(sprintf('f=%.2f GHz时RCS随方位角变化',f_axis(idx_f0)/1e9));
subplot(2,2,4);
plot(f_axis/1e9,RCS_dBsm(:,idx0),'LineWidth',1.2); grid on;
xlabel('频率 / GHz'); ylabel('RCS / dBsm');
title(sprintf('\\phi=%.2f°时RCS随频率变化',phi_c_deg));
colormap(jet(256));
print(gcf,'-dpng','-r300','figures/fig02_raw_data_rcs.png');

%% 距离压缩：频率维加窗 + IFFT（补零只加密网格）
% E(f)~exp(-j*4*pi*f*dR/c)，IFFT后峰值在dR处：远离雷达为正，与ISAR_RD.m一致。
Nfft_r = 2^nextpow2(pad_factor*Nf);
S1_r_theta = fftshift(ifft(bsxfun(@times,S_f_phi,Wr),Nfft_r,1),1);
range_axis = (-Nfft_r/2:Nfft_r/2-1).'*c/(2*Nfft_r*delta_f); % 距离轴，m
dr_image = c/(2*Nfft_r*delta_f); % 补零后的距离显示网格，m；不是分辨率

%% 图2：一维距离像随方位角的变化
HRRP_dB = 20*log10(abs(S1_r_theta)/max(abs(S1_r_theta(:)))+eps);
y_lim = 0.6*L*[-1,1];
figure('Name','一维距离像','Color','w','Position',[100,100,900,420]);
subplot(1,2,1);
imagesc(phi_axis_deg,range_axis,HRRP_dB); axis xy;
ylim(y_lim); caxis([-dynamic_range_dB,0]); colorbar;
xlabel('方位角\phi / deg'); ylabel('距离向y / m（远离雷达为正）');
title('距离像随方位角变化 / dB');
subplot(1,2,2);
plot(range_axis,HRRP_dB(:,idx0),'LineWidth',1.2); grid on;
xlim(y_lim); ylim([-dynamic_range_dB,0]);
xlabel('距离向y / m'); ylabel('归一化幅度 / dB');
title(sprintf('\\phi=%.2f°的一维距离像',phi_c_deg));
colormap(jet(256));
print(gcf,'-dpng','-r300','figures/fig03_range_profiles.png');

%% 横向成像（RD）：方位维加窗 + FFT
% 小转角：R-R0 ≈ y-x*theta，相位 exp(+j*4*pi*x*theta/lambda)，
% 对theta做FFT，峰值在“角频率”f_theta=2*x/lambda（周/rad）处，所以 x=lambda*f_theta/2。
% 等价于ISAR_RD.m中的 x=lambda*f_D/(2*Omega)（f_D=Omega*f_theta）。
S_window = bsxfun(@times,S1_r_theta,Wa);
Nfft_a = 2^nextpow2(pad_factor*Naz);
S_pad = complex(zeros(Nfft_r,Nfft_a));
idx_pad = Nfft_a/2+1+((1:Naz)-idx0); % 中心方位角放在Nfft_a/2+1，保持theta=0的位置
S_pad(:,idx_pad) = S_window;
S_RD = fftshift(fft(ifftshift(S_pad,2),[],2),2);
clear S_pad S_window;
f_theta = (-Nfft_a/2:Nfft_a/2-1)/(Nfft_a*delta_phi); % 角频率，周/rad
cross_range_axis = lambda*f_theta/2; % 横向轴，m
dx_image = lambda/(2*Nfft_a*delta_phi); % 补零后横向显示网格，m；不是分辨率

%% PFA：极坐标 (K,theta) -> 直角坐标 (Kx,Ky)
% 空间频率 K=4*pi*f/c。相位 -K*(R-R0) = K*sin(theta)*x - K*cos(theta)*y，
% 令 Kx=K*sin(theta)，Ky=K*cos(theta)，则 E=sum A*exp(j*(Kx*x-Ky*y))：
% 对Kx做FFT得x，对Ky做IFFT得y，正负号与RD完全一致。
if enable_pfa
    K_axis = 4*pi*f_axis(:)/c; % 列向量
    % 取极坐标扇环内接的矩形：Kx范围由最小K的两端转角决定，Ky上限由最大K决定
    Kx_lo = K_axis(1)*tan(theta_axis(1));
    Kx_hi = K_axis(1)*tan(theta_axis(end));
    Ky_lo = K_axis(1);
    Ky_hi = sqrt(K_axis(end)^2-max(Kx_lo^2,Kx_hi^2));
    Kx_axis = linspace(Kx_lo,Kx_hi,Naz);
    Ky_axis = linspace(Ky_lo,Ky_hi,Nf).';
    [KX,KY] = meshgrid(Kx_axis,Ky_axis);
    S_KxKy = interp2(theta_axis,K_axis,S_f_phi,atan2(KX,KY),sqrt(KX.^2+KY.^2),'cubic');
    S_KxKy(isnan(S_KxKy)) = 0;
    dKx = Kx_axis(2)-Kx_axis(1); dKy = Ky_axis(2)-Ky_axis(1);
    S_KxKy = bsxfun(@times,bsxfun(@times,S_KxKy,Wr),Wa);
    S_PFA = fftshift(fft(ifft(S_KxKy,Nfft_r,1),Nfft_a,2),2);
    S_PFA = fftshift(S_PFA,1);
    y_pfa = (-Nfft_r/2:Nfft_r/2-1).'*2*pi/(Nfft_r*dKy); % m
    x_pfa = (-Nfft_a/2:Nfft_a/2-1)*2*pi/(Nfft_a*dKx); % m
    % 插值到与RD相同的网格，便于并排比较
    S_PFA = interp2(x_pfa,y_pfa,abs(S_PFA),cross_range_axis,range_axis,'linear',0);
end

%% 裁切显示区域（由目标尺寸决定，不由FFT矩阵大小决定）
x_lim = 0.6*L*[-1,1];
idx_x = cross_range_axis>=x_lim(1) & cross_range_axis<=x_lim(2);
idx_y = range_axis>=y_lim(1) & range_axis<=y_lim(2);
x_image = cross_range_axis(idx_x);
y_image = range_axis(idx_y);
Image_abs = abs(S_RD(idx_y,idx_x));
Image_dB = 20*log10(Image_abs/(max(Image_abs(:))+eps)+eps);
if enable_pfa
    Image_pfa_abs = S_PFA(idx_y,idx_x);
    Image_pfa_dB = 20*log10(Image_pfa_abs/(max(Image_pfa_abs(:))+eps)+eps);
end

% 真实散射点（仅假数据）转到中心视角下的ISAR坐标
has_truth = ~isempty(truth_file) && exist(truth_file,'file')==2;
if has_truth
    T = load(truth_file);
    x_true = rot_x(T.NPosition(:,1:2),theta_c);
    y_true = rot_y(T.NPosition(:,1:2),theta_c);
end

%% 图3：RD图像 + 模型轮廓
figure('Name','ISAR RD图像','Color','w','Position',[100,100,620,520]);
imagesc(x_image,y_image,Image_dB); axis xy; axis equal; axis tight;
hold on;
if has_model
    plot(rot_x(Model.outline_xy,theta_c),rot_y(Model.outline_xy,theta_c),'w-','LineWidth',0.8);
end
if has_truth; plot(x_true,y_true,'wo','MarkerSize',8,'LineWidth',1); end
hold off;
xlabel('横向x=\lambda_0 f_\theta/2 / m'); ylabel('距离向y / m（远离雷达为正）');
title(sprintf('RD图像（\\phi_c=%.1f°，\\theta_m=%.1f°）；白线为模型俯视轮廓',phi_c_deg,theta_m*180/pi));
caxis([-dynamic_range_dB,0]); colorbar; colormap(jet(256));
print(gcf,'-dpng','-r300','figures/fig04_RD_image.png');

%% 图4：RD与PFA对比（上：全图；下：离旋转中心最远处的局部放大）
% RD假设小转角、窄带：离中心越远，距离徙动和二次相位越大，RD越散焦；PFA可校正。
if enable_pfa
    % 放大中心：取模型轮廓上离旋转中心最远的点（帆板端点）
    if has_model
        pts = Model.outline_xy(~isnan(Model.outline_xy(:,1)),:);
    else
        pts = [x_lim(2),0];
    end
    [~,i_far] = max(abs(rot_x(pts,theta_c))); % 横向最远点（RD散焦最明显）
    zoom_c = [rot_x(pts(i_far,:),theta_c),rot_y(pts(i_far,:),theta_c)];
    zoom_w = 0.06*L; % 放大窗口半宽，m
    figure('Name','RD与PFA对比','Color','w','Position',[100,100,900,800]);
    img_list = {Image_dB,Image_pfa_dB};
    name_list = {'RD（小转角近似）','PFA（极坐标插值）'};
    for k = 1:4
        subplot(2,2,k);
        imagesc(x_image,y_image,img_list{mod(k-1,2)+1}); axis xy; axis equal; axis tight;
        hold on;
        if has_model
            plot(rot_x(Model.outline_xy,theta_c),rot_y(Model.outline_xy,theta_c),'w-','LineWidth',0.8);
        end
        if has_truth; plot(x_true,y_true,'wo','MarkerSize',8); end
        if k<=2
            rectangle('Position',[zoom_c-zoom_w,2*zoom_w,2*zoom_w],'EdgeColor','w','LineStyle','--');
            title(name_list{k});
        else
            xlim(zoom_c(1)+zoom_w*[-1,1]); ylim(zoom_c(2)+zoom_w*[-1,1]);
            title([name_list{k-2},'：局部放大']);
        end
        hold off;
        xlabel('横向x / m'); ylabel('距离向y / m');
        caxis([-dynamic_range_dB,0]); colorbar;
    end
    colormap(jet(256));
    print(gcf,'-dpng','-r300','figures/fig05_RD_vs_PFA.png');
end

%% 图5：正负号检查——正确约定 / 误取共轭 / 方位角顺序取反
% 共轭（误用e^{-jwt}约定）：距离、横向同时反号，图像绕原点转180°。
% 方位角反序（误把phi减小当成顺时针）：只有横向反号，左右镜像。
S_case = {S_f_phi,conj(S_f_phi),fliplr(S_f_phi)};
name_case = {'正确：FEKO数据直接成像','误取共轭：绕原点翻转180°','方位反序：左右镜像'};
figure('Name','正负号检查','Color','w','Position',[100,100,1200,420]);
for k = 1:3
    S_k = fftshift(ifft(bsxfun(@times,S_case{k},Wr),Nfft_r,1),1);
    S_k = fftshift(fft(bsxfun(@times,S_k,Wa),Nfft_a,2),2); % 只看幅度，末尾补零即可
    S_k = abs(S_k(idx_y,idx_x));
    subplot(1,3,k);
    imagesc(x_image,y_image,20*log10(S_k/max(S_k(:))+eps)); axis xy; axis equal; axis tight;
    hold on;
    if has_truth; plot(x_true,y_true,'wo','MarkerSize',7); end
    hold off;
    xlabel('横向x / m'); ylabel('距离向y / m'); title(name_case{k});
    caxis([-dynamic_range_dB,0]);
end
colormap(jet(256));
print(gcf,'-dpng','-r300','figures/fig06_sign_check.png');

%% 打印参数与核验结果
fprintf('\n======= ISAR转台成像参数 =======\n');
fprintf('数据矩阵：Nf=%d个频点 × Naz=%d个方位角\n',Nf,Naz);
fprintf('f0=%.3f GHz，Br=%.1f MHz，delta_f=%.2f MHz\n',f0/1e9,Br/1e6,delta_f/1e6);
fprintf('方位：%.3f~%.3f deg，中心%.3f deg，theta_m=%.2f deg\n',...
    phi_axis_deg(1),phi_axis_deg(end),phi_c_deg,theta_m*180/pi);
fprintf('距离分辨率rho_r=%.3f m；补零后距离网格=%.3f m\n',rho_r,dr_image);
fprintf('横向分辨率rho_a=%.3f m；补零后横向网格=%.3f m\n',rho_a,dx_image);
fprintf('加Hann窗后主瓣约展宽1.6倍（use_window=%d）\n',use_window);
fprintf('不模糊窗：距离%.2f m，横向%.2f m\n',R_ua,X_ua);
fprintf('提示：补零只加密显示网格，不提高分辨率；分辨率只由带宽Br和转角theta_m决定。\n');
if has_truth
    % 在每个真实点附近（半径1.5个分辨单元）找局部峰值
    r_search = 1.5*max(rho_r,rho_a);
    [XI,YI] = meshgrid(x_image,y_image);
    fprintf('\n------- 假数据定标核验（中心视角下的ISAR坐标） -------\n');
    fprintf(' 序号  真实x    真实y  |  RD峰x    RD峰y   误差  ');
    if enable_pfa; fprintf('|  PFA峰x  PFA峰y   误差'); end
    fprintf('\n');
    for i = 1:numel(x_true)
        mask = (XI-x_true(i)).^2+(YI-y_true(i)).^2<=r_search^2;
        [~,id] = max(Image_abs(:).*mask(:));
        err_rd = hypot(XI(id)-x_true(i),YI(id)-y_true(i));
        fprintf('  %d   %6.2f  %6.2f  | %6.2f  %6.2f  %5.3f ',i,x_true(i),y_true(i),XI(id),YI(id),err_rd);
        if enable_pfa
            [~,id] = max(Image_pfa_abs(:).*mask(:));
            err_pfa = hypot(XI(id)-x_true(i),YI(id)-y_true(i));
            fprintf('| %6.2f  %6.2f  %5.3f',XI(id),YI(id),err_pfa);
        end
        fprintf('\n');
    end
    [~,id] = max(Image_abs(:));
    [~,i_strong] = max(T.NPosition(:,3));
    fprintf('全图最强点：(%.2f, %.2f) m；最强散射体真实位置：(%.2f, %.2f) m\n',...
        XI(id),YI(id),x_true(i_strong),y_true(i_strong));
end
