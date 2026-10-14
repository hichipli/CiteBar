<div align="center">

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Deutsch](README.de.md) · **Français** · [Русский](README.ru.md)

<img src="../Assets.xcassets/AppIcon.appiconset/256.png" alt="Logo de CiteBar" width="112" height="112">

# CiteBar

**Arrêtez de rafraîchir Google Scholar.**<br>
Pour tous ceux qui vérifient leurs citations un peu trop souvent.

[Télécharger](https://github.com/hichipli/CiteBar/releases/latest) · [Site web](https://www.citebar.org/) · `brew install --cask hichipli/tap/citebar`

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](../LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

<img src="../website/assets/demo.gif" alt="Du panneau de la barre des menus au studio Citation Record : la machine à remonter le temps ramenée au jour des 1 000 citations, puis un essai des thèmes Gazette, Certificate et Night" width="420">

</div>

---

## Pourquoi CiteBar ?

Parce que rafraîchir votre profil Google Scholar toutes les vingt minutes ne fait pas avancer la recherche. CiteBar transforme cet onglet de navigateur obsédant en un discret compagnon dans la barre des menus : il vérifie une fois par jour, vous indique quel article vient d'être cité, et se fait oublier le reste du temps.

Idéal pour les chercheurs qui suivent l'impact de leurs publications, les doctorants qui fêtent leurs premières citations, les responsables d'équipe qui suivent tout un laboratoire, et tous ceux qui se sont déjà demandé : « Mon h-index vient-il de bouger ? »

## Démarrage rapide

**Vous voulez simplement utiliser CiteBar ?** Passez les détails techniques, tout est prêt en une minute environ.

1. **Téléchargez la dernière version**
   - Rendez-vous sur [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest).
   - Téléchargez le fichier `CiteBar-x.x.x-universal-[date].dmg`.
   - Ce DMG universel fonctionne aussi bien sur les Mac Apple Silicon que sur les Mac Intel.
   - Vous préférez Homebrew ? `brew install --cask hichipli/tap/citebar` s'occupe des étapes 1 et 2 pour vous.

2. **Installez CiteBar**
   - Ouvrez le DMG.
   - Faites glisser `CiteBar.app` dans `Applications`.
   - Lancez CiteBar depuis `Applications`.

3. **Ajoutez votre profil**
   - Au premier lancement, CiteBar ouvre Add Profiles. Collez-y le lien de votre profil Google Scholar.
   - Vous suivez un laboratoire ou des co-auteurs ? Collez tous leurs liens d'un coup, un par ligne, et rassemblez-les dans un groupe.
   - L'actualisation quotidienne est le réglage par défaut. Google Scholar lui-même se met à jour tous les jours ou tous les deux jours : CiteBar reste donc à jour.

Vous pouvez coller le lien complet du profil ou seulement l'identifiant, c'est-à-dire la valeur `user` dans l'URL :

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

Les versions actuelles sont signées avec un Apple Developer ID et notariées par Apple. macOS peut tout de même afficher la confirmation habituelle au premier lancement d'une app téléchargée sur Internet.

Si vous effectuez une mise à jour depuis la version `1.3.x` ou `1.4.1`, installez une fois manuellement le dernier DMG. Ensuite, les mises à jour automatiques intégrées à l'app fonctionneront normalement.

Un souci lors de l'installation ? Consultez le [guide d'installation](../DISTRIBUTION.md) (en anglais).

## Les fonctionnalités qui comptent

<img src="../website/assets/panel.png" alt="Le panneau de CiteBar : un profil à 1 284 citations, les citations par année, un article tout juste cité, les deux articles qui feraient passer le h-index à 14, deux articles suivis et un groupe de laboratoire avec ses citations cumulées" width="360">

**Le chiffre, avec son contexte**
- Votre nombre de citations s'affiche dans la barre des menus ; cliquez dessus pour ouvrir le panneau
- Citations par année, total de l'année en cours, progression sur 30 jours, h-index et i10-index
- Voyez quel article vient d'être cité, et cliquez pour découvrir qui l'a cité
- Quand votre prochain h-index est à portée de main, voyez précisément quels articles ont besoin de citations, et combien pour chacun
- Suivez des articles précis : marquez-les d'une étoile dans la Papers window pour les garder dans le panneau, avec leurs nouvelles citations en tête des notifications
- Des intitulés de colonnes et des infobulles expliquent chaque chiffre

**Des groupes pour les laboratoires et les collaborateurs**
- Regroupez des profils en laboratoire, en co-auteurs ou en promotion, avec citations cumulées et progression sur 30 jours
- Collez toute une liste de liens Scholar d'un seul coup
- Copiez les liens d'un groupe pour les partager avec vos collègues, qui n'ont plus qu'à les coller dans leur propre CiteBar

**Des notifications qui valent la peine d'être ouvertes**
- Les notifications nomment les articles qui ont gagné des citations
- Les paliers comme 100 ou 1 000 citations, ou un h-index en hausse, ont droit à leur propre message
- Aucun bruit du type « rien n'a changé »

**Un bilan de citations à partager**
- Quatre styles de carte : Record, Night, Gazette (une une de journal, avec un titre rédigé à partir de vos chiffres) et Certificate
- Choisissez ce qu'elle affiche : citations par année, h-index, articles les plus cités ou un seul article, progression sur 7 à 365 jours, et une note
- Partagez (AirDrop, Messages, Mail), copiez ou enregistrez en un clic, depuis le panneau ou depuis le menu ⋯ de n'importe quel profil dans Settings

<img src="../website/assets/card-record.png" alt="Carte Record" width="180"> <img src="../website/assets/card-night.png" alt="Carte Night" width="180"> <img src="../website/assets/card-gazette.png" alt="Carte Gazette" width="180"> <img src="../website/assets/card-certificate.png" alt="Carte Certificate" width="180">

**Une machine à remonter le temps pour votre bilan**
- Faites glisser le curseur le long d'une frise jusqu'à n'importe quel jour et créez la carte de ce jour-là
- Les paliers de citations et les hausses du h-index sont signalés, pour partager un moment qui vous aurait échappé
- Opérationnel dès le premier jour : les paliers antérieurs à l'installation de CiteBar sont datés à partir des totaux annuels de Google Scholar et marqués d'un ~, et chaque jour suivant est enregistré avec précision

**Respectueux et fiable**
- Une seule requête par profil, espacées de deux secondes
- En cas de coupure réseau, nouvel essai automatique ; face aux limites de débit de Google Scholar, CiteBar espace progressivement ses tentatives (de 15 minutes à 4 heures) puis reprend de lui-même
- Refresh Now fonctionne à tout moment
- Mises à jour automatiques via Sparkle

**La confidentialité par défaut**
- Toutes les données restent sur votre Mac
- Aucune télémétrie
- Ni serveur CiteBar, ni compte à créer

**Vos données, où vous voulez**
- Settings › Data indique où se trouvent les données (`~/Library/Application Support/CiteBar/`) et l'espace occupé par chaque partie : historique des citations, listes d'articles et historique des articles
- Conservez l'historique des citations indéfiniment (par défaut), ou pendant 5, 2 ou 1 an
- L'historique des articles, en option, enregistre le nombre de citations de chaque article à chaque changement, pour que les jours passés de la machine à remonter le temps affichent aussi les articles
- Exportez tout (profils, groupes, réglages, historique complet) dans un seul fichier et importez-le sur un nouveau Mac ; l'importation ne fait qu'ajouter, elle ne supprime jamais rien
- Sauvegarde automatique facultative après chaque actualisation vers iCloud Drive ou le dossier de votre choix, comme Google Drive ou Dropbox

**Une expérience macOS native**
- Présence légère dans la barre des menus, modes clair et sombre
- Réglages natifs avec les onglets Profiles, General, Data et About
- Lancement automatique à l'ouverture de session
- Compatible Apple Silicon et Intel

**Assez léger pour tourner en permanence**
- Utilisation du processeur quasi nulle au repos
- Activité réseau minimale, à des intervalles que vous choisissez
- Plus de détails d'implémentation dans les [notes techniques](../TECHNICAL.md) (en anglais)

## Confidentialité

CiteBar lit uniquement les pages de profil Google Scholar accessibles publiquement. Vos réglages et votre historique de citations restent sur votre Mac, dans `~/Library/Application Support/CiteBar/`.

L'app utilise des intervalles d'actualisation prudents, des délais entre les requêtes et un ralentissement après les erreurs, afin de consulter les nombres de citations de manière responsable.

## Aide et documentation du projet

- Installation ou boîtes de dialogue de sécurité de macOS : [guide d'installation](../DISTRIBUTION.md)
- Compiler depuis les sources : [guide de configuration](../SETUP.md)
- Bugs et demandes de fonctionnalités : [GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- Évolutions du projet : [journal des modifications](../CHANGELOG.md)

Cette documentation est rédigée en anglais, mais vous pouvez tout à fait ouvrir une issue en français.

Vous avez une idée, une demande de fonctionnalité encore vague, ou une façon de travailler que CiteBar ne prend pas encore bien en charge ? Ouvrez une issue. Inutile d'arriver avec une proposition aboutie ou une pull request : les retours concrets issus de vraies pratiques de recherche sont précieux en eux-mêmes.

## Développeurs et contributeurs

Vous souhaitez compiler depuis les sources, contribuer au code ou comprendre comment CiteBar fonctionne sous le capot ?

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

Documentation utile du projet (en anglais) :

- [Guide de contribution](../CONTRIBUTING.md)
- [Notes techniques](../TECHNICAL.md)
- [Guide de publication](../RELEASING.md)
- [Gestion des versions](../VERSION_MANAGEMENT.md)

## Licence

CiteBar est distribué sous [licence MIT](../LICENSE).

## Communauté

Merci à toutes celles et ceux qui contribuent à améliorer CiteBar.

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**Conçu avec soin pour la communauté universitaire**

[Télécharger la dernière version](https://github.com/hichipli/CiteBar/releases/latest) | [Signaler un problème](https://github.com/hichipli/CiteBar/issues) | [Contribuer](../CONTRIBUTING.md)

</div>
