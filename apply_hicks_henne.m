function airfoil_new = apply_hicks_henne( ...
    baseline, a_upper, a_lower, leScale, camber_fwd)
% APPLY_HICKS_HENNE
% Hicks–Henne + LE radius + forward camber (LOW-Re safe)

x = baseline(:,1);
y = baseline(:,2);

% Locate leading edge
[~, iLE] = min(x);

% Split surfaces
xu = x(1:iLE);   yu = y(1:iLE);
xl = x(iLE:end); yl = y(iLE:end);

% Common grid
xg = linspace(0,1,400)';
yu_i = interp1(xu, yu, xg, 'pchip');
yl_i = interp1(xl, yl, xg, 'pchip');

% Baseline camber & thickness
camber    = 0.5*(yu_i + yl_i);
thickness = yu_i - yl_i;

%% ---------------- Hicks–Henne ----------------
nU = numel(a_upper);
eta = linspace(0.15,0.85,nU);

d_camber = zeros(size(xg));
d_thick  = zeros(size(xg));

for k = 1:nU
    b = hicks_henne(xg, eta(k));
    d_camber = d_camber + 0.3*a_upper(k)*b;
    d_thick  = d_thick  + 0.7*abs(a_upper(k))*b;
end

%% ---------------- Forward camber (scalar-controlled) ----------------
b_fwd = exp(-((xg - 0.18)/0.10).^2);   % 10–30% chord
d_camber = d_camber + camber_fwd .* b_fwd;

%% ---------------- LE radius control ----------------
le_shape = exp(-40*xg);                % local to LE
thickness = thickness .* (1 + (leScale - 1) .* le_shape);

%% ---------------- Reconstruct ----------------
thickness_new = max(thickness + d_thick, 0.04*max(thickness));
camber_new    = camber + d_camber;

yu_new = camber_new + 0.5*thickness_new;
yl_new = camber_new - 0.5*thickness_new;

airfoil_new = [
    flipud([xg, yu_new])
    [xg(2:end), yl_new(2:end)]
];
end

function f = hicks_henne(x, eta)
p = 1.5;
q = log(0.5) / log(eta);
f = zeros(size(x));
x0 = 0.05;
idx = x > x0;
xe = (x(idx) - x0) / (1 - x0);
f(idx) = sin(pi * xe.^q).^p;
end
