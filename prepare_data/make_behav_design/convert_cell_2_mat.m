function M = convert_cell_2_mat(C)
% Input: C - cell of size N x 1 or 1 x N

% Preallocate an size(C)x1 numeric vector with NaNs
M = nan(size(C));

% Loop over each element, and if the cell is non-empty, assign its value
for i = 1:numel(C)
    if ~isempty(C{i})
        M(i) = C{i};
    end
end

end

