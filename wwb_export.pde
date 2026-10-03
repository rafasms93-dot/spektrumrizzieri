final long WWB_MIN_SPACING_HZ = 25000L;

ArrayList<WwbPoint> pendingWwbRows;
boolean wwbExportInProgress = false;

class WwbPoint implements Comparable<WwbPoint> {
  long frequencyHz;
  double amplitudeDbm;

  WwbPoint(long frequencyHz, double amplitudeDbm) {
    this.frequencyHz = frequencyHz;
    this.amplitudeDbm = amplitudeDbm;
  }

  public int compareTo(WwbPoint other) {
    if (frequencyHz < other.frequencyHz) return -1;
    if (frequencyHz > other.frequencyHz) return 1;
    return 0;
  }
}

public void exportToWWB() {
  if (wwbExportInProgress) {
    println("WWB export: a save dialog is already open.");
    return;
  }

  if (spektrumReader == null) {
    showWwbError("No RF scanner is available.");
    return;
  }

  double[] sourceBuffer;
  try {
    sourceBuffer = spektrumReader.getDbmBuffer();
  }
  catch (Exception exception) {
    showWwbError("Unable to capture the current RF scan.", exception);
    return;
  }

  if (sourceBuffer == null || sourceBuffer.length == 0) {
    showWwbError("The current RF scan is empty.");
    return;
  }

  try {
    pendingWwbRows = buildWwbRows(sourceBuffer.clone(), startFreq, binStep);
  }
  catch (Exception exception) {
    showWwbError("The current RF scan could not be prepared for WWB.", exception);
    pendingWwbRows = null;
    return;
  }

  if (pendingWwbRows.size() == 0) {
    showWwbError("The current RF scan contains no usable samples.");
    pendingWwbRows = null;
    return;
  }

  String timestamp = new java.text.SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
  java.io.File suggestedFile = new java.io.File(sketchPath("spektrum_wwb_" + timestamp + ".csv"));
  wwbExportInProgress = true;
  selectOutput("Save scan for Shure Wireless Workbench", "wwbExportFileSelected", suggestedFile);
}

ArrayList<WwbPoint> buildWwbRows(double[] buffer, int sourceStartFreq, int sourceBinStep) {
  ArrayList<WwbPoint> points = new ArrayList<WwbPoint>();

  for (int i = 0; i < buffer.length; i++) {
    double amplitude = buffer[i];
    if (Double.isNaN(amplitude) || Double.isInfinite(amplitude)) continue;

    long rawFrequencyHz = (long)sourceStartFreq + (long)i * (long)sourceBinStep;
    if (rawFrequencyHz < Integer.MIN_VALUE || rawFrequencyHz > Integer.MAX_VALUE) continue;

    long correctedFrequencyHz = (long)ifCorrectedFreq((int)rawFrequencyHz);
    points.add(new WwbPoint(correctedFrequencyHz, amplitude));
  }

  Collections.sort(points);
  if (sourceBinStep < WWB_MIN_SPACING_HZ) {
    points = reduceWwbPoints(points);
  }

  assertWwbSpacing(points);
  return points;
}

ArrayList<WwbPoint> reduceWwbPoints(ArrayList<WwbPoint> sortedPoints) {
  ArrayList<WwbPoint> reduced = new ArrayList<WwbPoint>();
  if (sortedPoints.size() == 0) return reduced;

  long windowStartHz = sortedPoints.get(0).frequencyHz;
  long windowEndHz = windowStartHz + WWB_MIN_SPACING_HZ;
  WwbPoint strongestPoint = null;

  for (WwbPoint point : sortedPoints) {
    while (point.frequencyHz >= windowEndHz) {
      if (strongestPoint != null) {
        // Keep the stable b1755bc4 behavior: use the corrected-frequency
        // window start and retain the strongest amplitude in that window.
        reduced.add(new WwbPoint(windowStartHz, strongestPoint.amplitudeDbm));
        strongestPoint = null;
      }
      windowStartHz = windowEndHz;
      windowEndHz += WWB_MIN_SPACING_HZ;
    }

    if (strongestPoint == null || point.amplitudeDbm > strongestPoint.amplitudeDbm) {
      strongestPoint = point;
    }
  }

  if (strongestPoint != null) {
    reduced.add(new WwbPoint(windowStartHz, strongestPoint.amplitudeDbm));
  }

  return reduced;
}

void assertWwbSpacing(ArrayList<WwbPoint> points) {
  for (int i = 1; i < points.size(); i++) {
    long spacingHz = points.get(i).frequencyHz - points.get(i - 1).frequencyHz;
    if (spacingHz < WWB_MIN_SPACING_HZ) {
      throw new IllegalStateException("WWB rows are less than 25 kHz apart.");
    }
  }
}

public void wwbExportFileSelected(java.io.File selection) {
  wwbExportInProgress = false;

  if (selection == null) {
    pendingWwbRows = null;
    println("WWB export cancelled.");
    return;
  }

  java.io.File csvFile = ensureCsvExtension(selection);
  try {
    writeWwbCsv(csvFile, pendingWwbRows);
    println("WWB export saved: " + csvFile.getAbsolutePath());
    javax.swing.JOptionPane.showMessageDialog(null,
      "WWB scan saved successfully.",
      appDisplayName(),
      javax.swing.JOptionPane.INFORMATION_MESSAGE);
  }
  catch (Exception exception) {
    showWwbError("Unable to save the WWB CSV file.", exception);
  }
  finally {
    pendingWwbRows = null;
  }
}

java.io.File ensureCsvExtension(java.io.File selection) {
  if (selection.getName().toLowerCase(Locale.US).endsWith(".csv")) return selection;
  return new java.io.File(selection.getParentFile(), selection.getName() + ".csv");
}

void writeWwbCsv(java.io.File outputFile, ArrayList<WwbPoint> rows) throws java.io.IOException {
  if (rows == null || rows.size() == 0) {
    throw new java.io.IOException("No WWB rows are available to save.");
  }

  java.io.BufferedWriter writer = null;
  try {
    writer = new java.io.BufferedWriter(
      new java.io.OutputStreamWriter(new java.io.FileOutputStream(outputFile), "UTF-8"));

    for (WwbPoint row : rows) {
      writer.write(String.format(Locale.US, "%.6f,%.2f",
        row.frequencyHz / 1000000.0,
        row.amplitudeDbm));
      writer.newLine();
    }
  }
  finally {
    if (writer != null) writer.close();
  }
}

void showWwbError(String message) {
  showWwbError(message, null);
}

void showWwbError(String message, Exception exception) {
  println("WWB export error: " + message);
  if (exception != null) exception.printStackTrace();
  MsgBox(message, appDisplayName() + " - WWB Export");
}
