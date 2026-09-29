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
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const LogoLfa(taille: 34),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LFA NEWS', style: titre(23, couleur: Colors.white).copyWith(height: 1)),
              const SizedBox(height: 2),
              const Text('Lycée Franco-Arabe de Kébémer',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFD6EDDD), fontWeight: FontWeight.w400)),
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
  const CarteUne({super.key, required this.article, required this.onTap, this.onLongPress});
  final Article article;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: const [
        BoxShadow(color: Color(0x33132619), blurRadius: 18, offset: Offset(0, 8)),
      ]),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 262,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Photo(octets: article.octets, sombre: true),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xEB061A0F), Color(0x73061A0F), Color(0x00061A0F)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 34, 18, 18),
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
              child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, onLongPress: onLongPress)),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class LigneArticle extends StatelessWidget {
  const LigneArticle({super.key, required this.article, required this.onTap, this.etiquette, this.onLongPress});
  final Article article;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? etiquette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: const [
                BoxShadow(color: Color(0x1A132619), blurRadius: 8, offset: Offset(0, 3)),
              ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 104,
                  height: 80,
                  child: Photo(
                    octets: article.octets,
                    icone: article.estPortrait || article.estInterview || article.estRencontre
                        ? Icons.person_outline
                        : Icons.image_outlined,
                  ),
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

class BandeauUrgent extends StatefulWidget {
  const BandeauUrgent({super.key, required this.article, required this.onTap});
  final Article article;
  final VoidCallback onTap;

  @override
  State<BandeauUrgent> createState() => _BandeauUrgentState();
}

class _BandeauUrgentState extends State<BandeauUrgent> {
  final _defilement = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ne défile qu'une fois, lentement, et seulement si le message est trop long.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_defilement.hasClients) return;
      final total = _defilement.position.maxScrollExtent;
      if (total <= 0) return;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _defilement.animateTo(total,
          duration: Duration(milliseconds: (total * 40).clamp(1800, 9000).round()), curve: Curves.linear);
    });
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: orangeUrgent,
      child: InkWell(
        onTap: widget.onTap,
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
                child: SingleChildScrollView(
                  controller: _defilement,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(widget.article.titre,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
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

Widget messageVide(String texte, {IconData icone = Icons.auto_stories_outlined}) => Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 46, color: vertClair),
          const SizedBox(height: 14),
          Text(texte, textAlign: TextAlign.center, style: const TextStyle(color: gris, fontSize: 15, height: 1.4)),
        ],
      ),
    );

/// Fait apparaître son enfant en douceur, léger décalage vers le haut,
/// avec un délai croissant pour un effet en cascade dans une liste.
class ApparitionDouce extends StatelessWidget {
  const ApparitionDouce({super.key, required this.enfant, this.indice = 0});
  final Widget enfant;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final delai = (indice * 60).clamp(0, 300);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delai),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: enfant,
    );
  }
}

const rougeDirect = Color(0xFFC62828);

/// Petit point rouge qui clignote doucement, pour signaler un direct.
class PointClignotant extends StatefulWidget {
  const PointClignotant({super.key, this.couleur = rougeDirect, this.taille = 8});
  final Color couleur;
  final double taille;

  @override
  State<PointClignotant> createState() => _PointClignotantState();
}

class _PointClignotantState extends State<PointClignotant> with SingleTickerProviderStateMixin {
  late final _controleur = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(CurvedAnimation(parent: _controleur, curve: Curves.easeInOut)),
      child: Container(
        width: widget.taille,
        height: widget.taille,
        decoration: BoxDecoration(color: widget.couleur, shape: BoxShape.circle),
      ),
    );
  }
}

class BandeauDirect extends StatelessWidget {
  const BandeauDirect({super.key, required this.direct, required this.onTap});
  final Direct direct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [vert, Color(0xFF187A47)]),
        boxShadow: [BoxShadow(color: Color(0x400F6B3A), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
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
                    PointClignotant(taille: 8),
                    SizedBox(width: 5),
                    Text('EN DIRECT',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vert)),
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
      ),
    );
  }
}
