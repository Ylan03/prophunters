# Modifications Hyltaria

Portage des personnalisations de l'ancienne version (`prophunters.zip`) sur le dépôt actuel.
Ce fichier est exclu du GMA par `pack.ps1` (`*.md`).

## Reprises telles quelles
- `init.lua` : `ph_roundlimit` 10 → 100000 (mapvote auto quasi désactivé), `ph_mapstartwait` 30 → 31.
- `sv_rounds.lua` : durée de manche fixe de 7 minutes.
- `sv_player.lua` : modèle `anon` pour les Hunters, `boxman` pour les autres joueurs.
- `taunts/default.lua` : taunts « Wankil Crazy », « Je suis une voiture », « AH » (catégorie Custom).
- `sv_teams.lua` : 1 seul Hunter, choix manuel Hunters/Props bloqué, rotation = tout le monde
  (spectateurs compris) passe Prop puis un joueur aléatoire devient Hunter.

## Corrections par rapport à l'ancienne version
- `BalanceTeams()` : plus de variable `smallerTeam` indéfinie ; les surplus sont choisis parmi les Hunters ;
  s'il n'y a aucun Hunter, un Prop est désigné.
- Remplacement immédiat du Hunter s'il se déconnecte ou passe spectateur pendant la préparation ou la manche
  (jamais le dernier Prop vivant).
- `SwapTeams()` : plus de `nokill` indéfini (le nouveau Hunter n'est plus tué), plus de message vide,
  protection si aucun joueur.
- Modèles personnalisés précachés ; `SetModel` en double dans `PlayerLoadout` retiré.
- `sv_teams.lua.OLD` non repris (l'original est dans l'historique Git).

## Dépendances externes (non incluses)
- `models/player/anon/anon.mdl`, `models/vinrax/player/boxman_player.mdl`
- `sound/music/ylan03/prophunters/wankil.mp3`, `CarAlarm.mp3`, `AH.mp3`
