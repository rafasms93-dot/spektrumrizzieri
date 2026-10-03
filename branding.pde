final String BRANDING_LOGO_ASSET = "assets/branding/logo_rizzieri_rf_manager_color.png";
final String BRANDING_WATERMARK_ASSET = "assets/branding/watermark_rizzieri_r_monochrome.png";
final String BRANDING_ICON_ASSET = "assets/branding/icon_rizzieri_r_color.png";
final String BRANDING_WINDOWS_ICON_ASSET = "assets/branding/icon_rizzieri_r_color.ico";
final float BRANDING_WATERMARK_OPACITY = 0.08;

PImage brandingLogo;
PImage brandingWatermark;
PImage brandingIcon;

void setupBranding() {
  surface.setTitle(appDisplayName());

  brandingLogo = loadBrandingImage(BRANDING_LOGO_ASSET, "full logo");
  brandingWatermark = loadBrandingImage(BRANDING_WATERMARK_ASSET, "graph watermark");
  brandingIcon = loadBrandingImage(BRANDING_ICON_ASSET, "application icon");

  // Processing 3 applies the PNG icon to the desktop window where supported.
  // The matching ICO asset is available for the Windows executable packager.
  if (brandingIcon != null) surface.setIcon(brandingIcon);
}

PImage loadBrandingImage(String assetPath, String description) {
  java.io.File assetFile = new java.io.File(sketchPath("data/" + assetPath));
  if (!assetFile.isFile()) {
    println("Branding " + description + " not found: " + assetFile.getAbsolutePath());
    return null;
  }

  try {
    PImage imageAsset = loadImage(assetPath);
    if (imageAsset == null || imageAsset.width <= 0 || imageAsset.height <= 0) {
      println("Branding " + description + " could not be decoded.");
      return null;
    }
    return imageAsset;
  }
  catch (Exception exception) {
    println("Branding " + description + " could not be loaded.");
    exception.printStackTrace();
    return null;
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
  if (brandingWatermark == null) return;

  final float maxWidth = graphWidth() * 0.35;
  final float maxHeight = graphHeight() * 0.35;
  float imageScale = min(maxWidth / brandingWatermark.width, maxHeight / brandingWatermark.height);
  float imageWidth = brandingWatermark.width * imageScale;
  float imageHeight = brandingWatermark.height * imageScale;
  float imageX = graphX() + (graphWidth() - imageWidth) / 2.0;
  float imageY = graphY() + (graphHeight() - imageHeight) / 2.0;

  pushStyle();
  imageMode(CORNER);
  tint(255, round(255 * BRANDING_WATERMARK_OPACITY));
  image(brandingWatermark, imageX, imageY, imageWidth, imageHeight);
  popStyle();
}
