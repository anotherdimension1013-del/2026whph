%{
%      单频全方位RCS曲线（汇报用）
%      数据：FEKO单频（f0）、theta=90°、phi=0:0.5:359.5的单站扫描，导出为.ffe
%      输出：figures/fig07_rcs_360.png（直角坐标 + 极坐标）
%}
clc; clear; close all;

%% 选项
ffe_file = 'data/radarsat1_rcs360_Monostatic.ffe'; % 改成自己导出的文件名
E_comp = 'Etheta'; % 'Etheta'：VV；'Ephi'：HH
if ~exist('figures','dir'); mkdir('figures'); end

%% 读取并换算为dBsm（入射场幅度1 V/m）
[S_f_phi,f_axis,phi_axis_deg] = read_ffe(ffe_file,E_comp);
RCS_dBsm = 10*log10(4*pi*abs(S_f_phi(1,:)).^2+eps);

%% 图：RCS随方位角变化
figure('Name','全方位RCS','Color','w','Position',[100,100,1000,420]);
subplot(1,2,1);
plot(phi_axis_deg,RCS_dBsm,'LineWidth',1); grid on;
xlim([phi_axis_deg(1),phi_axis_deg(end)]);
set(gca,'XTick',0:45:360);
xlabel('方位角\phi / deg'); ylabel('RCS / dBsm');
title(sprintf('f=%.2f GHz，%s单站RCS',f_axis(1)/1e9,E_comp));
subplot(1,2,2);
% 极坐标：半径用(RCS-下限)，避免负值；不依赖polarplot，兼容旧版本
r_floor = max(RCS_dBsm)-50; % 显示下限：最大值以下50 dB
r = max(RCS_dBsm-r_floor,0);
phi_rad = phi_axis_deg*pi/180;
plot(r.*cos(phi_rad),r.*sin(phi_rad),'LineWidth',1); hold on;
for rr = 10:10:50 % 同心圆刻度
    plot(rr*cos(0:0.01:2*pi),rr*sin(0:0.01:2*pi),':','Color',[0.6,0.6,0.6]);
    text(rr,0,sprintf('%.0f',r_floor+rr),'FontSize',8);
end
hold off; axis equal; axis off;
title('极坐标（半径：dBsm；x轴为\phi=0°，逆时针增大）');
print(gcf,'-dpng','-r300','figures/fig07_rcs_360.png');

%% 打印峰值方位
[~,idx_pk] = sort(RCS_dBsm,'descend');
fprintf('RCS最大的几个方位角（deg）：%s\n',mat2str(phi_axis_deg(idx_pk(1:5))));
fprintf('平均RCS=%.1f dBsm，最大RCS=%.1f dBsm\n',10*log10(mean(10.^(RCS_dBsm/10))),max(RCS_dBsm));
