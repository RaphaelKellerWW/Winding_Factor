# MeasEval → ParamGUI → VICE

Die ParamGUI R3310 benennt die folgenden Felder um. Quelle ist bevorzugt
`Inv_Param_GUI`, ersatzweise `Inv_Param` aus der vollständigen FluxEval-Datei.
Ziele liegen unter `Parameter`. Die GUI selbst bleibt lokal im Gitignore.

| Quelle | Ziel |
| --- | --- |
| `CtrlMaps.Psi_d` | `MACHINE.Ctrl_Map.Psi_d_FIT_param_mat_Vs` |
| `CtrlMaps.Psi_q` | `MACHINE.Ctrl_Map.Psi_q_FIT_param_mat_Vs` |
| `CtrlMaps.L_dd` | `MACHINE.Ctrl_Map.L_dd_param_mat_H` |
| `CtrlMaps.L_qq` | `MACHINE.Ctrl_Map.L_qq_param_mat_H` |
| `CtrlMaps.L_dq` | `MACHINE.Ctrl_Map.L_dq_param_mat_H` |
| `CtrlMaps.L_qd` | `MACHINE.Ctrl_Map.L_qd_param_mat_H` |
| `CtrlMaps.Id_breakpoints` | `MACHINE.Ctrl_Map.Id_fine_param_vec_A` |
| `CtrlMaps.Iq_breakpoints` | `MACHINE.Ctrl_Map.Iq_fine_param_vec_A` |
| `CtrlMaps.EESM_winding_ratio` | `MACHINE.Ctrl_Map.EESM_winding_ratio` |
| `TrqMaps.rpm_breakpoints` | `MACHINE.Trq_Map.rpm_breakpoints_param_vec_rpm` |
| `TrqMaps.Trq_breakpoints` | `MACHINE.Trq_Map.Trq_breakpoints_param_vec_Nm` |
| `TrqMaps.U_DC_breakpoints` | `MACHINE.Trq_Map.U_DC_breakpoints_param_vec_V` |
| `TrqMaps.Id_opti` | `MACHINE.Trq_Map.Id_Opti_param_mat_A` |
| `TrqMaps.Iq_opti` | `MACHINE.Trq_Map.Iq_Opti_param_mat_A` |
| `TrqMaps.I_exc_opti` | `MACHINE.Trq_Map.I_Rot_Opti_param_mat_A` |
| `Limits.Trq_Lim_max` | `MACHINE.Limit_Trq.torque_lim_max_mat_Nm` |
| `Limits.Trq_Lim_min` | `MACHINE.Limit_Trq.torque_lim_min_mat_Nm` |
| `PW.Id_DCI`, `Iq_DCI`, `Id_HFFI`, `Iq_HFFI`, `HFFI_ampl_d`, `HFFI_ampl_q` | gleichnamige Felder unter `PW` |

Die Drehmomentbegrenzungen werden zusätzlich unter
`MACHINE.Torque_limitation_*` abgelegt. `Trq_breakpoints` ist im vorhandenen
MeasEval-Export auf −1 bis 1 normiert, trotz des historischen Zielnamens `_Nm`.

Maps4D wird separat aus `Inv_Param.Maps4D` kopiert:

| Quelle | Ziel |
| --- | --- |
| `CtrlMaps` | `MACHINE.Maps4D.Ctrl_Map` |
| `Interpolated.TrqMaps` | `MACHINE.Maps4D.Trq_Map` |
| `Interpolated.Limits.Trq_Lim_max/min` | `MACHINE.Maps4D.Limit_Trq.torque_lim_max/min_mat_Nm` |
| `Interpolated.PW` | `PW.Maps4D` |

Für `MACHINE_GUI.Maps4D` verwendet der Save-Helfer die GUI-Variante.

Für den Wicklungsfaktor relevant:

- Älterer EESM-Pfad: `Id* = Id + k·Iexc`, `k = EESM_winding_ratio`.
- MATLAB-Kennfelder: Zeilen `Iq`, Spalten `Id*`. Der ParamGUI-Import kopiert sie.
  Erst das VICE-Python-Skript transponiert die sechs Fluss-/Induktivitätstabellen.
- Maps4D verwendet physikalische d/q-Achsen je Erregerstrom-Slice. Die explizite
  Iexc-Achse fehlt im untersuchten `Inv_Param.Maps4D.CtrlMaps`-Export;
  die ursprüngliche Slice-Reihenfolge steht im LUT.
- Beim GUI-Save werden NaN gefüllt bzw. durch Null mit Masken ersetzt.
  Dort wird außerdem `L_dq` aus `L_dd` und `L_qd` aus `L_qq` gebildet.
- Für `CtrlMaps.L_exc` fehlt im untersuchten Import eine direkte Zuweisung
  auf `MACHINE.Ctrl_Map.L_Rot_param_mat_H`.
- Der separate VICE-Startup-Helfer spiegelt die Id-Achse. Das gehört zu einem
  anderen Pfad als dem ParamGUI-Import.

Grundlage: lokale ParamGUI R3310, `Functions/MAPS4D_Save.m` und
VICE `003_004_000_002`, Python-Parametrierskript. Keine Veröffentlichungsfreigabe
für das vollständige GUI-Paket im Bestand gefunden; deshalb bleibt es lokal.
