function save_airfoil_dat(fullpath, airfoil, name)
% SAVE_AIRFOIL_DAT
% Writes XFLR5-compatible airfoil by controlled resampling

    % -------------------------------
    % PARAMETERS (critical)
    % -------------------------------
    N_target = 120;   % matches typical S1223 / GOE files

    % -------------------------------
    % Clean input
    % -------------------------------
    airfoil = airfoil(all(isfinite(airfoil),2),:);

    % Remove duplicates
    [~,ia] = unique(round(airfoil,8),'rows','stable');
    airfoil = airfoil(ia,:);

    % Split surfaces (TE -> LE -> TE)
    [~, iLE] = min(airfoil(:,1));

    upper = airfoil(1:iLE,:);
    lower = airfoil(iLE:end,:);

    % -------------------------------
% Physically correct x-based resampling
% -------------------------------
Nu = floor(N_target/2);
Nl = N_target - Nu;

% Ensure monotonic x
upper = sortrows(upper, -1);   % TE -> LE
lower = sortrows(lower,  1);   % LE -> TE

% Cosine-spaced x (better LE resolution)
beta_u = linspace(0, pi, Nu)';
beta_l = linspace(0, pi, Nl)';

xu = 0.5 * (1 + cos(beta_u));   % 1 → 0
xl = 0.5 * (1 - cos(beta_l));   % 0 → 1

% Interpolate y(x)
yu = interp1(upper(:,1), upper(:,2), xu, 'pchip');
yl = interp1(lower(:,1), lower(:,2), xl, 'pchip');

% Assemble final airfoil (TE → LE → TE)
airfoil_rs = [
    xu yu
    xl(2:end) yl(2:end)
];


    % -------------------------------
    % Write file
    % -------------------------------
    outdir = fileparts(fullpath);
    if ~isempty(outdir) && ~exist(outdir,'dir')
        mkdir(outdir);
    end

    fid = fopen(fullpath,'wt');
    if fid < 0
        error('Could not open file for writing:\n%s', fullpath);
    end

    fprintf(fid,'%s\n', name);
    fprintf(fid,'%.6f  %.6f\n', airfoil_rs.');

    fclose(fid);

    fprintf('✓ Airfoil saved (%d points, XFLR5-compatible)\n', size(airfoil_rs,1));
end
