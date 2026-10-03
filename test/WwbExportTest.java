import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
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

    double[] invalidSamples = new double[] {
      -13.89, Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, -20.125
    };
    ArrayList<spektrum.WwbPoint> validRows = app.buildWwbRows(invalidSamples, 470000000, 25000);
    require(validRows.size() == 2, "stable export must discard NaN and infinities");
    requireClose(validRows.get(0).amplitudeDbm, -13.89,
      "stable export must preserve amplitude without a -75 dB transformation");

    app.ifType = app.IF_TYPE_BELOW;
    app.ifOffset = 600000000;
    ArrayList<spektrum.WwbPoint> reversed = app.buildWwbRows(
      new double[] {-100.0, -90.0, -80.0}, 100000000, 25000);
    require(reversed.get(0).frequencyHz == 499950000L, "IF-below lower corrected frequency");
    require(reversed.get(2).frequencyHz == 500000000L, "IF-below upper corrected frequency");
    requireClose(reversed.get(0).amplitudeDbm, -80.0,
      "sorting after IF correction must retain amplitude association");

    app.ifType = app.IF_TYPE_NONE;
    double[] fine = new double[40];
    Arrays.fill(fine, -120.0);
    fine[12] = -10.0;
    fine[13] = -20.0;
    ArrayList<spektrum.WwbPoint> reduced = app.buildWwbRows(fine, 450024994, 1000);
    require(reduced.size() == 2, "stable sequential-window reduction row count");
    require(reduced.get(0).frequencyHz == 450024994L,
      "stable reduction must remain anchored at the first corrected frequency");
    require(reduced.get(1).frequencyHz == 450049994L,
      "stable reduction must advance by exactly 25 kHz");
    requireClose(reduced.get(0).amplitudeDbm, -10.0,
      "stable reduction must preserve the strongest amplitude without offset");

    File fixture = new File(System.getProperty(
      "wwb.fixture", "test-data/sample_wwb_scan.csv"));
    List<String> expectedFixture = Files.readAllLines(fixture.toPath(), StandardCharsets.UTF_8);
    double[] fixtureAmplitudes = new double[expectedFixture.size()];
    for (int i = 0; i < expectedFixture.size(); i++) {
      fixtureAmplitudes[i] = Double.parseDouble(expectedFixture.get(i).split(",")[1]);
    }

    ArrayList<spektrum.WwbPoint> fixtureRows = app.buildWwbRows(
      fixtureAmplitudes, 470000000, 25000);
    File generatedCsv = File.createTempFile("wwb-stable-regression-", ".csv");

    Locale previous = Locale.getDefault();
    try {
      Locale.setDefault(Locale.GERMANY);
      app.writeWwbCsv(generatedCsv, fixtureRows);
    }
    finally {
      Locale.setDefault(previous);
    }

    List<String> generatedFixture = Files.readAllLines(
      generatedCsv.toPath(), StandardCharsets.UTF_8);
    require(generatedFixture.equals(expectedFixture),
      "generated CSV must match the b1755bc4-compatible fixture exactly");
    require(!generatedFixture.get(0).toLowerCase(Locale.US).contains("frequency"),
      "WWB CSV must not have a header");
    require(generatedFixture.get(0).equals("470.000000,-109.00"),
      "WWB CSV must use Locale.US formatting and no -75 dB transformation");
    generatedCsv.delete();

    double[] largeFixture = new double[250000];
    for (int i = 0; i < largeFixture.length; i++) {
      largeFixture[i] = -120.0 + (i % 71) * 0.25;
    }
    long startedAt = System.nanoTime();
    ArrayList<spektrum.WwbPoint> largeRows = app.buildWwbRows(
      largeFixture, 100000000, 1000);
    long elapsedMillis = (System.nanoTime() - startedAt) / 1000000L;
    require(largeRows.size() == 10000, "large fixture reduction row count");
    require(elapsedMillis < 10000L, "large fixture shows a gross processing regression");

    System.out.println("WWB stable-export regression tests passed.");
    System.out.println("LARGE_FIXTURE_SAMPLES=250000");
    System.out.println("LARGE_FIXTURE_ROWS=" + largeRows.size());
    System.out.println("LARGE_FIXTURE_MS=" + elapsedMillis);
  }
}
