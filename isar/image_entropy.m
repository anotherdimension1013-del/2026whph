function H = image_entropy(Image_dB)
%IMAGE_ENTROPY  ISAR图像熵（聚焦质量指标）：熵越小，能量越集中在少数清晰的散射点上
%   p = |I|^2/sum|I|^2，H = -sum(p*ln p)。不同图像必须在同一网格、同一区域上比较。
P = 10.^(Image_dB(:)/10);
p = P/sum(P);
p = p(p>0);
H = -sum(p.*log(p));
end
