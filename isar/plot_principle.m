%{
%      汇报第3页：转台等效示意图
%      左：目标绕z轴顺时针转动 <=> 目标不动、雷达逆时针绕目标转（FEKO中phi=270°+转角）
%      右：每个(频率f, 方位角phi)对应空间频率平面上的一点 K=4*pi*f/c，方向为雷达方向，
%          全部数据排成扇形（极坐标格式）；RD把它近似成矩形，PFA把它插值到矩形网格。
%      右图为示意，夸大了转角和带宽，使扇形的弯曲肉眼可见。
%      输出：figures/fig_p03_turntable.png
%}
clc; clear; close all;
script_dir = fileparts(mfilename('fullpath'));
if ~isempty(script_dir); cd(script_dir); addpath(script_dir); end
if ~exist('figures','dir'); mkdir('figures'); end
D = load('design_params.mat','Model');
o = D.Model.outline_xy;
blue = [0.15,0.35,0.75]; red = [0.85,0.2,0.15]; grey = [0.5,0.5,0.5];

figure('Name','转台等效','Color','w','Position',[50,50,1200,500]);

%% 左：转台等效
subplot(1,2,1); hold on;
plot(o(:,1),o(:,2),'-','Color',blue,'LineWidth',1.2);
% 目标顺时针转动箭头
t = linspace(100,20,40)*pi/180; r0 = 9.5;
plot(r0*cos(t),r0*sin(t),'-','Color',grey,'LineWidth',1.5);
quiver(r0*cos(t(end-1)),r0*sin(t(end-1)),r0*(cos(t(end))-cos(t(end-1))),r0*(sin(t(end))-sin(t(end-1))),...
    0,'Color',grey,'MaxHeadSize',8,'LineWidth',1.5);
text(-1.5,11,'目标顺时针转动','Color',grey,'FontSize',11);
% 雷达沿圆弧逆时针扫描（示意范围）
R_rad = 14; phi_r = (250:5:350)*pi/180;
plot(R_rad*cos(phi_r),R_rad*sin(phi_r),':','Color',red,'LineWidth',1);
phi_s = [270,300,330]*pi/180;
for k = 1:numel(phi_s)
    plot(R_rad*cos(phi_s(k)),R_rad*sin(phi_s(k)),'^','Color',red,'MarkerFaceColor',red,'MarkerSize',9);
    plot([0,0.92*R_rad*cos(phi_s(k))],[0,0.92*R_rad*sin(phi_s(k))],'--','Color',red,'LineWidth',0.6);
end
text(R_rad*cos(phi_s(3))+0.6,R_rad*sin(phi_s(3)),'雷达（\phi 扫描）','Color',red,'FontSize',11);
text(-15.5,-15.5,'等效：目标不动，雷达逆时针绕目标转','Color',red,'FontSize',11);
hold off; axis equal; box on; grid on;
xlim([-17,17]); ylim([-17,13]);
xlabel('x / m'); ylabel('y / m'); title('转台等效：FEKO扫描方位角 \phi = 目标转动');

%% 右：空间频率平面上的扇形数据（示意）
subplot(1,2,2); hold on;
c = 3e8; f0_demo = 5.3e9; B_demo = 2.2e9; theta_demo = 40; % 夸大的带宽与转角
f_demo = linspace(f0_demo-B_demo/2,f0_demo+B_demo/2,9);
th_demo = linspace(-theta_demo/2,theta_demo/2,11)*pi/180;
[TH,FF] = meshgrid(th_demo,f_demo);
K = 4*pi*FF/c;
Kx = K.*sin(TH); Ky = K.*cos(TH); % 雷达方向以中心视角为参考：横向Kx，距离向Ky
plot(Kx(:),Ky(:),'o','Color',blue,'MarkerFaceColor',blue,'MarkerSize',4);
plot(Kx.',Ky.','-','Color',[0.6,0.7,0.9]); % 等频率弧
plot(Kx,Ky,'-','Color',[0.6,0.7,0.9]); % 等角度射线
% PFA的内接矩形
Kmin = min(K(:)); Kmax = max(K(:));
kx1 = Kmin*sin(th_demo(end)); ky1 = Kmin*cos(0)*1; ky2 = sqrt(Kmax^2-kx1^2);
plot([-kx1,kx1,kx1,-kx1,-kx1],[ky1,ky1,ky2,ky2,ky1],'--','Color',red,'LineWidth',1.5);
text(-kx1,ky2+18,'PFA：插值到矩形网格后做二维FFT','Color',red,'FontSize',11);
text(max(Kx(:))+4,max(Ky(:,end))-20,{'频率 \rightarrow 半径','K = 4\pi f/c'},'Color',blue,'FontSize',11);
text(-max(Kx(:)),min(Ky(:))-12,'方位角 \rightarrow 方向','Color',blue,'FontSize',11);
hold off; axis equal; box on; grid on; xlim([-105,150]);
xlabel('横向空间频率 K_x / (rad/m)'); ylabel('距离向空间频率 K_y / (rad/m)');
title('数据在空间频率平面上排成扇形（示意，夸大了转角与带宽）');
print(gcf,'-dpng','-r300','figures/fig_p03_turntable.png');
