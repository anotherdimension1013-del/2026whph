%{
%      生成FEKO格式的假数据(.ffe)：若干理想点散射体的单站后向散射场
%      目的：拿到真实FEKO数据之前，验证read_ffe.m与ISAR_FEKO.m的定标和正负号。
%      FEKO时间约定 e^{jwt}：远场 ~ e^{-jkr}/r，FEKO导出的是去掉e^{-jkr}/r后的 r*E。
%      平面波从雷达方向u照射（沿-u传播），在散射点r_p处的入射场相位为 e^{+jk u·r_p}；
%      散射场回到u方向再乘 e^{+jk u·r_p}，所以：
%          E(f,phi) = A * exp(+j*2*k*(u·r_p))，k=2*pi*f/c，u=(cos(phi),sin(phi),0)
%      令 phi=270°+theta，有 u·r_p = -(R-R0)，即 E = A*exp(-j*4*pi*f*(R-R0)/c)，
%      与ISAR_RD.m中的 Phase_a=exp(-j*4*pi*(R-R0)/lambda) 一致。
%      这里用精确公式（每个频点各自的k），不做小角度近似。
%}
clc; clear; close all;

%% 读取参数设计结果（频率、方位扫描与design_params.m完全一致）
if ~exist('design_params.mat','file'); design_params; close all; end
load('design_params.mat');

%% 点散射体：目标坐标系（FEKO全局坐标），每行[x(m)，y(m)，幅度]
% 位置取在卫星模型的典型散射中心上，并故意让幅度不对称，便于发现镜像翻转。
NPosition = [ 0.75,  0.00, 1.00;   % 右侧帆板-本体二面角（最强）
             -0.75,  0.00, 0.15;   % 左侧二面角（phi=300°时不在其反射区，弱）
              0.75, -0.75, 0.50;   % 本体角点（朝向雷达）
             -0.75, -0.75, 0.30;   % 本体角点
              0.75,  0.75, 0.30;   % 本体角点
              3.25,  0.00, 0.40;   % 右帆板端点
             -3.25,  0.00, 0.25;   % 左帆板端点
              0.00, -0.75, 0.35];  % 本体-y面中心（不对称校验点）
Ntarget = size(NPosition,1);
Position_x = NPosition(:,1);
Position_y = NPosition(:,2);
Position_Abs = NPosition(:,3);

%% 生成E(f,phi)
k_axis = 2*pi*f_axis(:)/c; % 列向量：各频点波数
phi_rad = phi_axis_deg*pi/180; % 行向量：各方位角
E_theta = complex(zeros(Nf,Naz));
for i = 1:Ntarget
    u_dot_r = Position_x(i)*cos(phi_rad)+Position_y(i)*sin(phi_rad); % 1×Naz
    E_theta = E_theta+Position_Abs(i)*exp(1j*2*k_axis*u_dot_r); % Nf×Naz
end
E_phi = complex(zeros(Nf,Naz)); % 点散射体不产生交叉极化
RCS_theta = 4*pi*abs(E_theta).^2; % 入射场幅度1 V/m时的RCS，m^2
RCS_phi = 4*pi*abs(E_phi).^2;

%% 按FEKO .ffe格式写文件：每个频点一个块
if ~exist('data','dir'); mkdir('data'); end
ffe_file = 'data/synthetic.ffe';
fid = fopen(ffe_file,'w');
fprintf(fid,'##File Type: Far field\n##File Format: 8\n##Source: synthetic\n');
fprintf(fid,'##Date: %s\n',datestr(now,'yyyy-mm-dd HH:MM:SS'));
fprintf(fid,'** 由make_synthetic_ffe.m生成的点散射体假数据\n\n');
for nf = 1:Nf
    fprintf(fid,'#Request Name: Monostatic\n');
    fprintf(fid,'#Frequency:   %.8E\n',f_axis(nf));
    fprintf(fid,'#Coordinate System: Spherical\n');
    fprintf(fid,'#No. of Theta Samples: 1\n#No. of Phi Samples: %d\n',Naz);
    fprintf(fid,'#Result Type: Radar cross section\n#No. of Header Lines: 1\n');
    fprintf(fid,'#%19s %18s %18s %18s %18s %18s %18s %18s %18s\n','"Theta"','"Phi"',...
        '"Re(Etheta)"','"Im(Etheta)"','"Re(Ephi)"','"Im(Ephi)"','"RCS(Theta)"','"RCS(Phi)"','"RCS(Total)"');
    for na = 1:Naz
        fprintf(fid,'%20.8E %18.8E %18.8E %18.8E %18.8E %18.8E %18.8E %18.8E %18.8E\n',...
            theta_inc_deg,phi_axis_deg(na),real(E_theta(nf,na)),imag(E_theta(nf,na)),...
            real(E_phi(nf,na)),imag(E_phi(nf,na)),RCS_theta(nf,na),RCS_phi(nf,na),...
            RCS_theta(nf,na)+RCS_phi(nf,na));
    end
    fprintf(fid,'\n');
end
fclose(fid);
save('data/synthetic_truth.mat','NPosition');
fprintf('已生成%s：%d个频点×%d个方位角，%d个点散射体\n',ffe_file,Nf,Naz,Ntarget);
