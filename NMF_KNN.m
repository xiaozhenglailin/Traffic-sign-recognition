close all;
clear;
clc;

maxm = 145;
maxn = 426;
%读入训练集
[trainlist, traintype] = textread('./data/train.txt','%s%n');
Train = zeros(maxm * maxn, size(traintype, 1));
for i = 1 : size(traintype, 1)
    img_path = ['./data/', trainlist{i}];
    img = imread(img_path);
    img = rgb2gray(img);
    img = imresize(img, [maxm, maxn]);
    Train(:, i) = img(1 : maxm * maxn);
end

%读入测试集
[testlist, testtype] = textread('./data/test.txt','%s%n');
Test = zeros(maxm * maxn, size(testtype, 1));
for i = 1 : size(testtype, 1)
    img_path = ['./data/', testlist{i}];
    img = imread(img_path);
    img = rgb2gray(img);
    img = imresize(img, [maxm, maxn]);
    Test(:, i) = img(1 : maxm * maxn);
end

%读入开集
[neglist, negtype] = textread('./data/test_neg.txt','%s%n');
Neg = zeros(maxm * maxn, size(negtype, 1));
for i = 1 : size(negtype, 1)
    img_path = ['./data/', neglist{i}];
    img = imread(img_path);
    img = rgb2gray(img);
    img = imresize(img, [maxm, maxn]);
    Neg(:, i) = img(1 : maxm * maxn);
end

rn = randperm(size(negtype, 1)); 
Neg_train = Neg(:, rn(1 : floor(size(negtype, 1)/2)));
negtraintype = negtype(rn(1 : floor(size(negtype, 1)/2)));
Open = [Test Neg(:, rn(floor(size(negtype, 1)/2) + 1 : end))];
opentype = [testtype; negtype(rn(floor(size(negtype, 1)/2) + 1 : end))];

%% 训练
r = 80;
maxiter = 1000;
J = zeros(maxiter, 1);
Train = Train / max(Train(:));
W = abs(randn(maxm * maxn, r));                                          %非负初始化
H = abs(randn(r, size(traintype, 1)));
J(1) = 0.5 * sum(sum((Train - W * H).^2));                                     %代价函数为欧氏距离

for iter = 1: maxiter
    Wold = W;
    Hold = H;
    H = Hold.* ((Wold') * Train)./((Wold') * Wold * Hold + 1e-9);              %更新W和H
    W = Wold.* (Train * (H'))./(Wold * H * (H') + 1e-9);

    norms = sqrt(sum(H'.^2));                                              %归一化
    H = H./(norms'*ones(1, size(traintype, 1)));
    W = W.*(ones(maxm * maxn, 1)*norms);
    
    J(iter) = 0.5 * sum(sum(( Train - W * H).^2));                             %更新代价函数
end
% %绘出代价函数和特征
% figure;
% plot([1 : maxiter], J);
% figure;
% for i = 1 : r/2
%     subplot(5, 8, i);
%     im = reshape(W(:, i), maxm, maxn); 
%     imagesc(im);colormap('gray');  
% end
% suptitle('图2-NMF特征图像');

%% 测试集识别
%迭代，将测试数据表示为W基矢量的线性组合
Ht = abs(randn(r, size(testtype, 1)));
for iter = 1: maxiter
    Hold = Ht;
    Ht = Hold.* ((W') * Test)./((W') * W * Hold + 1e-9);                      %更新H

    norms = sqrt(sum(Ht'.^2));                                             %归一化
    Ht = Ht./(norms'*ones(1, size(testtype, 1)));
end
rec_V = W * H;
rec_T = W * Ht;                                                            %重构图

%识别
testtype_knn = zeros(size(testtype, 1), 1);
dist = zeros(1, size(traintype, 1));
dist_debug = zeros(1, size(testtype, 1));
for i = 1 : size(testtype, 1)
   for j = 1 : size(traintype, 1)
       dist(j) = norm(Ht(:, i) - H(:, j))^2;
   end
   [mindist index] = sort(dist);
%    %KNN，K=1
%    testtype_knn(i) = traintype(index(1));
%    dist_debug(i) = mindist(1);
%    %KNN，K=3
%    preindex = traintype(index(1:3));
%    for j = 1 : 3
%        count_preindex(j) = size(find(preindex == preindex(j)), 1);
%    end
%    maxindex = find(count_preindex == max(count_preindex));
%    testtype_knn(i) = preindex(maxindex(1));
   %KNN，K=5
   preindex = traintype(index(1:5));
   for j = 1 : 5
       count_preindex(j) = size(find(preindex == preindex(j)), 1);
   end
   maxindex = find(count_preindex == max(count_preindex));
   testtype_knn(i) = preindex(maxindex(1));
end

%评估
N = zeros(12, 12);
for i = 1 : 12
    for j = 1 : 12
       N(i, j) = size(find(testtype_knn(find(testtype == j)) == i), 1);
    end
end
ptp_i = zeros(12, 1);%每个类别的识别率
pfp_i = zeros(12, 1);%每个类别的虚警率
Nii_sum = 0;
Nij_sum = zeros(12, 1);
for i = 1 : 12
   Nii_sum = Nii_sum + N(i, i);
   ptp_i(i) = N(i, i)/size(find(testtype == i), 1); 
   for j = 1 : 12
      if i ~= j
          Nij_sum(i) = Nij_sum(i) + N(i, j);
      end
   end
   pfp_i(i) = Nij_sum(i)/size(find(testtype ~= i), 1);
end
ptp = Nii_sum/size(testtype, 1);%总体识别率
pfp = sum(Nij_sum)/(11 * size(testtype, 1));

%% 开集识别
%迭代，将测试数据表示为W基矢量的线性组合
Hn = abs(randn(r, size(negtraintype, 1)));
for iter = 1: maxiter
    Hold = Hn;
    Hn = Hold.* ((W') * Neg_train)./((W') * W * Hold + 1e-9);                      %更新H

    norms = sqrt(sum(Hn'.^2));                                             %归一化
    Hn = Hn./(norms'*ones(1, size(negtraintype, 1)));
end
rec_N = W * Hn;                                                            %重构图

negtraintype_knn = zeros(size(negtraintype, 1), 1);
negtraindist = zeros(1, size(traintype, 1));
negtraindist_debug = -1 * ones(1, 12);
for i = 1 : size(negtraintype, 1)
   for j = 1 : size(traintype, 1)
       negtraindist(j) = norm(Hn(:, i) - H(:, j))^2;
   end
   [mindist index] = sort(negtraindist);
%    %KNN，K=1   
%    negtraindist_debug(i) = mindist(1);
%    negtraintype_knn(i) = traintype(index(1));
%    %KNN，K=3
%    preindex = traintype(index(1:3));
%    for j = 1 : 3
%        count_preindex(j) = size(find(preindex == preindex(j)), 1);
%    end
%    maxindex = find(count_preindex == max(count_preindex));
%    negtype_knn(i) = preindex(maxindex(1));
%    negdist_debug(i) = mindist(maxindex(1));
   %KNN，K=5
   preindex = traintype(index(1:5));
   for j = 1 : 5
       count_preindex(j) = size(find(preindex == preindex(j)), 1);
   end
   maxindex = find(count_preindex == max(count_preindex));
   negtype_knn(i) = preindex(maxindex(1));
   negdist_debug(i) = mindist(maxindex(1));
end
th = -1 *ones(1, 12);
for i = 1 : 12
    temp = max(negtraindist_debug(find(negtraintype_knn == i))); 
    if size(temp, 2) ~= 0
        th(i) = temp(1);
    end
    
%     tempmax = max(negtraindist_debug(find(negtraintype_knn == i))); 
%     tempmin = min(negtraindist_debug(find(negtraintype_knn == i))); 
%     if size(tempmax, 2) ~= 0 && size(tempmin, 2) ~= 0
%         th(i) = (tempmax(1) + tempmin(1))/2;
%     end
end

%迭代，将测试数据表示为W基矢量的线性组合
Ho = abs(randn(r, size(opentype, 1)));
for iter = 1: maxiter
    Hold = Ho;
    Ho = Hold.* ((W') * Open)./((W') * W * Hold + 1e-9);                      %更新H

    norms = sqrt(sum(Ho'.^2));                                             %归一化
    Ho = Ho./(norms'*ones(1, size(opentype, 1)));
end
rec_O = W * Ho;                                                            %重构图

opentype_knn = zeros(size(opentype, 1), 1);
dist = zeros(1, size(traintype, 1));
opendist_debug = zeros(1, size(opentype, 1));
for i = 1 : size(opentype, 1)
   for j = 1 : size(traintype, 1)
       dist(j) = norm(Ho(:, i) - H(:, j))^2;
   end
   [mindist index] = sort(dist);
%    %KNN，K=1
%    if mindist(1) < th(traintype(index(1))) || th(traintype(index(1))) == -1
%        opentype_knn(i) = traintype(index(1));
%    else
%        opentype_knn(i) = 13;
%    end
%    opendist_debug(i) = mindist(1);
%    %KNN，K=3
%    preindex = traintype(index(1:3));
%    for j = 1 : 3
%        count_preindex(j) = size(find(preindex == preindex(j)), 1);
%    end
%    maxindex = find(count_preindex == max(count_preindex));
%    if mindist(maxindex(1)) < th(preindex(maxindex(1))) || th(preindex(maxindex(1))) == -1
%        opentype_knn(i) = preindex(maxindex(1));
%    else
%        opentype_knn(i) = 13;
%    end
   %KNN，K=5
   preindex = traintype(index(1:5));
   for j = 1 : 5
       count_preindex(j) = size(find(preindex == preindex(j)), 1);
   end
   maxindex = find(count_preindex == max(count_preindex));
   if mindist(maxindex(1)) < th(preindex(maxindex(1))) || th(preindex(maxindex(1))) == -1
       opentype_knn(i) = preindex(maxindex(1));
   else
       opentype_knn(i) = 13;
   end
end
%评估
Nopen = zeros(13, 13);
for i = 1 : 13
    for j = 1 : 13
       Nopen(i, j) = size(find(opentype_knn(find(opentype == j)) == i), 1);
    end
end
ptp_i_open = zeros(13, 1);%每个类别的识别率
pfp_i_open = zeros(13, 1);%每个类别的虚警率
Nii_sum_open = 0;
Nij_sum_open = zeros(13, 1);
for i = 1 : 13
   Nii_sum_open = Nii_sum_open + Nopen(i, i);
   ptp_i_open(i) = Nopen(i, i)/size(find(opentype == i), 1); 
   for j = 1 : 13
      if i ~= j
          Nij_sum_open(i) = Nij_sum_open(i) + Nopen(i, j);
      end
   end
   pfp_i_open(i) = Nij_sum_open(i)/size(find(opentype ~= i), 1);
end
ptp_open = Nii_sum_open/size(opentype, 1);%总体识别率
pfp_open = sum(Nij_sum_open)/(12 * size(opentype, 1));


