# CRUCIBLE

> **Note de traduction :** ceci est la traduction française de [`README.md`](README.md).
> **La version anglaise fait foi** ; en cas de divergence, c'est elle qui prévaut.

Le noyau de décision prouvé d'une usine qui transformera une spécification écrite en Ada/SPARK
accompagné d'une preuve vérifiée par machine, et qui refusera de livrer ce qu'elle n'aura pas pu
prouver.

**Ce qu'est cette version, sans détour :** elle ne prend pas encore de spécification et ne forge
rien. Elle vous donne les cœurs de décision prouvés de l'usine, que vous pouvez reprouver sur votre
propre matériel plutôt que de nous croire, et une porte MCP dont le seul outil fonctionnel est une
barrière de licence. Aucun binaire précompilé n'est fourni. Les notes de version disent exactement ce
qui est présent et ce qui ne l'est pas.

CRUCIBLE est lui-même écrit comme il construit : les parties qui décident sont des paquetages SPARK
prouvés, et chacune a été produite par l'usine à partir de prose, non écrite à la main.

---

## Les deux gardes

**La preuve.** Un modèle peut proposer. Il n'est jamais cru. C'est `gnatprove` qui tranche, et une
barrière rejette les manières habituelles de simuler un succès — `SPARK_Mode Off`, `Warnings Off`,
un corps supposé, un contrat qui n'énonce rien.

**Le déterminisme.** Un verdict que vous ne pouvez pas reproduire n'est pas un verdict. Les
vérifications rejouées donnent la même réponse, sinon elles ne comptent pas.

---

## Ce que contient le dépôt

| chemin | contenu |
|---|---|
| `src/` | L'Ada. Les juges sont des spécifications en fonctions-expressions : des faits entrent, un verdict sort, aucune E/S. |
| `src/edition-agpl/`, `src/edition-commercial/` | L'édition, compilée dans le binaire — jamais un drapeau d'exécution. |
| `crucible.gpr` | Le fichier de projet. `CRUCIBLE_EDITION` choisit l'édition. |
| `cla/` | Les modèles Harmony non modifiés et la liste des signatures. |

Les juges décident : l'admission en entrée, la décomposition, l'émission des contrats, le verdict du
prouveur, la vacuité, la cohérence des jointures, l'admission, la provenance, l'interface unique et
la licence de l'édition. Chacun est admis hors du poste de travail : reprouvé sur une autre machine,
avec un reçu signé là-bas.

---

## Construire

Les deux éditions se construisent depuis la même source :

```sh
CRUCIBLE_EDITION=agpl       gprbuild -P crucible.gpr -p     # bin/crucible-agpl
CRUCIBLE_EDITION=commercial gprbuild -P crucible.gpr -p     # bin/crucible-commercial
```

Chaque binaire répond au protocole MCP sur stdio et annonce sa propre édition dans le résultat
d'`initialize` : vous savez toujours auquel vous parlez.

## Prouver

```sh
gnatprove -P crucible.gpr --level=2 --mode=all --checks-as-errors=on --warnings=error -j0
```

Zéro vérification non prouvée est le seul résultat qui passe. Ne nous croyez pas sur parole : le
prouveur est celui d'AdaCore, publiquement disponible, et il se moque de savoir qui a écrit le code.

---

## Licence et contributions

CRUCIBLE est sous **AGPL-3.0-or-later** (`LICENSE`, le texte non modifié de la Free Software
Foundation). Une licence commerciale sur la même source est disponible sur demande — voir
`COMMERCIAL-LICENCE.md`. Aucun texte juridique de ce dépôt n'est rédigé par nous.

Les contributions sont bienvenues sous la Harmony Contributor License Agreement v1.0, variante
licence, Outbound Licence Option Five, régie par le droit d'Angleterre et du pays de Galles. C'est
une licence, non une cession : vous gardez votre droit d'auteur et votre contribution reste AGPL.
Voir `CLA.md` et `CONTRIBUTING.md`.

---

## État réel

- **Produit par un système d'IA agentique**, un humain tenant la barrière et lisant avant publication.
- Le refus, par l'édition AGPL, d'émettre sous une autre licence est **une déclaration de licence, pas
  un verrou**. Une seule source, deux licences ; n'importe qui peut construire l'une ou l'autre
  édition. Ce refus dit simplement à un utilisateur honnête ce à quoi il a droit.
- Une preuve établit que le code satisfait le contrat que nous avons écrit. Elle n'établit pas que ce
  contrat soit le bon. Là où nous avons trouvé nos propres contrats en défaut, nous l'avons dit.
