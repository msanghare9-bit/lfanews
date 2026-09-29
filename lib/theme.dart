import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const vert = Color(0xFF0F6B3A);
const vertVif = Color(0xFF2E9E5B);
const vertPale = Color(0xFFF2F6F3);
const vertClair = Color(0xFFDCE9E0);
const vertFonce = Color(0xFF2F5E44);
const encre = Color(0xFF13261B);
const gris = Color(0xFF4A5E52);
const bordure = Color(0xFFE3ECE6);
const bordureChamp = Color(0xFFCFDDD3);
const orangeUrgent = Color(0xFFB8400E);
const voile = Color(0xDB082415);

TextStyle titre(double taille, {Color couleur = encre}) => TextStyle(
      fontFamily: 'ArchivoTitre',
      fontWeight: FontWeight.w800,
      fontSize: taille,
      height: 1.12,
      color: couleur,
    );

ThemeData lfaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Archivo',
    colorScheme: ColorScheme.fromSeed(seedColor: vert, primary: vert, surface: Colors.white),
    scaffoldBackgroundColor: Colors.white,
  );
  final bord = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: bordureChamp),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: encre, displayColor: encre),
    appBarTheme: const AppBarTheme(
      backgroundColor: vert,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: vert,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Archivo'),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: vert,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: bord,
      enabledBorder: bord,
      focusedBorder: bord.copyWith(borderSide: const BorderSide(color: vert, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Archivo', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
