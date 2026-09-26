import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'modeles.dart';
import 'theme.dart';

String dateFr(DateTime d) => DateFormat('d MMMM yyyy', 'fr_FR').format(d);

String initiales(String nom) {
  final parts = nom.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'LF';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class LogoLfa extends StatelessWidget {
  const LogoLfa({super.key, this.taille = 36});
  final double taille;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/logo.png', width: taille, height: taille);
}

class TitreAppli extends StatelessWidget {
  const TitreAppli({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LogoLfa(taille: 38),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LFA NEWS', style: titre(23, couleur: vert).copyWith(height: 1)),
              const SizedBox(height: 2),
              const Text('Lycée Franco-Arabe de Kébémer',
                  style: TextStyle(fontSize: 11.5, color: gris, fontWeight: FontWeight.w400)),
            ],
          ),
        ],
      );
}

/// Photo si elle existe, sinon un emplacement vert discret.
class Photo extends StatelessWidget {
  const Photo({super.key, required this.octets, this.sombre = false, this.icone = Icons.image_outlined});
  final Uint8List? octets;
  final bool sombre;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    if (octets != null) {
      return Image.memory(octets!,
          fit: BoxFit.cover, gaplessPlayback: true, width: double.infinity, height: double.infinity);
    }
    return Container(
      color: sombre ? vertFonce : vertClair,
      alignment: Alignment.center,
      child: Icon(icone, size: 34, color: sombre ? const Color(0xFFBFD8C8) : vert),
    );
  }
}

class CarteUne extends StatelessWidget {
  const CarteUne({super.key, required this.article, required this.onTap});
  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Photo(octets: article.octets, sombre: true),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: voile,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('À LA UNE  ·  ${article.categorie.toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0xFF8FD3A8))),
                    const SizedBox(height: 6),
                    Text(article.titre,
                        maxLines: 3, overflow: TextOverflow.ellipsis, style: titre(22, couleur: Colors.white)),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Material(color: Colors.transparent, child: InkWell(onTap: onTap)),
            ),
          ],
        ),
      ),
    );
  }
}

class LigneArticle extends StatelessWidget {
  const LigneArticle({super.key, required this.article, required this.onTap, this.etiquette});
  final Article article;
  final VoidCallback onTap;
  final String? etiquette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 104,
                height: 80,
                child: Photo(
                  octets: article.octets,
                  icone: article.estPortrait || article.estInterview
                      ? Icons.person_outline
                      : Icons.image_outlined,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiquette ?? article.categorie,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vert)),
                  const SizedBox(height: 3),
                  Text(article.titre,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(dateFr(article.date), style: const TextStyle(fontSize: 12, color: gris)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BandeauUrgent extends StatelessWidget {
  const BandeauUrgent({super.key, required this.article, required this.onTap});
  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: orangeUrgent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                child: const Text('URGENT',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: orangeUrgent)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(article.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Paragraphes extends StatelessWidget {
  const Paragraphes(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) {
    final blocs = texte.split(RegExp(r'\n\s*\n')).map((b) => b.trim()).where((b) => b.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(b, style: const TextStyle(fontSize: 16, height: 1.6)),
          ),
      ],
    );
  }
}

Widget messageVide(String texte) => Padding(
      padding: const EdgeInsets.all(32),
      child: Text(texte, textAlign: TextAlign.center, style: const TextStyle(color: gris, fontSize: 15)),
    );

const rougeDirect = Color(0xFFC62828);

class BandeauDirect extends StatelessWidget {
  const BandeauDirect({super.key, required this.direct, required this.onTap});
  final Direct direct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: rougeDirect,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: rougeDirect),
                    SizedBox(width: 4),
                    Text('EN DIRECT',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rougeDirect)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(direct.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              if (direct.estMatch) ...[
                const SizedBox(width: 8),
                Text(direct.score, style: titre(18, couleur: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
