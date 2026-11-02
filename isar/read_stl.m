function [F,V] = read_stl(filename)
%READ_STL  读取二进制STL文件（不依赖工具箱，MATLAB与Octave通用）
%   [F,V] = read_stl(filename)
%   F：Ntri×3 三角形顶点索引；V：(3*Ntri)×3 顶点坐标（未合并重复顶点）
%   画图：patch('Faces',F,'Vertices',V,...)
fid = fopen(filename,'r');
if fid<0; error('read_stl：无法打开%s',filename); end
fread(fid,80,'uint8'); % 80字节文件头
Ntri = fread(fid,1,'uint32');
data = fread(fid,[12,Ntri],'12*float32',2); % 每个三角形：法向3 + 顶点9，后跟2字节属性
fclose(fid);
if size(data,2)~=Ntri
    error('read_stl：%s不是二进制STL，或文件不完整。',filename);
end
V = reshape(data(4:12,:),3,[]).'; % 去掉法向，按顶点排列
F = reshape(1:3*Ntri,3,[]).';
end
