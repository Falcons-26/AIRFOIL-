function [alpha, cl, cd, cm] = parse_xfoil_polar(filename)

alpha = [];
cl = [];
cd = [];
cm = [];

fid = fopen(filename,'r');
lines = textscan(fid,'%s','Delimiter','\n');
fclose(fid);
lines = lines{1};

% Find header separator
startLine = 0;
for i = 1:length(lines)
    if contains(lines{i}, '-----')
        startLine = i+1;
        break;
    end
end

if startLine == 0
    return;
end

for i = startLine:length(lines)
    vals = sscanf(lines{i},'%f');
    if numel(vals) >= 5
        alpha(end+1,1) = vals(1);
        cl(end+1,1)    = vals(2);
        cd(end+1,1)    = vals(3);
        cm(end+1,1)    = vals(5);
    end
end
end
