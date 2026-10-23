%% LOAD DATA
clc, clear;
% Compact measurement MAT; regenerate with extract_meas_from_fluxeval if needed.
resourceRoot = fileparts(mfilename('fullpath'));
data = load(fullfile(resourceRoot, 'DataSets', 'Set2', 'extracted', 'evaluation', ...
    'eval_flux_eesm_excitation_0A_to_40A_measurements.mat'));

fieldnames_total = fieldnames(data.Total);

rpm_mask = ~cellfun(@isempty, regexp(fieldnames_total, "^(pos|neg)_(0|[1-9][0-9]*)_rpm$", 'once'));
rpm_fields = fieldnames_total(rpm_mask);

id_meas = {};
iq_meas = {};
i_exc_meas  = {};
id_req = {};
iq_req = {};
i_exc_req = {};

psi_d_meas = {};
psi_q_meas = {};

rpm_meas = {};
rpm_req = {};

exc_ref = {};
rpm_ref = {};

for idx_rpm = 1:numel(rpm_fields)
    rpm_field = rpm_fields{idx_rpm};
    rpm_data = data.Total.(rpm_field);
    fieldnames_rpm = fieldnames(rpm_data);

    exc_mask = ~cellfun(@isempty, regexp(fieldnames_rpm, "^(pos|neg)_(0|[1-9][0-9]*)_A$", 'once'));
    exc_fields = fieldnames_rpm(exc_mask);

    % Sort each speed's excitation blocks by their actual reference current.
    exc_values = cellfun(@(name) rpm_data.(name).Ref_exc_current, exc_fields);
    [~, i_sort_exc] = sort(exc_values);
    exc_fields = exc_fields(i_sort_exc);

    for idx_exc = 1:numel(exc_fields)
        exc_field = exc_fields{idx_exc};
        exc_data = rpm_data.(exc_field);

        meas = exc_data.Meas;

        exc_ref{idx_exc, idx_rpm} = exc_data.Ref_exc_current;
        rpm_ref{idx_exc, idx_rpm} = exc_data.Ref_Speed;

        id_meas{idx_exc, idx_rpm} = meas.PE_Id_meas_avg(:);
        iq_meas{idx_exc, idx_rpm} = meas.PE_Iq_meas_avg(:);
        i_exc_meas{idx_exc, idx_rpm} = meas.I_exc_meas(:);
        id_req{idx_exc, idx_rpm} = meas.PE_Id_req_meas(:);
        iq_req{idx_exc, idx_rpm} = meas.PE_Iq_req_meas(:);
        i_exc_req{idx_exc, idx_rpm} = meas.I_exc_req(:);
        psi_d_meas{idx_exc, idx_rpm} = meas.PE_psi_d_meas(:);
        psi_q_meas{idx_exc, idx_rpm} = meas.PE_psi_q_meas(:);

        rpm_meas{idx_exc, idx_rpm} = meas.CAN_RPM_meas(:);
        rpm_req{idx_exc, idx_rpm} = meas.PE_Rpm_req(:);

    end
end

% Reorder all columns together by reference speed, preserving cell contents.
[~, i_sort_rpm] = sort(cell2mat(rpm_ref(1, :)));
rpm_fields = rpm_fields(i_sort_rpm);
id_meas = id_meas(:, i_sort_rpm);
iq_meas = iq_meas(:, i_sort_rpm);
i_exc_meas = i_exc_meas(:, i_sort_rpm);
id_req = id_req(:, i_sort_rpm);
iq_req = iq_req(:, i_sort_rpm);
i_exc_req = i_exc_req(:, i_sort_rpm);
psi_d_meas = psi_d_meas(:, i_sort_rpm);
psi_q_meas = psi_q_meas(:, i_sort_rpm);
rpm_meas = rpm_meas(:, i_sort_rpm);
rpm_req = rpm_req(:, i_sort_rpm);
exc_ref = exc_ref(:, i_sort_rpm);
rpm_ref = rpm_ref(:, i_sort_rpm);
% Rows are sorted per speed; use exc_ref to identify their reference currents.


%% Meas Plot

figure(1)
scatter3(vertcat(id_meas{:}), vertcat(iq_meas{:}), vertcat(i_exc_meas{:}))
xlabel('I_d (A)')
ylabel('I_q (A)')
zlabel('I_{exc} (A)')
