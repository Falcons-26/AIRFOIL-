function J = objective_airfoil_fmincon( ...
    x, baseline, config, paramList, optSpec, baselineParams)

% OBJECTIVE_AIRFOIL_FMINCON
% Baseline-relative, low-Re robust objective

%% ------------------------------------------------------------
% Decode design variables
%% ------------------------------------------------------------
a_upper = x(1:6);
a_lower = -0.5 * a_upper;

leScale    = x(13);
camber_fwd = x(14);

%% ------------------------------------------------------------
% Geometry deformation
%% ------------------------------------------------------------
airfoil_new = apply_hicks_henne( ...
    baseline, a_upper, a_lower, leScale, camber_fwd);

%% ------------------------------------------------------------
% Aerodynamics (silent)
%% ------------------------------------------------------------
[params, ~, success] = xfoil_analysis(airfoil_new, config, false);

if ~success
    J = 1e6;
    return;
end

%% ------------------------------------------------------------
% SAFETY CHECK
%% ------------------------------------------------------------
if numel(params) ~= numel(paramList)
    error('Param mismatch: params=%d, paramList=%d', ...
        numel(params), numel(paramList));
end

%% ------------------------------------------------------------
% Baseline-relative weighted objective
%% ------------------------------------------------------------
J = 0;

for k = optSpec.indices
    p  = params(k);
    p0 = baselineParams(k);

    if abs(p0) < 1e-6
        continue;
    end

    rel = (p - p0) / abs(p0);
    J   = J - optSpec.weights(k) * rel;
end

end
