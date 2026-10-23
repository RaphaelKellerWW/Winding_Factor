function tests = test_extract_meas_from_fluxeval
tests = functiontests(localfunctions);
end

function test_sorted_complete_measurements(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
Total = struct;
Total.pos_3000_rpm.pos_10_A = example_slice(3000, 10);
Total.pos_3000_rpm.Note = 'not a measurement group';
Total.pos_3000_rpm.pos_2_A = example_slice(3000, 2);
Total.neg_1000_rpm.pos_5_A = example_slice(-1000, 5);
Total.OptimParam = struct('R_s', .013);
Info = struct('label', 'synthetic regression fixture');
source = fullfile(folder, 'FluxEval.mat');
save(source, 'Total', 'Info');
verifyEqual(testCase, exist('extract_meas_from_fluxeval', 'file'), 2, ...
    'The standalone path-based extractor is missing.');
outputFile = extract_meas_from_fluxeval(source);
actual = load(outputFile);
verifyEqual(testCase, actual.rpm_fields, {'neg_1000_rpm'; 'pos_3000_rpm'});
verifyEqual(testCase, actual.exc_ref, {5, 2; [], 10});
verifyEqual(testCase, actual.rpm_ref, {-1000, 3000; [], 3000});
verifyEqual(testCase, actual.exc_fields, {'pos_5_A', 'pos_2_A'; [], 'pos_10_A'});
verifyEqual(testCase, actual.Total.pos_3000_rpm.pos_2_A.Meas, ...
    Total.pos_3000_rpm.pos_2_A.Meas);
verifyEqual(testCase, actual.Meas.AngleMatrix{2, 2}, ...
    Total.pos_3000_rpm.pos_10_A.Meas.AngleMatrix);
verifyEqual(testCase, actual.Meas.Outliers{1, 1}, ...
    Total.neg_1000_rpm.pos_5_A.Meas.Outliers);
verifyEqual(testCase, actual.Meas.ExtraChannel{1, 2}, [NaN, 2]);
verifyEqual(testCase, actual.OptimParam, Total.OptimParam);
verifyEqual(testCase, actual.Info, Info);
verifyFalse(testCase, isfield(actual.Total.pos_3000_rpm.pos_2_A, 'Calc'));
verifyFalse(testCase, isfield(actual.Total.pos_3000_rpm, 'Note'));
unchanged = load(source);
verifyEqual(testCase, unchanged.Total, Total);
end

function test_explicit_destination_and_missing_optional_metadata(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
Total.pos_3000_rpm.pos_2_A = example_slice(3000, 2);
source = fullfile(folder, 'input.mat');
save(source, 'Total');
destination = fullfile(folder, 'out', 'measurements.mat');
outputFile = extract_meas_from_fluxeval(string(source), string(destination));
verifyEqual(testCase, outputFile, destination);
verifyTrue(testCase, isfile(destination));
actual = load(destination);
verifyEqual(testCase, actual.Total.pos_3000_rpm.pos_2_A.Meas, ...
    Total.pos_3000_rpm.pos_2_A.Meas);
verifyError(testCase, @() extract_meas_from_fluxeval(source, source), ...
    'DataSets:SourceOverwrite');
end

function test_no_groups_is_an_error(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
Total = struct('OptimParam', struct('R_s', 1));
source = fullfile(folder, 'no_measurements.mat');
save(source, 'Total');
verifyError(testCase, @() extract_meas_from_fluxeval(source), ...
    'DataSets:NoMeasurements');
end

function test_bulk_relative_root_and_optional_metadata(testCase)
folder = tempname(pwd);
mkdir(fullfile(folder, 'Set1', 'FluxEval'));
previousPath = path;
cleanupPath = onCleanup(@() path(previousPath)); %#ok<NASGU>
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
addpath(fileparts(fileparts(mfilename('fullpath'))));
Total.pos_3000_rpm.pos_2_A = example_slice(3000, 2);
Total.pos_3000_rpm.Note = 'nonmeasurement metadata';
save(fullfile(folder, 'Set1', 'FluxEval', 'fixture.mat'), 'Total');
[~, relativeRoot] = fileparts(folder);
inventory = extract_measurements(relativeRoot);
verifyEqual(testCase, inventory.evaluations.source, 'Set1/FluxEval/fixture.mat');
verify_measurements(folder);
end

function slice = example_slice(rpm, current)
Meas = struct('PE_Index_meas', [1, 2], 'ExtraChannel', [NaN, current], ...
    'AngleMatrix', reshape(1:48, 24, 2), 'Outliers', struct('indices', 2));
slice = struct('Ref_Speed', rpm, 'Ref_exc_current', current, ...
    'Ref_rotor_temperature', 30, 'Meas', Meas, 'Calc', struct('discard', true));
end
