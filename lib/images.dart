import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Choisit une photo, déjà réduite pour rester légère.
Future<Uint8List?> choisirPhoto(ImageSource source) async {
  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 60,
  );
  if (x == null) return null;
  return x.readAsBytes();
}

/// Petite image pour la liste des articles (quelques dizaines de Ko).
String vignetteDe(Uint8List octets) => reduire((octets, 480));

/// Réduit une image à [taille] pixels de côté au plus, en JPEG base64.
String reduire((Uint8List, int) e) {
  final (octets, taille) = e;
  final im = img.decodeImage(octets);
  if (im == null) return '';
  final petite = im.width <= taille && im.height <= taille
      ? im
      : (im.width >= im.height ? img.copyResize(im, width: taille) : img.copyResize(im, height: taille));
  return base64Encode(img.encodeJpg(petite, quality: 60));
}
