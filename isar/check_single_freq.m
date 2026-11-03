%{
%      单频试算数据的横向一维像检查（真实FEKO数据的横向定标与正负号验证）
%      数据：单个频点、一组方位角的单站散射场（试算得到的.ffe）
%      单频没有距离分辨能力，但对方位角做FFT即可得到横向一维像：x = lambda*f_theta/2。
%      RADARSAT-1的SAR天线由4段平板拼接（接缝在x=-7,-3.5,0,3.5,7 m，y≈-2.1 m），
%      斜视时平板中部的贡献相互抵消，回波主要来自各段平板边缘处感应电流的截断（物理光学的边缘贡献），
%      因此横向像的峰应出现在接缝/端点旋转到中心视角后的横向坐标处。
%      注：data/radarsat1_trial_10GHz.ffe 为测试B（关闭棱边绕射、射线密度Normal）的结果。
%      输出：figures/fig08_single_freq_xprofile.png
%}
clc; clear; close all;

%% 选项
ffe_file = 'data/radarsat1_trial_10GHz.ffe'; % 单频试算导出的.ffe
E_comp = 'Etheta'; % VV
x_joint = [-7,-3.5,0,3.5,7]; % 天线分段接缝/端点的x坐标，m（由STL读出）
y_antenna = -2.1; % 天线平板的y坐标，m
dynamic_range_dB = 40;

%% 读取与横向成像
c = 3e8;
[S_f_phi,f_axis,phi_axis_deg] = read_ffe(ffe_file,E_comp);
lambda = c/f_axis(1);
Naz = numel(phi_axis_deg);
delta_phi = mean(diff(phi_axis_deg))*pi/180;
theta_c = (mean(phi_axis_deg)-270)*pi/180; % 中心视角对应的目标转角
Wa = 0.5-0.5*cos(2*pi*(0:Naz-1)/(Naz-1)); % Hann窗
Nfft_a = 2^nextpow2(16*Naz);
S_x = fftshift(fft(S_f_phi(1,:).*Wa,Nfft_a));
f_theta = (-Nfft_a/2:Nfft_a/2-1)/(Nfft_a*delta_phi); % 角频率，周/rad
cross_range_axis = lambda*f_theta/2; % 横向轴，m
profile_dB = 20*log10(abs(S_x)/max(abs(S_x))+eps);

%% 理论位置：接缝点顺时针转theta_c后的横向坐标（同ISAR_RD.m的转动公式）
x_pred = x_joint*cos(theta_c)+y_antenna*sin(theta_c);
x_mirror = -x_pred; % 若发生镜像，峰会出现在这里

%% 画图
D = load('design_params.mat','Model');
o = D.Model.outline_xy;
x_model = o(:,1)*cos(theta_c)+o(:,2)*sin(theta_c);
figure('Name','单频横向像','Color','w','Position',[100,100,900,380]);
plot(cross_range_axis,profile_dB,'LineWidth',1.2); hold on;
plot(x_pred,zeros(size(x_pred)),'kv','MarkerFaceColor','k','MarkerSize',7);
plot(x_mirror,-dynamic_range_dB*ones(size(x_mirror))+2,'r^','MarkerSize',7);
plot(min(x_model)*[1,1],[-dynamic_range_dB,0],'r--',max(x_model)*[1,1],[-dynamic_range_dB,0],'r--');
hold off; grid on;
xlim(0.9*max(abs(x_model))*[-1.4,1.4]); ylim([-dynamic_range_dB,3]);
xlabel('横向x / m'); ylabel('归一化幅度 / dB');
title(sprintf('真实FEKO数据：f=%.0f GHz单频横向像（%d个方位角，\\phi_c=%.1f°）',f_axis(1)/1e9,Naz,mean(phi_axis_deg)));
legend({'横向像','天线接缝理论位置','若镜像应出现的位置','模型横向范围'},'Location','southoutside','Orientation','horizontal');
print(gcf,'-dpng','-r300','figures/fig08_single_freq_xprofile.png');

%% 打印核验
fprintf('横向分辨率约%.2f m（矩形窗），Hann窗主瓣约展宽1.6倍\n',lambda/(2*Naz*delta_phi));
fprintf('接缝理论横向位置：%s m\n',mat2str(round(x_pred*100)/100));
