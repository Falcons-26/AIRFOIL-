function [params, polar, success] = xfoil_analysis(airfoil, config, verbose)

if nargin < 3
    verbose = false;
end

params  = [];
polar   = struct();
success = false;

%% ------------------------------------------------------------------------
% Write airfoil
%% ------------------------------------------------------------------------
airfoil_file = fullfile(config.work_dir, 'airfoil.dat');
fid = fopen(airfoil_file,'w');
fprintf(fid,'Airfoil\n');
fprintf(fid,'%.8f %.8f\n', airfoil');
fclose(fid);

%% ------------------------------------------------------------------------
% Remove old polar to avoid XFOIL prompts  <<< CRITICAL
%% ------------------------------------------------------------------------
polar_file = fullfile(config.work_dir,'polar.out');
if isfile(polar_file)
    delete(polar_file);
end

%% ------------------------------------------------------------------------
% Write XFOIL input (NON-INTERACTIVE)
%% ------------------------------------------------------------------------
input_file = fullfile(config.work_dir,'xfoil.inp');
fid = fopen(input_file,'w');

fprintf(fid,'LOAD airfoil.dat\n');
fprintf(fid,'PANE\n');
fprintf(fid,'OPER\n');
fprintf(fid,'VISC %.0f\n', config.Re);
fprintf(fid,'MACH %.3f\n', config.Mach);

% ---- LOW-Re SETTINGS (FORCED EVERY RUN) ----
fprintf(fid,'VPAR\n');
fprintf(fid,'N 4\n');              % Ncrit = 4
fprintf(fid,'XTR 0.05 0.10\n');    % Early transition
fprintf(fid,'\n');                 % exit VPAR
% ------------------------------------------

% ---- Polar accumulation (NO PROMPTS) ----
fprintf(fid,'PACC\n');
fprintf(fid,'polar.out\n\n');

% ---- Alpha sweep ----
fprintf(fid,'ASEQ -2 10 0.25\n');

% ---- STOP POLAR + EXIT CLEANLY ----
fprintf(fid,'PACC\n\n');
fprintf(fid,'QUIT\n');

fclose(fid);

%% ------------------------------------------------------------------------
% Run XFOIL safely
%% ------------------------------------------------------------------------
cwd = pwd;
builtin('cd', config.work_dir);

cmd = sprintf('"%s" < xfoil.inp', config.xfoil_path);
[~,~] = system(cmd);

builtin('cd', cwd);

%% ------------------------------------------------------------------------
% Parse results
%% ------------------------------------------------------------------------
if ~isfile(polar_file)
    if verbose
        fprintf('✗ XFOIL failed (no polar.out)\n');
    end
    return;
end

[alpha, cl, cd_val, cm] = parse_xfoil_polar(polar_file);

if numel(alpha) < 6
    return;
end

params = calculate_14_params(alpha, cl, cd_val, cm);

polar.alpha = alpha;
polar.cl    = cl;
polar.cd    = cd_val;
polar.cm    = cm;

success = true;

if verbose
    fprintf('✓ XFOIL success (Re=%.0f, Ncrit=4)\n', config.Re);
end
end
