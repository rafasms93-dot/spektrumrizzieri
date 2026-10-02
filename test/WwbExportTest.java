import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class WwbExportTest {
  private static void require(boolean condition, String message) {
    if (!condition) throw new AssertionError(message);
  }

  private static void requireClose(double actual, double expected, String message) {
    if (Math.abs(actual - expected) > 0.0000001) {
      throw new AssertionError(message + ": expected " + expected + ", got " + actual);
    }
  }

  public static void main(String[] args) throws Exception {
    spektrum app = new spektrum();
    app.ifType = app.IF_TYPE_NONE;
    app.ifOffset = 0;

    double[] sameSnapshot = new double[] {
      -13.89, Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, -20.125
    };
    ArrayList<spektrum.RfExportPoint> raw = app.buildRawRows(sameSnapshot, 470000000, 25000);
    ArrayList<spektrum.RfExportPoint> wwb = app.buildWwbRows(sameSnapshot, 470000000, 25000);

    require(raw.size() == 2, "raw export must discard NaN and infinity");
    require(wwb.size() == 2, "WWB export must discard NaN and infinity");
    requireClose(raw.get(0).amplitude, -13.89, "raw export must preserve amplitude");
    requireClose(wwb.get(0).amplitude, -88.89, "WWB must apply -75 dB exactly once");
    require(raw.get(0).amplitude != wwb.get(0).amplitude,
      "raw and WWB exports from one snapshot must differ");

    app.ifType = app.IF_TYPE_BELOW;
    app.ifOffset = 600000000;
    ArrayList<spektrum.RfExportPoint> reversed = app.buildRawRows(
      new double[] {-100.0, -90.0, -80.0}, 100000000, 25000);
    require(reversed.get(0).frequencyHz == 499950000L, "IF-below lower corrected frequency");
    require(reversed.get(2).frequencyHz == 500000000L, "IF-below upper corrected frequency");
    requireClose(reversed.get(0).amplitude, -80.0, "IF sorting must retain amplitude association");

    app.ifType = app.IF_TYPE_NONE;
    double[] fine = new double[40];
    for (int i = 0; i < fine.length; i++) fine[i] = -120.0;
    fine[12] = -10.0;
    fine[13] = -20.0;
    ArrayList<spektrum.RfExportPoint> fineRaw = app.buildRawRows(fine, 450024994, 1000);
    ArrayList<spektrum.RfExportPoint> fineWwb = app.buildWwbRows(fine, 450024994, 1000);

    require(fineRaw.size() == 40, "raw export must preserve fine bins");
    require(fineWwb.get(0).frequencyHz == 450025000L, "WWB frequency must align to clean grid");
    require(fineWwb.get(1).frequencyHz == 450050000L, "WWB grid must advance exactly 25 kHz");
    requireClose(fineWwb.get(0).amplitude, -85.0, "first WWB window must preserve peak and offset");
    requireClose(fineWwb.get(1).amplitude, -95.0, "second WWB window must preserve peak and offset");
    for (int i = 1; i < fineWwb.size(); i++) {
      require(fineWwb.get(i).frequencyHz - fineWwb.get(i - 1).frequencyHz >= 25000L,
        "WWB rows must be at least 25 kHz apart");
    }

    Locale previous = Locale.getDefault();
    Locale.setDefault(Locale.GERMANY);
    File rawCsv = File.createTempFile("raw-export-test-", ".csv");
    File wwbCsv = File.createTempFile("wwb-export-test-", ".csv");
    app.writeRawCsv(rawCsv, raw);
    app.writeWwbCsv(wwbCsv, wwb);
    List<String> rawLines = Files.readAllLines(rawCsv.toPath(), StandardCharsets.UTF_8);
    List<String> wwbLines = Files.readAllLines(wwbCsv.toPath(), StandardCharsets.UTF_8);
    Locale.setDefault(previous);

    require(rawLines.get(0).equals("470.000000,-13.89"),
      "raw CSV must use Locale.US and preserve amplitude precision");
    require(wwbLines.get(0).equals("470.000000,-88.89"),
      "WWB CSV must use six/two decimals and Locale.US");
    require(!rawLines.get(0).toLowerCase(Locale.US).contains("frequency"), "raw CSV must not have a header");
    require(!wwbLines.get(0).toLowerCase(Locale.US).contains("frequency"), "WWB CSV must not have a header");

    rawCsv.delete();
    wwbCsv.delete();
    System.out.println("RF export tests passed: raw fidelity, WWB offset/grid, IF, spacing, invalid samples, locale.");
  }
}
