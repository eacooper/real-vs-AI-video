%% set up variables for model

% Real/fake response as a 0/1 numeric
T.response_real = double(strcmpi(T.response, 'Real'));

% create a column that identifies each unique model + content theme, which
% is what we'll use as the random effect for stimulus
stim_str = string(T.stimulus);
T.model_stim = categorical(T.model_code + "_" + stim_str);

% add duration column with true durations in sec as numeric, 0 will be baseline
T.duration = T.duration_code;
T.duration(T.duration_code == 1) = 2;
T.duration(T.duration_code == 2) = 4;
T.duration(T.duration_code == 3) = 6;
T.duration(T.duration_code == 4) = 8;

% Categorical predictors / grouping factors
T.participant_id = categorical(T.participant_id);
T.model_stim     = categorical(T.model_stim);
T.model_label    = categorical(T.model_label);

% Baseline for model_label is REAL
T.model_label = categorical(T.model_label, {'Real','Veo 3.1','Sora','Bytedance Seedance Pro'}, 'Ordinal', false);

% z score confidence ratings
T.conf_z = (T.confidence - mean(T.confidence)) / std(T.confidence);

%% fit model for REAL responses (no confidence ratings included)

glme_sdt = fitglme(T, 'response_real ~ model_label * duration + (1 | participant_id) + (1 + duration | model_stim)', ...
    'Distribution','Binomial', 'Link','logit', 'FitMethod','MPL');

disp(glme_sdt);

% compute and report odds ratios

coefTbl = glme_sdt.Coefficients;    % Extract fixed effects table
beta    = coefTbl.Estimate;             % Log-odds estimates
SE      = coefTbl.SE;                   % Log-odds standard error
OR      = exp(beta);                    % Odds ratios

% 95% confidence intervals (log-odds -> odds)
CI_lower = exp(beta - 1.96 .* SE);
CI_upper = exp(beta + 1.96 .* SE);

% Combine into a clean table
OR_table = table(coefTbl.Name, beta, SE, OR, CI_lower, CI_upper, coefTbl.tStat, coefTbl.pValue, ...
    'VariableNames', {'Predictor','Beta','SE','OR','CI_Lower','CI_Upper','t','p'} );

disp(OR_table);


%% does confidence predict accuracy?
% this model now aims to understand the relationship between response
% accuracy, confidence, model, and duration. 

glme_acc_conf = fitglme(T, 'is_correct_numeric ~ conf_z * model_label * duration + (1 | participant_id) + (1 + duration | model_stim)', ...
 'Distribution','Binomial','Link','logit','FitMethod','MPL');

disp(glme_acc_conf);

% compute and report odds ratios

coefTbl = glme_acc_conf.Coefficients;    % Extract fixed effects table
beta    = coefTbl.Estimate;             % Log-odds estimates
SE      = coefTbl.SE;                   % Log-odds standard error
OR      = exp(beta);                    % Odds ratios

% 95% confidence intervals (log-odds -> odds)
CI_lower = exp(beta - 1.96 .* SE);
CI_upper = exp(beta + 1.96 .* SE);

% Combine into a clean table
OR_table = table(coefTbl.Name, beta, SE, OR, CI_lower, CI_upper, coefTbl.tStat, coefTbl.pValue, ...
    'VariableNames', {'Predictor','Beta','SE','OR','CI_Lower','CI_Upper','t','p'} );

disp(OR_table);