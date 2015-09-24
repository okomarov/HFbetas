%% Options
OPT_HASWEIGHTS    = true;
OPT_LAGDAY        = 1;
OPT_PTFNUM        = 10;
OPT_PTFNUM_DOUBLE = [5,5];
OPT_INDEP_SORT    = false;
OPT_NOMICRO       = true;

%% Data
datapath = '..\data\TAQ\sampled\5min\nobad';

% Index data
master = loadresults('master');

% First and last price
price_fl = loadresults('price_fl');

% Permnos
permnos = unique(master.mst.Permno);
nseries = numel(permnos);

% Capitalizations
cap = loadresults('cap');

% NYSE breakpoints
if OPT_NOMICRO
    bpoints = loadresults('ME_breakpoints_TXT','..\results');
    idx     = ismember(bpoints.Date, unique(master.mst.Date/100));
    bpoints = bpoints(idx,{'Date','Var3'});
end
%% Lag 1 period
w = [NaN(1,nseries); cap.Data(1+OPT_LAGDAY:end,:)];

if OPT_NOMICRO
    bpoints.Var3 = [NaN(OPT_LAGDAY,1); bpoints.Var3(1:end-OPT_LAGDAY)];
end
%% Cache by dates

% master
master.mst     = sortrows(master.mst,'Date','ascend');
[dates,~,subs] = unique(master.mst.Date);
N              = numel(dates);
nrows          = accumarray(subs,1);
mst            = mat2cell(master.mst,nrows,6);

% price first last
price_fl       = sortrows(price_fl,'Date','ascend');
[dates,~,subs] = unique(price_fl.Date);
nrows          = accumarray(subs,1);
price_fl       = mat2cell(price_fl,nrows,size(price_fl,2));

% cap
w = num2cell(w,2);
%%

ptf  = NaN(N,OPT_PTFNUM);
ptf2 = NaN(N,prod(OPT_PTFNUM_DOUBLE));
bin2 = NaN(N, nseries);

% 12:00, 12:30 and 13:00
END_TIME_SIGNAL = 120000;
START_TIME_HPR = 121000;

poolStartup(8,'AttachedFiles',{'poolStartup.m'})
tic
parfor ii = 2:N
    disp(ii)
    
    % TAQ_EXACT
    s = struct('permnos',permnos,'datapath',datapath, 'mst', mst{ii},'price_fl',price_fl{ii},...
        'END_TIME_SIGNAL', END_TIME_SIGNAL, 'START_TIME_HPR',START_TIME_HPR)
    [st_signal, en_signal, st_hpr, end_hpr] = getPrices('taq_exact',s);

    % Signal: Filled back half-day ret
    past_ret = en_signal./st_signal-1;

    % hpr with 5 min skip
    hpr = end_hpr./st_hpr-1;
    
    % Filter microcaps
    if OPT_NOMICRO
        nyseCap  = bpoints.Var3(ismember(bpoints.Date, price_fl{ii}.Date/100));
        idx      = st_signal < 5 | w{ii} < nyseCap;
        hpr(idx) = NaN;
    end
    
    if OPT_HASWEIGHTS
        weight = w{ii};
    else
        weight = [];
    end
    % PTF ret
    ptf(ii,:) = portfolio_sort(hpr,past_ret, 'PortfolioNumber',OPT_PTFNUM, 'Weights',weight);
    
    % PTF ret
    [ptf2(ii,:), bin2(ii,:)] = portfolio_sort(hpr,{w{ii},past_ret}, 'PortfolioNumber',OPT_PTFNUM_DOUBLE,...
        'Weights',weight,'IndependentSort',OPT_INDEP_SORT);
end
toc

t = stratstats(dates, [ptf, ptf(:,1)-ptf(:,end)] ,'d',0);
t{:,:}'

t2 = stratstats(dates, ptf2 ,'d',0);
t2{:,:}'
reshape(t2.Annret, OPT_PTFNUM_DOUBLE)'
% t.Properties.VariableNames'

OPT_HASWEIGHTS
