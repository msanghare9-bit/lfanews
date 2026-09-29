import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../modeles.dart';
import '../theme.dart';
import '../widgets.dart';
import '../actions_article.dart';
import '../direct_service.dart';
import '../session.dart';
import 'apropos.dart';
import 'article.dart';
import 'cours.dart';
import '../emission_service.dart';
import 'direct.dart';
import '../maj.dart';
import 'emission.dart';
import 'videos.dart';
import 'espace.dart';
import 'recherche.dart';

class Accueil extends StatefulWidget {
  const Accueil({super.key});

  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  int _onglet = 0;
  String? _categorie;
  final _flux = FirebaseFirestore.instance
      .collection('articles')
      .orderBy('date', descending: true)
      .limit(150)
      .snapshots();
  final _directs = directsEnCours();
  final _derniereEmission = emissions.orderBy('debut', descending: true).limit(1).snapshots();

  void _actions(Article a) {
    final ed = Session.instance.editeur.value;
    if (ed != null && ed.estAdmin) menuActionsArticle(context, ed, a);
  }

  void _ouvrir(Article a) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageArticle(article: a)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _flux,
      builder: (context, snap) {
        final articles =
            snap.hasData ? snap.data!.docs.map(Article.fromDoc).toList() : <Article>[];
        return Scaffold(
          body: IndexedStack(
            index: _onglet,
            children: [
              _fil(snap, articles),
              Recherche(articles: articles),
              const Cours0(),
              const EspaceRedaction(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _onglet,
            onDestinationSelected: (i) => setState(() => _onglet = i),
            backgroundColor: Colors.white,
            indicatorColor: vertClair,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: vert), label: 'Accueil'),
              NavigationDestination(
                  icon: Icon(Icons.search), selectedIcon: Icon(Icons.search, color: vert), label: 'Rechercher'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book, color: vert), label: 'Cours'),
              NavigationDestination(
                  icon: Icon(Icons.edit_outlined), selectedIcon: Icon(Icons.edit, color: vert), label: 'Se connecter'),
            ],
          ),
        );
      },
    );
  }

  Widget _fil(AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap, List<Article> tous) {
    Widget corps;
    if (snap.hasError && tous.isEmpty) {
      corps = messageVide("Impossible de charger les actualités. Vérifiez votre connexion internet.");
    } else if (!snap.hasData) {
      corps = const Center(child: CircularProgressIndicator());
    } else {
      final maintenant = DateTime.now();
      final urgents = tous.where((a) => a.urgent && maintenant.difference(a.date).inDays < 7).toList();
      final liste = _categorie == null ? tous : tous.where((a) => a.categorie == _categorie).toList();
      Article? une;
      if (_categorie == null && liste.isNotEmpty) {
        une = liste.firstWhere((a) => a.epingle, orElse: () => liste.first);
      }
      final reste = liste.where((a) => a.id != une?.id).toList();
      corps = ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const BandeauMiseAJour(),
          StreamBuilder<List<Direct>>(
            stream: _directs,
            builder: (context, s) => Column(
              children: [
                for (final d in s.data ?? const <Direct>[])
                  BandeauDirect(
                    direct: d,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => PageDirect(directId: d.id))),
                  ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _derniereEmission,
            builder: (context, s) {
              if (!s.hasData || s.data!.docs.isEmpty) return const SizedBox.shrink();
              final e = Emission.fromDoc(s.data!.docs.first);
              final ecart = DateTime.now().difference(e.debut).abs();
              if (ecart > const Duration(hours: 48)) return const SizedBox.shrink();
              return BandeauEmission(
                emission: e,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => PageEmission(emissionId: e.id))),
              );
            },
          ),
          if (urgents.isNotEmpty)
            BandeauUrgent(article: urgents.first, onTap: () => _ouvrir(urgents.first)),
          _puces(),
          if (_categorie == null) const CarteBienvenue(),
          if (liste.isEmpty) messageVide('Aucun article dans cette rubrique pour le moment.'),
          if (une != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: ApparitionDouce(enfant: CarteUne(article: une, onTap: () => _ouvrir(une!), onLongPress: () => _actions(une!))),
            ),
          for (final e in reste.asMap().entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ApparitionDouce(
                indice: e.key,
                enfant: LigneArticle(article: e.value, onTap: () => _ouvrir(e.value), onLongPress: () => _actions(e.value)),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const TitreAppli(),
        actions: [
          IconButton(
            tooltip: 'Vidéos',
            icon: const Icon(Icons.play_circle_outline, color: Colors.white),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListeVideos())),
          ),
          IconButton(
            tooltip: 'Émissions',
            icon: const Icon(Icons.headphones_outlined, color: Colors.white),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListeEmissions())),
          ),
          IconButton(
            tooltip: 'À propos de LFA News',
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PageAPropos())),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: bordure),
        ),
      ),
      body: corps,
    );
  }

  Widget _puces() {
    Widget puce(String texte, String? valeur) {
      final choisi = _categorie == valeur;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texte),
          selected: choisi,
          showCheckmark: false,
          onSelected: (_) => setState(() => _categorie = valeur),
          selectedColor: vert,
          backgroundColor: Colors.white,
          side: BorderSide(color: choisi ? vert : bordureChamp),
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
            color: choisi ? Colors.white : encre,
            fontWeight: choisi ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          puce('Tout', null),
          for (final c in categories) puce(c, c),
        ],
      ),
    );
  }
}
