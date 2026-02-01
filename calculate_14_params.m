function params = calculate_14_params(alpha, cl, cd, cm)
% Robust 14-parameter extraction for low-Re XFOIL data
% Handles duplicate CL values (common near stall)

% --- Sanity cleanup ---
valid = isfinite(alpha) & isfinite(cl) & isfinite(cd) & isfinite(cm);
alpha = alpha(valid);
cl    = cl(valid);
cd    = cd(valid);
cm    = cm(valid);

% --- Remove duplicate CL values (critical fix) ---
[cl_unique, ia] = unique(cl, 'stable');
alpha_u = alpha(ia);
cd_u    = cd(ia);
cm_u    = cm(ia);

% --- Sort by alpha (safety) ---
[alpha_u, idx] = sort(alpha_u);
cl_u = cl_unique(idx);
cd_u = cd_u(idx);
cm_u = cm_u(idx);

% --- 1. Zero-lift angle ---
AOA_0Lift = interp1(cl_u, alpha_u, 0, 'linear', 'extrap');

% --- 2. Lift slope ---
p = polyfit(alpha_u, cl_u, 1);
Lift_0AOA = p(1);

% --- 3–4. Clmax ---
[Clmax, imax] = max(cl_u);
Clmax_AOA = alpha_u(imax);

% --- 5–6. Cdmin ---
[Cdmin, imin] = min(cd_u);
AOA_Cdmin = alpha_u(imin);

% --- 7–8. L/D max ---
LD = cl_u ./ cd_u;
[LD_max, iLD] = max(LD);
AOA_LD_max = alpha_u(iLD);

% --- 9–10. Endurance (Cl^1.5 / Cd) ---
EnduranceMetric = cl_u.^1.5 ./ cd_u;
[Endurance, iE] = max(EnduranceMetric);
AOA_Endurance = alpha_u(iE);

% --- 11. dCL/dAOA (local slope near 0–5°) ---
mask = alpha_u >= 0 & alpha_u <= 5;
if nnz(mask) >= 2
    p_local = polyfit(alpha_u(mask), cl_u(mask), 1);
    dCL_dAOA = p_local(1);
else
    dCL_dAOA = NaN;
end

% --- 12–13. CL for endurance/range ---
CL_Endurance = cl_u(iE);
CL_Range     = CL_Endurance;

% --- 14. Cm at 0 deg ---
Cm_0 = interp1(alpha_u, cm_u, 0, 'linear', 'extrap');

% --- 15. Cl at 5 deg ---
Cl_5deg = interp1(alpha_u, cl_u, 5, 'linear', 'extrap');

% --- Pack output ---
params = [
    AOA_0Lift
    Lift_0AOA
    Clmax_AOA
    Clmax
    AOA_Cdmin
    Cdmin
    AOA_LD_max
    LD_max
    AOA_Endurance
    Endurance
    dCL_dAOA
    CL_Endurance
    CL_Range
    Cm_0
    Cl_5deg
];
end
