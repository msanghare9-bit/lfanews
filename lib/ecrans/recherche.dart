import 'package:flutter/material.dart';

import '../modeles.dart';
import '../theme.dart';
import '../widgets.dart';
import 'article.dart';

class Recherche extends StatefulWidget {
  const Recherche({super.key, required this.articles});
  final List<Article> articles;

  @override
  State<Recherche> createState() => _RechercheState();
}

class _RechercheState extends State<Recherche> {
  String _texte = '';

  @override
  Widget build(BuildContext context) {
    final q = _texte.trim().toLowerCase();
    final resultats = q.isEmpty
        ? <Article>[]
        : widget.articles
            .where((a) => '${a.titre} ${a.texte} ${a.personne} ${a.categorie}'.toLowerCase().contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Rechercher', style: titre(22, couleur: Colors.white))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 4),
          TextField(
            onChanged: (v) => setState(() => _texte = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Un mot, un nom, une rubrique…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          if (q.isNotEmpty && resultats.isEmpty) messageVide('Aucun article ne correspond à « $_texte ».'),
          for (final a in resultats)
            LigneArticle(
              article: a,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => PageArticle(article: a))),
            ),
        ],
      ),
    );
  }
}
