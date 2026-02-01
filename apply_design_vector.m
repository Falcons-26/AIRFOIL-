function airfoil = apply_design_vector(baseline, x, config)
% APPLY_DESIGN_VECTOR
% Maps full design vector (length 14) to geometry
%
% Design vector definition (LOCKED v1.0):
%  1–6   : Hicks–Henne upper modes
%  7–12  : (unused, kept zero)
%  13    : LE radius scale
%  14    : Forward camber

% ---------------- Decode ----------------
a_upper = zeros(6,1);
a_upper(:) = x(1:6);

% Lower surface tied (low-Re safe)
a_lower = -0.5 * a_upper;

% LE radius
leScale = x(13);

% Forward camber
camber_fwd = x(14);

% ---------------- Geometry ----------------
airfoil = apply_hicks_henne( ...
    baseline, ...
    a_upper, ...
    a_lower, ...
    leScale, ...
    camber_fwd );
end
