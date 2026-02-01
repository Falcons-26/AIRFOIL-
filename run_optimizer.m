% ============================================================
% RUN_OPTIMIZER.m — Airfoil Optimizer (pre-v1.0 test version)
% ============================================================

clear; clc;

fprintf('\n=== AIRFOIL OPTIMIZER ===\n');

%% ------------------------------------------------------------
% Select baseline airfoil
%% ------------------------------------------------------------
[fname, fpath] = uigetfile('*.dat','Select baseline airfoil');
if isequal(fname,0)
    error('No airfoil selected.');
end

baseline = readmatrix(fullfile(fpath,fname), ...
    'FileType','text','NumHeaderLines',1);
baseline = baseline(:,1:2);

geom0 = compute_geometry_metrics(baseline);

fprintf('\nBaseline geometry:\n');
fprintf(' Max thickness : %.4f\n', geom0.maxThickness);
fprintf(' Max camber    : %.4f\n', geom0.maxCamber);
fprintf(' LE radius     : %.4e\n', geom0.leRadius);

%% ------------------------------------------------------------
% Name optimized airfoil
%% ------------------------------------------------------------
airfoil_name = input('\nEnter name for optimized airfoil: ','s');

%% ------------------------------------------------------------
% Flow configuration (LOCKED)
%% ------------------------------------------------------------
config.xfoil_path = ...
"C:\Users\Joshua\Desktop\MATLAB\airfoil_nehamizer1\xfoil.exe";
config.work_dir = pwd;
config.Mach = 0.0;
config.Ncrit = 4;

Re_list = [150000 250000];

%% ------------------------------------------------------------
% Objective menu
%% ------------------------------------------------------------
fprintf('\nObjective modes:\n');
fprintf(' 1 : Clmax only\n');
fprintf(' 2 : Endurance only (Cl^(3/2)/Cd)\n');
fprintf(' 3 : Dual (Endurance + Clmax)\n');

mode = input('\nSelect objective mode: ');

%% ------------------------------------------------------------
% Build design vector
%% ------------------------------------------------------------
[x0, lb, ub, activeIdx] = build_design_vector(mode);

fprintf('\nActive design variables:\n');
disp(activeIdx');

%% ------------------------------------------------------------
% Baseline reference evaluation
%% ------------------------------------------------------------
End_ref = 0;
Clmax_ref = inf;

for Re = Re_list
    config.Re = Re;
    [params,~,ok] = xfoil_analysis(baseline, config, false);
    if ~ok
        error('Baseline XFOIL failed');
    end
    End_ref   = End_ref + params(10);
    Clmax_ref = min(Clmax_ref, params(4));
end
End_ref = End_ref / numel(Re_list);

fprintf('\nBaseline reference:\n');
fprintf(' Avg endurance = %.4f\n', End_ref);
fprintf(' Min Clmax     = %.4f\n', Clmax_ref);

%% ------------------------------------------------------------
% Optimization
%% ------------------------------------------------------------
opts = optimoptions('fmincon', ...
    'Algorithm','sqp', ...
    'Display','iter', ...
    'MaxIterations',40, ...
    'OptimalityTolerance',1e-4);

[x_opt, ~] = fmincon( ...
 @(x) objective_dispatcher( ...
        x, baseline, config, Re_list, ...
        End_ref, Clmax_ref, mode), ...
 x0, [], [], [], [], lb, ub, [], opts);


%% ------------------------------------------------------------
% Build optimized airfoil
%% ------------------------------------------------------------
airfoil_opt = apply_design_vector(baseline, x_opt, config);

%% ------------------------------------------------------------
% Post-optimization evaluation (AUTHORITATIVE)
%% ------------------------------------------------------------
End_opt = 0;
Clmax_opt = inf;

for Re = Re_list
    config.Re = Re;
    [params,~,ok] = xfoil_analysis(airfoil_opt, config, false);
    if ~ok
        warning('Optimized airfoil failed XFOIL');
        return;
    end
    End_opt   = End_opt + params(10);
    Clmax_opt = min(Clmax_opt, params(4));
end
End_opt = End_opt / numel(Re_list);

%% ------------------------------------------------------------
% Improvement gate (CRITICAL)
%% ------------------------------------------------------------
tol = 1e-4;
improved = false;

switch mode
    case 1
        improved = Clmax_opt > Clmax_ref * (1 + tol);
    case 2
        improved = End_opt > End_ref * (1 + tol);
    case 3
        improved = (End_opt > End_ref * (1 + tol)) || ...
                   (Clmax_opt > Clmax_ref * (1 + tol));
end

if ~improved
    fprintf('\n❌ No improvement detected.\n');
    fprintf(' Baseline airfoil is locally optimal for this objective.\n');
    fprintf(' No file saved.\n');
    return;
end

%% ------------------------------------------------------------
% Print result summary
%% ------------------------------------------------------------
geom_opt = compute_geometry_metrics(airfoil_opt);

fprintf('\n=== OPTIMIZATION RESULT ===\n');

fprintf('\nGeometry:\n');
fprintf(' Max thickness : %.4f  (Δ %.2f%%)\n', ...
    geom_opt.maxThickness, ...
    100*(geom_opt.maxThickness/geom0.maxThickness - 1));

fprintf(' Max camber    : %.4f  (Δ %.2f%%)\n', ...
    geom_opt.maxCamber, ...
    100*(geom_opt.maxCamber/geom0.maxCamber - 1));

fprintf(' LE radius     : %.4e  (Δ %.2f%%)\n', ...
    geom_opt.leRadius, ...
    100*(geom_opt.leRadius/geom0.leRadius - 1));

fprintf('\nAerodynamics (Re-averaged):\n');
fprintf(' Endurance     : %.4f  (Δ %.2f%%)\n', ...
    End_opt, 100*(End_opt/End_ref - 1));

fprintf(' Min Clmax     : %.4f  (Δ %.2f%%)\n', ...
    Clmax_opt, 100*(Clmax_opt/Clmax_ref - 1));

%% ------------------------------------------------------------
% Save optimized airfoil
%% ------------------------------------------------------------
outdir = ...
'C:\Users\Joshua\Desktop\MATLAB\airfoil_nehamizer1\data\optimized_airfoils';

outfile = fullfile(outdir, [airfoil_name '.dat']);

save_airfoil_dat(outfile, airfoil_opt, airfoil_name);

fprintf('\n✓ Optimized airfoil saved:\n%s\n', outfile);
