final String BRANDING_PRODUCT_NAME = "Spektrum Rizzieri";
final String BRANDING_LOGO_ASSET = "assets/branding/logo.png";

PImage brandingLogo;

void setupBranding() {
  surface.setTitle(BRANDING_PRODUCT_NAME);

  java.io.File logoFile = new java.io.File(sketchPath("data/" + BRANDING_LOGO_ASSET));
  if (!logoFile.isFile()) {
    println("Branding logo not found; using text fallback: " + logoFile.getAbsolutePath());
    return;
  }

  try {
    brandingLogo = loadImage(BRANDING_LOGO_ASSET);
    if (brandingLogo == null || brandingLogo.width <= 0 || brandingLogo.height <= 0) {
      brandingLogo = null;
      println("Branding logo could not be decoded; using text fallback.");
      return;
    }

    // Processing 3 applies this to the desktop window where the renderer supports it.
    surface.setIcon(brandingLogo);
  }
  catch (Exception exception) {
    brandingLogo = null;
    println("Branding logo could not be loaded; using text fallback.");
    exception.printStackTrace();
  }
}

void drawBranding() {
  final float areaX = 15;
  final float areaY = height - 112;
  final float areaWidth = 170;
  final float areaHeight = 96;

  pushStyle();
  if (brandingLogo != null) {
    float imageScale = min(areaWidth / brandingLogo.width, areaHeight / brandingLogo.height);
    float imageWidth = brandingLogo.width * imageScale;
    float imageHeight = brandingLogo.height * imageScale;
    imageMode(CORNER);
    image(brandingLogo,
      areaX + (areaWidth - imageWidth) / 2.0,
      areaY + (areaHeight - imageHeight) / 2.0,
      imageWidth,
      imageHeight);
  } else {
    fill(#A7A7A7);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(BRANDING_PRODUCT_NAME, areaX, areaY, areaWidth, areaHeight);
  }
  popStyle();
}
