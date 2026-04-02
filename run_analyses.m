clear all; close all;

%% Load the response data
T = readtable('data.csv');

%% Flags for running stats and saving figures
saveFigs = 1;
runStats = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Fit logistic models if requested
if(runStats) fit_model; end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Overall accuracy per model (collapsed over duration)

% get unique model names
models = unique(string(T.model_label));

% initialize a new table for results
overall = table;

% for each model
for i = 1:numel(models)

    mask = string(T.model_label) == models(i);  % just trials from this model
    n = sum(mask);                              % how many were there
    k = sum(T.is_correct_numeric(mask));        % how many of these were correct
    [p, ci] = binofit(k, n);                    % compute proportions

    overall = [overall;
        table(models(i), n, p, ci(1), ci(2), ...
        'VariableNames', {'Model','N','Accuracy','CI_Lower','CI_Upper'})];
end

disp('OVERALL ACCURACY');
disp(overall);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Real vs Fake accuracy by duration

% unique model labels
modelLabels     = string(T.model_label);
uniqueModels    = unique(modelLabels);

% identify real vs non-real models
isRealModel = contains(string(T.model_label), "real", 'IgnoreCase', true);
aiModels    = uniqueModels(~contains(uniqueModels,"real",'IgnoreCase',true));

% duration parsing
durCats     = categories(categorical(T.duration_label));
durVals     = str2double(erase(durCats,"s"));
nDur        = numel(durVals);

% placeholders for accuracy
pMat    = NaN(nDur, 2);
lowMat  = NaN(nDur, 2);
highMat = NaN(nDur, 2);

% store individual AI model curves
nAI = numel(aiModels);
pAI = NaN(nDur, nAI);

% for real or not real
for g = 1:2

    useReal = (g == 1);

    % for each duration
    for d = 1:nDur

        thisDur = durCats{d};

        % get appropriate indices
        mask    = (isRealModel == useReal) & strcmp(string(T.duration_label), thisDur);

        % compute accuracy and CI
        numTrials   = sum(mask);
        numCorrect  = sum(T.is_correct_numeric(mask));
        [p, ci]     = binofit(numCorrect, numTrials);
        pMat(d,g)   = 100*p;
        lowMat(d,g) = 100*(p - ci(1));
        highMat(d,g)= 100*(ci(2) - p);
    end
end

% individual AI model curves
for m = 1:nAI
    for d = 1:nDur

        thisDur = durCats{d};
        mask    = strcmp(modelLabels, aiModels(m)) & strcmp(string(T.duration_label), thisDur);

        numTrials   = sum(mask);
        numCorrect  = sum(T.is_correct_numeric(mask));
        pAI(d,m)    = 100*numCorrect / numTrials;
    end
end

% plot
figure; hold on;
errorbar(durVals, pMat(:,1), lowMat(:,1), highMat(:,1), '-o', 'LineWidth', 2); % real model (thick)
errorbar(durVals, pMat(:,2), lowMat(:,2), highMat(:,2), '-o', 'LineWidth', 2); % pooled AI (medium)

% individual AI models (thin red lines)
for m = 1:nAI
    plot(durVals, pAI(:,m), '-', 'Color', [0.8/m 0 0], 'LineWidth', 0.8);
end

xlabel('Duration'); ylabel('Accuracy');
ylim([40 100]); xlim([-1 9]);
legendEntries = [{'Real model','All AI models'}, cellstr(aiModels')];
legend(legendEntries, 'Location','best');
title('Accuracy by Duration');

if saveFigs; saveas(gcf, fullfile('figs','figure2.png')); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Sensitivity and Criterion by duration (pooled over models)

nBoot = 1000;  % bootstrap samples for CIs

% placeholders for results
dprime = NaN(nDur,1);
crit   = NaN(nDur,1);
dCI    = NaN(nDur,2);
cCI    = NaN(nDur,2);

% grab performance info needed for SDT analysis
isRealGT    = strcmpi(string(T.is_real),    "true");
isCorrect   = strcmpi(string(T.is_correct), "true");
respReal    = (isRealGT & isCorrect) | (~isRealGT & ~isCorrect);

% for each duration
for d = 1:nDur

    % grab the appropriate indices
    thisDur = durCats{d};
    idx = strcmp(string(T.duration_label), thisDur);

    gt  = isRealGT(idx);    % ground truth (0/1)
    rsp = respReal(idx);    % response "real" (0/1)

    % SDT metrics
    [dprime(d), crit(d)] = sdt_metrics(gt, rsp);

    % Bootstrap CIs
    n   = numel(gt);
    db  = zeros(nBoot,1);
    cb  = zeros(nBoot,1);
    for b = 1:nBoot
        samp = randi(n, n, 1);
        [db(b), cb(b)] = sdt_metrics(gt(samp), rsp(samp));
    end
    dCI(d,:) = prctile(db, [2.5 97.5]);
    cCI(d,:) = prctile(cb, [2.5 97.5]);
end

% Errors for plotting
dErrLow  = dprime - dCI(:,1);
dErrHigh = dCI(:,2) - dprime;
cErrLow  = crit   - cCI(:,1);
cErrHigh = cCI(:,2) - crit;

figure; hold on;

% d'
subplot(1,2,1); hold on;
errorbar(durVals, dprime, dErrLow, dErrHigh, '-o', 'LineWidth', 1.5);
xlabel('Duration'); ylabel('d''');
title('d'' by Duration');

% criterion
subplot(1,2,2); hold on;
errorbar(durVals, crit, cErrLow, cErrHigh, '-o', 'LineWidth', 1.5);
xlabel('Duration'); ylabel('Criterion c');
title('Criterion by Duration');

if saveFigs; saveas(gcf, fullfile('figs','figure3.png')); end

% table of plotted d' and criterion values
dprimeTable = table(durVals, dprime(:), dErrLow(:), dErrHigh(:), crit(:), cErrLow(:), cErrHigh(:), ...
    'VariableNames', {'Duration','dPrime','dErrLow','dErrHigh','Criterion','cErrLow','cErrHigh'});

disp('DPRIME AND CRITERION');
disp(dprimeTable);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Confidence ratings and calibration

% table of median confidence
medianTbl = groupsummary(T, "model_label", "median", "confidence");
disp(medianTbl);

% confidence calibration curves
% OLS on raw 0/1, pooled across stimuli

% grab unique durations and models
T.duration_label    = string(T.duration_label);
T.model_label       = string(T.model_label);
durCats             = unique(T.duration_label);
mdlCats             = unique(T.model_label);

% prep results table
Cal = table('Size',[0 7], 'VariableTypes',{'string','string','double','double','double','double','double'}, ...
    'VariableNames',{'duration_label','model_label','nTrials','slope_pp','se_pp','ciLo_pp','ciHi_pp'});

% for each duration and model
for d = 1:numel(durCats)
    for m = 1:numel(mdlCats)

        % get appropriate indices
        ii = (T.duration_label==durCats(d)) & (T.model_label==mdlCats(m));

        % grab confidence and correctness
        x = T.confidence(ii);
        y = T.is_correct_numeric(ii);

        lm = fitlm(x, y);                   % OLS
        b  = lm.Coefficients.Estimate(2);   % slope (proportion / unit)
        se = lm.Coefficients.SE(2);         % standard error of slope

        % store in table
        Cal = [Cal; {durCats(d), mdlCats(m), n, 100*b, 100*se, 100*(b - 1.96*se), 100*(b + 1.96*se)}];
    end
end

% AI pooled line: pool all non-Real trials within each duration
CalAI = table('Size',[0 7], 'VariableTypes',{'string','string','double','double','double','double','double'}, ...
    'VariableNames',{'duration_label','model_label','nTrials','slope_pp','se_pp','ciLo_pp','ciHi_pp'});

for d = 1:numel(durCats)

    ii = (T.duration_label==durCats(d)) & (T.model_label~="Real");

    x = T.confidence(ii);
    y = T.is_correct_numeric(ii);

    lm = fitlm(x, y);
    b  = lm.Coefficients.Estimate(2);
    se = lm.Coefficients.SE(2);

    CalAI = [CalAI; {durCats(d), "AI (pooled)", n, 100*b, 100*se, 100*(b - 1.96*se), 100*(b + 1.96*se)}];
end

% plot duration vs calibration
figure; hold on; box on;

Cal.dur_s   = str2double(erase(Cal.duration_label,"s"));
CalAI.dur_s = str2double(erase(CalAI.duration_label,"s"));

% other model lines (no CI)
for m = 1:numel(mdlCats)
    idx = Cal.model_label == mdlCats(m);
    x = Cal.dur_s(idx); y = Cal.slope_pp(idx);
    [x,ord] = sort(x); y = y(ord);
    plot(x, y, 'o-');
end

% Real line with 95% CI error bars
idxR = Cal.model_label == "Real";
x = Cal.dur_s(idxR); y = Cal.slope_pp(idxR);
lo = y - Cal.ciLo_pp(idxR);
hi = Cal.ciHi_pp(idxR) - y;
[x,ord] = sort(x); y = y(ord); lo = lo(ord); hi = hi(ord);
errorbar(x, y, lo, hi, 'o-', 'LineWidth', 1.5);


% AI pooled with 95% CI error bars
x = CalAI.dur_s; y = CalAI.slope_pp;
lo = y - CalAI.ciLo_pp;
hi = CalAI.ciHi_pp - y;
[x,ord] = sort(x); y = y(ord); lo = lo(ord); hi = hi(ord);
errorbar(x, y, lo, hi, 'k--', 'LineWidth', 1.5);


xlabel('Duration (s)');
ylabel('Confidence calibration (slope, percentage points / confidence unit)');
legend([cellstr(mdlCats); {'AI (pooled)'}], 'Location','best');
title('Confidence calibration vs duration (OLS on raw trials)');

if saveFigs; saveas(gcf, fullfile('figs','figure4.png')); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Per stimulus accuracy

% collapse T.column to everything up to the second underscore, generating a
% tag per unique content theme
colStr              = string(T.column);
colPrefix           = regexp(colStr, '^[^_]+_[^_]+', 'match', 'once');
missing             = ismissing(colPrefix);
colPrefix(missing)  = colStr(missing);
T.column_prefix     = categorical(colPrefix);

% ensure model labels are categorical
T.model_label = categorical(T.model_label);

% model and content them categories
rowCats = categories(T.model_label);
colCats = categories(T.column_prefix);

% mean accuracy per model_label & content theme
S = groupsummary(T, {'model_label','column_prefix'}, ...
    'mean', 'is_correct_numeric');

% get stimukus indices
[~, r] = ismember(string(S.model_label),    string(rowCats));
[~, c] = ismember(string(S.column_prefix), string(colCats));

% create matrix of per theme accuracy for each model
accMat = NaN(numel(rowCats), numel(colCats));
accMat(sub2ind(size(accMat), r, c)) = S.mean_is_correct_numeric;

% add top row: average across models
overallRow  = mean(accMat, 1, 'omitnan');
accMatPlus  = [overallRow; accMat];
rowCatsPlus = ["All models (mean)"; rowCats];

% reordering
accMatPlus  = accMatPlus([1,3,5,4,2],:);
rowCatsPlus = rowCatsPlus([1,3,5,4,2]);

% sort columns by overall accuracy (low → high) ---
[overallSorted, colOrder]   = sort(overallRow, 'descend');
accMatPlus                  = accMatPlus(:, colOrder);
colCats                     = colCats(colOrder);

% plot heatmap
figure;

h = heatmap(colCats, rowCatsPlus, accMatPlus);
h.ColorLimits = [0 1];
h.CellLabelFormat = '%.2f';
nColors = 256;
redGreenMap = [linspace(1,0,nColors)', linspace(0,1,nColors)', zeros(nColors,1)];
colormap(redGreenMap);

xlabel('Column (up to 2nd underscore)');
ylabel('Model');
title('Accuracy heatmap (top row = mean across models)');

if saveFigs; saveas(gcf, fullfile('figs','figure5A.png')); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Human vs nonhuman

% ensure types
T.duration_label    = string(T.duration_label);
T.durVal            = str2double(erase(T.duration_label,"s"));
T.model_label       = string(T.model_label);

% create column for human v nonhuman
T.motion = categorical( string( (T.stimulus>=1 & T.stimulus<=12) ) );
T.motion = renamecats(T.motion, ["false","true"], ["NonHuman","Human"]);

% create column for real v nonreal
T.model2 = repmat("NonReal", height(T), 1);
T.model2(strcmpi(T.model_label,"Real")) = "Real";
T.model2 = categorical(T.model2, ["Real","NonReal"]);

% accuracy + binomial 95% CI for each (duration x model2 x motion)
[G, dv, m2, mot] = findgroups(T.durVal, T.model2, T.motion);
k = splitapply(@sum,   T.is_correct_numeric, G);   % # correct
n = splitapply(@numel, T.is_correct_numeric, G);   % # trials

phat = nan(size(k)); lo = phat; hi = phat;
for g = 1:numel(k)
    [phat(g), pci] = binofit(k(g), n(g), 0.05);
    lo(g) = pci(1); hi(g) = pci(2);
end

Sum = table(dv, m2, mot, phat, lo, hi, 'VariableNames', {'durVal','model2','motion','acc','ciLo','ciHi'});
disp('HUMAN VS NOT');
disp(Sum);

% plot
figure; hold on;

motions = categories(Sum.motion);   % Human, NonHuman
models  = categories(Sum.model2);   % Real, NonReal

for p = 1:numel(motions)
    ls = "-"; if motions{p}=="NonHuman", ls="--"; end
    for i = 1:numel(models)
        idx = (Sum.motion==motions{p}) & (Sum.model2==models{i});
        [x, ord] = sort(Sum.durVal(idx));
        y  = 100*Sum.acc(idx);  y  = y(ord);
        el = 100*(Sum.acc(idx) - Sum.ciLo(idx)); el = el(ord);
        eu = 100*(Sum.ciHi(idx) - Sum.acc(idx)); eu = eu(ord);
        errorbar(x, y, el, eu, 'o', 'LineStyle', ls);
    end
end

xlabel('Duration (s)'); ylabel('Accuracy (%)');
legend({'Real–Human','NonReal–Human','Real–NonHuman','NonReal–NonHuman'}, 'Location','best');
title('Accuracy by Duration (binomial 95% CI)');

if saveFigs; saveas(gcf, fullfile('figs','figure6.png')); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Per participant accuracy

% ensure types
T.participant_id = string(T.participant_id);

% compute accuracy per participant
[G, pid] = findgroups(T.participant_id);
nTrials  = splitapply(@numel, T.is_correct_numeric, G);
nCorrect = splitapply(@sum,   T.is_correct_numeric, G);
accuracy = 100 * (nCorrect ./ nTrials);

AccTbl = table(pid, nTrials, nCorrect, accuracy, 'VariableNames', {'participant_id','nTrials','nCorrect','accuracy_pct'});

% sort best to worst
AccTbl = sortrows(AccTbl, 'accuracy_pct', 'descend');

% plot
figure;
plot(AccTbl.accuracy_pct, 'o-');
xlabel('Participants (sorted best → worst)');
ylabel('Accuracy (%)');
title('Participant Accuracy');

if saveFigs; saveas(gcf, fullfile('figs','figure5B.png')); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Correlation with time taken

% ensure types
T.participant_id      = string(T.participant_id);

% per-participant summaries
[G, pid] = findgroups(T.participant_id);
nTrials  = splitapply(@numel, T.is_correct_numeric, G);
nCorrect = splitapply(@sum,   T.is_correct_numeric, G);
meanTime = splitapply(@mean,  T.time_taken, G);

accuracy = 100 * (nCorrect ./ nTrials);

SummaryTbl = table(pid, nTrials, accuracy, meanTime, 'VariableNames', {'participant_id','nTrials','accuracy_pct','mean_time'});

% correlation
[r, p] = corr(meanTime, accuracy, 'Type','Pearson');

% display results
fprintf('\nPearson correlation: r = %.4f, p = %.6f\n', r, p);

% plot
figure; hold on; box on;
scatter(meanTime, accuracy, 40, 'filled');
lsline;  % best-fit regression line
xlabel('Time Taken (s)');
ylabel('Accuracy (%)');
title('Time vs Accuracy');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mobile vs not

% ensure types
T.participant_id      = string(T.participant_id);
T.is_mobile           = strcmpi(T.is_mobile, "true");

% compute overall accuracy by mobile status
[G, mobile] = findgroups(T.is_mobile);
nTrials     = splitapply(@numel, T.is_correct_numeric, G);
nCorrect    = splitapply(@sum,   T.is_correct_numeric, G);
accuracy    = 100 * (nCorrect ./ nTrials);

% unique participant × mobile pairs
U = unique(T(:, {'participant_id','is_mobile'}));

% count participants by mobile status
[G, mobile]     = findgroups(U.is_mobile);
nParticipants   = splitapply(@numel, U.participant_id, G);

disp('MOBILE');

CountTbl = table(mobile, nParticipants, 'VariableNames', {'is_mobile','nParticipants'});
AccTbl = table(mobile, nTrials, nCorrect, accuracy, 'VariableNames', {'is_mobile','nTrials','nCorrect','accuracy_pct'});

disp(CountTbl);
disp(AccTbl);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% strategies

% ensure types
T.participant_id    = string(T.participant_id);
T.strat1            = string(T.strat1);
T.strat2            = string(T.strat2);
T.strat3            = string(T.strat3);

% per-participant accuracy (for median split)
pid             = T.participant_id;
[G, pidNames]   = findgroups(pid);
acc             = splitapply(@mean, double(T.is_correct_numeric), G);   % proportion correct
AccTbl          = table(pidNames, acc, 'VariableNames', {'participant_id','acc'});

% grab one row per participant (strats are constant per participant)
U = unique(T(:, {'participant_id','strat1','strat2','strat3'}), 'rows');
nParticipants = height(U);

% one response string per participant
perParticipant = U.strat1 + " " + U.strat2 + " " + U.strat3;

% lemmatized word analysis (docs = participants)
docs = tokenizedDocument(lower(perParticipant));
docs = erasePunctuation(docs);
docs = removeStopWords(docs);
docs = normalizeWords(docs, 'Style','lemma');

docs = removeWords(docs, ["look","thing","like","image","try","video","something","just","seem","generate","anything","make",...
    "ai","real","obvious","go","aigenerated","watch"]);

% bag of words (documents = participants)
bag = bagOfWords(docs);

presence = bag.Counts > 0;                 % participants x words (logical)

% overall % participants using each word
participantCounts = sum(presence, 1);
participantPerc   = 100 * participantCounts / nParticipants;

% build + sort table
W_participants = table(string(bag.Vocabulary(:)), participantPerc(:), participantCounts(:), ...
    'VariableNames', {'Word','PercentParticipants','NumParticipants'});

W_participants = sortrows(W_participants, 'PercentParticipants', 'descend');

% merge "move" and "movement" into "movement/move" (union; no double-count)
idxMove = ismember(bag.Vocabulary, ["move","movement"]);
if any(idxMove)

    movePresenceAll = any(presence(:,idxMove), 2);
    combinedCount = sum(movePresenceAll);
    combinedPercent = 100 * combinedCount / nParticipants;

    % Remove old rows
    W_participants(ismember(W_participants.Word, ["move","movement"]), :) = [];

    % Add merged row
    newRow = table("movement/move", combinedPercent, combinedCount, ...
        'VariableNames', W_participants.Properties.VariableNames);

    W_participants = [W_participants; newRow];
    W_participants = sortrows(W_participants, 'PercentParticipants', 'descend');
end

% bar plot of top N words by % participants
topN = 20;
topW = W_participants(1:min(topN, height(W_participants)), :);

figure;
bar(topW.PercentParticipants);
set(gca, 'XTick', 1:height(topW), 'XTickLabel', topW.Word, 'XTickLabelRotation', 45);
ylabel('% Participants');
title('Top Strategy Words');

if saveFigs; saveas(gcf, fullfile('figs','figure7.png')); end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Helper function for SDT
function [dprime, c] = sdt_metrics(isReal, respReal)
% isReal: logical / 0-1, 1 = real stimulus
% respReal: logical / 0-1, 1 = "real" response

isReal   = logical(isReal);
respReal = logical(respReal);

H  = sum(isReal   & respReal); % hits
M  = sum(isReal   & ~respReal); % misses
F  = sum(~isReal  & respReal); % false alarms
CR = sum(~isReal  & ~respReal); % correct rejections

sN = H + M;       % number of real trials
nN = F + CR;      % number of fake trials

% hit and false alarm rates
HR  = (H) / (sN);
FAR = (F) / (nN);

% z values
zH = norminv(HR);
zF = norminv(FAR);

dprime = zH - zF;
c      = -0.5 * (zH + zF);   % SDT criterion (positive = conservative)
end
