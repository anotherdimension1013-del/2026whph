%{
%      汇报用的三组对比实验：俯仰角、子孔径融合、分辨率
%      数据：E0（ε=0°，0.3 m，单孔径，已完成）
%            A （ε=30°，0.3 m子孔径，方位扫描60°）
%            B （ε=30°，0.15 m，单孔径12.5°）
%      成像：统一用后向投影（bp_image.m）在目标坐标系的水平面上成像，避免算法差异混入对比；
%            融合：60°数据按子孔径（6.3°，50%重叠）分别成像，各自按最大值归一化后逐像素平均：
%            算术平均——任一角度出现过的散射都会保留，但个别角度的强镜面闪光会留下拖影；
%            几何平均（对数域平均）——保留在多数角度都持续存在的散射中心，抑制只在个别角度出现的闪光。
%      指标：散射中心个数（间距小于该图分辨率的峰合并）、轮廓覆盖率（isar_metrics.m）、
%            平均光斑面积（spot_area.m，最强20个点的-3 dB面积平均，统一在0.05 m网格上计算，越小越清晰）、-3 dB点宽度；
%            图像熵只记录在表中：散射中心越多熵越大，不适合衡量“能否看出形状”。
%      输出：figures/fig_p07_elevation.png、fig_p08_fusion.png、fig_p09_resolution.png、
%            fig_p10_scattering.png，以及results_metrics.md。
%      坐标约定与ISAR_RD.m、ISAR_FEKO.m一致（FEKO中phi=270°+转角，e^{jwt}约定，无需取共轭）。
%}
clc; clear; close all;
% 切换到本脚本所在文件夹：保证函数和model、data、figures等相对路径都能找到
script_dir = fileparts(mfilename('fullpath'));
if ~isempty(script_dir); cd(script_dir); addpath(script_dir); end

%% 选项
data_source = 'feko'; % 'feko'：FEKO计算A、B的结果；'po'：简化PO预览数据（仅用于调试流程）
E_comp = 'Etheta'; % VV
phi_c_deg = 300; % 中心方位角，deg
theta_sub_deg = 6.3; % 子孔径转角，deg（ε=30°时对应0.3 m横向分辨率）
thr_dB = -15; % 散射中心门限，dB
r_cover = 0.5; % 轮廓覆盖半径，m
dynamic_range_dB = 25; % 显示动态范围，dB
cmap = hot(256); outline_color = [0.3,0.85,1];
lims = [-8.7,8.7,-4,3.5]; % 显示窗口[x1,x2,y1,y2]，m：只显示卫星所在区域
t_E0_min = 31; % FEKO用时，min（E0实测）
t_A_h = NaN; t_B_h = NaN; % FEKO用时，h（计算A、B完成后填入）

switch data_source
    case 'feko'
        file_A = 'data/radarsat1_A.ffe'; file_B = 'data/radarsat1_B.ffe'; fig_tag = '';
    case 'po'
        file_A = 'data/po_A.ffe'; file_B = 'data/po_B.ffe'; fig_tag = '_po';
    otherwise
        error('data_source只能是feko或po。');
end
file_E0 = 'data/radarsat1_C_low.ffe';
if ~exist('figures','dir'); mkdir('figures'); end

%% 模型轮廓：ε=0°用水平投影；ε=30°用计入叠掩的投影（高度z的点沿雷达方向平移z·tanε）
D = load('design_params.mat','Model');
outline_0 = D.Model.outline_xy;
outline_30 = load('model/radarsat1_outline_eps30_phi300.txt'); % tools/make_outline.py ... 30 300

%% 读取数据
[S_E0,f_E0,phi_E0,info_E0] = read_ffe(file_E0,E_comp);
[S_A,f_A,phi_A,info_A] = read_ffe(file_A,E_comp);
[S_B,f_B,phi_B,info_B] = read_ffe(file_B,E_comp);
eps_E0 = 90-info_E0.theta_deg; eps_A = 90-info_A.theta_deg; eps_B = 90-info_B.theta_deg;
c = 3e8;
rho_of = @(f,phi_deg,ep) [c/(2*numel(f)*mean(diff(f))*cosd(ep)), ...
    c/mean(f)/(2*numel(phi_deg)*mean(diff(phi_deg))*pi/180*cosd(ep))]; % [距离,横向]分辨率

%% 成像网格（目标坐标系，m）
x_axis = -9:0.05:9; y_axis = -6:0.05:6; % 0.3 m图像
x_fine = -9:0.025:9; y_fine = -6:0.025:6; % 0.15 m图像
x_coh = -8.5:0.015:8.5; y_coh = -4:0.015:3.5; % 60°整段相干图像（横向分辨率约3 cm）
to_dB = @(I) 20*log10(abs(I)/max(abs(I(:)))+eps);

%% 1) E0：ε=0°，全部92个角度
tic;
Image_E0 = to_dB(bp_image(S_E0,f_E0,phi_E0,eps_E0,1:numel(phi_E0),x_axis,y_axis));
M_E0 = isar_metrics(Image_E0,x_axis,y_axis,outline_0,thr_dB,r_cover,0.3);
rho_E0 = rho_of(f_E0,phi_E0,eps_E0);

%% 2) A：中间子孔径、60°整段相干、子孔径融合
delta_phi_A = mean(diff(phi_A));
n_sub = round(theta_sub_deg/delta_phi_A)+1; % 子孔径角度数
idx_c = find(abs(phi_A-phi_c_deg)<=theta_sub_deg/2+1e-9);
Image_Ac = to_dB(bp_image(S_A,f_A,phi_A,eps_A,idx_c,x_axis,y_axis));
M_Ac = isar_metrics(Image_Ac,x_axis,y_axis,outline_30,thr_dB,r_cover,0.3);
rho_Ac = rho_of(f_A,phi_A(idx_c),eps_A);

Image_Acoh = to_dB(bp_image(S_A,f_A,phi_A,eps_A,1:numel(phi_A),x_coh,y_coh));
M_Acoh = isar_metrics(Image_Acoh,x_coh,y_coh,outline_30,thr_dB,r_cover,0.3); % 距离分辨率0.3 m

sub_start = 1:floor(n_sub/2):(numel(phi_A)-n_sub+1); % 50%重叠
P_mean = zeros(numel(y_axis),numel(x_axis)); % 算术平均
logP_mean = zeros(numel(y_axis),numel(x_axis)); % 对数域平均（几何平均）
P_floor = 10^(-40/10); % 对数前的下限，避免log(0)
for k = 1:numel(sub_start)
    P_k = abs(bp_image(S_A,f_A,phi_A,eps_A,sub_start(k)+(0:n_sub-1),x_axis,y_axis)).^2;
    P_k = P_k/max(P_k(:)); % 各子孔径先按自身最大值归一化
    P_mean = P_mean+P_k/numel(sub_start);
    logP_mean = logP_mean+log(P_k+P_floor)/numel(sub_start);
end
Image_Amean = 10*log10(P_mean/max(P_mean(:))+eps);
P_geo = exp(logP_mean);
Image_Afu = 10*log10(P_geo/max(P_geo(:))+eps); % 默认融合结果：几何平均
M_Amean = isar_metrics(Image_Amean,x_axis,y_axis,outline_30,thr_dB,r_cover,0.3);
M_Afu = isar_metrics(Image_Afu,x_axis,y_axis,outline_30,thr_dB,r_cover,0.3);

%% 3) B：ε=30°，0.15 m单孔径
Image_B = to_dB(bp_image(S_B,f_B,phi_B,eps_B,1:numel(phi_B),x_fine,y_fine));
M_B = isar_metrics(Image_B,x_fine,y_fine,outline_30,thr_dB,r_cover,0.15);
rho_B = rho_of(f_B,phi_B,eps_B);
fprintf('成像完成，用时%.1f s\n',toc);
in_x = x_axis>=lims(1) & x_axis<=lims(2); in_y = y_axis>=lims(3) & y_axis<=lims(4);
crop = @(I) I(in_y,in_x);
M_E0.entropy = image_entropy(crop(Image_E0));
M_Ac.entropy = image_entropy(crop(Image_Ac));
M_Amean.entropy = image_entropy(crop(Image_Amean));
M_Afu.entropy = image_entropy(crop(Image_Afu));
M_Acoh.entropy = image_entropy(crop(bin_power(Image_Acoh,x_coh,y_coh,x_axis,y_axis)));
M_B.entropy = image_entropy(crop(bin_power(Image_B,x_fine,y_fine,x_axis,y_axis)));
% 平均光斑面积：最强20个散射中心的-3 dB面积平均（清晰度；拖影越多面积越大）
n_top = 20;
M_E0.spot = spot_area(Image_E0,x_axis,y_axis,M_E0.peaks,n_top);
M_Ac.spot = spot_area(Image_Ac,x_axis,y_axis,M_Ac.peaks,n_top);
M_Amean.spot = spot_area(Image_Amean,x_axis,y_axis,M_Amean.peaks,n_top);
M_Afu.spot = spot_area(Image_Afu,x_axis,y_axis,M_Afu.peaks,n_top);
% 细网格图像先按功率平均到同一0.05 m网格，避免整段相干图像的细密条纹把拖影“切碎”
Image_Acoh_q = bin_power(Image_Acoh,x_coh,y_coh,x_axis,y_axis);
Image_B_q = bin_power(Image_B,x_fine,y_fine,x_axis,y_axis);
M_Acoh.spot = spot_area(Image_Acoh_q,x_axis,y_axis,isar_metrics(Image_Acoh_q,x_axis,y_axis,outline_30,thr_dB,r_cover,0.3).peaks,n_top);
M_B.spot = spot_area(Image_B_q,x_axis,y_axis,isar_metrics(Image_B_q,x_axis,y_axis,outline_30,thr_dB,r_cover,0.15).peaks,n_top);

%% -3 dB点宽度：取A中间子孔径的最强点，在B中找0.5 m以内的对应峰值
pk_A = M_Ac.peaks(1,1:2);
d2 = sum(bsxfun(@minus,M_B.peaks(:,1:2),pk_A).^2,2);
[d_min,i_B] = min(d2);
if sqrt(d_min)>0.5; warning('B中0.5 m以内没有找到与A最强点对应的峰值。'); end
pk_B = M_B.peaks(i_B,1:2);
width_A = peak_width(Image_Ac,x_axis,y_axis,pk_A);
width_B = peak_width(Image_B,x_fine,y_fine,pk_B);

%% 图p07：俯仰角对比（E0 vs A中间子孔径）
fig_titles = {sprintf('ε=0°：%d个散射中心，轮廓覆盖率%.0f%%',M_E0.n_sc,100*M_E0.coverage), ...
              sprintf('ε=30°：%d个散射中心，轮廓覆盖率%.0f%%',M_Ac.n_sc,100*M_Ac.coverage)};
figure('Name','俯仰角对比','Color','w','Position',[50,50,1200,430]);
show_img(1,2,1,Image_E0,x_axis,y_axis,outline_0,fig_titles{1},dynamic_range_dB,cmap,outline_color,lims);
show_img(1,2,2,Image_Ac,x_axis,y_axis,outline_30,fig_titles{2},dynamic_range_dB,cmap,outline_color,lims);
print(gcf,'-dpng','-r300',['figures/fig_p07_elevation',fig_tag,'.png']);

%% 图p08：融合对比（单孔径 / 整段相干 / 算术平均融合 / 几何平均融合）
mtxt = @(M) sprintf('%d个，覆盖%.0f%%，光斑%.2f m^2',M.n_sc,100*M.coverage,M.spot);
figure('Name','子孔径融合','Color','w','Position',[50,50,1250,700]);
show_img(2,2,1,Image_Ac,x_axis,y_axis,outline_30,['单个子孔径：',mtxt(M_Ac)],dynamic_range_dB,cmap,outline_color,lims);
show_img(2,2,2,Image_Acoh,x_coh,y_coh,outline_30,['60°整段相干：',mtxt(M_Acoh)],dynamic_range_dB,cmap,outline_color,lims);
show_img(2,2,3,Image_Amean,x_axis,y_axis,outline_30,['算术平均融合：',mtxt(M_Amean)],dynamic_range_dB,cmap,outline_color,lims);
show_img(2,2,4,Image_Afu,x_axis,y_axis,outline_30,['几何平均融合：',mtxt(M_Afu)],dynamic_range_dB,cmap,outline_color,lims);
print(gcf,'-dpng','-r300',['figures/fig_p08_fusion',fig_tag,'.png']);

%% 图p09：分辨率对比（上：全图；下：最强点局部放大）
figure('Name','分辨率对比','Color','w','Position',[50,50,1200,820]);
show_img(2,2,1,Image_Ac,x_axis,y_axis,outline_30,...
    sprintf('%.2f m：%d个，%.0f%%',mean(rho_Ac),M_Ac.n_sc,100*M_Ac.coverage),dynamic_range_dB,cmap,outline_color,lims);
show_img(2,2,2,Image_B,x_fine,y_fine,outline_30,...
    sprintf('%.2f m：%d个，%.0f%%',mean(rho_B),M_B.n_sc,100*M_B.coverage),dynamic_range_dB,cmap,outline_color,lims);
zw = 1.0; % 放大窗口半宽，m
show_img(2,2,3,Image_Ac,x_axis,y_axis,outline_30,...
    sprintf('局部放大：-3 dB宽度 %.2f×%.2f m',width_A),dynamic_range_dB,cmap,outline_color,lims);
xlim(pk_A(1)+zw*[-1,1]); ylim(pk_A(2)+zw*[-1,1]);
show_img(2,2,4,Image_B,x_fine,y_fine,outline_30,...
    sprintf('局部放大：-3 dB宽度 %.2f×%.2f m',width_B),dynamic_range_dB,cmap,outline_color,lims);
xlim(pk_A(1)+zw*[-1,1]); ylim(pk_A(2)+zw*[-1,1]);
print(gcf,'-dpng','-r300',['figures/fig_p09_resolution',fig_tag,'.png']);

%% 图p10：散射机理（融合图上标出最强的散射中心，并按位置归属部件）
% 部件区域（目标坐标系，近似）：SAR天线 y<-1.75；桁架 -1.75≤y<-0.7且|x|>1.0；
% 本体 |x|≤1.2；太阳翼 |x|>1.5且y≥-0.7。ε=30°有叠掩，归属仅作参考。
n_label = min(10,M_Afu.n_sc);
pk = M_Afu.peaks(1:n_label,:);
part = cell(n_label,1);
for k = 1:n_label
    xk = pk(k,1); yk = pk(k,2);
    if yk<-1.75
        part{k} = 'SAR天线';
    elseif yk<-0.7 && abs(xk)>1.0
        part{k} = '天线桁架';
    elseif abs(xk)<=1.2
        part{k} = '本体';
    elseif abs(xk)>1.5
        part{k} = '太阳翼';
    else
        part{k} = '连接结构';
    end
end
figure('Name','散射机理','Color','w','Position',[50,50,900,520]);
show_img(1,1,1,Image_Afu,x_axis,y_axis,outline_30,'几何平均融合图像中的主要散射中心',dynamic_range_dB,cmap,outline_color,lims);
hold on;
for k = 1:n_label
    plot(pk(k,1),pk(k,2),'o','Color',[0.2,1,0.4],'MarkerSize',9,'LineWidth',1.2);
    text(pk(k,1)+0.25,pk(k,2)+0.25,sprintf('%d',k),'Color',[0.2,1,0.4],'FontSize',11,'FontWeight','bold');
end
hold off;
print(gcf,'-dpng','-r300',['figures/fig_p10_scattering',fig_tag,'.png']);

%% 指标表
row = @(name,rho,M,w,t) sprintf('| %s | %.2f m | %d | %.0f%% | %.2f m² | %.2f | %s | %s |\n',name,rho,M.n_sc,100*M.coverage,M.spot,M.entropy,w,t);
fid = fopen(['results_metrics',fig_tag,'.md'],'w');
fprintf(fid,'数据来源：%s；散射中心门限%d dB，覆盖半径%.1f m\n\n',data_source,thr_dB,r_cover);
fprintf(fid,'| 图像 | 分辨率 | 散射中心个数 | 轮廓覆盖率 | 平均光斑面积 | 图像熵 | -3 dB点宽度 | FEKO用时 |\n|---|---|---|---|---|---|---|---|\n');
fprintf(fid,'%s',row('E0：ε=0°，单孔径',mean(rho_E0),M_E0,'—',sprintf('%d min',t_E0_min)));
fprintf(fid,'%s',row('A：ε=30°，单个子孔径',mean(rho_Ac),M_Ac,sprintf('%.2f×%.2f m',width_A),sprintf('%.1f h（A整体）',t_A_h)));
fprintf(fid,'%s',row('A：60°整段相干',NaN,M_Acoh,'—','同上'));
fprintf(fid,'%s',row('A：算术平均融合',mean(rho_Ac),M_Amean,'—','同上'));
fprintf(fid,'%s',row('A：几何平均融合',mean(rho_Ac),M_Afu,'—','同上'));
fprintf(fid,'%s',row('B：ε=30°，单孔径',mean(rho_B),M_B,sprintf('%.2f×%.2f m',width_B),sprintf('%.1f h',t_B_h)));
fprintf(fid,'\n散射中心（融合图，按强度排序）：\n\n| 编号 | x / m | y / m | 相对强度 / dB | 所属部件（按位置） |\n|---|---|---|---|---|\n');
for k = 1:n_label
    fprintf(fid,'| %d | %.2f | %.2f | %.1f | %s |\n',k,pk(k,1),pk(k,2),pk(k,3),part{k});
end
fclose(fid);
type(['results_metrics',fig_tag,'.md']);
