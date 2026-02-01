function [c, ceq] = airfoil_nonlcon(x, baseline, constraintSpec)

ceq = [];
c   = [];

if isempty(constraintSpec)
    return;
end
a_upper    = x(1:6);
a_lower    = -0.5 * a_upper;
leScale    = x(13);
camber_fwd = x(14);

airfoil_new = apply_hicks_henne( ...
    baseline, a_upper, a_lower, leScale, camber_fwd);



% -------------------------------------------------
% Extract geometry metrics from airfoil
% -------------------------------------------------
x = airfoil_new(:,1);
y = airfoil_new(:,2);

[~, iLE] = min(x);

xu = x(1:iLE);    yu = y(1:iLE);
xl = x(iLE:end);  yl = y(iLE:end);

xg = linspace(0,1,300)';

yu_i = interp1(xu, yu, xg, 'linear', 'extrap');
yl_i = interp1(xl, yl, xg, 'linear', 'extrap');

thickness_dist = yu_i - yl_i;
camber_dist    = 0.5 * (yu_i + yl_i);

% Ignore LE / TE for minimum thickness (important)
idx = (xg > 0.05 & xg < 0.95);

tmax = max(thickness_dist);
tmin = min(thickness_dist(idx));
cmax = max(abs(camber_dist));

c = [];

% Maximum thickness
c(end+1) = tmax - constraintSpec.maxThickness;

% Minimum thickness
c(end+1) = constraintSpec.minThickness - tmin;

% Maximum camber
c(end+1) = cmax - constraintSpec.maxCamber;

% Optional LE radius constraint
if ~isempty(constraintSpec.minLERadius)
    dx = diff(x(1:iLE));
    dy = diff(y(1:iLE));
    leRadius = min(sqrt(dx.^2 + dy.^2));
    c(end+1) = constraintSpec.minLERadius - leRadius;
end
