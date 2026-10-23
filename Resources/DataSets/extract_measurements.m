function inventory = extract_measurements(datasetRoot)
%EXTRACT_MEASUREMENTS Export every measurement channel, grouped by rpm/Iexc.
%   extract_measurements uses this file's directory as datasetRoot.
%   Originals are read only. Full evaluations belong in SetN/FluxEval/.
%   Raw repeats, index-zero records and original channel metadata are kept.
%   Saved Meas structures (including Outliers and matrices) are copied exactly.
if nargin == 0
    datasetRoot = fileparts(mfilename('fullpath'));
end
datasetRoot = char(java.io.File(char(datasetRoot)).getCanonicalPath());
previousPath = path;
restorePath = onCleanup(@() path(previousPath)); %#ok<NASGU>
addpath(fileparts(datasetRoot));
sets = dir(fullfile(datasetRoot, 'Set*'));
sets = sets([sets.isdir]);
inventory = struct([]);
for k = 1:numel(sets)
    setRoot = fullfile(datasetRoot, sets(k).name);
    sources = dir(fullfile(setRoot, 'raw', '*.mat'));
    rawEntries = struct([]);
    for j = 1:numel(sources)
        source = fullfile(sources(j).folder, sources(j).name);
        fprintf('RAW  %s/%s\n', sets(k).name, sources(j).name);
        rawEntries = append_entry(rawEntries, extract_raw(source, setRoot, datasetRoot));
    end
    sources = dir(fullfile(setRoot, 'FluxEval', '*.mat'));
    evalEntries = struct([]);
    for j = 1:numel(sources)
        source = fullfile(sources(j).folder, sources(j).name);
        fprintf('MEAS %s/%s\n', sets(k).name, sources(j).name);
        evalEntries = append_entry(evalEntries, extract_evaluation(source, setRoot, datasetRoot));
    end
    item = struct('set', sets(k).name, 'raw', rawEntries, ...
        'evaluations', evalEntries, 'evaluation_status', 'available');
    if isempty(evalEntries)
        item.evaluation_status = 'pending';
    end
    inventory = append_entry(inventory, item);
end
manifest = struct('schema_version', 1, 'sets', inventory);
fid = fopen(fullfile(datasetRoot, 'inventory.json'), 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Cannot write inventory.json.');
closeFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(manifest, 'PrettyPrint', true));
fprintf('Extraction complete: %d sets. Run verify_measurements next.\n', numel(sets));
end

function entry = extract_raw(source, setRoot, datasetRoot)
loaded = load(source);
names = fieldnames(loaded);
assert(numel(names) == 1, 'Expected one recorder variable: %s', source);
raw = loaded.(names{1});
assert(isstruct(raw) && isfield(raw, 'Y') && isfield(raw, 'X'), ...
    'Unsupported recorder structure: %s', source);
assert(numel(raw.X) == 1, 'Expected one common sample axis: %s', source);
signalNames = cellfun(@(s) strrep(s, ' ', ''), {raw.Y.Name}, 'UniformOutput', false);
assert(numel(unique(signalNames)) == numel(signalNames), ...
    'Channel names collide after removing spaces: %s', source);
assert(all(cellfun(@isvarname, signalNames)), 'Invalid MATLAB channel name.');
rpm = raw.Y(strcmp(signalNames, 'PE_Rpm_req')).Data(:);
exc = raw.Y(strcmp(signalNames, 'I_exc_req')).Data(:);
index = raw.Y(strcmp(signalNames, 'PE_Index_meas')).Data(:);
n = numel(index);
assert(numel(rpm) == n && numel(exc) == n && numel(raw.X.Data) == n, ...
    'Grouping/sample axes have different lengths: %s', source);
assert(all(isfinite(rpm)) && all(isfinite(exc)) && all(isfinite(index)), ...
    'Nonfinite grouping coordinate/index: %s', source);
assert(all(arrayfun(@(s) isnumeric(s.Data) && isvector(s.Data) && numel(s.Data) == n, raw.Y)), ...
    'Expected one numeric value per sample in every channel: %s', source);
Total = struct;
summary = struct([]);
speeds = unique(rpm);
for r = 1:numel(speeds)
    speedName = axis_name(speeds(r), 'rpm');
    currents = unique(exc(rpm == speeds(r)));
    for c = 1:numel(currents)
        currentName = axis_name(currents(c), 'A');
        rows = find(rpm == speeds(r) & exc == currents(c));
        % Stable ordering retains the acquisition order of repeated samples.
        [~, order] = sort(index(rows));
        rows = rows(order);
        Meas = struct;
        for f = 1:numel(raw.Y)
            values = raw.Y(f).Data;
            Meas.(signalNames{f}) = reshape(values(rows), 1, []);
        end
        slice = struct('Meas', Meas, 'Ref_Speed', speeds(r), ...
            'Ref_exc_current', currents(c), 'SampleIndex', reshape(rows, 1, []), ...
            'Time', reshape(raw.X.Data(rows), 1, []));
        Total.(speedName).(currentName) = slice;
        s = slice_summary(speedName, currentName, slice, numel(rows), numel(signalNames));
        s.unique_measurement_indices = numel(unique(index(rows)));
        s.index_zero_samples = nnz(index(rows) == 0);
        summary = append_entry(summary, s);
    end
end
Signals = rmfield(raw.Y, 'Data');
for f = 1:numel(Signals)
    Signals(f).FieldName = signalNames{f};
end
Recorder = rmfield(raw, {'X', 'Y'});
Recorder.X = rmfield(raw.X, 'Data');
Metadata = source_metadata(source, datasetRoot, 'raw_samples');
Metadata.source_variable = names{1};
Metadata.sample_order = 'PE_Index_meas ascending; repeats in acquisition order';
Metadata.processing = 'No averaging, filtering, outlier removal or flux calculation';
Metadata.slices = summary;
destination = output_path(setRoot, 'raw', source);
save(destination, 'Total', 'Signals', 'Recorder', 'Metadata', '-v7');
entry = file_entry(source, destination, datasetRoot, summary);
end

function entry = extract_evaluation(source, setRoot, datasetRoot)
destination = output_path(setRoot, 'evaluation', source);
[destination, data] = extract_meas_from_fluxeval(source, destination);
Metadata = data.Metadata;
Metadata.source = relative_path(source, datasetRoot);
save(destination, 'Metadata', '-append');
entry = file_entry(source, destination, datasetRoot, Metadata.slices);
end

function s = slice_summary(speedName, currentName, slice, count, fieldCount)
s = struct('speed_group', speedName, 'excitation_group', currentName, ...
    'rpm', double(slice.Ref_Speed), 'excitation_A', double(slice.Ref_exc_current), ...
    'records', count, 'meas_fields', fieldCount);
end

function name = axis_name(value, unit)
prefix = 'pos_';
if value < 0
    prefix = 'neg_';
end
number = strrep(sprintf('%.15g', abs(value)), '.', 'p');
number = strrep(number, '-', 'm');
number = strrep(number, '+', 'p');
name = [prefix number '_' unit];
assert(isvarname(name), 'Invalid axis name %s', name);
end

function destination = output_path(setRoot, kind, source)
folder = fullfile(setRoot, 'extracted', kind);
if ~exist(folder, 'dir')
    mkdir(folder);
end
[~, stem] = fileparts(source);
destination = fullfile(folder, [stem '_measurements.mat']);
end

function metadata = source_metadata(source, root, kind)
info = dir(source);
metadata = struct('schema_version', 1, 'kind', kind, ...
    'source', relative_path(source, root), 'source_bytes', info.bytes);
end

function entry = file_entry(source, destination, root, slices)
input = dir(source);
output = dir(destination);
entry = struct('source', relative_path(source, root), 'source_bytes', input.bytes, ...
    'extract', relative_path(destination, root), 'extract_bytes', output.bytes, ...
    'records', sum([slices.records]), 'slices', slices);
end

function path = relative_path(path, root)
path = strrep(path(numel(root)+2:end), '\', '/');
end

function entries = append_entry(entries, entry)
if isempty(entries)
    entries = entry;
else
    entries(end+1) = entry;
end
end
