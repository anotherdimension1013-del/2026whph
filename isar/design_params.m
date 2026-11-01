%{
%      ISAR转台成像：FEKO扫频×扫角参数设计
%      思路：FEKO平面波单站扫描得到E(f,phi)，等效为步进频信号在各转角下的频域回波。
%      频率维IFFT -> 距离像；方位维FFT -> 横向像（小转角RD）；转角较大时用PFA。
%      坐标约定沿用ISAR_RD.m：
%          原点为目标旋转中心O；x为横向（向右为正）；y为距离向（远离雷达为正）；
%          雷达位于(0,-R0)，即FEKO中的方向 theta=90°, phi=270°。
%          目标绕z轴顺时针转过theta角 <=> 目标不动、雷达方向逆时针转到 phi=270°+theta。
%      本脚本只做参数计算与可行性检查，不生成回波。输出：命令行参数表、
%      params_table.md、design_params.mat、figures/fig01_model_topview.png。
%}
clc; clear; close all;

%% 选项
model_mode = 'satellite'; % 'satellite'：参数化卫星模型；'custom'：只给最大尺寸L（如下载的STL）
L_custom = 8; % model_mode='custom'时使用的目标最大尺寸，m
os_ua = 1.5; % 不模糊窗口相对目标尺寸的余量：c/(2*delta_f)>os_ua*L，lambda/(2*delta_phi)>os_ua*L
phi_c_deg = 300; % 中心观测方位角（FEKO的phi），deg；270°为正对-y方向（太阳帆板镜面闪烁）
theta_inc_deg = 90; % 雷达俯仰：FEKO的theta，90°表示雷达位于xy平面内（转台平面）
pol_mode = 'VV'; % 'VV'：eta=0°，接收Etheta；'HH'：eta=90°，接收Ephi
t_per_point = 0.5; % 每个(频点,角度)单站解的估计耗时，s；请用试算实测后替换

%% 目标模型：参数化卫星（立方体本体 + 两块太阳帆板）
% 本体：中心在原点的立方体，边长bus_a。
% 帆板：零厚度PEC薄板，位于y=0平面（xz平面），法向为±y，直接贴在本体±x面上。
%       帆板与本体侧面构成90°二面角（棱线沿z轴），雷达在xy平面内时为强散射中心。
bus_a = 1.5; % 本体边长，m
panel_len = 2.5; % 单块帆板沿x方向长度，m
panel_wid = 1.2; % 帆板沿z方向宽度，m
switch lower(model_mode)
    case 'satellite'
        L = bus_a+2*panel_len; % 目标最大尺寸（翼展），m
        % 俯视轮廓（xy平面投影），每个部件一行多边形顶点，用于叠加到ISAR图像
        Model.bus_xy = bus_a/2*[-1,-1; 1,-1; 1,1; -1,1; -1,-1];
        Model.panel_r_xy = [bus_a/2,0; bus_a/2+panel_len,0]; % 右帆板投影为线段
        Model.panel_l_xy = -Model.panel_r_xy; % 左帆板
        Model.bus_a = bus_a; Model.panel_len = panel_len; Model.panel_wid = panel_wid;
    case 'custom'
        L = L_custom;
        Model = struct();
    otherwise
        error('model_mode只能是satellite或custom。');
end
target_radius = L/2; % 以本体中心为旋转中心时的最大半径，m（对称模型）

%% 电磁波与距离向参数（步进频）
c = 3e8; % 光速，m/s
f0 = 10e9; % 中心频率，Hz（X波段）
lambda = c/f0; % 中心波长，m
Br = 1e9; % 扫频带宽，Hz
rho_r = c/(2*Br); % 距离向理论分辨率，m（矩形窗）
f_min = f0-Br/2; f_max = f0+Br/2; % 扫频起止，Hz
lambda_min = c/f_max; % 最短波长，m，用于角度采样的保守设计

% 频率步进：不模糊距离 R_ua=c/(2*delta_f) 必须大于 os_ua*L
delta_f_max = c/(2*os_ua*L); % 允许的最大频率步进，Hz
% 把上限向下取到{1,2,2.5,5}×10^n序列中的“整”数
p10 = 10^floor(log10(delta_f_max)); m_nice = [1,2,2.5,5,10];
delta_f = p10*m_nice(find(m_nice*p10<=delta_f_max,1,'last'));
Nf = round(Br/delta_f)+1; % 频点数（含两端点）
R_ua = c/(2*delta_f); % 不模糊距离窗，m
f_axis = f_min+(0:Nf-1)*delta_f; % 频率轴，Hz

%% 方位向参数（转角）
% 横向分辨率 rho_a = lambda/(2*theta_m)，令 rho_a ≈ rho_r
res_a = rho_r; % 希望达到的横向分辨率，m
theta_m = lambda/(2*res_a); % 所需总转角，rad
theta_m_deg = ceil(theta_m*180/pi*2)/2; % 向上取到0.5°，便于在FEKO中填写
theta_m = theta_m_deg*pi/180;
rho_a = lambda/(2*theta_m); % 实际理论横向分辨率，m

% 角度步进：横向不模糊窗 X_ua = lambda_min/(2*delta_phi) 必须大于 os_ua*L
delta_phi_max = lambda_min/(2*os_ua*L); % rad
delta_phi_deg = floor(delta_phi_max*180/pi*100)/100; % 向下取到0.01°
% 再微调，使总转角恰好是步进的整数倍
Naz = ceil(theta_m_deg/delta_phi_deg)+1; % 角度点数（含两端点）
delta_phi_deg = theta_m_deg/(Naz-1);
delta_phi = delta_phi_deg*pi/180;
X_ua = lambda_min/(2*delta_phi); % 横向不模糊窗（最高频处，最保守），m
phi_start_deg = phi_c_deg-theta_m_deg/2; % FEKO中phi扫描起点，deg
phi_end_deg = phi_c_deg+theta_m_deg/2; % FEKO中phi扫描终点，deg
phi_axis_deg = phi_start_deg+(0:Naz-1)*delta_phi_deg; % 方位角轴，deg
theta_axis = (phi_axis_deg-phi_c_deg)*pi/180; % 相对中心的转角（逆时针看雷达=目标顺时针），rad

%% 极化
switch upper(pol_mode)
    case 'VV'
        eta_deg = 0; E_comp = 'Etheta'; % 入射E沿theta方向；theta=90°时为-z方向（竖直）
    case 'HH'
        eta_deg = 90; E_comp = 'Ephi'; % 入射E沿phi方向（水平）
    otherwise
        error('pol_mode只能是VV或HH。');
end

%% RD适用性检查（与ISAR_RD.m相同的两项，外加带宽引起的横向尺度变化）
% 目标在中心视角下的投影：目标顺时针转theta_c后的(x,y)
theta_c = (phi_c_deg-270)*pi/180;
if strcmpi(model_mode,'satellite')
    pts = [Model.bus_xy; Model.panel_r_xy; Model.panel_l_xy];
else
    pts = target_radius*[1,0; -1,0; 0,1; 0,-1];
end
x_img = pts(:,1)*cos(theta_c)+pts(:,2)*sin(theta_c);
y_img = -pts(:,1)*sin(theta_c)+pts(:,2)*cos(theta_c);
x_max = max(abs(x_img)); y_max = max(abs(y_img));
% 转动距离徙动：横向x处的点在theta_m内距离变化约x*theta_m
range_migration = x_max*theta_m;
% 二次相位误差：y*(1-cos(theta))≈y*theta^2/2，取边缘theta=theta_m/2
phase_error_max = 4*pi/lambda*max(sqrt(x_img.^2+y_img.^2))*(theta_m/2)^2/2;
% 带宽引起的横向尺度变化：x方向多普勒正比于f，频带边缘横向位置相差x*Br/f0
cross_scale_blur = x_max*Br/f0;

%% 计算量估算
N_total = Nf*Naz; % 主扫描单站解个数
N_rcs_cut = numel(0:0.5:360); % 附加：f0单频、phi全方位0.5°步进的RCS曲线
T_est_h = (N_total+N_rcs_cut)*t_per_point/3600; % 估计总耗时，h
% 全波（MoM/MLFMM）网格估算：表面积 / 单个三角形面积（边长lambda_min/8）
if strcmpi(model_mode,'satellite')
    area_total = 6*bus_a^2+2*2*panel_len*panel_wid; % 本体6面+帆板两面，m^2
else
    area_total = NaN;
end
edge_len = lambda_min/8; % MoM推荐网格边长
N_tri_MoM = area_total/(sqrt(3)/4*edge_len^2); % 三角形个数
N_unk_MoM = 1.5*N_tri_MoM; % RWG未知量≈1.5×三角形数
mem_MoM_GB = 16*N_unk_MoM^2/2^30; % 直接MoM复数双精度矩阵内存，GB
cells_r = L/rho_r; cells_a = L/rho_a; % 目标在距离/横向上占据的分辨单元数
electric_size = L/lambda_min; % 电尺寸（最高频）

%% 打印参数表
fprintf('\n======= ISAR转台成像：FEKO参数设计 =======\n');
fprintf('目标：%s，最大尺寸L=%.2f m，电尺寸L/lambda_min=%.0f\n',model_mode,L,electric_size);
fprintf('中心频率f0=%.2f GHz，lambda=%.2f cm\n',f0/1e9,lambda*100);
fprintf('带宽Br=%.0f MHz，扫频%.3f~%.3f GHz\n',Br/1e6,f_min/1e9,f_max/1e9);
fprintf('频率步进delta_f=%.2f MHz（上限%.2f MHz），频点数Nf=%d\n',delta_f/1e6,delta_f_max/1e6,Nf);
fprintf('不模糊距离R_ua=%.2f m（要求>%.2f m）\n',R_ua,os_ua*L);
fprintf('总转角theta_m=%.2f deg，phi扫描%.3f~%.3f deg\n',theta_m_deg,phi_start_deg,phi_end_deg);
fprintf('角度步进delta_phi=%.4f deg（上限%.4f deg），角度点数Naz=%d\n',delta_phi_deg,delta_phi_max*180/pi,Naz);
fprintf('横向不模糊窗X_ua=%.2f m（要求>%.2f m）\n',X_ua,os_ua*L);
fprintf('距离分辨率rho_r=%.3f m；横向分辨率rho_a=%.3f m\n',rho_r,rho_a);
fprintf('目标占据分辨单元：距离%.0f个×横向%.0f个\n',cells_r,cells_a);
fprintf('极化：%s（FEKO平面波eta=%d°，接收%s），雷达俯仰theta=%d°\n',upper(pol_mode),eta_deg,E_comp,theta_inc_deg);
fprintf('----- RD适用性（中心视角phi=%.1f°） -----\n',phi_c_deg);
fprintf('最大横向|x|=%.2f m，最大距离|y|=%.2f m\n',x_max,y_max);
fprintf('转动距离徙动约=%.3f m（半个距离单元=%.3f m）\n',range_migration,rho_r/2);
fprintf('二次相位误差约=%.2f rad（门限pi/4=%.2f rad）\n',phase_error_max,pi/4);
fprintf('带宽引起的横向尺度展宽约=%.3f m（横向单元=%.3f m）\n',cross_scale_blur,rho_a);
fprintf('----- 计算量 -----\n');
fprintf('主扫描：Nf×Naz=%d×%d=%d个单站解\n',Nf,Naz,N_total);
fprintf('附加RCS曲线：f0单频，phi=0:0.5:360，%d个单站解\n',N_rcs_cut);
fprintf('若每点%.2f s，总耗时约%.1f h（请先试算实测）\n',t_per_point,T_est_h);
fprintf('全波MoM参考：表面积%.1f m^2，三角形约%.2e个，未知量约%.2e，直接MoM矩阵约%.1e GB\n',...
    area_total,N_tri_MoM,N_unk_MoM,mem_MoM_GB);
if range_migration>rho_r/2
    warning('转动距离徙动超过半个距离单元：RD图像边缘散射点会展宽，建议同时做PFA对比。');
end
if phase_error_max>pi/4
    warning('二次相位误差超过pi/4：RD图像边缘散焦，PFA可校正。');
end

%% 写出参数表（Markdown）与参数文件
fid = fopen('params_table.md','w');
fprintf(fid,'| 参数 | 符号 | 数值 | 说明 |\n|---|---|---|---|\n');
fprintf(fid,'| 目标最大尺寸 | L | %.2f m | 电尺寸约 %.0f λ |\n',L,electric_size);
fprintf(fid,'| 中心频率 | f0 | %.2f GHz | λ0 = %.2f cm |\n',f0/1e9,lambda*100);
fprintf(fid,'| 带宽 | Br | %.0f MHz | %.3f~%.3f GHz |\n',Br/1e6,f_min/1e9,f_max/1e9);
fprintf(fid,'| 频率步进 | Δf | %.2f MHz | 上限 c/(2·%.1fL) = %.2f MHz |\n',delta_f/1e6,os_ua,delta_f_max/1e6);
fprintf(fid,'| 频点数 | Nf | %d | |\n',Nf);
fprintf(fid,'| 不模糊距离 | c/(2Δf) | %.2f m | > %.1fL = %.2f m |\n',R_ua,os_ua,os_ua*L);
fprintf(fid,'| 总转角 | θm | %.2f° | φ: %.3f°~%.3f° |\n',theta_m_deg,phi_start_deg,phi_end_deg);
fprintf(fid,'| 角度步进 | Δφ | %.4f° | 上限 λmin/(2·%.1fL) = %.4f° |\n',delta_phi_deg,os_ua,delta_phi_max*180/pi);
fprintf(fid,'| 角度点数 | Naz | %d | |\n',Naz);
fprintf(fid,'| 横向不模糊窗 | λmin/(2Δφ) | %.2f m | > %.2f m |\n',X_ua,os_ua*L);
fprintf(fid,'| 距离分辨率 | ρr = c/(2Br) | %.3f m | 矩形窗 |\n',rho_r);
fprintf(fid,'| 横向分辨率 | ρa = λ0/(2θm) | %.3f m | 矩形窗 |\n',rho_a);
fprintf(fid,'| 极化 | | %s | 平面波 η=%d°，接收 %s |\n',upper(pol_mode),eta_deg,E_comp);
fprintf(fid,'| 雷达俯仰 | θ | %d° | 雷达在转台平面内 |\n',theta_inc_deg);
fprintf(fid,'| 单站解总数 | Nf×Naz | %d | 另加 RCS 曲线 %d 点 |\n',N_total,N_rcs_cut);
fclose(fid);
save('design_params.mat','c','f0','lambda','Br','rho_r','delta_f','Nf','f_axis',...
    'theta_m','theta_m_deg','delta_phi_deg','Naz','phi_axis_deg','phi_c_deg',...
    'theta_inc_deg','pol_mode','eta_deg','E_comp','rho_a','R_ua','X_ua','L','Model','model_mode');

% 顺时针转动th（同ISAR_RD.m）：x'=x*cos+y*sin, y'=-x*sin+y*cos
rot_x = @(xy,th) xy(:,1)*cos(th)+xy(:,2)*sin(th);
rot_y = @(xy,th) -xy(:,1)*sin(th)+xy(:,2)*cos(th);

%% 图1：模型俯视图与雷达视线（雷达位于图的下方，与ISAR_RD.m一致）
if ~exist('figures','dir'); mkdir('figures'); end
figure('Name','模型俯视图与观测几何','Color','w');
subplot(1,2,1); hold on;
if strcmpi(model_mode,'satellite')
    fill(Model.bus_xy(:,1),Model.bus_xy(:,2),[0.8,0.8,0.8]);
    plot(Model.panel_r_xy(:,1),Model.panel_r_xy(:,2),'b-','LineWidth',3);
    plot(Model.panel_l_xy(:,1),Model.panel_l_xy(:,2),'b-','LineWidth',3);
    plot(bus_a/2*[1,-1],[0,0],'rp','MarkerSize',12,'MarkerFaceColor','r'); % 二面角棱线
end
% 雷达方向：从原点指向phi方向
phi_line = [phi_start_deg,phi_c_deg,phi_end_deg]*pi/180;
for k = 1:3
    plot([0,0.9*L*cos(phi_line(k))],[0,0.9*L*sin(phi_line(k))],'k--');
end
text(0.95*L*cos(phi_c_deg*pi/180),0.95*L*sin(phi_c_deg*pi/180),'雷达方向');
hold off; axis equal; grid on; box on;
xlim(0.8*L*[-1,1]); ylim(L*[-1,0.6]);
xlabel('x / m（FEKO全局坐标）'); ylabel('y / m');
title('目标坐标系：红星为帆板-本体二面角');
subplot(1,2,2); hold on;
% 中心视角下的ISAR坐标：目标顺时针转theta_c
if strcmpi(model_mode,'satellite')
    plot(rot_x(Model.bus_xy,theta_c),rot_y(Model.bus_xy,theta_c),'k-','LineWidth',2);
    plot(rot_x(Model.panel_r_xy,theta_c),rot_y(Model.panel_r_xy,theta_c),'b-','LineWidth',2);
    plot(rot_x(Model.panel_l_xy,theta_c),rot_y(Model.panel_l_xy,theta_c),'b-','LineWidth',2);
end
hold off; axis equal; grid on; box on;
xlim(0.7*L*[-1,1]); ylim(0.7*L*[-1,1]);
xlabel('横向x / m'); ylabel('距离向y / m（远离雷达为正）');
title(sprintf('中心视角phi=%.0f°下的ISAR坐标',phi_c_deg));
print(gcf,'-dpng','-r300','figures/fig01_model_topview.png');
