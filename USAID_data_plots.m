function USAID_data_plots_ABM_2022

global ts i_beta a_beta var_S_N beta_N i_goods pcolors flag
global machismo_int youth_int stigma_int f_breakdown_int mh_int f_cohesion_int H_int_1 H_int_2
global resilience

pcolors = {'#0072BD','#D95319','#EDB120','#7E2F8E','#77AC30','#4DBEEE','#A2142F'};
flag_plot  = 0;
flag_x_y   = 0;
flag_print = 0;

flag_intervention = 2; % 0-none, 1-all interventions, 2-direct injection, 3, 4-resilience
country = 'H'; % H or ES

if flag_intervention
    plot_one_model = 0;
else
    plot_one_model = 1; % 1-one plot (don't use with intervention)
end
if strcmp(country,'H')
    num_eval = 3000*3.0; % ES: used 3000*3, higher values result in smaller betas
    fig_no = 0;
else
    num_eval = 3000*4.0; % H:  used 3000*4.5 because the beta coefficients for 3000*3 are too large
    fig_no = 100;
end

% READ AND INITIALIZE DATA
flag.old         = 1  % non-unit weights and (1 - stock) multiplier for stock derivatives
flag.plot_stocks = 0; % if set to 1, then run twice: flag.old_data = 2 then 1
flag.old_data    = 1; % 2-old, 1-new, old scaling, 0-new, new scaling (also changes lambda)
flag.correct     = 0; % 1-change sign in GM, 0-original sign
flag.FIM         = 1; % 1-analysis of SE of beta using FIM (and uncontrained maximization)
flag.find_idx    = 0; % FIM: find the index using largest beta (for 2022 only)

if flag.old_data==2
    T = readtable('data_2021_09_07.xlsx','sheet',country);
    yrs_max = 2021; % 2021 is the last year for old data
else
    if flag.old_data==1
        T = readtable('data_2022_11_26aTI_raw.xlsx','sheet',country);
        T = readtable('data_2022_11_26bTI_raw.xlsx','sheet',country);
        yrs_max = 2022;
    else
        T = readtable('data_2022_11_21TI_raw.xlsx','sheet',country); % original scaling
        yrs_max = 2022;
    end
end

var_names_orig = string(T.Properties.VariableNames(2:end));
var_names = strrep(var_names_orig,'_',' ');
yrs_all = T{:,1};
if strcmp(country,'ES')
    yrs_min = 2015; % 2014 is the first year
else
    yrs_min = 2014; % 2014 is the first year
end
yrs_lbl = {yrs_min,yrs_max};
yrs_ind = yrs_all >= yrs_min & yrs_all <= yrs_max;

data_values_orig = T{yrs_ind,2:end};
data_values_orig(data_values_orig(:)<0) = NaN; % replace -999 with NaN
[years_N,var_N] = size(data_values_orig);
yrs         = 1:years_N;
data_sd     = nanstd(data_values_orig);
data_good_idx   = find(data_sd>1e-5); % good = data is not constant
data_const_idx  = setdiff(1:var_N,data_good_idx);
var_const   = var_names_orig(data_const_idx);
var_good = var_names_orig(data_good_idx);
if flag_print
    fprintf('CONSTANTS OR ALL NaN:\n'), fprintf('%s\n',sort(var_const)), fprintf('\n')
    fprintf('GOOD:\n'), fprintf('%s\n',sort(var_good)), fprintf('\n')
    fprintf('ALL:\n'), fprintf('%s\n',sort(var_names_orig)), fprintf('\n')
end
machismo_int = 0;
youth_int    = 0;
stigma_int   = 0;
f_breakdown_int = 0;
mh_int          = 0;
f_cohesion_int  = 0;
H_int_1         = 0;
H_int_2         = 0;
resilience = 0;

% PLOT DATA
if flag_plot
    fig = figure(200+fig_no); fig.Name = 'all data'; clf; fig.Position = [41 185 1361 792];
    for i=1:var_N
        subplot(5,8,i)
        y_i = data_values_orig(:,i);
        plot(yrs,y_i,'o-','LineWidth',2)
        title(var_names(i)), ax = gca; ax.XLim = [1 years_N]; ax.XTick = [1 years_N];
        ax.XTickLabel = yrs_lbl; ax.YLim = [0 1];
    end
    
    fig = figure(202+fig_no); fig.Name = 'data'; clf; fig.Position = [798 416 860 539];
    for i=1:length(data_good_idx)
        subplot(4,4,i)
        i_good = data_good_idx(i);
        y_i = data_values_orig(:,i_good);
        plot(yrs,y_i,'LineWidth',2)
        title(var_names(i_good)), ax = gca; ax.XLim = [1 years_N]; ax.XTick = [1 years_N];
        ax.XTickLabel = yrs_lbl; ax.YLim = [0 1];
    end
    
%   keyboard
end

% SET UP STOCKS
stocks_idx = [1:12];
var_S_N = length(stocks_idx); % number of stocks
var_names_orig(stocks_idx) = ["PHV" "LE" "GM" "IN" "PG" "SD" "UN" "SV" "TM" "PSV" "SA" "MD"];
for i=1:var_S_N
    idx = stocks_idx(i);
    if flag_print, fprintf('%2i %3s (%s)\n',idx,var_names(idx),var_names_orig(idx)), end
end
if ~isempty(setxor(stocks_idx,1:var_S_N))
    error('stocks should be the first %i columns',var_S_N)
end
if flag_print
    for i=var_S_N+1:var_N
        fprintf('%2i %3s\n',i,var_names(i))
    end
end

% data_values are from columns 2-end of the table and correspond to var_names
[ data_values,x_data,y_data ] = ...
    init_variables(data_values_orig,years_N,var_N,var_names_orig,stocks_idx,...
    yrs,var_names);

if flag_x_y % go to PLOT MODEL RESULTS to plot data
    fig = figure(204+fig_no); fig.Name = 'x-y'; clf; fig.Position = [41 21 1785 956];
    fig.Color = 'w';
    for i=1:size(x_data,2)
        subplot(5,6,i), plot(x_data(:,i),y_data(:,i),'o-','LineWidth',2)
        lbls = regexp(a_beta{i},' -> ','split');
%       title(sprintf('beta %2i',i))
        ax = gca; ax.YLim = [0 1];
        x_lim = [nanmin(x_data(:,i)) nanmax(x_data(:,i))];
        if diff(x_lim)>1, ax.XLim = x_lim; else, ax.XLim = [-.5 .5] + mean(x_lim); end
        xlabel(lbls{1},'FontWeight','bold'), ylabel(lbls{2},'FontWeight','bold')
    end
    keyboard
end

% RUN MODEL
flag_run = 1;
% lambda = 0.001*10;      flag_lasso = 1; % if lasso is used, need larger lambda
if flag.old_data==1
    lambda = 0.001*.9*6*2;  flag_lasso = 0; % 1.5 -> more fitting to data, larger beta
elseif flag.old_data==2
    if strcmp(country,'ES')
        lambda = 0.001*.9*6*1;  flag_lasso = 0;
    else
        lambda = 0.001*.9*6*1.9; % 1 (small betas ~ 0.7), 2 (0.1), 1.85
    end
else
    lambda = 0.001*.9*6*4;  flag_lasso = 0; % original lambda is less stable
end
if strcmp(country,'H'), flag_lasso = 2; end % 2-use ES beta values
[betas1,betas0,betas0s] = load_betas(3,1); % 1,2,3 corresponds to lambda = 0.001,0.01,0.001 [multiplier = 5]
betas1 = [betas1 ; zeros(var_S_N*2,1)];
betas0 = [betas0 ; zeros(var_S_N*2,1)];
betas0 = ones(size(betas0))*0.1;   % same solution when lambda = 0.1, if less than 0.5
% betas0 = rand(size(betas0))*1.0; % same solution when lambda = 0.1, even at 1.0
y_data = data_values(:,stocks_idx);
[y_err0,y_model0] = eval_stocks(betas0,data_values,years_N,var_N,var_names_orig,...
    stocks_idx,0,flag_lasso);

% ABC (Note - cannot uniquely determine the prior variance of beta - depends on threshold)
flag.ABC = 0;
if flag.ABC
    N_ABC = 100*100*3;
    for i=1:N_ABC
        betas_i(i,:) = abs(randn(size(betas0)))*1.5; % 4 -> y_err is all Inf, 2 very few
        y_err_i(i) = eval_stocks(betas_i(i,:),data_values,years_N,var_N,var_names_orig,...
            stocks_idx,0,0); % use flag_lasso = 0
    end
    y_err_sort = sort(y_err_i);
    num_not_inf = sum(y_err_i<Inf);
    percent_not_inf = num_not_inf / N_ABC * 100
    accept_percent = 0.5;
    accept_threshold = y_err_sort(ceil(N_ABC*accept_percent/100));
    accept_i = y_err_i < accept_threshold;
    y_ABC = y_err_i(accept_i);
    betas_ABC = betas_i(accept_i,:);
    plot_betas(mean(betas_ABC),-1)
    [U,S,V] = svd(betas_ABC-mean(betas_ABC),'econ'); % betas = U*S*V' = sum U.j Sjj V.j

    fig = figure(99); fig.Name = 'ABC (difficult to see patterns)';
    subplot(2,2,1), histogram(log10(y_ABC)), title(sprintf('log10 errors, N = %i',sum(accept_i)))
    subplot(2,2,2), imagesc(U), title('U')
    subplot(2,2,3), plot(diag(S),'bo-'), title('S')
    subplot(2,2,4), imagesc(V'), title("V'")

    keyboard, return
end

% PLOT STOCKS DATA FROM DIFFERENT DATA SETS
if flag.plot_stocks
    plot_results(100, flag.old_data==2, var_S_N, var_names_orig, stocks_idx, yrs, y_data, ...
        var_names, years_N, yrs_lbl)
    return
end

if flag_run
    options = optimoptions('fmincon','MaxFunctionEvaluations',num_eval);
    lower_bounds = zeros(size(betas0));
    upper_bounds = inf(size(betas0));
    betas = fmincon(@(betas) ...
        eval_stocks(betas,data_values,years_N,var_N,var_names_orig,stocks_idx,...
        lambda,flag_lasso),...
        betas0,[],[],[],[],lower_bounds,upper_bounds,[],options);
    [y_err,y_model] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
        stocks_idx,lambda,flag_lasso);
    y_err_0 = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,stocks_idx,0,0);
    fprintf('\nBeta values [original betas0s, optimized betas] for lambda = %.4f\n',lambda)
    plot_betas( betas,          200)
%     fprintf('%8.1f %2i\n',[betas i_beta']')
%     fprintf('%8.1f %8.1f %2i\n',[betas1 betas i_beta']')
%     keyboard
    % UNCONSTRAINED OPTIMIZATION, THEN SELECTED OPTIMIZATION TO GET HESSIAN OF SUBSET OF BETAS
    if flag.FIM
        % ALL BETAS
        options = optimoptions('fminunc','MaxFunctionEvaluations',num_eval*10,'MaxIterations',400*10);
        [betasSqrt,~,~,~,~,hessianSqrt] = fminunc(@(betasSqrt) ...
            eval_stocks(betasSqrt.^2,data_values,years_N,var_N,var_names_orig,stocks_idx,...
            lambda,flag_lasso),sqrt(betas),options);

%         se = sqrt(diag(inv(hessianSqrt))); % VERY LARGE SE USING THE DIAGONAL ELEMENTS
%         betasSqrtSE = betasSqrt + se;
%         betasSE = (betasSqrtSE).^2 - betasSqrt.^2;
%         plot_betas( betasSE,      212), xlim([0 10])

        % SELECTED BETAS
        options = optimoptions('fminunc','MaxFunctionEvaluations',num_eval);
        if flag.find_idx
            if flag.old_data==1
                idx = find((betasSqrt.^2)>0.3); % 2022: 0.3 (22 betas), 0.4 (16), 0.5 (12)
            elseif flag.old_data==2
                idx = find((betasSqrt.^2)>0.5); % 2021: 0.5 (11)
            end
            keyboard
        else
            idx_2021 = [ 1 2 4 15 16  19 27 28 41 49  50   ];        % betaSE(19) is very large
            idx_2022 = [ 2 4 7 15 16  17 18 26 27 28 32  41:50 52];
            
            idx      = setdiff(union(idx_2021,idx_2022),19);
            idx      = idx_2022;
        end
        [betasSqrtIdx,~,~,~,~,hessianSqrtSelect] = fminunc(@(betas_sqrt_idx) ...
            eval_stocks_idx(betasSqrt.^2,betas_sqrt_idx,idx,... % eval_stocks_idx takes square of betas_sqrt_idx
            data_values,years_N,var_N,var_names_orig,stocks_idx,...
            lambda,flag_lasso),...
            betasSqrt(idx),options);

        se = sqrt(diag(inv(hessianSqrtSelect)));
        betasSqrtSESelect = betasSqrt;
        betasSqrtSESelect(idx) = betasSqrt(idx) + se;
        betasSE = (betasSqrtSESelect).^2 - betasSqrt.^2;
        plot_betas( betasSE,      202), xlim([0 20])
        plot_betas( betasSqrt.^2, 201)
        keyboard
    end
else
    y_model = y_model0;
end

if flag_intervention==1    % after optimization (use betas)
    i_ints{1} = [ 35 ];    % 31-youth empowerment          
    x_ints{1} = [ 33/.365*.5 ]/33*50;  a_ints{1} = 'youth';
    i_ints{2} = [ 18 19 ]; % 18-economy, 19-economic opportunity
    x_ints{2} = [ 33 33 ];             a_ints{2} = 'economy';
    i_ints{3} = [ 22 23];  % 22-f breakdown, 23 f cohesion
    x_ints{3} = [-33 33]/33*200;       a_ints{3} = 'family';
    i_ints{4} = [ 29   ];  % 29-machismo
    x_ints{4} = [-33   ]/33*100;       a_ints{4} = 'machismo';
    i_ints{5} = [ 31   ];  % 31-stigma
    x_ints{5} = [-33   ]/33*200;       a_ints{5} = 'stigma';
    i_ints{6} = [ 30   ];  % 30-mental health
    x_ints{6} = [ 33   ]/33*200;       a_ints{6} = 'mental health';
    i_ints{7} = [i_ints{1} i_ints{3}];
    x_ints{7} = [x_ints{1} x_ints{3}]; a_ints{7} = 'youth - family';
    
    n_ints    = length(i_ints);

    for k=1:n_ints
        data_values_int_orig = data_values_orig;
        for j=1:length(i_ints{k})
            data_values_int_orig(:,i_ints{k}(j)) = ...
                data_values_int_orig(:,i_ints{k}(j))*(1+x_ints{k}(j)/100); % change data
        end
        data_values_int = init_variables(data_values_int_orig,years_N,var_N,...
            var_names_orig,stocks_idx,yrs,var_names);
    
        [y_err_ints{k},y_model_ints{k}] = eval_stocks(betas,data_values_int,years_N,var_N,var_names_orig,...
            stocks_idx,0,flag_lasso);
    end
elseif flag_intervention==2
    H_int_1 = 0;
    H_int_2 = 0;
    if (country == 'H')
        x_intervention = 9/100;
        I = 1;
        a_ints{I} = 'Youth + stigma + family + mental-health + machismo';
        f_breakdown_int = -x_intervention/2;
        f_cohesion_int  =  x_intervention/2;
        mh_int          =  x_intervention/2;
        machismo_int = -x_intervention/2;
        youth_int    =  x_intervention/2;
        stigma_int   = -x_intervention/2;
        [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
            stocks_idx,0,flag_lasso); I = I+1;
        a_ints{I} = 'Youth + stigma + machismo';
        f_breakdown_int = -x_intervention*0;
        f_cohesion_int  =  x_intervention*0;
        mh_int          =  x_intervention*0;
        machismo_int = -x_intervention*1;
        youth_int    =  x_intervention*1;
        stigma_int   = -x_intervention*1;
        [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
            stocks_idx,0,flag_lasso); I = I+1;
        a_ints{I} = 'Family + mental-health';
        f_breakdown_int = -x_intervention*1;
        f_cohesion_int  =  x_intervention*1;
        mh_int          =  x_intervention*1;
        machismo_int = -x_intervention*0;
        youth_int    =  x_intervention*0;
        stigma_int   = -x_intervention*0;
        [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
            stocks_idx,0,flag_lasso); I = I+1;
    else
        flag.version_2021_09_07 = 1
        if flag.version_2021_09_07
            I = 1;
            a_ints{I} = 'Youth + stigma + machismo';
            x_intervention = 9/100;
            machismo_int    = -x_intervention*1/2;
            youth_int       =  x_intervention*1/2;
            stigma_int      = -x_intervention*0;
            f_breakdown_int = -x_intervention*0;
            f_cohesion_int  =  x_intervention*0;
            mh_int          =  x_intervention*0;
            [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
                stocks_idx,0,flag_lasso); I = I+1;
            a_ints{I} = 'Youth + family + mental-health';
            machismo_int    = -x_intervention*0;
            youth_int       =  x_intervention*1/2;
            stigma_int      = -x_intervention*0;
            f_breakdown_int = -x_intervention*1/2;
            f_cohesion_int  =  x_intervention*1/2;
            mh_int          =  x_intervention*1/2;
            [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
                stocks_idx,0,flag_lasso);
        else
            % VERSION 2022-03-28
            %   replace Youth + stigma + machismo with Youth + machismo + bad-governance
            %   delete Youth + family + mental-health
            I = 1;
            a_ints{I} = 'Youth + machismo + bad-governance';
            x_intervention = 9/100;
            machismo_int    = -x_intervention*0;
            youth_int       =  x_intervention*0;
            H_int_1         =  x_intervention*1/3; % machismo, bad-governance, youth-empowerment
            H_int_2         =  x_intervention*1;   % victimizer, gang-affiliation, cohesion, territorial, bully
            stigma_int      = -x_intervention*0;
            f_breakdown_int = -x_intervention*0;
            f_cohesion_int  =  x_intervention*0;
            mh_int          =  x_intervention*0;

            [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
                stocks_idx,0,flag_lasso);
        end
    end
    n_ints = length(a_ints);
elseif flag_intervention==4 % Zhixi here is the new code
    I = 1;
    x_intervention = 9/100;
    n_ints = 1; 
    a_ints{I} = 'Resilience from ABM';
    resilience =  x_intervention;

    [y_err_ints{I},y_model_ints{I}] = eval_stocks(betas,data_values,years_N,var_N,var_names_orig,...
        stocks_idx,0,flag_lasso);
else
    n_ints = 1; a_ints{1} = ''; y_model_ints{1} = '';
    [y_err1,y_model1] = eval_stocks(betas1,data_values,years_N,var_N,var_names_orig,...
        stocks_idx,0,flag_lasso);
end

% PLOT MODEL RESULTS
for k=1:n_ints
    fig = figure(220+k+fig_no); fig.Name = ['compare data ' a_ints{k}]; clf;
    fig.Position = [319 242 1014 714]; fig.Color = 'w';
    for i=1:var_S_N
        subplot(3,4,i)
        idx = stocks_idx(i);
        plot(yrs',y_data(:,i),'-','LineWidth',2); hold on
        plot(yrs(i_goods{i}),y_data(i_goods{i},i),'o','MarkerSize',10,...
            'MarkerFaceColor',pcolors{1},'MarkerEdgeColor',pcolors{1})
        if plot_one_model
            h = plot(ts',[              y_model(:,i)],'LineWidth',2); hold off
            h(1).LineStyle = '--'; h(1).Color = pcolors{2};
        else
            if flag_intervention, y_model1 = y_model_ints{k}; end
            h = plot(ts',[y_model1(:,i) y_model(:,i)],'LineWidth',2); hold off
            h(2).LineStyle = '--'; h(1).Color = pcolors{2}; h(2).Color = pcolors{3};
        end
        title(var_names(idx)), ax = gca; ax.XLim = [1 years_N]; ax.XTick = [1 years_N];
        ax.XTickLabel = yrs_lbl; ax.YLim = [0 1]; % can be negative
        if i==1
            if plot_one_model
                legend('data curve','data points','SD model')
            else
                if flag_intervention
                    legend('data curve','data points','intervention','no intervention') % sgtitle(a_ints{k})
                else
                    legend('data curve','data points','model (previous run)','model (new run)')
                end
            end
        end
    end
end

keyboard


function [y_err,y_model] = eval_stocks_idx(Betas,betas_sqrt_idx,idx,data_values,years_N,var_N,var_names_orig,...
    stocks_idx,lambda,flag_lasso)

    Betas(idx) = betas_sqrt_idx.^2;
    [y_err,y_model] = eval_stocks(Betas,data_values,years_N,var_N,var_names_orig,...
        stocks_idx,lambda,flag_lasso);


function [ data_values,x_data,y_data ] = ...
    init_variables(data_values_in,years_N,var_N,var_names_orig,stocks_idx,...
    yrs,var_names)

global t_num dt ts t_N y_data_ts weights_ts i_goods stock_initial i_beta a_beta flag
global var_S_N beta_N

global PHV_all LE_all GM_all IN_all PG_all SD_all UN_all SV_all TM_all PSV_all SA_all MD_all
global Access_to_Abortion_all Access_to_Contraception_all Bad_Governance_all Bully_all ...
    Deportation_all Economy_all Economy_Opportunities_all Exposure_to_Violent_Media_all ...
    Extortion_all Family_Breakdown_all Family_Cohesion_all Gang_Affiliation_all ...
    Gang_Cohesion_all Gang_Control_all Interventions_all Impunity_Governance_all ...
    Machismo_all Mental_Health_all Neighborhood_Stigma_all School_Quality_all ...
    Territorial_Fights_all Victimizer_all Youth_Empowerment_all

% BETA
a_beta = [
    "LE*(media + bad gov - youth + stigma) -> PHV"
    "GM*(territory - LE) -> PHV"
    "GM*(g control - impunity) ->  LE"
    "PHV*(-impunity) ->  LE"
    "PG*(media - LE - f cohesion - mh) ->  GM"
    "MD*(deport) ->  GM"
    "LE ->  IN"
    "IN ->  PG"
    "UN*(media) ->  PG"
    "PSV ->  PG"
    "SV*(-g control + victimizer + GM) ->  PG"
    "PHV*(f breakdown + media - mh) ->  PG"
    "TM*(-abortion - intervention + UN) ->  SD"
    "PSV*(bully - intervention - s quality) ->  SD"
    "PHV ->  SD"
    "SD*(stigma + extortion - e opportunities) ->  UN"
    "SA*(-e opportunites + g affiliation - LE - mh + SD) ->  SV"
    "GM ->  SV"
    "PSV*SA ->  SV"
    "UN*(media + f breakdown - youth - g control) ->  SV"
    "SV*(-contraception) ->  TM"
    "SV -> PSV"
    "PHV*SA -> PSV"
    "MD*(-f cohesion) -> PSV"
    "GM*(SA + g cohesion) -> PSV"
    "GM ->  SA"
    "PHV*(-economy) ->  MD"
    "UN*(machismo - e opportunities) ->  MD"
];
beta_N = length(a_beta);

% DEFINE VARIABLES
t_num = 4;
dt = 1/t_num;
ts = 1:dt:years_N;
t_N = length(ts);

% INDECES FOR BETA
% i_beta = [1:7 10:11 13 17 19:22 24:25 27 29:32 34 36 40 44 46:47]; % map from old eqns to new
% i_beta = [i_beta 50:61 62:73];
i_beta = [1:beta_N+var_S_N*2];

% INTERPOLATE, EXTRAPOLATE, SET WEIGHTS
if flag.old
    w_low = 0.1*3;         % low weight value (e.g. for missing data), default is 1.0
    w_high_multiplier = 5; % multiplier for more important stocks
else
    w_low = 1; w_high_multiplier = 1;
end

% i_weights = [1 6 12 2 4 7]; % 1-PHV 8-SV 10-PSV 12-Migration 2-Law 4-Incarceration 3-G Member
i_weights = [1 8 12 2 4 3]; % 1-PHV 8-SV 10-PSV 12-Migration 2-Law 4-Incarceration 3-G Member

weights = ones(years_N,var_S_N); % weights for errors
data_values = data_values_in;

for i=1:var_N % for each of the variables
    i_good = find(~isnan(data_values_in(:,i))); % find good indeces
    if isempty(i_good)
        data_value_first = 1/2; % all missing, so just 1/2
        data_values(:,i) = data_value_first;
    else
        i_good_first = i_good(1);
        i_good_last = i_good(end);
        if (i_good_last - i_good_first + 1) > length(i_good) % gaps in data
            for j1=i_good_first:i_good_last
                if ~ismember(j1,i_good) && ismember(j1-1,i_good) % j1: beginning of gap
                    for j2=j1:i_good_last-1      % look at all possible endings of gap
                        if ismember(j2+1,i_good) % j2: end of gap
                            data_values(j1:j2,i) = ... % interpolate good data at ends of gap
                                interp1([j1-1 j2+1],data_values([j1-1 j2+1],i),j1:j2);
                            if i<=var_S_N        % if this is a stock, then use a low weight
                                weights(j1:j2,i) = w_low;
                            end
                            break % end for, look for j1 at the beginning of the next gap
                        end
                    end
                end
            end
        end
        data_value_first = data_values_in(i_good_first,i); % NOCB Next Obs Carry Backward
        data_value_last = data_values_in(i_good_last,i);   % LOCF Last Obs Carry Forward
        data_values(1:i_good_first,i) = data_value_first;
        data_values(i_good_last:end,i) = data_value_last;
    end
    if i<=var_S_N
        stock_initial(i) = data_value_first;     % not used, but maybe useful later
        if isempty(i_good)
            weights(:,i) = w_low;                % no data: all weights are low
        else
            weights(1:i_good_first,i) = w_low;   % NOCB imputed data: low weights
            weights(i_good_last:end,i) = w_low;  % LOCF imputed data: low weights
        end
    end
    i_goods{i} = i_good; % save all good
end

weights(:,i_weights) = weights(:,i_weights)*w_high_multiplier; % important stocks: multiply
% weights(:,12) = weights(:,12)*9; % MD

% weights(1:years_N-1,3) = w_low; % GM only 2021 is 1 (use years_N-1 = 2020)
% weights(:,          5) = w_low; % PG
% weights(setdiff(1:years_N,years_N-2),7) = w_low; % UN only 2019 is 1 (years_N-2 = 2019)

y_data = data_values(:,stocks_idx);
y_data_ts = interp1(1:years_N,y_data,ts);
weights_ts = interp1(1:years_N,weights,ts);

flag_print = 0;

if flag_print
    fprintf('\n\n\nINITIALIZE THESE GLOBAL VARIABLES ONCE\n')
    global_str = "global";
end

for i=1:var_N
    var_name_all = strcat(var_names_orig(i),"_all");
    i_str = num2str(i);
    eval_str = strcat(var_name_all,"=data_values(:,",i_str,");");
    eval(eval_str)
    if flag_print
        fprintf('%s\n',eval_str)
        global_str = strcat(global_str," ",var_name_all);
    end
end

if flag_print
    fprintf('\n')
    fprintf('%s\n',global_str)
    fprintf('\n')
    
    global_str = "global";
end

for i=1:var_S_N
    idx = stocks_idx(i);
    i_str = num2str(i);
    S_var_name = strcat("S_",var_names_orig(idx));
    S_all_name = strcat(S_var_name,"_all");
    eval_strA(i,1) = strcat(S_all_name,"=","zeros(t_N,1);");
    eval(eval_strA(i,1)), 
    eval_strA(i,2) = strcat(S_all_name,"(1)=","stock_initial(",i_str,");"); % initial value
    eval(eval_strA(i,2))
    eval_strA(i,3) = strcat("y_model(1,",i_str,") = ",S_all_name,"(1);");
    eval(eval_strA(i,3))
    if flag_print, global_str = strcat(global_str," ",S_all_name); end
end

if flag_print
    for k=1:3
        for i=1:var_S_N
            fprintf('%s\n',eval_strA(i,k))
        end
    end
    
    fprintf('\n')
    fprintf('%s\n',global_str)
    fprintf('\n')
    keyboard
end

y_data(:, 1:2) = PHV_all*[1 1];
x_data(:, 1) = (LE_all).*(Exposure_to_Violent_Media_all + Bad_Governance_all ...
                         - Youth_Empowerment_all + Neighborhood_Stigma_all);
x_data(:, 2) = (GM_all).*(Territorial_Fights_all - LE_all);
y_data(:, 3:4) = LE_all*[1 1];
x_data(:, 3) = (GM_all).*(Gang_Control_all - Impunity_Governance_all);
x_data(:, 4) = (PHV_all).*(1-Impunity_Governance_all);
y_data(:, 5:6) = GM_all*[1 1];
x_data(:, 5) = (PG_all).*(Exposure_to_Violent_Media_all - LE_all - Family_Cohesion_all - Mental_Health_all);
x_data(:, 6) = (MD_all).*(Deportation_all);
y_data(:, 7) = IN_all;
x_data(:, 7) = (LE_all);
y_data(:, 8:12) = PG_all*[1 1 1 1 1];
x_data(:, 8) = (IN_all);
x_data(:, 9) = (UN_all).*(Exposure_to_Violent_Media_all);
x_data(:,10) = (PSV_all);
x_data(:,11) = (SV_all).*(-Gang_Control_all + Victimizer_all + GM_all);
x_data(:,12) = (PHV_all).*(Family_Breakdown_all + Exposure_to_Violent_Media_all - Mental_Health_all);
y_data(:,13:15) = SD_all*[1 1 1];
x_data(:,13) = (TM_all).*(-Access_to_Abortion_all - Interventions_all + UN_all);
x_data(:,14) = (PSV_all).*(Bully_all - Interventions_all - School_Quality_all);
x_data(:,15) = (PHV_all);
y_data(:,16) = UN_all;
x_data(:,16) = (SD_all).*(Neighborhood_Stigma_all + Extortion_all - Economy_Opportunities_all);
y_data(:,17:20) = SV_all*[1 1 1 1];
x_data(:,17) = (SA_all).*(-Economy_Opportunities_all + Gang_Affiliation_all - LE_all - Mental_Health_all + SD_all);
x_data(:,18) = (GM_all);
x_data(:,19) = (PSV_all).*(SA_all);
x_data(:,20) = (UN_all).*(Exposure_to_Violent_Media_all + Family_Breakdown_all ...
                         - Youth_Empowerment_all - Gang_Control_all);
y_data(:,21) = TM_all;
x_data(:,21) = (SV_all).*(1-Access_to_Contraception_all);
y_data(:,22:25) = PSV_all*[1 1 1 1];
x_data(:,22) = (SV_all);
x_data(:,23) = (PHV_all).*(SA_all);
x_data(:,24) = (MD_all).*(1-Family_Cohesion_all);
x_data(:,25) = (GM_all).*(SA_all + Gang_Cohesion_all);
y_data(:,26) = SA_all;
x_data(:,26) = (GM_all);
y_data(:,27:28) = MD_all*[1 1];
x_data(:,27) = (PHV_all).*(1-Economy_all);
x_data(:,28) = (UN_all).*(Machismo_all - Economy_Opportunities_all);


function [y_err,y_model] = eval_stocks(Betas,data_values,years_N,var_N,var_names_orig,...
    stocks_idx,lambda,flag_lasso,yrs,yrs_lbl,var_names)

global t_num dt ts t_N y_data_ts weights_ts stock_initial i_beta beta_N var_S_N
global PHV_all LE_all GM_all IN_all PG_all SD_all UN_all SV_all TM_all PSV_all SA_all MD_all
global Access_to_Abortion_all Access_to_Contraception_all Bad_Governance_all Bully_all ...
    Deportation_all Economy_all Economy_Opportunities_all Exposure_to_Violent_Media_all ...
    Extortion_all Family_Breakdown_all Family_Cohesion_all Gang_Affiliation_all ...
    Gang_Cohesion_all Gang_Control_all Interventions_all Impunity_Governance_all ...
    Machismo_all Mental_Health_all Neighborhood_Stigma_all School_Quality_all ...
    Territorial_Fights_all Victimizer_all Youth_Empowerment_all
global machismo_int youth_int stigma_int f_breakdown_int mh_int f_cohesion_int H_int_1 H_int_2

%  1 Physical Violence (PHV)
%  2 Law Enforcement (LE)
%  3 Gang Membership (GM)
%  4 Incarceration (IN)
%  5 Positive Perception (PG)
%  6 School Dropout (SD)
%  7 Unemployment (UN)
%  8 Sexual Violence (SV)
%  9 Teenage Mothers (TM)
% 10 Psych Violence (PSV)
% 11 Substance Abuse (SA)
% 12 Migration Displacement (MD)
% 13 Access to Abortion
% 14 Access to Contraception
% 15 Bad Governance
% 16 Bully
% 17 Deportation
% 18 Economy
% 19 Economy Opportunities
% 20 Exposure to Violent Media
% 21 Extortion
% 22 Family Breakdown
% 23 Family Cohesion
% 24 Gang Affiliation
% 25 Gang Cohesion
% 26 Gang Control
% 27 Interventions
% 28 Impunity Governance
% 29 Machismo
% 30 Mental Health
% 31 Neighborhood Stigma
% 32 School Quality
% 33 Territorial Fights
% 34 Victimizer
% 35 Youth Empowerment
% 36 Gang Violence
% 37 SocialCohesion
% 38 WitnessingPhysicalViolence

flag_eval = 0; % 1-use eval function, 0-hard code the evaulation

% INITIALIZE var_S_N STOCKS
S_PHV_all=zeros(t_N,1);
S_LE_all =zeros(t_N,1);
S_GM_all =zeros(t_N,1);
S_IN_all =zeros(t_N,1);
S_PG_all =zeros(t_N,1);
S_SD_all =zeros(t_N,1);
S_UN_all =zeros(t_N,1);
S_SV_all =zeros(t_N,1);
S_TM_all =zeros(t_N,1);
S_PSV_all=zeros(t_N,1);
S_SA_all =zeros(t_N,1);
S_MD_all =zeros(t_N,1);

stock_initial = Betas(beta_N+var_S_N+(1:var_S_N));

S_PHV_all(1)=stock_initial( 1);
S_LE_all(1) =stock_initial( 2);
S_GM_all(1) =stock_initial( 3);
S_IN_all(1) =stock_initial( 4);
S_PG_all(1) =stock_initial( 5);
S_SD_all(1) =stock_initial( 6);
S_UN_all(1) =stock_initial( 7);
S_SV_all(1) =stock_initial( 8);
S_TM_all(1) =stock_initial( 9);
S_PSV_all(1)=stock_initial(10);
S_SA_all(1) =stock_initial(11);
S_MD_all(1) =stock_initial(12);

y_model(1, :) = stock_initial;

for k=1:t_N-1
    t     = ts(k);
    t_int = round(t);
    % SET VARIABLES AND STOCKS AT TIME t
    if flag_eval
        for i=1:var_N
            var_name = var_names_orig(i);
            if i<=var_S_N
                eval_str = strcat("S_",var_name,"=","S_",var_name,"_all(k);");
            else
                eval_str = strcat(var_name,"=",var_name,"_all(t_int);");
            end
            eval(eval_str)
            if k==2, fprintf('%s\n',eval_str), end
        end
    else
        S_PHV=S_PHV_all(k);
        S_LE=S_LE_all(k);
        S_GM=S_GM_all(k);
        S_IN=S_IN_all(k);
        S_PG=S_PG_all(k);
        S_SD=S_SD_all(k);
        S_UN=S_UN_all(k);
        S_SV=S_SV_all(k);
        S_TM=S_TM_all(k);
        S_PSV=S_PSV_all(k);
        S_SA=S_SA_all(k);
        S_MD=S_MD_all(k);

        Access_to_Abortion=Access_to_Abortion_all(t_int);
        Access_to_Contraception=Access_to_Contraception_all(t_int);
        Bad_Governance=Bad_Governance_all(t_int) - H_int_1;
        Bully=Bully_all(t_int) - H_int_2;
        Deportation=Deportation_all(t_int);
        Economy=Economy_all(t_int);
        Economy_Opportunities=Economy_Opportunities_all(t_int);
        Exposure_to_Violent_Media=Exposure_to_Violent_Media_all(t_int);
        Extortion=Extortion_all(t_int);
        Family_Breakdown=Family_Breakdown_all(t_int);
        Family_Cohesion=Family_Cohesion_all(t_int);
        Gang_Affiliation=Gang_Affiliation_all(t_int) - H_int_2;
        Gang_Cohesion=Gang_Cohesion_all(t_int) - H_int_2;
        Gang_Control=Gang_Control_all(t_int);
        Interventions=Interventions_all(t_int);
        Impunity_Governance=Impunity_Governance_all(t_int);
        Machismo=Machismo_all(t_int) - H_int_1;
        Mental_Health=Mental_Health_all(t_int);
        Neighborhood_Stigma=Neighborhood_Stigma_all(t_int);
        School_Quality=School_Quality_all(t_int);
        Territorial_Fights=Territorial_Fights_all(t_int) - H_int_2;
        Victimizer=Victimizer_all(t_int) - H_int_2;
        Youth_Empowerment=Youth_Empowerment_all(t_int) + H_int_1;
    end

    betas(i_beta) = Betas;

    global machismo_int youth_int stigma_int f_breakdown_int mh_int f_cohesion_int H_int_1 H_int_2
    global resilience flag

% DON'T USE Interventions
    Interventions = 0;

    D_S_PHV = ...
        + betas( 1)*(S_LE)*(Exposure_to_Violent_Media + Bad_Governance ...
                         - Youth_Empowerment + Neighborhood_Stigma) ...
        + betas( 2)*(S_GM)*(Territorial_Fights - S_LE) ...
        - betas(beta_N+1) - youth_int + stigma_int;
    D_S_LE = ...
        + betas( 3)*(S_GM)*(Gang_Control - Impunity_Governance) ...
        + betas( 4)*(S_PHV)*(1-Impunity_Governance) ...
        - betas(beta_N+2);
    D_S_GM = ...
        + betas( 5)*(S_PG)*(Exposure_to_Violent_Media - S_LE - Family_Cohesion - Mental_Health) ...
        + betas( 6)*(S_MD)*(Deportation) ...
        - betas(beta_N+3) - f_cohesion_int - mh_int;
    D_S_IN = ...
        + betas( 7)*(S_LE) ...
        - betas(beta_N+4);
    D_S_PG = ...
        + betas( 8)*(S_IN) ...
        + betas( 9)*(S_UN)*(Exposure_to_Violent_Media) ...
        + betas(10)*(S_PSV) ...
        + betas(11)*(S_SV)*(-Gang_Control + Victimizer + S_GM) ...
        + betas(12)*(S_PHV)*(Family_Breakdown + Exposure_to_Violent_Media - Mental_Health) ...
        - betas(beta_N+5) + f_breakdown_int - mh_int ...
        - 2*resilience;
    D_S_SD = ...
        + betas(13)*(S_TM)*(-Access_to_Abortion - Interventions + S_UN) ...
        + betas(14)*(S_PSV)*(Bully - Interventions - School_Quality) ...
        + betas(15)*(S_PHV) ...
        - betas(beta_N+6);
    D_S_UN = ...
        + betas(16)*(S_SD)*(Neighborhood_Stigma + Extortion - Economy_Opportunities) ...
        - betas(beta_N+7) + stigma_int ...
        - resilience;
    if flag.correct
        sign_Gang_Control = +1; % no visible effect on stocks, but effects on some smaller beta
    else
        sign_Gang_Control = -1;
    end
    D_S_SV = ...
        + betas(17)*(S_SA)*(-Economy_Opportunities + Gang_Affiliation - S_LE - Mental_Health + S_SD) ...
        + betas(18)*(S_GM) ...
        + betas(19)*(S_PSV)*(S_SA) ...
        + betas(20)*(S_UN)*(Exposure_to_Violent_Media + Family_Breakdown  ...
                        - Youth_Empowerment + sign_Gang_Control*Gang_Control) ...
        - betas(beta_N+8) - mh_int + f_breakdown_int - youth_int;
    D_S_TM = ...
        + betas(21)*(S_SV)*(1-Access_to_Contraception) ...
        - betas(beta_N+9);
    D_S_PSV = ...
        + betas(22)*(S_SV) ...
        + betas(23)*(S_PHV)*(S_SA) ...
        + betas(24)*(S_MD)*(1-Family_Cohesion) ...
        + betas(25)*(S_GM)*(S_SA + Gang_Cohesion) ...
        - betas(beta_N+10) - f_cohesion_int;
    D_S_SA = ...
        + betas(26)*(S_GM) ...
        - betas(beta_N+11);
    D_S_MD = ...
        + betas(27)*(S_PHV)*(1-Economy) ...
        + betas(28)*(S_UN)*(Machismo - Economy_Opportunities) ...
        - betas(beta_N+12) + machismo_int;
    
    % SET STOCKS AT TIME t+1
    for i=1:var_S_N
        if flag_eval
            idx = stocks_idx(i);
            i_str = num2str(i);
            S_var_name = strcat("S_",var_names_orig(idx));
            D_var_name = strcat("D_",S_var_name);
            D_var_name = strcat(D_var_name,"*",S_var_name);
            eval_str = strcat(S_var_name,"_all(k+1) = ",S_var_name,"_all(k) + ",D_var_name,"*dt;");
            eval(eval_str)
            if k==1, fprintf('%s\n',eval_str), end
            eval_str = strcat("y_model(k+1,",i_str,") = ",S_var_name,"_all(k+1);"); % set y
            eval(eval_str)
            if k==2, fprintf('%s\n',eval_str), end
        else
            if flag.old
                S_PHV_all(k+1) = S_PHV_all(k) + D_S_PHV*S_PHV*(1-S_PHV)*dt;
                S_LE_all(k+1)  = S_LE_all(k)  + D_S_LE*S_LE  *(1-S_LE)*dt;
                S_GM_all(k+1)  = S_GM_all(k)  + D_S_GM*S_GM  *(1-S_GM)*dt;
                S_IN_all(k+1)  = S_IN_all(k)  + D_S_IN*S_IN  *(1-S_IN)*dt;
                S_PG_all(k+1)  = S_PG_all(k)  + D_S_PG*S_PG  *(1-S_PG)*dt;
                S_SD_all(k+1)  = S_SD_all(k)  + D_S_SD*S_SD  *(1-S_SD)*dt;
                S_UN_all(k+1)  = S_UN_all(k)  + D_S_UN*S_UN  *(1-S_UN)*dt;
                S_SV_all(k+1)  = S_SV_all(k)  + D_S_SV*S_SV  *(1-S_SV)*dt;
                S_TM_all(k+1)  = S_TM_all(k)  + D_S_TM*S_TM  *(1-S_TM)*dt;
                S_PSV_all(k+1) = S_PSV_all(k) + D_S_PSV*S_PSV*(1-S_PSV)*dt;
                S_SA_all(k+1)  = S_SA_all(k)  + D_S_SA*S_SA  *(1-S_SA)*dt;
                S_MD_all(k+1)  = S_MD_all(k)  + D_S_MD*S_MD  *(1-S_MD)*dt;
            else
                S_PHV_all(k+1) = S_PHV_all(k) + D_S_PHV*S_PHV*dt;
                S_LE_all(k+1)  = S_LE_all(k)  + D_S_LE*S_LE  *dt;
                S_GM_all(k+1)  = S_GM_all(k)  + D_S_GM*S_GM  *dt;
                S_IN_all(k+1)  = S_IN_all(k)  + D_S_IN*S_IN  *dt;
                S_PG_all(k+1)  = S_PG_all(k)  + D_S_PG*S_PG  *dt;
                S_SD_all(k+1)  = S_SD_all(k)  + D_S_SD*S_SD  *dt;
                S_UN_all(k+1)  = S_UN_all(k)  + D_S_UN*S_UN  *dt;
                S_SV_all(k+1)  = S_SV_all(k)  + D_S_SV*S_SV  *dt;
                S_TM_all(k+1)  = S_TM_all(k)  + D_S_TM*S_TM  *dt;
                S_PSV_all(k+1) = S_PSV_all(k) + D_S_PSV*S_PSV*dt;
                S_SA_all(k+1)  = S_SA_all(k)  + D_S_SA*S_SA  *dt;
                S_MD_all(k+1)  = S_MD_all(k)  + D_S_MD*S_MD  *dt;
            end
            y_model(k+1,:) = [
                S_PHV_all(k+1) S_LE_all(k+1) S_GM_all(k+1) S_IN_all(k+1) S_PG_all(k+1) ...
                S_SD_all(k+1)  S_UN_all(k+1) S_SV_all(k+1) S_TM_all(k+1) S_PSV_all(k+1) ...
                S_SA_all(k+1)  S_MD_all(k+1) ];
        end
    end
end
% EVALUATE THE DERIVATIVES
%     D_S_PHV = ...
%         + betas(1)*(S_LE)*(Exposure_to_Violent_Media + Bad_Governance ...
%                          - Youth_Empowerment + Neighborhood_Stigma) ...
%         + betas(2)*(S_GM)*(Territorial_Fights - S_LE) ...
%         - betas(3)*(S_PHV)*(S_SA) ...
%         - betas(4)*(S_PHV) ...
%         - betas(5)*(S_PHV)*(-Impunity_Governance);
% %   REMOVE COLLINEAR TERMS
% %       - 0       *(S_PHV)*(Family_Breakdown + Exposure_to_Violent_Media - Mental_Health) ...
% %       - 0       *(S_PHV)*(Economy) ...
%     D_S_LE = ...
%         + betas(6)*(S_GM)*(Gang_Control - Impunity_Governance) ...
%         - betas(7)*(S_LE) ...
%         + betas(5)*(S_PHV)*(-Impunity_Governance) ...
%         - betas(1)*(S_LE)*(Exposure_to_Violent_Media + Bad_Governance ...
%                          - Youth_Empowerment + Neighborhood_Stigma);
%     D_S_GM = ...
%         + betas(10)*(S_PG)*(Exposure_to_Violent_Media - S_LE - Family_Cohesion - Mental_Health) ...
%         + betas(11)*(S_MD)*(Deportation) ...
%         - (betas(31)+betas(44))*(S_GM) ...
%         - betas(13)*(S_GM)*(Gang_Cohesion + S_SA) ...
%         - betas( 2)*(S_GM)*(Territorial_Fights - S_LE) ...
%         - betas( 6)*(S_GM)*(Gang_Control - Impunity_Governance);
%     D_S_IN = ...
%         + betas( 7)*(S_LE) ...
%         - betas(17)*(S_IN); % deleted multiplier (S_PG)
%     D_S_PG = ...
%         + betas(17)*(S_IN) ...
%         + betas(19)*(S_UN)*(Exposure_to_Violent_Media) ...
%         + betas(20)*(S_PSV) ...
%         + betas(21)*(S_SV)*(-Gang_Control + Victimizer + S_GM) ...
%         + betas(22)*(S_PHV)*(Family_Breakdown + Exposure_to_Violent_Media - Mental_Health) ...
%         - betas(10)*(S_PG)*(Exposure_to_Violent_Media - S_LE - Family_Cohesion - Mental_Health);
%     D_S_SD = ...
%         + betas(24)*(S_TM)*(-Access_to_Abortion - Interventions + S_UN) ...
%         + betas(25)*(S_PSV)*(Bully - Interventions - School_Quality) ...
%         + betas( 4)*(S_PHV) ...
%         - betas(27)*(S_SD)*(Neighborhood_Stigma + Extortion - Economy_Opportunities);
%     D_S_UN = ...
%         + betas(27)*(S_SD)*(Neighborhood_Stigma + Extortion - Economy_Opportunities) ...
%         - betas(29)*(S_UN)*(Exposure_to_Violent_Media - Youth_Empowerment  ...
%                         + Family_Breakdown - Gang_Control);
% %   REMOVE COLLINEAR TERMS
% %       - 0.0990 *(S_UN)*(Machismo - Economy_Opportunities) ...
% %       - 0.00965*(S_UN)*(Exposure_to_Violent_Media);
%     D_S_SV = ...
%         + betas(30)*(S_SA)*(-Economy_Opportunities + Gang_Affiliation - S_LE - Mental_Health + S_SD) ...
%         + betas(31)*(S_GM) ...
%         + betas(32)*(S_PSV)*(S_SA) ...
%         + betas(29)*(S_UN)*(Exposure_to_Violent_Media + Family_Breakdown  ...
%                         - Youth_Empowerment - Gang_Control) ...
%         - betas(34)*(S_SV) ...
%         - betas(21)*(S_SV)*(-Gang_Control + Victimizer + S_GM);
% %   REMOVE COLLINEAR TERMS
% %       - 0      *(S_SV)*(-Access_to_Contraception) ...
%     D_S_TM = ...
%         + betas(36)*(S_SV)*(-Access_to_Contraception) ...
%         - betas(24)*(S_TM)*(-Access_to_Abortion - Interventions + S_UN);
%     D_S_PSV = ...
%         + betas(34)*(S_SV) ...
%         + betas( 3)*(S_PHV)*(S_SA) ...
%         + betas(40)*(S_MD)*(- Family_Cohesion) ...
%         + betas(13)*(S_GM)*(S_SA + Gang_Cohesion) ...
%         - betas(32)*(S_PSV)*(S_SA) ...
%         - betas(25)*(S_PSV)*(Bully - Interventions - School_Quality);
% %   REMOVE COLLINEAR TERMS
% %       - 0.01   *(S_PSV) ...
%     D_S_SA = ...
%         + betas(44)*(S_GM) ...
%         - betas(30)*(S_SA)*(-Economy_Opportunities + Gang_Affiliation - S_LE - Mental_Health + S_SD);
%     D_S_MD = ...
%         + betas(46)*(S_PHV)*(Economy) ...
%         + betas(47)*(S_UN)*(Machismo - Economy_Opportunities) ...
%         - betas(11)*(S_MD)*(Deportation) ...
%         - betas(40)*(S_MD)*(- Family_Cohesion);
%     
%     % SET STOCKS AT TIME t+1
%     for i=1:var_S_N
%         if flag_eval
%             idx = stocks_idx(i);
%             i_str = num2str(i);
%             S_var_name = strcat("S_",var_names_orig(idx));
%             D_var_name = strcat("D_",S_var_name);
%             D_var_name = strcat(D_var_name,"*",S_var_name);
%             eval_str = strcat(S_var_name,"_all(k+1) = ",S_var_name,"_all(k) + ",D_var_name,"*dt;");
%             eval(eval_str)
%             if k==1, fprintf('%s\n',eval_str), end
%             eval_str = strcat("y_model(k+1,",i_str,") = ",S_var_name,"_all(k+1);"); % set y
%             eval(eval_str)
%             if k==2, fprintf('%s\n',eval_str), end
%         else
%             S_PHV_all(k+1) = S_PHV_all(k) + D_S_PHV*S_PHV*(1-S_PHV)*dt;
%             S_LE_all(k+1)  = S_LE_all(k)  + D_S_LE*S_LE  *(1-S_LE)*dt;
%             S_GM_all(k+1)  = S_GM_all(k)  + D_S_GM*S_GM  *(1-S_GM)*dt;
%             S_IN_all(k+1)  = S_IN_all(k)  + D_S_IN*S_IN  *(1-S_IN)*dt;
%             S_PG_all(k+1)  = S_PG_all(k)  + D_S_PG*S_PG  *(1-S_PG)*dt;
%             S_SD_all(k+1)  = S_SD_all(k)  + D_S_SD*S_SD  *(1-S_SD)*dt;
%             S_UN_all(k+1)  = S_UN_all(k)  + D_S_UN*S_UN  *(1-S_UN)*dt;
%             S_SV_all(k+1)  = S_SV_all(k)  + D_S_SV*S_SV  *(1-S_SV)*dt;
%             S_TM_all(k+1)  = S_TM_all(k)  + D_S_TM*S_TM  *(1-S_TM)*dt;
%             S_PSV_all(k+1) = S_PSV_all(k) + D_S_PSV*S_PSV*(1-S_PSV)*dt;
%             S_SA_all(k+1)  = S_SA_all(k)  + D_S_SA*S_SA  *(1-S_SA)*dt;
%             S_MD_all(k+1)  = S_MD_all(k)  + D_S_MD*S_MD  *(1-S_MD)*dt;
%             y_model(k+1,:) = [
%                 S_PHV_all(k+1) S_LE_all(k+1) S_GM_all(k+1) S_IN_all(k+1) S_PG_all(k+1) ...
%                 S_SD_all(k+1)  S_UN_all(k+1) S_SV_all(k+1) S_TM_all(k+1) S_PSV_all(k+1) ...
%                 S_SA_all(k+1)  S_MD_all(k+1) ];
%         end
%     end
% end

% save into y and evaluate errors
y_err = nansum(nansum(weights_ts.*(y_model - y_data_ts).^2));

if flag_lasso==1
    y_err = y_err + sum(abs(betas))*lambda; % absolute sum
elseif flag_lasso==0
    y_err = y_err + sum(betas.^2)*lambda; % sum of squares
elseif flag_lasso==2
    idx_constrained = [2 18 19 4 15 27]; % corresponding to no data
    betas_constrained = [1.9622 1.2637 1.1608 1.5700 1.2395 2.7576]; % ES betas(idx_constrained)
    idx_not_constrained = setdiff(1:length(betas),idx_constrained);
    y_err = y_err + sum(betas(idx_not_constrained).^2)*lambda ...
        + sum((betas(idx_constrained) - betas_constrained).^2)*lambda;
end

return


function plot_betas(betas,fig_no)
global a_beta var_N var_S_N beta_N

i_order = [ 1:2 17:20 22:25 3:4 5:6 7 8:12 13:15 16 21 26 27:28];
x_pos = [(1:2) (3:6)+0.5 (7:10)+1 (11:12)+1.5 ...
    (13:14)+2 (15)+2.5 (16:20)+3 ...
    (21:23)+3.5 (24)+4 (25)+4.5 (26)+5 (27:28)+5.5];
for j=1:var_S_N; fprintf('%2i %s\n',j,a_beta(j)), end
fig = figure(230+fig_no); fig.Name = 'beta'; fig.Color = 'w';
fig.Position = [740 43 804 533];
barh(x_pos,betas(i_order)), ax = gca;
ax.YTick = x_pos;
ax.YTickLabel = a_beta(i_order); ax.YDir = 'reverse';
for j=1:var_N
    if j<=var_S_N
        fprintf('%2i %8.1f %8.1f %8.1f\n',j,betas([j beta_N+j beta_N+var_S_N+j]))
    else
        fprintf('%2i %8.1f\n',j,betas(j))
    end
end


function plot_results(fig_no, hold_on, var_S_N, ...
    var_names_orig, stocks_idx, yrs, y_data, var_names, years_N, yrs_lbl)
% PLOT MODEL DATA (comment out model results)
fig = figure(220+fig_no); fig.Name = 'compare data'; fig.Position = [680 263 1014 714];
if hold_on, clf, end
for i=1:var_S_N
    subplot(3,4,i)
    idx = stocks_idx(i);
    S_var_name_all = strcat("S_",var_names_orig(idx),"_all");
%   eval(strcat("plot(yrs,",S_var_name_all,",'-','LineWidth',2)"))
    if hold_on, hold on, sym = '-ko'; else, sym = '-r+'; end
    plot(yrs,y_data(:,i),sym,'LineWidth',2)
    if ~hold_on, hold off, end
    title(var_names(idx)), ax = gca; ax.XLim = [1 years_N]; ax.XTick = [1 years_N];
    ax.XTickLabel = yrs_lbl; ax.YLim = [0 1]; % can be negative
end
if ~hold_on % show legend only after second plot
    legend('data_2021_09_07.xlsx','data_2022_11_26TI_raw.xlsx','Interpreter','none')
end

return


function [ betas1,betas0,betas0s ] = load_betas(idx1,idx0)

global t_num

if t_num==1
    error("t_num = 1, this should be at least 4")
elseif t_num==4
%   lambda = 0.01, 0.001
    Betas0s = [
    0.8104    1.0623    0.2509
         0    4.3309    6.2118
         0    0.0002    0.0000
    0.0526    0.1672    0.0000
    0.4185    0.6020    0.0000
         0    0.0001    2.1207
         0         0    0.0000
         0         0    0.0000
    0.2532    1.7372    3.7182
    0.0041    1.1971    2.0245
    0.2282    0.2521    0.0000
         0    0.0001    0.0000
         0         0    0.0000
         0    0.0001    0.1548
    9.8100   14.4581    1.8719
    0.4203    0.1475    1.2592
         0         0    0.0000
    0.6116    0.5525    0.0000
    0.0118    0.0006    1.6576
         0    0.8246    0.0000
    0.0305    0.0001    0.0000
         0    3.4988    4.3403
         0    0.2624    1.4710
    0.0004    1.1630    0.0000
         0    1.2964    1.8460
    0.0828    0.0003    0.0000
    1.4162    6.2807    8.2384
    1.7945   13.2233   10.2145 ];
end

betas1 = Betas0s(:,idx1);
betas0 = Betas0s(:,idx0);
betas0s= Betas0s(:,1:end);
