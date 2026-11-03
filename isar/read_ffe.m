function [S_f_phi,f_axis,phi_axis_deg,info] = read_ffe(filename,E_comp)
%READ_FFE  读取FEKO远场文件(.ffe)，整理成单站复数散射场矩阵 S(频率, 方位角)
%   [S_f_phi,f_axis,phi_axis_deg,info] = read_ffe(filename,E_comp)
%   filename : .ffe文件名
%   E_comp   : 'Etheta'（VV）或 'Ephi'（HH）
%   S_f_phi  : Nf×Naz复数矩阵，行=频率，列=方位角（与ISAR_RD.m“距离向为行”一致）
%   f_axis   : 1×Nf 频率轴，Hz（升序）
%   phi_axis_deg : 1×Naz 方位角轴，deg（升序，跨越360°时自动展开）
%   info     : 列名、俯仰角theta等
%
%   做法：先读列名行，按列名查找Theta、Phi、Re/Im(E分量)所在列（不写死列号）；
%   每个“#Frequency:”给出其后数据行的频率。不论FEKO把各方位角放在一个块还是多个块里，
%   最后都按(频率,phi)重新排成矩阵。所有数据行一次性解析，适合上百万行的大文件。
%   第一次读取后在同目录保存同名.mat缓存，文件未修改时直接加载缓存。

if nargin<2; E_comp = 'Etheta'; end
cache_file = [regexprep(filename,'\.ffe$',''),'_',E_comp,'.mat'];
d_ffe = dir(filename);
if isempty(d_ffe); error('read_ffe：找不到文件%s',filename); end
if exist(cache_file,'file')==2
    C = load(cache_file);
    if isfield(C,'ffe_bytes') && C.ffe_bytes==d_ffe.bytes
        S_f_phi = C.S_f_phi; f_axis = C.f_axis; phi_axis_deg = C.phi_axis_deg; info = C.info;
        fprintf('read_ffe：从缓存%s读取，Nf=%d × Naz=%d\n',cache_file,numel(f_axis),numel(phi_axis_deg));
        return;
    end
end

txt = fileread(filename);
lines = regexp(txt,'\r?\n','split');
clear txt;
lines = strtrim(lines);
lines = lines(~cellfun('isempty',lines));
first_char = cellfun(@(s) s(1),lines);

% 列名行：取第一个含"Theta"的#行（各块列名相同时只需解析一次）
is_hdr = first_char=='#' & ~cellfun('isempty',strfind(lines,'"Theta"'));
hdr_lines = unique(lines(is_hdr));
if numel(hdr_lines)~=1
    error('read_ffe：文件中各块的列名不一致（%d种），请检查导出设置。',numel(hdr_lines));
end
tok = regexp(hdr_lines{1},'"([^"]+)"','tokens');
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
n_col = numel(col_names);

% 频率行与数据行
is_freq = strncmpi(lines,'#Frequency:',11);
is_data = ~(first_char=='#' | first_char=='*');
f_val = cellfun(@(s) sscanf(s(12:end),'%f'),lines(is_freq));
% 每个数据行对应其前面最近的一个频率行
freq_id = cumsum(is_freq);
if any(freq_id(is_data)==0); error('read_ffe：数据行出现在第一个#Frequency之前。'); end
f_data = f_val(freq_id(is_data));
f_data = f_data(:);

% 一次性解析全部数据行
num = sscanf(strjoin(lines(is_data),' '),'%f');
n_data = sum(is_data);
if numel(num)~=n_data*n_col
    error('read_ffe：数据行列数与列名数(%d)不一致。',n_col);
end
num = reshape(num,n_col,n_data).';
data = [f_data,num(:,col)];

% 俯仰角theta应只有一个值
theta_all = unique(round(data(:,2)*1e6)/1e6);
if numel(theta_all)>1
    error('read_ffe：检测到多个theta值(%s)，本程序只处理单一俯仰角的方位扫描。',mat2str(theta_all.'));
end

% 方位角：若扫描跨越0°/360°（如355°~5°），把0°之后的部分加360°展开。
% 判断方法：把角度看成圆周上的点，最大的空隙才是扫描的“起止缺口”。
phi = mod(round(data(:,3)*1e6)/1e6,360);
phi_u = unique(phi);
gap = [diff(phi_u);phi_u(1)+360-phi_u(end)];
[~,i_gap] = max(gap);
if i_gap<numel(phi_u)
    phi(phi<=phi_u(i_gap)) = phi(phi<=phi_u(i_gap))+360;
end

[f_axis,~,i_f] = unique(data(:,1));
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
ffe_bytes = d_ffe.bytes;
save(cache_file,'S_f_phi','f_axis','phi_axis_deg','info','ffe_bytes');
end
