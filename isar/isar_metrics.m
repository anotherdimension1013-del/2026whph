function M = isar_metrics(Image_dB,x_axis,y_axis,outline_xy,thr_dB,r_cover,r_nms)
%ISAR_METRICS  ISAR图像的两个统一指标：散射中心个数、轮廓覆盖率
%   M = isar_metrics(Image_dB,x_axis,y_axis,outline_xy,thr_dB,r_cover)
%   Image_dB   : 归一化dB图像（最大值0 dB）
%   outline_xy : 模型俯视轮廓，N×2，多边形之间用NaN行分隔
%   thr_dB     : 散射中心门限，dB（如-15）
%   r_cover    : 覆盖半径，m（如0.5）
%   r_nms      : 合并半径，m（取该图像的分辨率）：间距小于r_nms的峰只保留最强的一个，
%                避免高分辨率方向上的旁瓣波纹被重复计数；缺省为0（不合并）
%   M.n_sc     : 散射中心个数 = 门限以上的局部峰值（3×3邻域最大）个数
%   M.coverage : 轮廓覆盖率 = 轮廓上（每0.05 m取一点）r_cover以内存在散射中心的比例
%   M.peaks    : [x, y, dB] 各散射中心，按强度降序
%   按“峰值”而不是“像素”统计，使指标不随分辨率改变（细分辨率的亮点更窄，像素更少）。

% 局部峰值（边界补-Inf，避免循环移位把对边当成邻居）
[ny,nx] = size(Image_dB);
P = -Inf(ny+2,nx+2); P(2:end-1,2:end-1) = Image_dB;
is_pk = Image_dB>=thr_dB;
for di = -1:1
    for dj = -1:1
        if di==0 && dj==0; continue; end
        is_pk = is_pk & Image_dB>=P((2:end-1)+di,(2:end-1)+dj);
    end
end
[XI,YI] = meshgrid(x_axis,y_axis);
pk = [XI(is_pk),YI(is_pk),Image_dB(is_pk)];
[~,order] = sort(pk(:,3),'descend');
pk = pk(order,:);
if nargin<7; r_nms = 0; end
if r_nms>0 && size(pk,1)>1 % 非极大值抑制：从强到弱，保留与已保留峰的距离都≥r_nms的峰
    keep = false(size(pk,1),1); keep(1) = true;
    for k = 2:size(pk,1)
        kept = pk(keep,1:2);
        keep(k) = all((kept(:,1)-pk(k,1)).^2+(kept(:,2)-pk(k,2)).^2>=r_nms^2);
    end
    pk = pk(keep,:);
end
M.peaks = pk;
M.n_sc = size(pk,1);

% 轮廓加密：每段按0.05 m插点
pts = zeros(0,2);
o = outline_xy;
for k = 1:size(o,1)-1
    if any(isnan(o(k,:))) || any(isnan(o(k+1,:))); continue; end
    seg_len = norm(o(k+1,:)-o(k,:));
    n = max(1,ceil(seg_len/0.05));
    t = (0:n-1).'/n;
    pts = [pts; o(k,:)+t*(o(k+1,:)-o(k,:))]; %#ok<AGROW>
end
if isempty(pk)
    M.coverage = 0;
else
    d2 = bsxfun(@minus,pts(:,1),pk(:,1).').^2+bsxfun(@minus,pts(:,2),pk(:,2).').^2;
    M.coverage = mean(min(d2,[],2)<=r_cover^2);
end
M.thr_dB = thr_dB; M.r_cover = r_cover;
end
