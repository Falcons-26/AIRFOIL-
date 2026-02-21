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

