---
description: Prépare un email client en français résumant des commits git récents
argument-hint: [last N commit(s)] | [hash1 hash2 ...]
allowed-tools: Bash, Read, Glob
---

# Client Email Skill

Tu dois rédiger un email en français à l'attention du client, résumant les modifications récentes apportées au site web.

## Arguments reçus

$ARGUMENTS

## Étape 1 — Récupérer les informations git

Détermine quels commits analyser selon les arguments :

- Si les arguments contiennent "last N commit" ou "derniers N commit" : exécute `git log --oneline -N` pour obtenir les N commits les plus récents
- Si les arguments contiennent des hashes de commit spécifiques : utilise ces hashes directement
- Si aucun argument n'est fourni : utilise le dernier commit (`git log --oneline -1`)

Pour chaque commit identifié, exécute :
```
git show --stat --pretty=format:"%H%n%s%n%b" HASH
```

Analyse les messages de commit et les fichiers modifiés pour comprendre ce qui a été développé.

## Étape 2 — Vérifier si staging.md existe

Vérifie si un fichier `staging.md` existe dans le répertoire courant du projet.
- Si oui : ajoute son contenu à la fin du mail
- Si non : aucune section staging ne doit être ajoutée

## Étape 3 — Vérifier les captures d'écran

- Si l'utilisateur a joint des images à son message : compte-les et prévois de les référencer dans le corps de l'email sous la forme "(voir capture_01)", "(voir capture_02)", etc.
- Si aucune image n'est jointe : demande à l'utilisateur "Avez-vous des captures d'écran à joindre à cet email ? Si oui, combien ?"

## Étape 4 — Rédiger l'email en français

### Style de l'email

- Commence par "Bonjour,"
- Résume les modifications en paragraphes courts et naturels
- Regroupe les changements liés ensemble logiquement
- Ton conversationnel, pas trop formel — comme si tu écrivais à un client que tu connais bien
- Évite les listes à puces, utilise des paragraphes fluides
- Place les références captures "(voir capture_XX)" à la fin des paragraphes concernés
- Email concis — pas trop long

### Structure de l'email

```
Bonjour,

[Résumé des modifications développées en paragraphes courts]
[Chaque paragraphe peut se terminer par (voir capture_XX) si pertinent]

[Si staging.md existe — inclure le contenu du fichier staging.md tel quel]

Merci de me faire savoir si tout correspond à vos besoins.

bien cordialement,
gunther
```

### Exemples de formulations

Pour de nouvelles fonctionnalités :
> J'ai développé [description de la fonctionnalité].

Pour des modifications demandées :
> J'ai développé les modifications demandées :
>
> J'ai modifié [description]. (voir capture_01)

Pour demander validation avant mise en production :
> Merci de me faire savoir si vous souhaitez mettre la nouvelle section en ligne sur le véritable site de production.

## Étape 5 — Afficher et copier le résultat

Affiche l'email complet dans ta réponse, prêt à copier-coller.

Ensuite, copie le contenu brut de l'email dans le presse-papiers via Bash :
1. Écris le texte brut de l'email (sans aucun formatage markdown) dans un fichier temporaire
2. Copie ce fichier avec `wl-copy < /tmp/client_email_tmp.txt`
3. Supprime le fichier temporaire
4. Indique à l'utilisateur : "L'email a été copié dans votre presse-papiers."

Si des captures d'écran sont référencées, indique en dessous de l'email :
> **Captures à joindre :** capture_01.png, capture_02.png, ...
