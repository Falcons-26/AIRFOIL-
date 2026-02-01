function [x0, lb, ub, activeIdx] = build_design_vector(mode)
% BUILD_DESIGN_VECTOR
% Returns design vector setup based on objective mode

% Design variable meaning:
% 1–12 : HH modes
% 13   : LE radius scale
% 14   : forward camber

x0 = zeros(14,1);
lb = zeros(14,1);
ub = zeros(14,1);

% Defaults (inactive)
lb(:) = 0;
ub(:) = 0;

switch mode

    case 1  % Clmax-only
        activeIdx = [3 4 5 6 13 14];
        lb(3:6)  = -0.008;  ub(3:6)  = 0.008;
        lb(13)   = 0.85;    ub(13)   = 1.15;
        lb(14)   = -0.02;   ub(14)   = 0.02;
        x0(13)   = 1.0;

    case 2  % Endurance-only
        activeIdx = [1 2 13 14];
        lb(1:2)  = -0.004;  ub(1:2)  = 0.004;
        lb(13)   = 0.9;     ub(13)   = 1.1;
        lb(14)   = -0.02;   ub(14)   = 0.02;
        x0(13)   = 1.0;

    case 3  % Re-averaged endurance
        activeIdx = [1 2 13 14];
        lb(1:2)  = -0.004;  ub(1:2)  = 0.004;
        lb(13)   = 0.9;     ub(13)   = 1.1;
        lb(14)   = -0.02;   ub(14)   = 0.02;
        x0(13)   = 1.0;

    case 4  % Dual objective
        activeIdx = [1 2 3 4 13 14];
        lb(1:4)  = -0.006;  ub(1:4)  = 0.006;
        lb(13)   = 0.9;     ub(13)   = 1.1;
        lb(14)   = -0.02;   ub(14)   = 0.02;
        x0(13)   = 1.0;

    otherwise
        error('Invalid mode');
end
end
