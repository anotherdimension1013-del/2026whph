function show_img(n_row,n_col,k,Image_dB,x_axis,y_axis,outline_xy,title_str,dynamic_range_dB,cmap,outline_color,lims)
%SHOW_IMG  统一风格显示一幅dB图像（目标坐标系，叠加模型轮廓）
subplot(n_row,n_col,k);
imagesc(x_axis,y_axis,Image_dB); axis xy; axis equal; axis tight;
hold on; plot(outline_xy(:,1),outline_xy(:,2),'-','Color',outline_color,'LineWidth',0.6); hold off;
colormap(cmap); caxis([-dynamic_range_dB,0]); colorbar;
if nargin>=12 && ~isempty(lims); xlim(lims(1:2)); ylim(lims(3:4)); end
xlabel('x / m'); ylabel('y / m'); title(title_str);
end
