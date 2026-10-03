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
    println("Não foi possível ler a preferência de novidades; a janela será exibida.");
    exception.printStackTrace();
  }

  if (APP_VERSION.equals(lastViewedVersion)) return;

  String message = appDisplayName() + "\n\n"
    + "- Exportação restaurada ao fluxo estável.\n"
    + "- Exportação movida para uma aba própria.\n"
    + "- Marca d'água atualizada.\n"
    + "- Melhorias na instalação e atualização do aplicativo.";

  javax.swing.JOptionPane.showMessageDialog(null, message, "Novidades desta versão",
    javax.swing.JOptionPane.INFORMATION_MESSAGE);

  if (preferences != null) {
    try {
      preferences.put(WHATS_NEW_VERSION_KEY, APP_VERSION);
      preferences.flush();
    }
    catch (Exception exception) {
      println("Não foi possível registrar a versão visualizada das novidades.");
      exception.printStackTrace();
    }
  }
}
