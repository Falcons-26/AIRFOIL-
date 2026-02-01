function J = objective_dispatcher( ...
    x, baseline, config, Re_list, End_ref, Clmax_ref, mode)
% OBJECTIVE_DISPATCHER
%
% v2.2 UPDATE:
% - Adds MODE 4: Turbulent-LE Plateau Clmax
% - Designed for XTR = 0.02, Ncrit = 4
% - Robust, XFLR5-compatible Clmax definition
%
% Modes:
% 1 = Laminar Clmax (legacy)
% 2 = Endurance
% 3 = Dual
% 4 = Turbulent-LE Plateau Clmax  <-- NEW (RECOMMENDED)

penalty = 1e6;

Cl_plateau_vals = zeros(numel(Re_list),1);
Clmax_vals      = zeros(numel(Re_list),1);
End_vals        = zeros(numel(Re_list),1);

%% ------------------------------------------------------------
% Loop over Reynolds numbers
%% ------------------------------------------------------------
for i = 1:numel(Re_list)

    cfg = config;
    cfg.Re = Re_list(i);

    airfoil = apply_design_vector(baseline, x, cfg);

    [params, polar, ok] = xfoil_analysis(airfoil, cfg, false);
    if ~ok
        J = penalty;
        return;
    end

    alpha = polar.alpha;
    cl    = polar.cl;

    % Guard against bad polars
    if numel(alpha) < 10
        J = penalty;
        return;
    end

    % Store legacy metrics
    Clmax_vals(i) = max(cl);
    End_vals(i)   = params(10);

    % -------- MODE 4 CORE METRIC --------
    % Plateau Cl between 12 and 16 degrees
    mask = (alpha >= 12) & (alpha <= 16);

    if nnz(mask) < 3
        % No stable plateau -> early stall -> bad design
        Cl_plateau_vals(i) = -10;
    else
        Cl_plateau_vals(i) = mean(cl(mask));
    end
end

%% ------------------------------------------------------------
% Aggregate across Reynolds numbers
%% ------------------------------------------------------------
Cl_plateau_min = min(Cl_plateau_vals);
Clmax_min     = min(Clmax_vals);
End_avg       = mean(End_vals);

%% ------------------------------------------------------------
% Objective modes
%% ------------------------------------------------------------
switch mode

    case 1  % ===== Laminar Clmax (unchanged) =====
        J = -(Clmax_min - Clmax_ref) / Clmax_ref;

    case 2  % ===== Endurance only =====
        J = -(End_avg - End_ref) / End_ref;

    case 3  % ===== Dual =====
        wE = 0.7;
        wC = 0.3;
        J = -( ...
            wE * (End_avg - End_ref) / End_ref + ...
            wC * (Clmax_min - Clmax_ref) / Clmax_ref );

    case 4  % ===== Turbulent-LE Plateau Clmax (RECOMMENDED) =====
        % Pure maximization of sustained high-lift capability
        J = -Cl_plateau_min;

    otherwise
        error('Invalid objective mode');
end

end
