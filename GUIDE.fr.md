# Guide rapide — construire, prouver et vérifier CRUCIBLE

> **Note de traduction :** guide court en français. Le texte complet est dans
> [`README.fr.md`](README.fr.md) ; **la version anglaise [`README.md`](README.md) fait foi.**

## Ce qu'il vous faut

- GNAT et GNATprove (publiquement disponibles chez AdaCore ; Alire les installe ensemble).
- Aucun service hébergé, aucun compte. Tout tourne sur votre machine.

## Trois commandes

```sh
# 1. Construire l'édition AGPL
CRUCIBLE_EDITION=agpl gprbuild -P crucible.gpr -p

# 2. Prouver tout le projet (seul résultat acceptable : zéro vérification non prouvée)
gnatprove -P crucible.gpr --level=2 --mode=all --checks-as-errors=on --warnings=error -j0

# 3. Demander au binaire quelle édition il est (MCP, sur stdio)
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"vous","version":"0"}}}' | ./bin/crucible-agpl
```

À l'étape 3, la réponse porte `serverInfo.name` = `crucible-agpl`. Remplacez `agpl` par
`commercial` et vous obtenez l'autre édition depuis la même source.

## Où regarder

- `src/*.ads` — les juges. Chacun : des faits entrent, un verdict sort, aucune E/S. Leurs contrats
  sont la spécification lisible.
- `LICENSE` — AGPL-3.0, le texte non modifié de la Free Software Foundation.
- `CLA.md` et `cla/` — les modèles Harmony non modifiés.

## Ce qu'il faut savoir d'emblée

- **Une preuve dit que le code satisfait le contrat que nous avons écrit, pas que ce contrat est le
  bon.** La distinction compte, et nous ne la gommons pas.
- Chaque cœur est **reprouvé sur une autre machine**, avec un reçu signé là-bas — pas une
  auto-certification sur la machine qui a écrit le code.
- Ce code est produit par un système d'IA et relu par un humain avant publication.

## Questions, ou une erreur repérée

Les tickets sont bienvenus. **Si quelque chose est faux, nous préférons qu'on nous le dise.**
