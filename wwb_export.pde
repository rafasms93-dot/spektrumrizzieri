final long WWB_MIN_SPACING_HZ = 25000L;
final double WWB_AMPLITUDE_OFFSET_DB = -75.0;

ArrayList<RfExportPoint> pendingRawRows;
ArrayList<RfExportPoint> pendingWwbRows;
boolean rfExportInProgress = false;

class RfExportPoint implements Comparable<RfExportPoint> {
  long frequencyHz;
  double amplitude;

  RfExportPoint(long frequencyHz, double amplitude) {
    this.frequencyHz = frequencyHz;
    this.amplitude = amplitude;
  }

  public int compareTo(RfExportPoint other) {
    if (frequencyHz < other.frequencyHz) return -1;
    if (frequencyHz > other.frequencyHz) return 1;
    return 0;
  }
}

public void exportRawScan() {
  double[] snapshot = captureRfSnapshot("Raw Scan");
  if (snapshot == null) return;

  try {
    pendingRawRows = buildRawRows(snapshot, startFreq, binStep);
  }
  catch (Exception exception) {
    showExportError("The current RF scan could not be prepared for raw export.", exception);
    pendingRawRows = null;
    return;
  }

  if (pendingRawRows.size() == 0) {
    showExportError("The current RF scan contains no usable samples.");
    pendingRawRows = null;
    return;
  }

  openExportDialog("Save raw RF scan", "rawExportFileSelected", "rizzieri_rf_raw_");
}

public void exportToWWB() {
  double[] snapshot = captureRfSnapshot("WWB");
  if (snapshot == null) return;

  try {
    pendingWwbRows = buildWwbRows(snapshot, startFreq, binStep);
  }
  catch (Exception exception) {
    showExportError("The current RF scan could not be prepared for WWB.", exception);
    pendingWwbRows = null;
    return;
  }

  if (pendingWwbRows.size() == 0) {
    showExportError("The current RF scan contains no usable samples.");
    pendingWwbRows = null;
    return;
  }

  openExportDialog("Save scan for Shure Wireless Workbench", "wwbExportFileSelected", "rizzieri_rf_wwb_");
}

double[] captureRfSnapshot(String exportName) {
  if (rfExportInProgress) {
    println(exportName + " export: a save dialog is already open.");
    return null;
  }

  if (spektrumReader == null) {
    showExportError("No RF scanner is available.");
    return null;
  }

  try {
    double[] sourceBuffer = spektrumReader.getDbmBuffer();
    if (sourceBuffer == null || sourceBuffer.length == 0) {
      showExportError("The current RF scan is empty.");
      return null;
    }
    return sourceBuffer.clone();
  }
  catch (Exception exception) {
    showExportError("Unable to capture the current RF scan.", exception);
    return null;
  }
}

void openExportDialog(String prompt, String callback, String filePrefix) {
  String timestamp = new java.text.SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
  java.io.File suggestedFile = new java.io.File(sketchPath(filePrefix + timestamp + ".csv"));
  rfExportInProgress = true;
  selectOutput(prompt, callback, suggestedFile);
}

ArrayList<RfExportPoint> buildRawRows(double[] buffer, int sourceStartFreq, int sourceBinStep) {
  ArrayList<RfExportPoint> points = new ArrayList<RfExportPoint>();

  for (int i = 0; i < buffer.length; i++) {
    double amplitude = buffer[i];
    if (Double.isNaN(amplitude) || Double.isInfinite(amplitude)) continue;

    long rawFrequencyHz = (long)sourceStartFreq + (long)i * (long)sourceBinStep;
    if (rawFrequencyHz < Integer.MIN_VALUE || rawFrequencyHz > Integer.MAX_VALUE) continue;

    long correctedFrequencyHz = (long)ifCorrectedFreq((int)rawFrequencyHz);
    points.add(new RfExportPoint(correctedFrequencyHz, amplitude));
  }

  Collections.sort(points);
  assertAscending(points);
  return points;
}

ArrayList<RfExportPoint> buildWwbRows(double[] buffer, int sourceStartFreq, int sourceBinStep) {
  ArrayList<RfExportPoint> preparedPoints = buildRawRows(buffer, sourceStartFreq, sourceBinStep);
  if (sourceBinStep < WWB_MIN_SPACING_HZ) {
    preparedPoints = reduceWwbPoints(preparedPoints);
  }

  ArrayList<RfExportPoint> adjustedPoints = applyWwbAmplitudeOffset(preparedPoints);
  assertWwbRows(preparedPoints, adjustedPoints);
  return adjustedPoints;
}

ArrayList<RfExportPoint> reduceWwbPoints(ArrayList<RfExportPoint> sortedPoints) {
  ArrayList<RfExportPoint> reduced = new ArrayList<RfExportPoint>();
  if (sortedPoints.size() == 0) return reduced;

  long currentGridFrequencyHz = alignToWwbGrid(sortedPoints.get(0).frequencyHz);
  RfExportPoint strongestPoint = null;

  for (RfExportPoint point : sortedPoints) {
    long pointGridFrequencyHz = alignToWwbGrid(point.frequencyHz);
    if (pointGridFrequencyHz != currentGridFrequencyHz) {
      if (strongestPoint != null) {
        reduced.add(new RfExportPoint(currentGridFrequencyHz, strongestPoint.amplitude));
      }
      currentGridFrequencyHz = pointGridFrequencyHz;
      strongestPoint = null;
    }

    if (strongestPoint == null || point.amplitude > strongestPoint.amplitude) {
      strongestPoint = point;
    }
  }

  if (strongestPoint != null) {
    reduced.add(new RfExportPoint(currentGridFrequencyHz, strongestPoint.amplitude));
  }

  return reduced;
}

long alignToWwbGrid(long frequencyHz) {
  return Math.floorDiv(frequencyHz + WWB_MIN_SPACING_HZ / 2L, WWB_MIN_SPACING_HZ)
    * WWB_MIN_SPACING_HZ;
}

ArrayList<RfExportPoint> applyWwbAmplitudeOffset(ArrayList<RfExportPoint> points) {
  ArrayList<RfExportPoint> adjusted = new ArrayList<RfExportPoint>();
  for (RfExportPoint point : points) {
    adjusted.add(new RfExportPoint(point.frequencyHz, point.amplitude + WWB_AMPLITUDE_OFFSET_DB));
  }
  return adjusted;
}

void assertAscending(ArrayList<RfExportPoint> points) {
  for (int i = 1; i < points.size(); i++) {
    if (points.get(i).frequencyHz < points.get(i - 1).frequencyHz) {
      throw new IllegalStateException("RF export frequencies are not ascending.");
    }
  }
}

void assertWwbRows(ArrayList<RfExportPoint> sourcePoints, ArrayList<RfExportPoint> adjustedPoints) {
  if (sourcePoints.size() != adjustedPoints.size()) {
    throw new IllegalStateException("WWB amplitude adjustment changed the row count.");
  }

  for (int i = 0; i < adjustedPoints.size(); i++) {
    RfExportPoint sourcePoint = sourcePoints.get(i);
    RfExportPoint adjustedPoint = adjustedPoints.get(i);
    if (sourcePoint.frequencyHz != adjustedPoint.frequencyHz
      || Double.compare(adjustedPoint.amplitude, sourcePoint.amplitude + WWB_AMPLITUDE_OFFSET_DB) != 0) {
      throw new IllegalStateException("WWB compatibility offset was not applied exactly once.");
    }

    if (i > 0) {
      long spacingHz = adjustedPoint.frequencyHz - adjustedPoints.get(i - 1).frequencyHz;
      if (spacingHz < WWB_MIN_SPACING_HZ) {
        throw new IllegalStateException("WWB rows are less than 25 kHz apart.");
      }
    }
  }
}

public void rawExportFileSelected(java.io.File selection) {
  rfExportInProgress = false;
  if (selection == null) {
    pendingRawRows = null;
    println("Raw RF export cancelled.");
    return;
  }

  java.io.File csvFile = ensureCsvExtension(selection);
  try {
    writeRawCsv(csvFile, pendingRawRows);
    showExportSuccess("Raw RF scan saved successfully.", csvFile);
  }
  catch (Exception exception) {
    showExportError("Unable to save the raw RF CSV file.", exception);
  }
  finally {
    pendingRawRows = null;
  }
}

public void wwbExportFileSelected(java.io.File selection) {
  rfExportInProgress = false;
  if (selection == null) {
    pendingWwbRows = null;
    println("WWB export cancelled.");
    return;
  }

  java.io.File csvFile = ensureCsvExtension(selection);
  try {
    writeWwbCsv(csvFile, pendingWwbRows);
    showExportSuccess("WWB scan saved successfully.", csvFile);
  }
  catch (Exception exception) {
    showExportError("Unable to save the WWB CSV file.", exception);
  }
  finally {
    pendingWwbRows = null;
  }
}

java.io.File ensureCsvExtension(java.io.File selection) {
  if (selection.getName().toLowerCase(Locale.US).endsWith(".csv")) return selection;
  return new java.io.File(selection.getParentFile(), selection.getName() + ".csv");
}

void writeRawCsv(java.io.File outputFile, ArrayList<RfExportPoint> rows) throws java.io.IOException {
  writeRfCsv(outputFile, rows, false);
}

void writeWwbCsv(java.io.File outputFile, ArrayList<RfExportPoint> rows) throws java.io.IOException {
  writeRfCsv(outputFile, rows, true);
}

void writeRfCsv(java.io.File outputFile, ArrayList<RfExportPoint> rows, boolean wwbFormat)
  throws java.io.IOException {
  if (rows == null || rows.size() == 0) {
    throw new java.io.IOException("No RF rows are available to save.");
  }

  java.io.BufferedWriter writer = null;
  try {
    writer = new java.io.BufferedWriter(
      new java.io.OutputStreamWriter(new java.io.FileOutputStream(outputFile), "UTF-8"));

    for (RfExportPoint row : rows) {
      if (wwbFormat) {
        writer.write(String.format(Locale.US, "%.6f,%.2f",
          row.frequencyHz / 1000000.0, row.amplitude));
      } else {
        writer.write(String.format(Locale.US, "%.6f,%s",
          row.frequencyHz / 1000000.0, Double.toString(row.amplitude)));
      }
      writer.newLine();
    }
  }
  finally {
    if (writer != null) writer.close();
  }
}

void showExportSuccess(String message, java.io.File csvFile) {
  println("RF export saved: " + csvFile.getAbsolutePath());
  javax.swing.JOptionPane.showMessageDialog(null, message, appDisplayName(),
    javax.swing.JOptionPane.INFORMATION_MESSAGE);
}

void showExportError(String message) {
  showExportError(message, null);
}

void showExportError(String message, Exception exception) {
  println("RF export error: " + message);
  if (exception != null) exception.printStackTrace();
  MsgBox(message, appDisplayName() + " - Export");
}
