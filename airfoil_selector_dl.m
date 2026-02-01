function airfoil_selector_dl()
    % 1) Select Excel file and sheet
    [f,p] = uigetfile({'*.xlsx;*.xls','Excel files'});
    if isequal(f,0), error('No file selected.'); end
    excelPath = fullfile(p,f);
    fprintf('Selected file: %s\n', excelPath);

    sNames = sheetnames(excelPath);
    fprintf('\nSheets found:\n');
    for i = 1:numel(sNames)
        fprintf('%2d) %s\n', i, sNames{i});
    end
    sheetIdx = input('Select sheet index: ');
    assert(sheetIdx>=1 && sheetIdx<=numel(sNames),'Invalid sheet index.');

    T_re = readtable(excelPath, 'Sheet', sNames{sheetIdx}, ...
                     'ReadVariableNames', true);
    N = height(T_re);
    fprintf('\nLoaded sheet "%s" with %d airfoils.\n', sNames{sheetIdx}, N);

    % 2) Build normalized metric matrix from numeric columns
    allNames = T_re.Properties.VariableNames;
    metricNames  = {};
    directions   = strings(0,1);
    M_cols       = {};
    for i = 1:numel(allNames)
        name = allNames{i};
        if strcmp(name,'NameOfAirfoil') || strcmp(name,'AirfoilName')
            continue;
        end
        col = T_re.(name);
        if isnumeric(col)
            metricNames{end+1} = name; %#ok<AGROW>
            M_cols{end+1}      = col;  %#ok<AGROW>
            low = lower(name);
            if contains(low,'cd') || contains(low,'drag')
                directions(end+1,1) = "min";
            else
                directions(end+1,1) = "max";
            end
        end
    end

    K = numel(metricNames);
    M = zeros(N,K);
    for j = 1:K
        M(:,j) = M_cols{j};
    end

    M_norm = zeros(size(M));
    for j = 1:K
        col  = M(:,j);
        cmin = min(col); cmax = max(col);
        if cmax>cmin
            M_norm(:,j) = (col - cmin)/(cmax - cmin);
        else
            M_norm(:,j) = 0.5*ones(N,1);
        end
        if directions(j)=="min"
            M_norm(:,j) = 1 - M_norm(:,j);
        end
    end

    fprintf('Using %d metric columns:\n', K);
    for j = 1:K
        fprintf('%2d) %s (%s)\n', j, metricNames{j}, directions(j));
    end

    % 3) Hard filters
    applyFilter = input('\nDo you want to apply any hard filters? (1=yes,0=no): ');
    if applyFilter==1
        fprintf('\nNumeric variables available for filters:\n');
        for i = 1:K
            fprintf('%2d) %s\n', i, metricNames{i});
        end
        nFilters = input('\nHow many hard filters? ');
        keepIdx = true(N,1);
        for k = 1:nFilters
            fprintf('\nFilter %d of %d:\n', k, nFilters);
            idxVar = round(input('  Enter index of variable to filter on: '));
            if idxVar<1 || idxVar>K, error('Invalid variable index.'); end
            vName = metricNames{idxVar};
            fprintf('  For %s: 1) >= min   2) <= max\n', vName);
            fType = input('  Enter 1 or 2: ');
            switch fType
                case 1
                    val = input(sprintf('    Enter minimum value for %s: ', vName));
                    keepIdx = keepIdx & (T_re.(vName) >= val);
                case 2
                    val = input(sprintf('    Enter maximum value for %s: ', vName));
                    keepIdx = keepIdx & (T_re.(vName) <= val);
                otherwise
                    error('Filter type must be 1 or 2.');
            end
        end
        T_re   = T_re(keepIdx,:);
        M_norm = M_norm(keepIdx,:);
        [N,~]  = size(M_norm);
        fprintf('\nAfter filters, %d airfoils remain.\n', N);
        if N==0, error('No airfoils left after filtering.'); end
    end

    % 4) Choose metrics to optimize & targets
    fprintf('\nMetrics available:\n');
    for j = 1:K
        fprintf('%2d) %s (%s)\n', j, metricNames{j}, directions(j));
    end
    nOpt = input('\nHow many metrics do you want to optimize? ');
    optIdx = zeros(nOpt,1);
    for k = 1:nOpt
        idx = round(input(sprintf('  Enter index of metric %d: ', k)));
        if idx<1 || idx>K, error('Invalid metric index.'); end
        optIdx(k) = idx;
    end

    targetVec = 0.5*ones(K,1);
    fprintf('\nEnter desired target (0–1) for each selected metric:\n');
    for k = 1:nOpt
        j = optIdx(k);
        targetVec(j) = input(sprintf('  %s: ', metricNames{j}));
    end

    % 5) Deep Learning L-BFGS: define dlarray versions
    M_norm_dl    = dlarray(M_norm);
    targetVec_dl = dlarray(targetVec(:));
    optIdx_dl    = dlarray(optIdx(:));

    w0 = dlarray(ones(K,1)/K);   % initial weights
    w  = w0;

    lossFcn = @(wVar) dlfeval(@airfoilLoss, wVar, M_norm_dl, targetVec_dl, optIdx_dl);

    solverState = lbfgsState(HistorySize=10, InitialInverseHessianFactor=1.0);
    maxIter = 200; gradTol = 1e-6; stepTol = 1e-6;

    fprintf('\nStarting L-BFGS (Deep Learning Toolbox)...\n');
    for iter = 1:maxIter
        [w, solverState] = lbfgsupdate(w, lossFcn, solverState);
        if iter==1 || mod(iter,10)==0
            fprintf('Iter %3d | Loss %.3e | |grad| %.3e | step %.3e | %s\n', ...
                iter, solverState.Loss, solverState.GradientsNorm, ...
                solverState.StepNorm, solverState.LineSearchStatus);
        end
        if solverState.GradientsNorm < gradTol || ...
           solverState.StepNorm     < stepTol   || ...
           solverState.LineSearchStatus == "failed"
            fprintf('Stopping at iter %d.\n', iter);
            break;
        end
    end

    % 6) Extract weights, score, and rank
    w_opt = extractdata(w);
    w_opt = max(w_opt,0);
    if sum(w_opt)>0, w_opt = w_opt/sum(w_opt); end

    fprintf('\nOptimized weights (sum=%.3f):\n', sum(w_opt));
    for j = 1:K
        fprintf('  %-25s: %.3f\n', metricNames{j}, w_opt(j));
    end

    scores = M_norm * w_opt;
    T_re.Score = scores;

    [sortedScores, idx] = sort(scores,'descend');
    fprintf('\nTop 10 scores (raw values):\n');
    disp(sortedScores(1:min(10,numel(sortedScores))));
    if ismember('NameOfAirfoil', T_re.Properties.VariableNames)
        fprintf('Corresponding airfoils:\n');
        disp(T_re.NameOfAirfoil(idx(1:min(10,numel(idx)))));
    elseif ismember('AirfoilName', T_re.Properties.VariableNames)
        fprintf('Corresponding airfoils:\n');
        disp(T_re.AirfoilName(idx(1:min(10,numel(idx)))));
    end

    T_sorted = sortrows(T_re,'Score','descend');
    numTop = min(10,height(T_sorted));
    fprintf('\nTop %d airfoils in sheet "%s":\n', numTop, sNames{sheetIdx});
    disp(T_sorted(1:numTop,:));
end

function [L,grad] = airfoilLoss(w, M_norm_dl, targetVec_dl, optIdx_dl)
    % w: dlarray column from lbfgsupdate via dlfeval
    w = reshape(w,[],1);

    % mask: only selected metrics get nonzero weights
    mask = zeros(size(w),'like',w);
    mask(optIdx_dl) = 1;
    w = w .* mask;

    % nonnegative, normalized weights
    w_pos = max(w,0);
    w_sum = sum(w_pos) + eps;
    w_norm = w_pos / w_sum;

    % global-average metric vector (over all airfoils)
    m_avg = mean(M_norm_dl,1).';   % Kx1 dlarray

    diff = m_avg - targetVec_dl;
    L    = sum(diff.^2);           % scalar dlarray

    grad = dlgradient(L,w);
end
