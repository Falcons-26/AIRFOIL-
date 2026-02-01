function f = hicks_henne(x, eta)
% LE-safe Hicks–Henne bump

p = 1.5;
q = log(0.5) / log(eta);

f = zeros(size(x));

x_min = 0.05;
idx = x > x_min;

x_eff = (x(idx) - x_min) / (1 - x_min);
f(idx) = sin(pi * x_eff.^q).^p;
end
