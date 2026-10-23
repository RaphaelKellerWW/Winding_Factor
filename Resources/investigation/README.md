# Untersuchung zum Wicklungsfaktor – Zusammenfassung

Zusammengeführt aus den 15 Untersuchungsberichten vom 22./23.10.2026.
Die Zahlen sind Ergebnisse dieser früheren Untersuchung; hier wurde nichts
neu berechnet. Für Git wird nur diese Zusammenfassung übernommen;
die übrigen lokalen Untersuchungsartefakte sind ausgeschlossen.

## Gefundene Ursache

Die damaligen 300/301-Auswertungen mit den Bezeichnungen „5 %“ und „10 %“
enthalten identische Mess-, Gitter- und Fitdaten für alle 14 Erregerstrom-Slices.
Ihre Reihenfolge unterscheidet sich: 0 A steht einmal am Anfang, einmal am Ende.

`Torque_LUT_Calc.m` schätzt den Wicklungsfaktor aus benachbarten Slices mit
`abs(ΔId) / ΔIexc`. Beim Übergang von 40 auf 0 A wird der Nenner negativ.
Dadurch ändern sich der Faktor `k`, die Projektion `Id* = Id + k·Iexc` und
anschließend das gesamte zusammengeführte Flusskennfeld.

Die damalige Gegenprobe sortierte die vollständigen Slices numerisch nach
`Ref_exc_current` vor der Faktorschätzung. Damit verschwand der Unterschied.
Es reicht nicht, nur den fertigen Faktor oder einzelne Breakpoints zu ersetzen.
Die Spannungsreserve allein erklärt den beobachteten Unterschied nicht;
ein frischer Import 300 → 301 erzeugte für beide Reserven 0 A am Ende.

## Zahlen am Diagnosepunkt

Physikalische Eingaben: `Id = −405 A`, `Iq = 293 A`, `Iexc = 33,2 A`.
Stationäre Spannungsrechnung bei 12.000 rpm, drei Polpaaren und `Rs = 0,013 Ω`.
Die Flussmessungen stammen von 3.000 rpm. Dieser Diagnosepunkt ist vom
berichteten Schwingungsfall bei 50 → 70 Nm zu unterscheiden.

| Berechnung | Variante „5 %“ | Variante „10 %“ |
| --- | ---: | ---: |
| Alter Export: Wicklungsfaktor k | 13,35836 | 11,28958 |
| Alter Export: Uq | 126,57 V | 11,87 V |
| Alter Export: Spannungsbetrag | 394,45 V | 386,96 V |
| Damalige main-Neuberechnung: Uq | 136,33 V | 15,64 V |
| main mit Sortierung: Uq | 136,33 V | 136,33 V |

Die kleine q-Komponente bedeutet hier keinen entsprechend kleinen
Spannungsbetrag. Die abweichenden Werte von altem Export und damaligem main
entstehen aus unterschiedlichen Berechnungsständen.

Die spätere Rohdaten-Gegenprobe interpoliert über den **gemessenen**
Erregerstrom: Die nominellen 32-/36-A-Slices liegen am Diagnosepunkt bei etwa
32,4025/36,4030 A. Daraus folgen bei tatsächlichen 33,2 A ungefähr **159,55 V Uq**.
Die ältere Gegenprobe mit **nominellen** Erregerströmen ergab **169,40 V**.
Beides sind stationäre Hochrechnungen aus 3.000-rpm-Daten.
Die erwarteten 200 V sind durch keine passende unabhängige 12.000-rpm-Messung
belegt.

## Achsen und Übergabe

- `Inv_Param.CtrlMaps` enthält 2D-Tabellen über `Id*` und `Iq`.
- `Inv_Param.Maps4D.CtrlMaps` enthält physikalische Id-/Iq-Tabellen je Slice.
  Unterschiedliche Id-Breakpoints sind deshalb für sich kein Fehler.
- Achsen und Tabellen müssen zusammenpassen. Legacy- und Maps4D-Breakpoints
  dürfen nicht gegeneinander ausgetauscht werden.
- Die ursprüngliche Maps4D-Slice-Reihenfolge steht in
  `LUT.CtrlMaps.complete.I_exc_vec`; dieser Vektor fehlt im untersuchten
  `Inv_Param.Maps4D.CtrlMaps`-Export als eigenständige Erregerstromachse.
- Die ParamGUI kopiert die älteren Tabellen; das VICE-Python-Skript
  transponiert sie für den C-Lesepfad. Details: [Feldzuordnung](../Mapping/README.md).
- Ungültige Werte werden teils als Null mit `*_ZERO`-Masken gespeichert.
  Diese Nullen sind keine gültigen physikalischen Messwerte.

## Was offen bleibt

Die berichtete **1,2-Hz-Schwingung ist nicht erklärt**. Im damaligen Bestand
fehlten synchrone Zeitreihen und aktive Reglerparameter. Der Hinweis, alte
Induktivitäten hätten die Schwingung beseitigt, stammt aus der damaligen
Teamkommunikation. Die synthetische Testbench reproduzierte keine 1,2 Hz.

Die 3D→2D-Projektion bleibt auch nach der Sortierkorrektur eine Modellannahme.
Fluss und Differentialinduktivität müssen zusammen betrachtet werden;
`L_exc = k²·L_dd` ist keine allgemeingültige EESM-Beziehung. Die untersuchten
Tabellen zeigten Abweichungen der Kreuzableitungen und teilweise negative
symmetrische Eigenwerte. Daraus allein folgt noch keine Ursache der Schwingung.

LOWESS, Polynome, 3D-RBF und Potentialfits wurden offline verglichen.
RBF war im Mittel etwas besser, hatte aber größere Maximalfehler als LOWESS.
Ein pauschaler Fitwechsel löst den nachgewiesenen Reihenfolgefehler nicht.

Weitere damalige Grenzen: kein vollständiger ParamGUI-/COM-/Hardware-Roundtrip;
vorhandenes SLX mit linearer Extrapolation gegenüber C-Code mit Randbegrenzung;
widersprüchliche historische GUI-Versionsangaben. Läufe erfolgten unter R2025b,
R2018a konnte damals nicht ausgeführt werden.

## Für die weitere Problemlösung

1. Wicklungsfaktor und Kennfeld bei verschiedenen Importreihenfolgen vergleichen;
   vollständige Erregerstrom-Slices vor der Zusammenführung sortieren.
2. Die physikalischen 3D-Slices als Vergleich zur reduzierten 2D-LUT nutzen,
   dabei gemessenen und angeforderten Erregerstrom getrennt halten.
3. Für die Schwingung Soll-/Istströme, aktive L/Gains, Spannung vor/nach
   Begrenzung, DC-Spannung, Reglermodi und Delays gemeinsam aufzeichnen.
4. Den tatsächlich verwendeten VICE-Build und die Kennfeldwerte nach dem
   Parametertransport abgleichen.

Laut damaliger Nutzerangabe unterscheiden sich 200er und 300er Messungen
zusätzlich durch −24 µs Stromsensor-Delay; eine Delay-Kausalität wurde nicht
nachgewiesen. 201/202 vervollständigen die 40-A-Messpunkte der 200er-Reihe;
300 enthält 2–40 A, 301 ergänzt 0 A.

Im alten Bericht ist ein lokaler Sortierfix unter `codex/eesm-excitation-order`,
Commit `39fed85e2c4bfd462f04474100f25f075aa2a868`, Basis `3189ae83`, vermerkt.
Der heutige Integrationsstand dieses Fixes wurde hier nicht untersucht.
