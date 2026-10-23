# Datensätze

Alle Austauschdateien sind `.mat`-Dateien. Es werden alle vorhandenen
Messkanäle übernommen, einschließlich Winkelmessungen, Hilfsgrößen,
Temperaturen, Konstanten und verschachtelter Outlier-Informationen.
Die vollständigen GUI-Auswertungen bleiben lokal im jeweiligen `FluxEval/`.

| Set | Drehzahl | Erregerstrom | Rohdateien / Samples | Vorhandene Auswertungen |
| --- | --- | --- | --- | --- |
| Set1 | 3000 rpm | 2–40 A | 3 / 22.552 | Matlab_200 sowie Matlab_200_201_202 |
| Set2 | 3000 rpm | 0–40 A | 2 / 24.393 | 2–40 A, 0–40 A, 0–40 A mit 10 % Spannungsreserve |
| Set3 | 2250 rpm | 3–30 A | 1 / 28.875 | ausstehend |

Set 1/2 haben je 268 Rohkanäle, Set 3 hat 195. Jede vorhandene
Auswertungsvariante besitzt 303 unmittelbare `Meas`-Felder pro Messgruppe;
einige davon enthalten weitere Unterstrukturen oder Matrizen.

| Auswertungsvariante | Messgruppen | Messpunkte |
| --- | --- | --- |
| Set1: Matlab_200 | 13 | 7.298 |
| Set1: Matlab_200_201_202 | 13 | 7.476 |
| Set2: 2–40 A | 13 | 7.514 |
| Set2: 0–40 A | 14 | 8.092 |
| Set2: 0–40 A, 10 % Spannungsreserve | 14 | 8.092 |

Die Varianten bleiben einzeln erhalten; insbesondere werden die beiden
Spannungsreserve-Auswertungen nicht miteinander vermischt.

```text
SetN/
  raw/                    unveränderte Recorder-Originale, im Git
  FluxEval/               vollständige lokale Auswertungen, ignoriert
  extracted/
    raw/                  alle Rohsamples nach Drehzahl/Iexc gruppiert, im Git
    evaluation/           extrahierte Meas-Daten je Auswertungsvariante, im Git
```

## Einzelne FluxEval-Datei extrahieren

Die eigenständige Funktion [extract_meas_from_fluxeval.m](../extract_meas_from_fluxeval.m)
benötigt nur den Eingabepfad und MATLAB; die GUI wird nicht benötigt.

```matlab
addpath('C:\Git\Winding_Factor\Resources');
source = fullfile('C:\Git\Winding_Factor\Resources\DataSets', ...
    'Set2', 'FluxEval', 'eval_flux_eesm_excitation_0A_to_40A.mat');
measFile = extract_meas_from_fluxeval(source);
data = load(measFile);
```

Optional kann das Ziel frei vorgegeben werden:

```matlab
measFile = extract_meas_from_fluxeval(source, 'C:\Temp\Set2_Meas.mat');
```

Ohne Zielangabe entsteht `<Originalname>_measurements.mat` neben der Quelle.
Liegt die Quelle in `FluxEval/`, schreibt die Funktion stattdessen nach
`../extracted/evaluation/`, damit der Export vom Git erfasst wird.
Die Quelldatei wird niemals überschrieben. Die Funktion lädt nur `Total`
und `Info` aus der großen Auswertungsdatei.

Der Export bietet zwei gleichwertige Zugriffe:

```matlab
% Vollständige Originalhierarchie mit allen Meas-Feldern und Ref_*-Angaben:
m = data.Total.pos_3000_rpm.pos_2_A.Meas;

% Cell-Layout entsprechend calculate_winding_factor.m, für JEDEN Kanal:
id = data.Meas.PE_Id_meas_avg{1, 1};
psi_d = data.Meas.PE_psi_d_meas{1, 1};
referenceCurrent = data.exc_ref{1, 1};
referenceSpeed = data.rpm_ref{1, 1};
```

Cell-Spalten sind numerisch nach `Ref_Speed` sortiert. Innerhalb jeder Spalte
sind die Zeilen numerisch nach `Ref_exc_current` sortiert. `rpm_fields` und
`exc_fields` ordnen die Cells den ursprünglichen Gruppennamen zu. Fehlt bei
einer Drehzahl eine Gruppe oder ein Kanal, bleibt die betreffende Cell leer.
Die Stromzeilen werden **je Drehzahl** sortiert; dieselbe Zeilennummer kann
bei unterschiedlichen Drehzahlen unterschiedliche Erregerströme bezeichnen.
Zur Identifikation deshalb `exc_ref` verwenden.

Werte, Datentypen und Matrixformen in `Meas` bleiben unverändert. Auch
`Meas.Outliers.Torque` wird vollständig übernommen. `OptimParam` und `Info`
werden, sofern vorhanden, separat gespeichert. Die großen berechneten
`Calc`-/`Eval`-/LUT-Kennfelder werden nicht kopiert. Der Export enthält
gespeicherte Auswertungsergebnisse und führt keine neue Auswertung durch.

## Gruppierte Rohdaten

```matlab
d = load(fullfile('C:\Git\Winding_Factor\Resources\DataSets', ...
    'Set3', 'extracted', 'raw', ...
    'flux_eesm_excitation_3A_to_30A_measurements.mat'));
m = d.Total.pos_2250_rpm.pos_3_A.Meas;
sampleIndices = d.Total.pos_2250_rpm.pos_3_A.SampleIndex;
time = d.Total.pos_2250_rpm.pos_3_A.Time;
```

Die Rohsample werden nach Soll-Drehzahl und Soll-Erregerstrom gruppiert und
innerhalb jeder Gruppe nach `PE_Index_meas` sortiert. Wiederholungen behalten
ihre Aufzeichnungsreihenfolge; es gibt keine Mittelung oder Filterung.
`SampleIndex` enthält die ursprüngliche, bei 1 beginnende Sampleposition.
`Time` enthält die dazugehörige Recorder-X-Achse.
`Signals` speichert die vollständigen ursprünglichen Kanalmetadaten ohne
`Data`, ergänzt um `FieldName`. Leerzeichen in Kanalnamen werden wie im
ursprünglichen Import entfernt. `Recorder` erhält die übrigen Metadaten.

Set 3 enthält 284 Samples mit Messindex 0. Diese bleiben als Rohdaten erhalten
und sind nicht als erfolgreiche Messpunkte zu interpretieren. Set 3 erhält
keine künstlich erzeugten Flusswerte oder vermeintlich fertige Auswertung.
Eine spätere FluxEval-Datei kann in `Set3/FluxEval/` abgelegt und mit derselben
Funktion extrahiert werden.

## Bestand, Reproduktion und Prüfung

[inventory.json](inventory.json) verzeichnet für jede Quelle und jeden Export
Dateigröße, Sample-/Punktzahl, Messgruppen und Anzahl der Felder. Bei Rohdaten
stehen auch Index-0-Zahlen und die Zahl unterschiedlicher Messindizes dabei.
[source_checksums.json](source_checksums.json) enthält die vor der ersten
Extraktion aufgenommenen SHA-256-Prüfsummen aller elf Originaldateien.

Alle lokal vorhandenen Quellen erneut extrahieren und prüfen:

```matlab
addpath('C:\Git\Winding_Factor\Resources\DataSets');
extract_measurements;
verify_measurements;
```

`extract_measurements` ersetzt die generierten Exporte und aktualisiert das
Inventar anhand der lokal vorhandenen Dateien. Vollständige Reproduktion
der Auswertungsexporte setzt die ignorierten Originale unter `FluxEval/`
voraus. Auf einem Git-Klon ohne diese Originale nur `verify_measurements`
ausführen; Vergleiche mit fehlenden FluxEval-Dateien werden als `SKIP`
ausgewiesen, die exportierten Dateien bleiben erhalten.

`verify_measurements` vergleicht jeden Rohkanal für jedes Sample mit dem
Original, prüft eindeutige vollständige Sampleabdeckung und die Sortierung.
Bei Auswertungsexporten werden sämtliche `Meas`-Inhalte einschließlich
verschachtelter Strukturen, Datentypen, NaNs und Matrixformen exakt
verglichen. Tests der Einzelfunktion:

```matlab
addpath('C:\Git\Winding_Factor\Resources');
r = runtests('C:\Git\Winding_Factor\Resources\DataSets\tests');
assert(all([r.Passed]));
```

Geprüft mit MATLAB R2025b. Die Rohdateien sind MATLAB-v7.3-Dateien, die
kompakten Exporte komprimierte MATLAB-v7-Dateien. Alle Austauschdateien
lassen sich mit `load` lesen. Die übrige lokale `Resources`-Sammlung bleibt
außerhalb dieses auf Datenaustausch beschränkten Git-Bestands.
