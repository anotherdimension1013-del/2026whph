function [S_f_phi,f_axis,phi_axis_deg,info] = read_ffe(filename,E_comp)
%READ_FFE  读取FEKO远场文件(.ffe)，整理成单站复数散射场矩阵 S(频率, 方位角)
%   [S_f_phi,f_axis,phi_axis_deg,info] = read_ffe(filename,E_comp)
%   filename : .ffe文件名
%   E_comp   : 'Etheta'（VV）或 'Ephi'（HH）
%   S_f_phi  : Nf×Naz复数矩阵，行=频率，列=方位角（与ISAR_RD.m“距离向为行”一致）
%   f_axis   : 1×Nf 频率轴，Hz（升序）
%   phi_axis_deg : 1×Naz 方位角轴，deg（升序，跨越360°时自动展开）
%   info     : 文件头中的列名、俯仰角theta等
%
%   做法：逐行扫描。遇到“#Frequency:”记录当前频率；遇到含"Theta"的列名行，
%   按列名查找Theta、Phi、Re/Im(E分量)所在列（不写死列号）；其余数字行为数据。
%   不论FEKO把各方位角放在一个块还是多个块里，最后都按(频率,phi)重新排成矩阵。

if nargin<2; E_comp = 'Etheta'; end
txt = fileread(filename);
lines = regexp(txt,'\r?\n','split');

f_now = NaN; % 当前块的频率
col = []; % 当前块的列号：[Theta,Phi,Re(E),Im(E)]
col_names = {};
data = zeros(numel(lines),5); % 每行：[f,theta,phi,ReE,ImE]
n_data = 0;
for k = 1:numel(lines)
    s = strtrim(lines{k});
    if isempty(s); continue; end
    if strncmpi(s,'#Frequency:',11)
        f_now = str2double(strtrim(s(12:end)));
    elseif s(1)=='#' && ~isempty(strfind(s,'"Theta"'))
        % 列名行：所有带双引号的字段
        tok = regexp(s,'"([^"]+)"','tokens');
        col_names = cellfun(@(t) t{1},tok,'UniformOutput',false);
        name_want = {'Theta','Phi',['Re(',E_comp,')'],['Im(',E_comp,')']};
        col = zeros(1,4);
        for m = 1:4
            idx = find(strcmpi(col_names,name_want{m}),1);
            if isempty(idx)
                error('read_ffe：文件中找不到列"%s"。现有列：%s',name_want{m},strjoin(col_names,', '));
            end
            col(m) = idx;
        end
    elseif s(1)=='#' || s(1)=='*'
        continue; % 其他文件头/注释行
    else
        v = sscanf(s,'%f').';
        if isempty(col) || isnan(f_now) || numel(v)<max(col)
            error('read_ffe：第%d行数据出现在列名或频率之前，或列数不足。',k);
        end
        n_data = n_data+1;
        data(n_data,:) = [f_now,v(col)];
    end
end
data = data(1:n_data,:);
if n_data==0; error('read_ffe：文件中没有数据行。'); end

% 俯仰角theta应只有一个值（雷达在转台平面内）
theta_all = unique(round(data(:,2)*1e6)/1e6);
if numel(theta_all)>1
    error('read_ffe：检测到多个theta值(%s)，本程序只处理单一俯仰角的方位扫描。',mat2str(theta_all.'));
end

% 方位角：若扫描跨越0°/360°（如355°~5°），把0°之后的部分加360°展开。
% 判断方法：把角度看成圆周上的点，最大的空隙才是扫描的“起止缺口”；
% 若最大空隙不在360°->0°处，说明扫描跨过了0°。全方位扫描(0~359.5)不会被误展开。
phi = mod(round(data(:,3)*1e6)/1e6,360); % 去掉文本舍入误差，统一到[0,360)
phi_u = unique(phi);
gap = [diff(phi_u);phi_u(1)+360-phi_u(end)]; % 最后一项为跨越360°的空隙
[~,i_gap] = max(gap);
if i_gap<numel(phi_u)
    phi(phi<=phi_u(i_gap)) = phi(phi<=phi_u(i_gap))+360;
end
f = data(:,1);

[f_axis,~,i_f] = unique(f);
[phi_axis_deg,~,i_phi] = unique(phi);
Nf = numel(f_axis); Naz = numel(phi_axis_deg);
S_f_phi = complex(NaN(Nf,Naz),NaN(Nf,Naz));
S_f_phi(sub2ind([Nf,Naz],i_f,i_phi)) = data(:,4)+1j*data(:,5);
if any(isnan(S_f_phi(:)))
    error('read_ffe：(频率,方位角)网格不完整，缺少%d个点。',sum(isnan(S_f_phi(:))));
end
f_axis = f_axis.'; phi_axis_deg = phi_axis_deg.';

info.col_names = col_names;
info.theta_deg = theta_all;
info.E_comp = E_comp;
info.n_rows = n_data;
fprintf('read_ffe：%s，%d行数据 -> Nf=%d个频点 × Naz=%d个方位角，theta=%.2f°，分量%s\n',...
    filename,n_data,Nf,Naz,theta_all,E_comp);
end
