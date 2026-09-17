# TP : DevSecOps sur `azure-quiz-frontend`

## Objectif

Vous avez déjà vos propres workflows de build, lint et déploiement (partie précédente du TP). En revanche, **aucun scan de sécurité n'existe encore** : à vous de construire la chaîne complète, en plus de l'existant, sans le casser.

**Ce n'est pas un TP « copier-coller »** : chaque outil ci-dessous doit être choisi, configuré et justifié par vous. Cherchez la doc officielle de chaque outil avant d'écrire le moindre YAML.

## À implémenter

Un workflow GitHub Actions par catégorie.

### 1. SAST (Static Application Security Testing)

Analyse du code source à la recherche de patterns de vulnérabilités connus, **sans exécuter l'application**.

Plusieurs familles d'outils existent, certaines combinant qualité de code et sécurité, d'autres dédiées. Comparez avant de choisir.

### 2. SCA (Software Composition Analysis)

Vos dépendances npm ont-elles des CVE connues ?

Cherchez aussi ce qu'apporte **en plus** un `dependency-review` sur les PR, par rapport à un scan qui vérifie l'état *actuel* du `package-lock.json` à chaque run. Les deux ont un rôle différent.

### 3. Secrets scanning

Détecter une clé ou un token committé par erreur, **dans le diff et dans l'historique git**.

### 4. Container et IaC

Deux choses à couvrir séparément :

- Votre `Dockerfile`, votre chart `helm/` et votre `nginx.conf` contiennent-ils des mauvaises pratiques ? (root par défaut, pas de limites de ressources, filesystem writable, etc.)
- L'image Docker *buildée* a-t-elle des CVE dans ses paquets système ?

### 5. DAST (Dynamic Application Security Testing)

Attaquer l'application *en cours d'exécution* depuis l'extérieur (HTTP), pas le code source.

Réfléchissez à comment servir un build en CI sans backend réel derrière, et à ce que ça peut concrètement détecter dans ce cas. Indice : les headers de réponse.

### 6. Accessibilité

Pas de la sécurité, mais la même logique de « quality gate » automatisée sur chaque PR.

Un lien ou bouton hors de tout landmark sémantique, un contraste insuffisant, une image sans `alt`, etc. Angular Material n'exempte pas de vérifier.

## Points d'attention

À anticiper, pas à découvrir en prod.

**Secrets et Dependabot.** Une PR ouverte par Dependabot (si vous en configurez un) n'a pas accès aux mêmes secrets GitHub Actions qu'une PR normale. Si un de vos scans a besoin d'un token, testez ce cas.

**Deux pistes de déploiement.** Ce dépôt en a deux, Static Web Apps et AKS avec nginx. Un header de sécurité ajouté d'un seul côté ne protège que la moitié des utilisateurs.

**Durcir sans casser.** Un scan de sécurité qui casse l'application pour la « durcir » n'a rien résolu. Tout changement de configuration (Dockerfile, Helm, `nginx.conf`, etc.) doit être testé (build réel, run, requête navigateur) avant d'être considéré comme fini, pas juste « le scan est vert ».

**L'héritage des headers nginx.** Son comportement est moins évident qu'il n'y paraît sur une config à plusieurs `location`. À vérifier avec un vrai test, pas en le supposant.

**Ne pas casser l'existant.** Vérifiez que vos nouveaux workflows ne cassent pas ceux déjà en place : déclencheurs qui se chevauchent, required checks existants, secrets déjà utilisés ailleurs, etc.

## Ne vous arrêtez pas au scan vert

Un scan qui détecte une CVE et qu'on ignore ne sert à rien. Pour chaque vulnérabilité **réelle** trouvée (pas les faux positifs) :

1. **Corrigez-la** : montée de version de dépendance, changement de config, ou réécriture du code concerné selon le cas.
2. **Redéployez sur Azure** (Static Web Apps ou AKS, nonprod) et **revérifiez que l'application fonctionne toujours**, pas seulement que le scan repasse au vert. Un correctif de sécurité qui casse le déploiement n'est pas terminé.

## Livrable

- Le lien vers votre dépôt (GitHub ou GitLab), vers la ou les PR/MR où les workflows ont été ajoutés, et vers un run ou pipeline **vert** pour chaque catégorie. Pas juste « ça marche chez moi », ça doit être vérifiable directement en ligne.
- Un workflow par catégorie dans `.github/workflows/` (ou `.gitlab-ci.yml`), avec un résultat lisible (Job Summary, widget MR ou artifact) sans avoir à fouiller dans les logs bruts.
- Les CVE réelles trouvées et corrigées, avec preuve d'un redéploiement Azure fonctionnel après correction.
- Une capture d'écran du dashboard SonarCloud ou SonarQube de votre projet (Quality Gate, bugs, vulnérabilités, couverture) montrant l'état réel après vos corrections. Pas juste le badge vert dans le README.
- Un README ou CHANGELOG expliquant vos choix d'outils et pourquoi.
- Être capable de répondre à l'oral :
  - « SAST vs DAST, quelle différence ? »
  - « SCA vs dependency-review, pourquoi les deux ? »
  - « Pourquoi l'accessibilité dans une CI de sécurité ? »

## Si vous êtes sur GitLab plutôt que GitHub

Les mêmes 6 catégories s'appliquent. C'est le fond (SAST, SCA, Secrets, Container et IaC, DAST, accessibilité) qui compte, pas la syntaxe YAML précise.

Ce qui change :

**Le format des pipelines.** GitHub Actions devient `.gitlab-ci.yml`, avec `include: template: Jobs/...` pour les scans intégrés.

**Le rendu des résultats.** `$GITHUB_STEP_SUMMARY` n'existe pas côté GitLab. L'équivalent, ce sont les **widgets de sécurité dans la Merge Request**, alimentés par des rapports au format spécifique déclarés en `artifacts: reports:` (`sast`, `dependency_scanning`, `secret_detection`, `container_scanning`, `dast`). Cherchez ce mécanisme avant de réinventer un résumé en texte brut.

L'accessibilité, elle, n'a pas de widget dédié : un job `axe-core` qui échoue reste la seule option, comme côté GitHub.

**Les paliers de licence.** Vérifié sur la doc officielle GitLab, pas une approximation :

| Catégorie | Palier requis |
| --- | --- |
| SAST | Free |
| Secret Detection | Free |
| Container Scanning | Free |
| Dependency Scanning | **Ultimate** |
| DAST | **Ultimate** |

Si votre organisation ou compte GitLab.com est en Free, il faudra construire ces deux derniers vous-mêmes, avec les mêmes outils que la version GitHub (Trivy, OWASP ZAP, etc.), juste appelés depuis `.gitlab-ci.yml` au lieu d'une Action.

## Pour démarrer la recherche

| Ressource | Ce qu'elle couvre |
| --- | --- |
| [OWASP](https://owasp.org) | Catégories SAST, DAST et SCA |
| SonarCloud / SonarQube | SAST et qualité de code, gratuit pour l'open source |
| Trivy (Aqua Security) | Couvre à lui seul plusieurs catégories ci-dessus |
| gitleaks | Secrets scanning |
| OWASP ZAP | DAST |
| axe-core, `@axe-core/cli` | Accessibilité |
| GitHub Actions | Job summaries (`$GITHUB_STEP_SUMMARY`), required status checks, Dependabot secrets vs Actions secrets |
| MDN | `Content-Security-Policy` et en-têtes de sécurité HTTP |
