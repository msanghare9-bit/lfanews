import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../modeles.dart';
import '../stats.dart';
import '../theme.dart';
import '../widgets.dart';
import 'article.dart';

class _Ligne {
  _Ligne(this.article, this.stat, this.jaime);
  final Article article;
  final Stat stat;
  final int jaime;
}

class Statistiques extends StatefulWidget {
  const Statistiques({super.key});

  @override
  State<Statistiques> createState() => _StatistiquesState();
}

class _StatistiquesState extends State<Statistiques> {
  late Future<List<_Ligne>> _donnees = _charger();
  late Future<int> _installations = nombreInstallations();

  Future<List<_Ligne>> _charger() async {
    final arts = await FirebaseFirestore.instance
        .collection('articles')
        .orderBy('date', descending: true)
        .limit(300)
        .get();
    final (stats, jaimes) = await chargerToutesStats();
    final lignes = arts.docs
        .map(Article.fromDoc)
        .map((a) => _Ligne(a, stats[a.id] ?? const Stat(0, 0), jaimes[a.id] ?? 0))
        .toList()
      ..sort((x, y) => y.stat.vues.compareTo(x.stat.vues));
    return lignes;
  }

  Future<void> _actualiser() async {
    setState(() {
      _donnees = _charger();
      _installations = nombreInstallations();
    });
    await _donnees;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Statistiques', style: titre(22))),
      body: FutureBuilder<List<_Ligne>>(
        future: _donnees,
        builder: (context, s) {
          if (s.hasError) return messageVide('Impossible de charger les statistiques. Vérifiez la connexion.');
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final lignes = s.data!;
          var vues = 0, lectures = 0, jaime = 0, jaimepas = 0;
          final parRubrique = <String, List<int>>{};
          for (final l in lignes) {
            vues += l.stat.vues;
            lectures += l.stat.lectures;
            jaime += l.jaime;
            jaimepas += l.stat.jaimepas;
            final r = parRubrique.putIfAbsent(l.article.categorie, () => [0, 0, 0]);
            r[0] += 1;
            r[1] += l.stat.vues;
            r[2] += l.stat.lectures;
          }
          final rubriques = parRubrique.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
          return RefreshIndicator(
            onRefresh: _actualiser,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                FutureBuilder<int>(
                  future: _installations,
                  builder: (context, si) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(color: vert, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_iphone, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${si.data ?? '…'} téléphones ont installé LFA News',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _chiffre('Vues', vues),
                    _chiffre('Lectures', lectures),
                    _chiffre("J'aime", jaime),
                    _chiffre("Je n'aime pas", jaimepas),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('Par rubrique', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final e in rubriques)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${e.key}  (${e.value[0]} article${e.value[0] > 1 ? 's' : ''})',
                              style: const TextStyle(fontSize: 15)),
                        ),
                        Text('${e.value[1]} vues · ${e.value[2]} lectures',
                            style: const TextStyle(fontSize: 13, color: gris)),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                const Text('Articles, du plus vu au moins vu',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (lignes.isEmpty) messageVide('Aucun article publié pour le moment.'),
                for (final l in lignes)
                  InkWell(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => PageArticle(article: l.article))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.article.titre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('${l.article.categorie} · ${dateFr(l.article.date)}',
                              style: const TextStyle(fontSize: 12, color: gris)),
                          const SizedBox(height: 5),
                          Text(
                            '${l.stat.vues} vues · ${l.stat.lectures} lectures (${l.stat.taux} %) · '
                            "${l.jaime} j'aime · ${l.stat.jaimepas} je n'aime pas",
                            style: const TextStyle(fontSize: 13, color: vert, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chiffre(String libelle, int n) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text('$n', style: titre(22, couleur: vert)),
            const SizedBox(height: 2),
            Text(libelle,
                textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 11, color: gris)),
          ],
        ),
      ),
    );
  }
}
