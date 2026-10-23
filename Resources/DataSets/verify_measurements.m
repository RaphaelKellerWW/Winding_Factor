function verify_measurements(datasetRoot)
%VERIFY_MEASUREMENTS Compare all exported values and shapes with the originals.
%   Raw verification works on a Git clone. Evaluation checks require the local
%   ignored FluxEval files and are reported as skipped when those are absent.
if nargin == 0
    datasetRoot = fileparts(mfilename('fullpath'));
end
manifest = jsondecode(fileread(fullfile(datasetRoot, 'inventory.json')));
checkedRaw = 0;
checkedEval = 0;
skippedEval = 0;
for k = 1:numel(manifest.sets)
    item = manifest.sets(k);
    for j = 1:numel(item.raw)
        entry = item.raw(j);
        input = load(fullfile(datasetRoot, entry.source));
        names = fieldnames(input);
        raw = input.(names{1});
        exported = load(fullfile(datasetRoot, entry.extract));
        n = numel(raw.Y(1).Data);
        sampleCounts = zeros(n, 1);
        channelNames = cellfun(@(s) strrep(s, ' ', ''), {raw.Y.Name}, 'UniformOutput', false);
        assert(isequaln(exported.Signals, signal_metadata(raw.Y, channelNames)), ...
            'Signal metadata changed in %s', entry.extract);
        recorder = rmfield(raw, {'X', 'Y'});
        recorder.X = rmfield(raw.X, 'Data');
        assert(isequaln(exported.Recorder, recorder), 'Recorder metadata changed.');
        assert(numel(entry.slices) == count_slices(exported.Total));
        rpmValues = [];
        speeds = fieldnames(exported.Total);
        for r = 1:numel(speeds)
            currents = fieldnames(exported.Total.(speeds{r}));
            currentValues = [];
            for c = 1:numel(currents)
                slice = exported.Total.(speeds{r}).(currents{c});
                rows = slice.SampleIndex;
                assert(all(rows >= 1 & rows <= n & rows == fix(rows)));
                assert(numel(unique(rows)) == numel(rows));
                sampleCounts(rows) = sampleCounts(rows) + 1;
                assert(isequal(fieldnames(slice.Meas), channelNames(:)), 'Missing/reordered raw channels.');
                for f = 1:numel(raw.Y)
                    expected = reshape(raw.Y(f).Data(rows), 1, []);
                    assert(isequaln(slice.Meas.(channelNames{f}), expected), ...
                        'Raw values changed: %s/%s', entry.source, channelNames{f});
                end
                assert(isequaln(slice.Time, reshape(raw.X.Data(rows), 1, [])));
                assert(all(slice.Meas.PE_Rpm_req == slice.Ref_Speed));
                assert(all(slice.Meas.I_exc_req == slice.Ref_exc_current));
                measurementIndex = slice.Meas.PE_Index_meas;
                assert(issorted(measurementIndex));
                tied = diff(measurementIndex) == 0;
                acquisitionSteps = diff(rows);
                assert(all(acquisitionSteps(tied) > 0), 'Repeated samples changed acquisition order.');
                currentValues(end+1) = slice.Ref_exc_current; %#ok<AGROW>
            end
            assert(issorted(currentValues));
            rpmValues(end+1) = slice.Ref_Speed; %#ok<AGROW>
        end
        assert(issorted(rpmValues));
        assert(all(sampleCounts == 1), 'Raw samples missing or duplicated: %s', entry.source);
        assert(entry.records == n);
        checkedRaw = checkedRaw + 1;
        fprintf('PASS raw: %s (%d samples, %d channels)\n', entry.source, n, numel(channelNames));
    end
    for j = 1:numel(item.evaluations)
        entry = item.evaluations(j);
        output = load(fullfile(datasetRoot, entry.extract));
        assert(numel(entry.slices) == count_slices(output.Total));
        if ~isfile(fullfile(datasetRoot, entry.source))
            skippedEval = skippedEval + 1;
            fprintf('SKIP source comparison (local FluxEval absent): %s\n', entry.source);
            continue;
        end
        source = fullfile(datasetRoot, entry.source);
        variables = whos('-file', source);
        requested = intersect({'Total', 'Info'}, {variables.name}, 'stable');
        input = load(source, requested{:});
        speeds = fieldnames(input.Total);
        speeds = speeds(~cellfun('isempty', regexp(speeds, '^(pos|neg)_.+_rpm$', 'once')));
        assert(isequal(sort(fieldnames(output.Total)), sort(speeds)), 'Missing speed group.');
        rpmValues = [];
        speeds = fieldnames(output.Total);
        assert(isequal(output.rpm_fields, speeds), 'Cell columns have incorrect speed labels.');
        allMeasFields = {};
        records = 0;
        for r = 1:numel(speeds)
            inputGroup = input.Total.(speeds{r});
            outputGroup = output.Total.(speeds{r});
            inputCurrents = fieldnames(inputGroup);
            inputCurrents = inputCurrents(~cellfun('isempty', ...
                regexp(inputCurrents, '^(pos|neg)_.+_A$', 'once')));
            assert(isequal(sort(inputCurrents), sort(fieldnames(outputGroup))), ...
                'Missing excitation group.');
            currents = fieldnames(outputGroup);
            currentValues = [];
            for c = 1:numel(currents)
                original = inputGroup.(currents{c});
                slice = outputGroup.(currents{c});
                originalFields = fieldnames(original);
                keep = strcmp(originalFields, 'Meas') | startsWith(originalFields, 'Ref_');
                expected = rmfield(original, originalFields(~keep));
                assert(isequaln(orderfields(slice), orderfields(expected)), ...
                    'Measurements or metadata changed: %s/%s/%s', entry.source, speeds{r}, currents{c});
                measFields = fieldnames(original.Meas);
                allMeasFields = union(allMeasFields, measFields, 'stable');
                for f = 1:numel(measFields)
                    assert(isequaln(output.Meas.(measFields{f}){c, r}, original.Meas.(measFields{f})), ...
                        'Cell data changed: %s/%s/%s/%s', entry.source, speeds{r}, currents{c}, measFields{f});
                end
                assert(isequaln(output.exc_ref{c, r}, original.Ref_exc_current));
                assert(isequaln(output.rpm_ref{c, r}, original.Ref_Speed));
                assert(strcmp(output.exc_fields{c, r}, currents{c}));
                records = records + numel(slice.Meas.PE_Index_meas);
                currentValues(end+1) = double(slice.Ref_exc_current); %#ok<AGROW>
            end
            assert(issorted(currentValues));
            rpmValues(end+1) = double(slice.Ref_Speed); %#ok<AGROW>
        end
        assert(issorted(rpmValues));
        assert(isequal(sort(fieldnames(output.Meas)), sort(allMeasFields(:))), 'Cell channels missing.');
        assert(records == entry.records);
        assert(isfield(output, 'OptimParam') == isfield(input.Total, 'OptimParam'));
        if isfield(input.Total, 'OptimParam')
            assert(isequaln(output.OptimParam, input.Total.OptimParam));
        end
        assert(isfield(output, 'Info') == isfield(input, 'Info'));
        if isfield(input, 'Info')
            assert(isequaln(output.Info, input.Info));
        end
        checkedEval = checkedEval + 1;
        fprintf('PASS evaluation: %s (%d points; all fields/shapes)\n', entry.source, records);
    end
end
fprintf('VERIFIED: %d raw files, %d evaluation variants; %d source comparisons skipped.\n', ...
    checkedRaw, checkedEval, skippedEval);
end

function signals = signal_metadata(input, names)
signals = rmfield(input, 'Data');
for f = 1:numel(signals)
    signals(f).FieldName = names{f};
end
end

function n = count_slices(total)
n = 0;
speeds = fieldnames(total);
for r = 1:numel(speeds)
    n = n + numel(fieldnames(total.(speeds{r})));
end
end
