final String BRANDING_LOGO_ASSET = "assets/branding/logo.png";
final float BRANDING_WATERMARK_OPACITY = 0.08;

PImage brandingLogo;

void setupBranding() {
  surface.setTitle(appDisplayName());

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
  final float areaWidth = 120;
  final float areaHeight = 60;
  final float areaX = 15 + (170 - areaWidth) / 2.0;
  final float areaY = graphHeight() - 130 - areaHeight - 18;

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
    textSize(10);
    text(appDisplayName(), areaX, areaY, areaWidth, areaHeight);
  }
  popStyle();
}

void drawGraphWatermark() {
  if (brandingLogo == null) return;

  final float maxWidth = graphWidth() * 0.35;
  final float maxHeight = graphHeight() * 0.35;
  float imageScale = min(maxWidth / brandingLogo.width, maxHeight / brandingLogo.height);
  float imageWidth = brandingLogo.width * imageScale;
  float imageHeight = brandingLogo.height * imageScale;
  float imageX = graphX() + (graphWidth() - imageWidth) / 2.0;
  float imageY = graphY() + (graphHeight() - imageHeight) / 2.0;

  pushStyle();
  imageMode(CORNER);
  tint(255, round(255 * BRANDING_WATERMARK_OPACITY));
  image(brandingLogo, imageX, imageY, imageWidth, imageHeight);
  popStyle();
}
