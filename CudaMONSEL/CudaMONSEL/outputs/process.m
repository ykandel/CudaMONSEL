filename = 'data3.txt';
A = importdata(filename);
rs = 140;
SE = A(:, 5);
size(SE)
SE1 = reshape(SE, [rs, 42000/rs]).';
size(SE1);
imshow(SE1/max(SE));
% SE1(:, 1) - SE(1:80, 1)