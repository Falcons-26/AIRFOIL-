function geom = compute_geometry_metrics(airfoil)
% COMPUTE_GEOMETRY_METRICS
% Extracts key manufacturability-related geometry metrics

x = airfoil(:,1);
y = airfoil(:,2);

% Split upper/lower surfaces
[~, iLE] = min(x);
xu = x(1:iLE);   yu = y(1:iLE);
xl = x(iLE:end); yl = y(iLE:end);

% Common grid
xq = linspace(0,1,400)';
yuq = interp1(xu, yu, xq, 'linear','extrap');
ylq = interp1(xl, yl, xq, 'linear','extrap');

thickness_dist = yuq - ylq;
camber_dist    = 0.5 * (yuq + ylq);

geom.maxThickness = max(thickness_dist);
geom.minThickness = min(thickness_dist);
geom.maxCamber    = max(abs(camber_dist));

% Approximate LE radius (curvature proxy)
dx = diff(xu);
dy = diff(yu);
geom.leRadius = min( sqrt(dx.^2 + dy.^2) );

end
