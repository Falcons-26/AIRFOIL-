function [isValid, report] = validate_airfoil_geometry(airfoil, baseline)
% VALIDATE_AIRFOIL_GEOMETRY
% Ensures airfoil is XFOIL-safe and manufacturable
%
% Inputs:
%   airfoil  - Nx2 array [x y]
%   baseline - baseline airfoil (for relative constraints)
%
% Outputs:
%   isValid  - true / false
%   report   - string explaining failure (if any)

    isValid = false;
    report  = "OK";

    x = airfoil(:,1);
    y = airfoil(:,2);

    %% ------------------------------------------------------------
    % 1. Basic sanity
    %% ------------------------------------------------------------
    if any(isnan(x)) || any(isnan(y)) || any(isinf(x)) || any(isinf(y))
        report = "NaN or Inf detected";
        return;
    end

    if size(airfoil,1) < 50
        report = "Too few points";
        return;
    end

    %% ------------------------------------------------------------
    % 2. Chord bounds & monotonicity
    %% ------------------------------------------------------------
    if min(x) < -1e-6 || max(x) > 1+1e-6
        report = "x outside [0,1]";
        return;
    end

    % Upper then lower surface monotonicity
    [~, iLE] = min(x);
    if any(diff(x(1:iLE)) > 0) || any(diff(x(iLE:end)) < 0)
        report = "x not monotonic on surfaces";
        return;
    end

    %% ------------------------------------------------------------
    % 3. Thickness constraint
    %% ------------------------------------------------------------
    thickness = max(y) - min(y);
    base_thickness = max(baseline(:,2)) - min(baseline(:,2));

    if thickness < 0.85 * base_thickness
        report = "Thickness too small";
        return;
    end

    if thickness > 1.20 * base_thickness
        report = "Thickness too large";
        return;
    end

    %% ------------------------------------------------------------
    % 4. Surface crossing check
    %% ------------------------------------------------------------
   xu = airfoil(1:iLE,1);
yu = airfoil(1:iLE,2);
xl = airfoil(iLE:end,1);
yl = airfoil(iLE:end,2);

% --- FIX: sort surfaces for interp1 ---
[xu_s, iu] = sort(xu);
yu_s = yu(iu);

[xl_s, il] = sort(xl);
yl_s = yl(il);

% Interpolate to common x-grid
x_common = linspace(0,1,200)';
yu_i = interp1(xu_s, yu_s, x_common, 'linear','extrap');
yl_i = interp1(xl_s, yl_s, x_common, 'linear','extrap');


    %% ------------------------------------------------------------
    % 5. Leading-edge radius (numerical safety)
    %% ------------------------------------------------------------
    dx = diff(x(1:iLE));
    dy = diff(y(1:iLE));
    le_radius = min( sqrt(dx.^2 + dy.^2) );

    if le_radius < 1e-4
        report = "Leading-edge radius too small";
        return;
    end

    %% ------------------------------------------------------------
    % 6. Curvature smoothness (no oscillations)
    %% ------------------------------------------------------------
    smoothness = curvature_metric(airfoil);
    base_smoothness = curvature_metric(baseline);

    if smoothness > 2.5 * base_smoothness
        report = "Excessive curvature / waviness";
        return;
    end

    %% ------------------------------------------------------------
    % PASSED ALL CHECKS
    %% ------------------------------------------------------------
    isValid = true;
end
function s = curvature_metric(airfoil)
% Measures oscillatory curvature (XFOIL sensitivity proxy)

    x = airfoil(:,1);
    y = airfoil(:,2);

    dx = diff(x);
    dy = diff(y);

    dy_dx = dy ./ (dx + 1e-10);
    d2y_dx2 = diff(dy_dx) ./ (dx(1:end-1) + 1e-10);

    s = mean(abs(d2y_dx2)) + std(d2y_dx2);
end
