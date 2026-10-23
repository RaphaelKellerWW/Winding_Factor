function [outputFile, data] = extract_meas_from_fluxeval(fluxEvalPath, outputFile)
%EXTRACT_MEAS_FROM_FLUXEVAL Save all Meas fields from one FluxEval as a MAT file.
%   outputFile = extract_meas_from_fluxeval('C:\path\FluxEval.mat')
%   outputFile = extract_meas_from_fluxeval(sourcePath, destinationPath)
%
%   Total.<rpm>.<Iexc>.Meas preserves the original measurements and shapes.
%   Meas.<channel>{excitationRow, speedColumn} provides the sorted cell layout
%   used by calculate_winding_factor.m, for EVERY field (including substructs).
%   rpm_ref, exc_ref and exc_fields identify each cell; missing cells are [].
%   Speeds and each speed's excitation groups are sorted by Ref_* values.
%   No averaging, filtering, flattening or recalculation is performed.
%
%   Default output: <source folder>/<source name>_measurements.mat.
%   For a source in FluxEval/, use ../extracted/evaluation/ instead.
%   The source file is never overwritten. Only Total and Info are loaded.
fluxEvalPath = char(fluxEvalPath);
assert(isfile(fluxEvalPath), 'DataSets:MissingSource', 'File not found: %s', fluxEvalPath);
fluxEvalPath = char(java.io.File(fluxEvalPath).getCanonicalPath());
[folder, stem, extension] = fileparts(fluxEvalPath);
if nargin < 2 || isempty(outputFile)
    [~, folderName] = fileparts(folder);
    if strcmpi(folderName, 'FluxEval')
        folder = fullfile(fileparts(folder), 'extracted', 'evaluation');
    end
    outputFile = fullfile(folder, [stem '_measurements.mat']);
end
outputFile = char(outputFile);
[~, ~, outputExtension] = fileparts(outputFile);
if isempty(outputExtension)
    outputFile = [outputFile '.mat'];
else
    assert(strcmpi(outputExtension, '.mat'), 'DataSets:OutputFormat', ...
        'Output must be a MAT file.');
end
outputFile = char(java.io.File(outputFile).getCanonicalPath());
assert(~strcmpi(fluxEvalPath, outputFile), 'DataSets:SourceOverwrite', ...
    'Output must differ from the source FluxEval.');
variables = whos('-file', fluxEvalPath);
assert(ismember('Total', {variables.name}), 'DataSets:MissingTotal', 'Source has no Total structure.');
requested = intersect({'Total', 'Info'}, {variables.name}, 'stable');
input = load(fluxEvalPath, requested{:});
names = fieldnames(input.Total);
rpmNames = names(~cellfun('isempty', regexp(names, '^(pos|neg)_.+_rpm$', 'once')));
groups = {};
for r = 1:numel(rpmNames)
    rpmGroup = input.Total.(rpmNames{r});
    names = fieldnames(rpmGroup);
    excNames = names(~cellfun('isempty', regexp(names, '^(pos|neg)_.+_A$', 'once')));
    for c = 1:numel(excNames)
        slice = rpmGroup.(excNames{c});
        assert(isfield(slice, 'Meas') && isstruct(slice.Meas), ...
            'DataSets:MissingMeas', 'Missing Meas in %s.%s', rpmNames{r}, excNames{c});
        assert(isfield(slice, 'Ref_Speed') && isfield(slice, 'Ref_exc_current'), ...
            'DataSets:MissingReference', 'Missing Ref_* grouping coordinates.');
        validateattributes(slice.Ref_Speed, {'numeric'}, {'scalar', 'real', 'finite'});
        validateattributes(slice.Ref_exc_current, {'numeric'}, {'scalar', 'real', 'finite'});
        fields = fieldnames(slice);
        slice = rmfield(slice, fields(~strcmp(fields, 'Meas') & ~startsWith(fields, 'Ref_')));
        groups{end+1} = struct('rpmName', rpmNames{r}, 'excName', excNames{c}, ...
            'speed', double(slice.Ref_Speed), 'current', double(slice.Ref_exc_current), ...
            'slice', slice); %#ok<AGROW>
    end
end
assert(~isempty(groups), 'DataSets:NoMeasurements', 'No rpm/Iexc measurement groups found.');
groups = [groups{:}];
[~, order] = sortrows([[groups.speed]' [groups.current]'], [1 2]);
groups = groups(order);
rpm_fields = unique({groups.rpmName}', 'stable');
counts = cellfun(@(s) nnz(strcmp({groups.rpmName}, s)), rpm_fields);
shape = [max(counts), numel(rpm_fields)];
exc_ref = cell(shape);
rpm_ref = cell(shape);
exc_fields = cell(shape);
allFields = {};
for k = 1:numel(groups)
    allFields = union(allFields, fieldnames(groups(k).slice.Meas), 'stable');
end
Meas = struct;
for f = 1:numel(allFields)
    Meas.(allFields{f}) = cell(shape);
end
Total = struct;
slices = struct('speed_group', {}, 'excitation_group', {}, 'rpm', {}, ...
    'excitation_A', {}, 'records', {}, 'meas_fields', {});
for r = 1:numel(rpm_fields)
    selected = find(strcmp({groups.rpmName}, rpm_fields{r}));
    for c = 1:numel(selected)
        k = selected(c);
        g = groups(k);
        Total.(g.rpmName).(g.excName) = g.slice;
        exc_ref{c, r} = g.slice.Ref_exc_current;
        rpm_ref{c, r} = g.slice.Ref_Speed;
        exc_fields{c, r} = g.excName;
        fields = fieldnames(g.slice.Meas);
        for f = 1:numel(fields)
            Meas.(fields{f}){c, r} = g.slice.Meas.(fields{f});
        end
        slices(k) = struct('speed_group', g.rpmName, 'excitation_group', g.excName, ...
            'rpm', g.speed, 'excitation_A', g.current, ...
            'records', numel(g.slice.Meas.PE_Index_meas), 'meas_fields', numel(fields));
    end
end
data = struct;
data.Total = Total;
data.Meas = Meas;
data.rpm_fields = rpm_fields;
data.exc_fields = exc_fields;
data.rpm_ref = rpm_ref;
data.exc_ref = exc_ref;
if isfield(input.Total, 'OptimParam')
    data.OptimParam = input.Total.OptimParam;
end
if isfield(input, 'Info')
    data.Info = input.Info;
end
sourceInfo = dir(fluxEvalPath);
data.Metadata = struct('schema_version', 1, 'kind', 'evaluated_measurements', ...
    'source', [stem extension], 'source_bytes', sourceInfo.bytes, ...
    'processing', 'Exact saved Meas/Ref_* copy; cell rows sorted per speed by Ref_exc_current', ...
    'slices', slices);
folder = fileparts(outputFile);
if ~exist(folder, 'dir')
    mkdir(folder);
end
save(outputFile, '-struct', 'data', '-v7');
end
