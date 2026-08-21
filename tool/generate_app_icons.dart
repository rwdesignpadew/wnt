import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final source = image.decodePng(File('assets/wnt_app.png').readAsBytesSync());
  if (source == null) throw StateError('Nie można odczytać logo PNG.');

  const android = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in android.entries) {
    _write(
      source,
      entry.value,
      'android/app/src/main/res/${entry.key}/ic_launcher.png',
    );
  }

  const ios = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  for (final entry in ios.entries) {
    _write(
      source,
      entry.value,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
      flattenWhite: true,
    );
  }
}

void _write(
  image.Image source,
  int size,
  String path, {
  bool flattenWhite = false,
}) {
  var resized = image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.cubic,
  );
  if (flattenWhite) {
    final canvas = image.Image(width: size, height: size);
    image.fill(canvas, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(canvas, resized);
    resized = canvas;
  }
  File(path).writeAsBytesSync(image.encodePng(resized));
}
