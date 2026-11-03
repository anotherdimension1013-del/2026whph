%{
%      ISAR转台成像：FEKO扫频×扫角参数设计
%      思路：FEKO平面波单站扫描得到E(f,phi)，等效为步进频信号在各转角下的频域回波。
%      频率维IFFT -> 距离像；方位维FFT -> 横向像（小转角RD）；转角较大时用PFA。
%      坐标约定沿用ISAR_RD.m：
%          原点为目标旋转中心O；x为横向（向右为正）；y为距离向（远离雷达为正）；
%          雷达位于(0,-R0)，即FEKO中的方向 theta=90°, phi=270°。
%          目标绕z轴顺时针转过theta角 <=> 目标不动、雷达方向逆时针转到 phi=270°+theta。
%      本脚本只做参数计算与可行性检查，不生成回波。输出：命令行参数表、
%      params_table.md、design_params.mat、figures/fig00_model_3d.png、figures/fig01_model_topview.png。
%}
clc; clear; close all;
% 切换到本脚本所在文件夹：保证read_stl/read_ffe等函数和model、data、figures等相对路径都能找到
script_dir = fileparts(mfilename('fullpath'));
if ~isempty(script_dir); cd(script_dir); addpath(script_dir); end

%% 选项
model_mode = 'radarsat1'; % 'radarsat1'：NASA RADARSAT-1模型（STL）；'satellite'：参数化箱体+双帆板卫星（备选）
rho_design = 0.3; % 设计分辨率（距离、横向相同），m；决定带宽与总转角
os_ua = 1.5; % 不模糊窗口相对目标尺寸的余量：c/(2*delta_f)>os_ua*L，lambda/(2*delta_phi)>os_ua*L
phi_c_deg = 300; % 中心观测方位角（FEKO的phi），deg；270°为正对-y方向（平板镜面闪烁）
epsilon_deg = 0; % 雷达俯仰角ε，deg：0°为雷达与目标同高（在xy平面内），30°为雷达位于斜上方30°
theta_inc_deg = 90-epsilon_deg; % FEKO平面波入射方向的天顶角θ（从+z轴量起）= 90°-ε
phi_span_deg = 0; % 宽角扫描的总方位范围，deg；0表示只扫一个子孔径（总转角theta_m）。子孔径融合时如设为60
c_el = cos(epsilon_deg*pi/180); % 俯仰修正：空间频率在xy平面内的分量为K*cos(ε)，水平面上的分辨率与窗口均除以cos(ε)
pol_mode = 'VV'; % 'VV'：eta=0°，接收Etheta；'HH'：eta=90°，接收Ephi
t_per_point = 0.18; % 每个(频点,角度)单站解的耗时，s；5.3 GHz、RL-GO射线密度Low实测（Normal约2.9 s/点）

%% 目标模型
% Model.outline_xy：俯视轮廓（xy平面投影），N×2，多个多边形之间用NaN行分隔，可直接plot。
% Model.stl_file：STL文件（单位m，旋转中心在原点）；参数化模型为空。
switch lower(model_mode)
    case 'radarsat1'
        % NASA 3D Resources的RADARSAT-1模型，由tools/convert_glb_to_stl.py转换：
        % 缩放0.1（翼展约16 m），绕x轴转90°使SAR天线与太阳翼平板竖直（法向沿y），本体中心移到原点。
        Model.stl_file = 'model/radarsat1_m.stl';
        Model.outline_xy = load('model/radarsat1_outline_xy.txt'); % tools/make_outline.py生成
        [F_stl,V_stl] = read_stl(Model.stl_file);
        L = 2*max(sqrt(V_stl(:,1).^2+V_stl(:,2).^2)); % 绕z轴转动时扫过的最大直径，m
        e1 = V_stl(F_stl(:,2),:)-V_stl(F_stl(:,1),:); e2 = V_stl(F_stl(:,3),:)-V_stl(F_stl(:,1),:);
        area_total = sum(sqrt(sum(cross(e1,e2,2).^2,2)))/2; % 网格表面积，m^2
    case 'satellite'
        % 本体：中心在原点的立方体，边长bus_a；帆板：y=0平面内的零厚度PEC薄板，贴在本体±x面上。
        bus_a = 1.5; panel_len = 2.5; panel_wid = 1.2; % m
        Model.stl_file = '';
        Model.outline_xy = [bus_a/2*[-1,-1; 1,-1; 1,1; -1,1; -1,-1]; NaN,NaN;
                            bus_a/2,0; bus_a/2+panel_len,0; NaN,NaN;
                            -bus_a/2,0; -bus_a/2-panel_len,0];
        L = bus_a+2*panel_len;
        area_total = 6*bus_a^2+2*2*panel_len*panel_wid;
    otherwise
        error('model_mode只能是radarsat1或satellite。');
end
Model.name = model_mode;
target_radius = L/2; % 最大转动半径，m

%% 电磁波与距离向参数（步进频）
c = 3e8; % 光速，m/s
f0 = 5.3e9; % 中心频率，Hz（C波段，RADARSAT-1自身SAR的工作频率；试算表明比X波段射线数少、计算快得多）
lambda = c/f0; % 中心波长，m
Br = c/(2*rho_design*c_el); % 扫频带宽，Hz（水平面上距离分辨率为rho_design）
rho_r = c/(2*Br)/c_el; % 距离向理论分辨率（水平面投影，矩形窗），m
f_min = f0-Br/2; f_max = f0+Br/2; % 扫频起止，Hz
lambda_min = c/f_max; % 最短波长，m，用于角度采样的保守设计

% 频率步进：不模糊距离 R_ua=c/(2*delta_f) 必须大于 os_ua*L
delta_f_max = c/(2*os_ua*L*c_el); % 允许的最大频率步进，Hz
% 把上限向下取到{1,1.25,2,2.5,4,5,6.25,8}×10^n序列中的“整”数
p10 = 10^floor(log10(delta_f_max)); m_nice = [1,1.25,2,2.5,4,5,6.25,8,10];
delta_f = p10*m_nice(find(m_nice*p10<=delta_f_max,1,'last'));
Nf = round(Br/delta_f)+1; % 频点数（含两端点）
R_ua = c/(2*delta_f)/c_el; % 不模糊距离窗（水平面投影），m
f_axis = f_min+(0:Nf-1)*delta_f; % 频率轴，Hz

%% 方位向参数（转角）
% 横向分辨率 rho_a = lambda/(2*theta_m)，令 rho_a ≈ rho_r
res_a = rho_design; % 希望达到的横向分辨率，m
theta_m = lambda/(2*res_a*c_el); % 所需总转角（单个子孔径），rad
% 角度步进：横向不模糊窗 X_ua = lambda_min/(2*delta_phi) 必须大于 os_ua*L
delta_phi_max = lambda_min/(2*os_ua*L*c_el); % rad
delta_phi_deg = floor(delta_phi_max*180/pi*200)/200; % 向下取到0.005°，便于在FEKO中填写
delta_phi = delta_phi_deg*pi/180;
% 角度点数：使总转角不小于所需值；再由步进反推实际总转角（保证FEKO中的数都是整齐的）
Naz_sub = ceil(theta_m*180/pi/delta_phi_deg)+1; % 单个子孔径的角度点数（含两端点）
theta_m_deg = delta_phi_deg*(Naz_sub-1);
theta_m = theta_m_deg*pi/180;
rho_a = lambda/(2*theta_m)/c_el; % 实际理论横向分辨率（水平面投影），m
X_ua = lambda_min/(2*delta_phi)/c_el; % 横向不模糊窗（最高频处，最保守），m
% FEKO中的方位扫描：单孔径时就是theta_m；宽角时为phi_span_deg（取步进的整数倍）
if phi_span_deg>theta_m_deg
    Naz = ceil(phi_span_deg/delta_phi_deg)+1;
else
    Naz = Naz_sub;
end
phi_scan_deg = delta_phi_deg*(Naz-1); % 实际方位扫描范围，deg
phi_start_deg = phi_c_deg-phi_scan_deg/2; % FEKO中phi扫描起点，deg
phi_end_deg = phi_c_deg+phi_scan_deg/2; % FEKO中phi扫描终点，deg
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
pts = Model.outline_xy(~isnan(Model.outline_xy(:,1)),:); % 轮廓顶点
x_img = pts(:,1)*cos(theta_c)+pts(:,2)*sin(theta_c);
y_img = -pts(:,1)*sin(theta_c)+pts(:,2)*cos(theta_c);
x_max = max(abs(x_img)); y_max = max(abs(y_img));
% 转动距离徙动：横向x处的点在theta_m内距离变化约x*theta_m
range_migration = x_max*theta_m;
% 二次相位误差：y*(1-cos(theta))≈y*theta^2/2，取边缘theta=theta_m/2
phase_error_max = 4*pi/lambda*c_el*max(sqrt(x_img.^2+y_img.^2))*(theta_m/2)^2/2;
% 带宽引起的横向尺度变化：x方向多普勒正比于f，频带边缘横向位置相差x*Br/f0
cross_scale_blur = x_max*Br/f0;

%% 计算量估算
N_total = Nf*Naz; % 主扫描单站解个数
N_rcs_cut = numel(0:0.5:360); % 附加：f0单频、phi全方位0.5°步进的RCS曲线
T_est_h = (N_total+N_rcs_cut)*t_per_point/3600; % 估计总耗时，h
% 全波（MoM/MLFMM）网格估算：表面积 / 单个三角形面积（边长lambda_min/8）
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
fprintf('俯仰角epsilon=%.0f deg（FEKO平面波theta=%.0f deg）\n',epsilon_deg,theta_inc_deg);
fprintf('子孔径总转角theta_m=%.2f deg（%d个角度）；FEKO中phi扫描%.3f~%.3f deg，共%d个角度\n',theta_m_deg,Naz_sub,phi_start_deg,phi_end_deg,Naz);
fprintf('角度步进delta_phi=%.4f deg（上限%.4f deg），角度点数Naz=%d\n',delta_phi_deg,delta_phi_max*180/pi,Naz);
fprintf('横向不模糊窗X_ua=%.2f m（要求>%.2f m）\n',X_ua,os_ua*L);
fprintf('距离分辨率rho_r=%.3f m；横向分辨率rho_a=%.3f m\n',rho_r,rho_a);
fprintf('目标占据分辨单元：距离%.0f个×横向%.0f个\n',cells_r,cells_a);
fprintf('极化：%s（FEKO平面波eta=%d°，接收%s）\n',upper(pol_mode),eta_deg,E_comp);
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
fprintf(fid,'| 子孔径总转角 | θm | %.2f° | %d 个角度 |\n',theta_m_deg,Naz_sub);
fprintf(fid,'| FEKO 方位扫描 | φ | %.3f°~%.3f° | %d 个角度 |\n',phi_start_deg,phi_end_deg,Naz);
fprintf(fid,'| 角度步进 | Δφ | %.4f° | 上限 λmin/(2·%.1fL) = %.4f° |\n',delta_phi_deg,os_ua,delta_phi_max*180/pi);
fprintf(fid,'| 角度点数 | Naz | %d | |\n',Naz);
fprintf(fid,'| 横向不模糊窗 | λmin/(2Δφ) | %.2f m | > %.2f m |\n',X_ua,os_ua*L);
fprintf(fid,'| 距离分辨率 | ρr = c/(2Br) | %.3f m | 矩形窗 |\n',rho_r);
fprintf(fid,'| 横向分辨率 | ρa = λ0/(2θm) | %.3f m | 矩形窗 |\n',rho_a);
fprintf(fid,'| 极化 | | %s | 平面波 η=%d°，接收 %s |\n',upper(pol_mode),eta_deg,E_comp);
fprintf(fid,'| 俯仰角 | ε | %.0f° | FEKO 平面波 θ = 90° − ε = %.0f° |\n',epsilon_deg,theta_inc_deg);
fprintf(fid,'| 中心方位 | φc | %.1f° | 相对 -y 方向转过 %.1f° |\n',phi_c_deg,phi_c_deg-270);
fprintf(fid,'| 单站解总数 | Nf×Naz | %d | 另加 RCS 曲线 %d 点 |\n',N_total,N_rcs_cut);
fclose(fid);
save('design_params.mat','c','f0','lambda','Br','rho_r','delta_f','Nf','f_axis',...
    'theta_m','theta_m_deg','delta_phi_deg','Naz','phi_axis_deg','phi_c_deg',...
    'theta_inc_deg','epsilon_deg','Naz_sub','pol_mode','eta_deg','E_comp','rho_a','R_ua','X_ua','L','Model','model_mode');

if ~exist('figures','dir'); mkdir('figures'); end


% 顺时针转动th（同ISAR_RD.m）：x'=x*cos+y*sin, y'=-x*sin+y*cos
rot_x = @(xy,th) xy(:,1)*cos(th)+xy(:,2)*sin(th);
rot_y = @(xy,th) -xy(:,1)*sin(th)+xy(:,2)*cos(th);

%% 图0：三维模型（汇报用）
if ~isempty(Model.stl_file)
    figure('Name','三维模型','Color','w','Position',[100,100,900,420]);
    view_list = [-35,25; 0,90]; % 斜视图、俯视图
    title_list = {'RADARSAT-1模型（NASA 3D Resources）','俯视图（xy平面，即ISAR成像平面）'};
    for k = 1:2
        subplot(1,2,k);
        patch('Faces',F_stl,'Vertices',V_stl,'FaceColor',[0.75,0.78,0.85],...
            'EdgeColor',[0.35,0.35,0.45],'LineWidth',0.1);
        axis equal; grid on; box on; view(view_list(k,:));
        camlight headlight; lighting gouraud;
        xlabel('x / m'); ylabel('y / m'); zlabel('z / m'); title(title_list{k});
    end
    print(gcf,'-dpng','-r300','figures/fig00_model_3d.png');
end

%% 图1：模型俯视图与雷达视线（雷达位于图的下方，与ISAR_RD.m一致）
figure('Name','模型俯视图与观测几何','Color','w','Position',[100,100,900,420]);
subplot(1,2,1); hold on;
plot(Model.outline_xy(:,1),Model.outline_xy(:,2),'b-','LineWidth',1.5);
% 雷达方向：从原点指向phi方向
phi_line = [phi_start_deg,phi_c_deg,phi_end_deg]*pi/180;
for k = 1:3
    plot([0,0.8*L*cos(phi_line(k))],[0,0.8*L*sin(phi_line(k))],'k--');
end
text(0.8*L*cos(phi_c_deg*pi/180),0.8*L*sin(phi_c_deg*pi/180),' 雷达方向');
plot(0,0,'r+','MarkerSize',10,'LineWidth',1.5); % 旋转中心
hold off; axis equal; grid on; box on;
xlim(0.65*L*[-1,1]); ylim(0.8*L*[-1,0.4]);
xlabel('x / m（FEKO全局坐标）'); ylabel('y / m');
title('目标坐标系（红十字为旋转中心）');
subplot(1,2,2);
% 中心视角下的ISAR坐标：目标顺时针转theta_c
plot(rot_x(Model.outline_xy,theta_c),rot_y(Model.outline_xy,theta_c),'b-','LineWidth',1.5);
axis equal; grid on; box on;
xlim(0.6*L*[-1,1]); ylim(0.6*L*[-1,1]);
xlabel('横向x / m'); ylabel('距离向y / m（远离雷达为正）');
title(sprintf('中心视角phi=%.0f°下的ISAR坐标（雷达在下方）',phi_c_deg));
print(gcf,'-dpng','-r300','figures/fig01_model_topview.png');
