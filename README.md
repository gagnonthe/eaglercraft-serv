# EaglerCraft 1.8 sur Render (EaglerXBungee-ready)

Ce dossier est une base Docker/Render adaptée au fonctionnement réel d'un serveur EaglerCraft 1.8 (proxy EaglerXBungee + WebSocket).

## Comment les serveurs EaglerCraft fonctionnent (résumé)

- EaglerCraft 1.8 côté navigateur se connecte en **WebSocket** au proxy Eagler (`ws://` en local, `wss://` en production).
- Le plugin/proxy recommandé est **EaglerXBungee** (plugin Bungee/Waterfall/FlameCord).
- Render expose un seul port HTTP public, donc il faut écouter sur `0.0.0.0:$PORT`.
- L'URL client doit être en `wss://<ton-service>.onrender.com/...`.

## Ce que tu dois savoir avant

- Render **web service** impose le port via la variable `PORT` (par défaut `10000`).
- Ton serveur doit écouter sur `0.0.0.0:<PORT>`.
- En **plan Free**, pas de disque persistant: les fichiers locaux peuvent être perdus à chaque redéploiement/restart/spin down.
- Sur Render, WebSocket et HTTP passent par le **même port public**.

## Mode gratuit (sans payer l'instance)

Le fichier `render.yaml` est déjà configuré avec `plan: free`.

Important:

- Le service Free se met en veille après ~15 min sans trafic (réveil ~1 min)
- Pas de disque persistant sur Free
- Quota mensuel (heures Free, bande passante, minutes de build)

Pour limiter les coûts:

- N'ajoute pas de méthode de paiement si tu veux éviter toute surfacturation automatique
- Surveille le dashboard Billing Render (usage)
- Évite les redéploiements inutiles et le trafic sortant massif

## Déploiement rapide

1. Mets ton `server.jar` (EaglerXBungee ou autre compatible 1.8) :
   - via `EAGLER_JAR_URL` dans Render (recommandé en Free)
   - ou en l'incluant dans l'image Docker (moins flexible)

### Important: `EaglerXServer.jar` vs serveur exécutable

- Le dépôt `lax1dude/eaglerxserver` fournit surtout des **plugins** (`EaglerXServer.jar`, etc.).
- Un plugin n'est pas un serveur autonome `java -jar`.
- Pour un setup simple, utilise `EAGLER_TEMPLATE_ZIP_URL` avec un template serveur complet.

Valeur prête à l'emploi (template Paper + plugins):

- `EAGLER_TEMPLATE_ZIP_URL=https://github.com/Eaglercraft-Templates/Eaglercraft-Server-Paper/archive/refs/heads/main.zip`

Si tu veux quand même le plugin seul (depuis releases):

- `https://github.com/lax1dude/eaglerxserver/releases/latest`
- Asset principal: `EaglerXServer.jar`

2. Au premier boot, des templates Eagler sont copiés automatiquement si absents:
   - `/data/plugins/EaglercraftXBungee/listeners.yml`
   - `/data/plugins/EaglercraftXBungee/settings.yml`
   - `/data/plugins/EaglercraftXBungee/authservice.yml`

3. Le script `start.sh` remplace automatiquement ces placeholders dans les configs:
   - `__PORT__`
   - `__BIND_HOST__`
   - `__SERVER_NAME__`
   - `__WS_PATH__`
   - `__ALLOWED_ORIGIN__`

4. Pousse ce repo sur GitHub.

5. Sur Render:
   - **New +** -> **Blueprint** (ou Web Service Docker)
   - sélectionne le repo
   - Render lit `render.yaml` automatiquement

6. Vérifie les logs de démarrage.

7. Côté client EaglerCraft, configure ton serveur en:
   - `wss://<nom-du-service>.onrender.com/`
   - ou avec un chemin si tu en utilises un (`EAGLER_WS_PATH`)

## Variables utiles

- `JAVA_OPTS` : mémoire Java (`-Xms512M -Xmx1024M` par défaut)
- `EAGLER_JAR_URL` : URL de téléchargement du jar (obligatoire en pratique sur Free si le jar n'est pas dans l'image)
- `EAGLER_TEMPLATE_ZIP_URL` : URL d'un zip de serveur complet (recommandé pour setup no-code)
- `BIND_HOST` : host d'écoute (défaut `0.0.0.0`)
- `SERVER_NAME` : nom affiché dans la conf template
- `EAGLER_WS_PATH` : chemin websocket public (défaut `/`)
- `EAGLER_ALLOWED_ORIGIN` : placeholder d'origine autorisée si utilisé
- `ACCEPT_EULA` : `true` pour générer `eula.txt` automatiquement
- `MINIMAL_TEMPLATE` : `true` pour retirer les plugins lourds du template (recommandé en Free)

## Dépannage

- Si le service ne démarre pas: vérifie que le jar existe et est valide.
- Si connexion impossible: vérifie que le listener est bien en `0.0.0.0:<PORT>` et que le client utilise `wss://`.
- En Free, les fichiers locaux sont éphémères: privilégie une source externe (URL de jar) ou un service payant si tu veux persister localement.
- Si le plugin régénère ses propres fichiers, adapte les placeholders dans les fichiers sous `/data/plugins/EaglercraftXBungee/`.
- Si tu as `Handshake timed out`, active `MINIMAL_TEMPLATE=true` et attends la fin complète du boot (premier démarrage plus long).

---

Si tu veux, je peux aussi t'ajouter une variante **Velocity (EaglerXVelocity)** en parallèle.
