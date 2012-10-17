function rtn = run_mdensMMCRF()

% add path of libsvm
addpath '~/softwares/libsvm-3.12/matlab/'
rand('twister', 0);

% actual running
% for name={'emotions','yeast','scene','enron','cal500','fp','cancer','medical','toy10','toy50'}
% X=dlmread(sprintf('/fs/group/urenzyme/workspace/data/%s_features',name{1}));
% Y=dlmread(sprintf('/fs/group/urenzyme/workspace/data/%s_targets',name{1}));

% simulate testing
for name={'toy10'}
X=dlmread(sprintf('./test_data/%s_features',name{1}));
Y=dlmread(sprintf('./test_data/%s_targets',name{1}));

% example selection with meaningful features
Xsum=sum(X,2);
X=X(find(Xsum~=0),:);
Y=Y(find(Xsum~=0),:);

% feature normalization (tf-idf for text data, scale and centralization for other numerical features)
if or(strcmp(name{1},'medical'),strcmp(name{1},'enron')) 
    X=tfidf(X);
elseif ~(strcmp(name{1}(1:2),'to'))
    X=(X-repmat(min(X),size(X,1),1))./repmat(max(X)-min(X),size(X,1),1);
end

% change Y from -1 to 0: labeling (0/1)
Y(Y==-1)=0;

% length of x and y
Nx = length(X(:,1));
Ny = length(Y(1,:));

% stratified cross validation index
nfold = 3;
Ind = getCVIndex(Y,nfold);

% performance
perf=[];

% get dot product kernels from normalized features or just read precomputed kernels
if or(strcmp(name{1},'fp'),strcmp(name{1},'cancer'))
    K=dlmread(sprintf('/fs/group/urenzyme/workspace/data/%s_kernel',name{1}));
else
    K = X * X'; % dot product
    K = K ./ sqrt(diag(K)*diag(K)');    %normalization diagonal is 1
end

%------------
%
% SVM, single label        
%
%------------
if 1==0
Ypred = [];
YpredVal = [];
% iterate on targets (Y1 -> Yx -> Ym)
for i=1:Ny
    % nfold cross validation
    Ycol = [];
    YcolVal = [];
    for k=1:nfold
        Itrain = find(Ind ~= k);
        Itest  = find(Ind == k);
        % training & testing with kernel
        if strcmp(name{1}(1:2),'to')
                svm_c=0.01;
        elseif strcmp(name{1},'cancer')
                svm_c=5
        else
                svm_c=0.5;
        end
        model = svmtrain(Y(Itrain,i),[(1:numel(Itrain))',K(Itrain,Itrain)],sprintf('-b 1 -q -c %.2f -t 4',svm_c));
        [Ynew,acc,YnewVal] = svmpredict(Y(Itest,k),[(1:numel(Itest))',K(Itest,Itrain)],model,'-b 1');
        [Ynew] = svmpredict(Y(Itest,i),[(1:numel(Itest))',K(Itest,Itrain)],model);
        Ycol = [Ycol;[Ynew,Itest]];
        if size(YnewVal,2)==2
            YcolVal = [YcolVal;[YnewVal(:,abs(model.Label(1,:)-1)+1),Itest]];
        else
            YcolVal = [YcolVal;[zeros(numel(Itest),1),Itest]];
        end
    end
    Ycol = sortrows(Ycol,size(Ycol,2));
    Ypred = [Ypred,Ycol(:,1)];
    YcolVal = sortrows(YcolVal,size(YcolVal,2));
    YpredVal = [YpredVal,YcolVal(:,1)];
end
% performance of svm
[ax,ay,t,auc]=perfcurve(reshape(Y,1,numel(Y)),reshape(YpredVal,1,numel(Y)),1);
[acc,vecacc,pre,rec,f1]=get_performance(Y,Ypred);
perf=[perf;[acc,vecacc,pre,rec,f1,auc]];perf
end
svm_c=0.01;



%------------
%
% wensMMCRF      
%
%------------
global Kx_tr;
global Kx_ts;
global Y_tr;
global Y_ts;
global E;
global debugging;
global params;
% set parameters
params.mlloss = 1;	% assign loss to microlabels or edges
params.profiling = 1;	% profile (test during learning)
params.epsilon = 0.8; %0.6;	% stopping criterion: minimum relative duality gap
params.C =svm_c ;		% margin slack
params.max_CGD_iter = 1;		% maximum number of conditional gradient iterations per example
params.max_LBP_iter = 2;		% number of Loopy belief propagation iterations
params.tolerance = 1E-10;		% numbers smaller than this are treated as zero
params.filestem = 'tmpmmcrf';		% file name stem used for writing output
params.profile_tm_interval = 10;	% how often to test during learning
params.maxiter = 10;		% maximum number of iterations in the outer loop
params.verbosity = 1;
params.debugging = 0;

if 1==0
    % random seed
    rand('twister', 0);
    % generate random graph
    Nrep=60;
    muList=cell(Nrep,1);
    Nnode=size(Y,2);
    Elist=cell(Nrep,1);
    for i=1:Nrep
        E=randPairGenerator(Nnode); % generate
        E=[E,min(E')',max(E')'];E=E(:,3:4); % arrange head and tail
        E=sortrows(E,[1,2]); % sort by head and tail
        Elist{i}=E; % put into cell array
    end
end
% random seed
rand('twister', 0);
% generate random graph
Nrep=5;
muList=cell(Nrep,1);
Nnode=size(Y,2);
Elist=cell(Nrep,1);
for i=1:Nrep
    E=randTreeGenerator(Nnode); % generate
    E=[E,min(E')',max(E')'];E=E(:,3:4); % arrange head and tail
    E=sortrows(E,[1,2]); % sort by head and tail
    Elist{i}=E; % put into cell array
end
%if ~strcmp(name{1},'cancer')
%        continue
%end
perfRand=[];
perfValEns=[];
perfBinEns=[];
Yenspred=zeros(size(Y));
YenspredBin=zeros(size(Y));
YenspredVal=zeros(size(Y));
for i=1:size(Elist,1)
    E = Elist{i};
    Ypred = [];
    YpredVal = [];
    % nfold cross validation
    for k=1:nfold
        Itrain = find(Ind ~= k);
        Itest  = find(Ind == k);
        Kx_tr = K(Itrain,Itrain);
        Kx_ts = K(Itest,Itrain)';
        Y_tr = Y(Itrain,:); Y_tr(Y_tr==0)=-1;
        Y_ts = Y(Itest,:); Y_ts(Y_ts==0)=-1;
        % running
        % rtn = learn_ensMMCRF;
        rtn = learn_MMCRF;
        % save margin dual mu
        muList{(i-1)*nfold+k}=rtn;
        % collecting results
        load(sprintf('Ypred_%s.mat', params.filestem));
        Ypred = [Ypred;[Ypred_ts,Itest]];
        YpredVal = [YpredVal;[Ypred_ts_val,Itest]];
    end
    YpredVal = sortrows(YpredVal,size(YpredVal,2));
    YpredVal = YpredVal(:,1:size(Y,2));
    YenspredVal = YenspredVal+YpredVal;
    Ypred = sortrows(Ypred,size(Ypred,2));
    Ypred = Ypred(:,1:size(Y,2));
    YenspredBin = YenspredBin+Ypred;
    
    % auc & roc random model
    [ax,ay,t,auc]=perfcurve(reshape(Y,1,numel(Y)),reshape(YpredVal,1,numel(Y)),1);
    [acc,vecacc,pre,rec,f1]=get_performance(Y,(Ypred==1));
    perfRand=[perfRand;[acc,vecacc,pre,rec,f1,auc]];
    
    % auc & roc ensemble val model
    [ax,ay,t,auc]=perfcurve(reshape(Y,1,numel(Y)),reshape(YenspredVal,1,numel(Y)),1);
    [acc,vecacc,pre,rec,f1]=get_performance(Y,YenspredVal>0);
    perfValEns=[perfValEns;[acc,vecacc,pre,rec,f1,auc]];
    
    % auc & roc ensemble bin model
    [acc,vecacc,pre,rec,f1]=get_performance(Y,YenspredBin>0);
    perfBinEns=[perfBinEns;[acc,vecacc,pre,rec,f1,0]];
end
YenspredVal=YenspredVal/Nrep;
Yenspred = (YenspredVal>0);

% performance of Random Model
perf=[perf;mean(perfRand,1)];
% performance of Bin ensemble
[acc,vecacc,pre,rec,f1]=get_performance(Y,YenspredBin>0);
perf=[perf;[acc,vecacc,pre,rec,f1,0]];perf
% performance of Val ensemble
[ax,ay,t,auc]=perfcurve(reshape(Y,1,numel(Y)),reshape(YenspredVal,1,numel(Y)),1);
[acc,vecacc,pre,rec,f1]=get_performance(Y,Yenspred);
perf=[perf;[acc,vecacc,pre,rec,f1,auc]];perf


%------------
%
% mdensMMCRF      
%
%------------
global Kx_tr;
global Kx_ts;
global Y_tr;
global Y_ts;
global E;
global debugging;
global params;
% set parameters
params.mlloss = 1;	% assign loss to microlabels or edges
params.profiling = 1;	% profile (test during learning)
params.epsilon = 0.8; %0.6;	% stopping criterion: minimum relative duality gap
params.C = svm_c;		% margin slack
params.max_CGD_iter = 1;		% maximum number of conditional gradient iterations per example
params.max_LBP_iter = 2;		% number of Loopy belief propagation iterations
params.tolerance = 1E-10;		% numbers smaller than this are treated as zero
params.filestem = 'tmpmmcrf';		% file name stem used for writing output
params.profile_tm_interval = 10;	% how often to test during learning
params.maxiter = 10;		% maximum number of iterations in the outer loop
params.verbosity = 1;
params.debugging = 0;
perfMadEns=[];
for i=1:size(Elist,1)
    % get new E
    Enew = [];
    for j=1:i
        Enew=[Enew;Elist{j}];
    end
    Enew=unique(Enew,'rows');
    E=Enew;
    Ypred = [];
    YpredVal = [];
    % nfold cross validation
    for k=1:nfold
        % training testing label
        Itrain = find(Ind ~= k);
        Itest  = find(Ind == k);
        % training testing kernel
        Kx_tr = K(Itrain,Itrain);
        Kx_ts = K(Itest,Itrain)';
        % training and testing target
        Y_tr = Y(Itrain,:); Y_tr(Y_tr==0)=-1;
        Y_ts = Y(Itest,:); Y_ts(Y_ts==0)=-1;
        % ensemble marginal dual
        muNew=zeros(4*size(Enew,1),size(Kx_tr,1));
        for j=1:i 
            muNew=muNew+mu_complete_zero(muList{(j-1)*nfold+k},Elist{j},Enew,params.C);
            % muNew=muNew+mu_complete_constrainted(muList{(i-1)*nfold+k},Elist{i},Enew,params.C);
            % muNew=muNew+onestep_inference(mu_complete_zero(muList{(i-1)*nfold+k},Elist{i},Enew,params.C));
        end
        muNew=muNew/Nrep;
        % running given mu and Enew
        params.mu=muNew;
        rtn = learn_ENSMMCRF;
        % collecting results
        load(sprintf('Ypred_%s.mat', params.filestem));
        Ypred = [Ypred;[Ypred_ts,Itest]];
        YpredVal = [YpredVal;[Ypred_ts_val,Itest]];
    end
    YpredVal = sortrows(YpredVal,size(YpredVal,2));
    YpredVal = YpredVal(:,1:size(Y,2));
    Ypred = sortrows(Ypred,size(Ypred,2));
    Ypred = Ypred(:,1:size(Y,2));

    % performance of Md ensemble
    [ax,ay,t,auc]=perfcurve(reshape(Y,1,numel(Y)),reshape(YpredVal,1,numel(Y)),1);
    [acc,vecacc,pre,rec,f1]=get_performance(Y,Ypred>0);
    perfMadEns=[perfMadEns;[acc,vecacc,pre,rec,f1,auc]];
end

% auc & roc
[ax,ay,t,auc]=perfcurve(reshape(Y,1,numel(Y)),reshape(YpredVal,1,numel(Y)),1);
[acc,vecacc,pre,rec,f1]=get_performance(Y,Ypred>0);
perf=[perf;[acc,vecacc,pre,rec,f1,auc]];perf
% plot roc
% plot(ax,ay,'blue');hold on
% save results
% dlmwrite(sprintf('results/%s_mdens',name{1}), Yenspred);


% plot data with true labels
hFig = figure('visible','off');
set(hFig, 'Position', [500,500,800,500])
subplot(3,4,1);plot(perfBinEns(:,1));title('Bin accuracy');
subplot(3,4,2);plot(perfBinEns(:,2));title('multilabel accuracy');
subplot(3,4,3);plot(perfBinEns(:,5));title('F1');
subplot(3,4,4);plot(perfBinEns(:,6));title('AUC');
subplot(3,4,5);plot(perfValEns(:,1));title('Val accuracy');
subplot(3,4,6);plot(perfValEns(:,2));title('multilabel accuracy');
subplot(3,4,7);plot(perfValEns(:,5));title('F1');
subplot(3,4,8);plot(perfValEns(:,6));title('AUC');
subplot(3,4,9);plot(perfMadEns(:,1));title('Mad accuracy');
subplot(3,4,10);plot(perfMadEns(:,2));title('multilabel accuracy');
subplot(3,4,11);plot(perfMadEns(:,5));title('F1');
subplot(3,4,12);plot(perfMadEns(:,6));title('AUC');
print(hFig, '-depsc',sprintf('../plots/%s_ens.eps',name{1}));
% save results
dlmwrite(sprintf('../results/%s_perf',name{1}),perf)
dlmwrite(sprintf('../results/%s_perfRand',name{1}),perfRand)
dlmwrite(sprintf('../results/%s_perfValEns',name{1}),perfValEns)
dlmwrite(sprintf('../results/%s_perfBinEns',name{1}),perfBinEns)
dlmwrite(sprintf('../results/%s_perfMadEns',name{1}),perfMadEns)

end

rtn = [];
end