final String WHATS_NEW_PREFERENCES_NODE = "/com/rizzieri/rfmanager";
final String WHATS_NEW_VERSION_KEY = "lastViewedVersion";

void showWhatsNewIfNeeded() {
  java.util.prefs.Preferences preferences = null;
  String lastViewedVersion = "";

  try {
    preferences = java.util.prefs.Preferences.userRoot().node(WHATS_NEW_PREFERENCES_NODE);
    lastViewedVersion = preferences.get(WHATS_NEW_VERSION_KEY, "");
  }
  catch (Exception exception) {
    println("Unable to read What's New preference; the dialog will still be shown.");
    exception.printStackTrace();
  }

  if (APP_VERSION.equals(lastViewedVersion)) return;

  String message = appDisplayName() + "\n\n"
    + "What's new:\n"
    + "- Two export modes: Raw Scan and Wireless Workbench\n"
    + "- Automatic -75 dB adjustment for WWB export\n"
    + "- Optimized 25 kHz frequency grid for WWB\n"
    + "- New Rizzieri RF Manager identity\n"
    + "- New logo positioning\n"
    + "- Discreet graph watermark\n"
    + "- Integrated application versioning";

  javax.swing.JOptionPane.showMessageDialog(null, message, "What's New - " + appDisplayName(),
    javax.swing.JOptionPane.INFORMATION_MESSAGE);

  if (preferences != null) {
    try {
      preferences.put(WHATS_NEW_VERSION_KEY, APP_VERSION);
      preferences.flush();
    }
    catch (Exception exception) {
      println("Unable to store What's New preference.");
      exception.printStackTrace();
    }
  }
}
