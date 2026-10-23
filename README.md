# Winding Factor – Messdatenaustausch

Die Datensätze unter [Resources/DataSets](Resources/DataSets/README.md) enthalten
unveränderte Rohdateien und gruppierte Messdaten als MATLAB-MAT-Dateien.
Die großen vollständigen FluxEval-Auswertungen bleiben lokal und sind ignoriert.

Eine einzelne Auswertung extrahieren:

```matlab
addpath('C:\Git\Winding_Factor\Resources');
measFile = extract_meas_from_fluxeval('C:\Pfad\zur\FluxEval.mat');
data = load(measFile);
% Cell-Zeilen: Erregerstrom, Cell-Spalten: Drehzahl; numerisch sortiert.
id = data.Meas.PE_Id_meas_avg{1, 1};
% Originalhierarchie bleibt ebenfalls erhalten:
% data.Total.pos_3000_rpm.pos_2_A.Meas
```

[calculate_winding_factor.m](Resources/calculate_winding_factor.m) lädt den
kompakten Messdatenexport von Set 2. Die Auswertung für Set 3 steht noch aus;
dessen Rohdaten sind bereits vollständig gruppiert verfügbar.

Die Beziehung zwischen MeasEval, ParamGUI und VICE steht als kompakte
[Mapping-Referenz](Resources/Mapping/README.md) zur Verfügung. Die
vollständige ParamGUI bleibt lokal und ist vom Git ausgeschlossen.

Die frühere Untersuchung ist in einer [Zusammenfassung](Resources/investigation/README.md)
konsolidiert: Reihenfolgefehler, Vergleichswerte und offene Fragen.
