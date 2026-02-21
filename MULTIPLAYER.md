# Shadow Hunter — Mode multijoueur en ligne

## Option 1 : Render (serveur cloud, par défaut)

Le serveur tourne sur [render.com](https://render.com). Gratuit, mais **dort après 15 min d'inactivité** — le premier joueur attend ~60 secondes que le serveur se réveille.

**Aucune config requise.** Laissez le champ "Serveur perso" vide dans le lobby.

---

## Option 2 : Serveur local via ngrok (recommandé entre amis)

Pas de mise en veille, pas de cloud. Un joueur fait tourner le serveur sur son PC.

### Étape 1 — Installer ngrok

- Télécharger sur [ngrok.com/download](https://ngrok.com/download)
- Créer un compte gratuit → copier le token d'authent
- Lancer une fois : `ngrok config add-authtoken VOTRE_TOKEN`

### Étape 2 — Lancer le serveur Godot

Depuis le dossier du projet :

```bash
godot --headless --path . res://scenes/server/server_main.tscn
```

Le serveur écoute sur le port **9080**.

### Étape 3 — Exposer avec ngrok

```bash
ngrok tcp 9080
```

ngrok affiche quelque chose comme :
```
Forwarding  tcp://0.tcp.eu.ngrok.io:12345 -> localhost:9080
```

L'URL à partager : **`ws://0.tcp.eu.ngrok.io:12345`**

> Remplacer `tcp://` par `ws://` — ne pas utiliser `wss://` avec ngrok TCP.

### Étape 4 — Se connecter

1. L'hôte (celui qui a lancé le serveur) **ET** les amis ouvrent Shadow Hunter
2. Menu principal → **Jouer en ligne**
3. Dans le champ **"Serveur perso"** en bas du panneau, coller l'URL ngrok
4. L'hôte clique **"Créer une partie"** → note le code de salon affiché
5. Les amis entrent le même code → **"Rejoindre"**
6. Quand tout le monde est là → l'hôte clique **"Lancer la partie"**

### Notes

- L'URL ngrok change à chaque redémarrage (plan gratuit) → la repartager à chaque session
- Le serveur s'arrête quand la fenêtre Godot headless est fermée
- L'hôte-serveur voit toutes les factions dans les logs (acceptable entre amis de confiance)
- 2 à 8 joueurs supportés

---

## Option 3 : Réseau local (LAN)

Sans ngrok, pour jouer sur le même réseau Wi-Fi :

1. Lancer le serveur Godot headless (voir Étape 2 ci-dessus)
2. Trouver l'IP locale de la machine hôte : `ipconfig` (Windows) ou `ip a` (Linux)
3. Dans le champ "Serveur perso" : `ws://192.168.x.x:9080`
4. Même procédure que l'Option 2 ensuite

---

## Résumé

| Scénario | URL à mettre dans "Serveur perso" |
|----------|-----------------------------------|
| Render (défaut) | *(laisser vide)* |
| ngrok | `ws://0.tcp.eu.ngrok.io:XXXXX` |
| Réseau local | `ws://192.168.x.x:9080` |
| Dev local | `ws://localhost:9080` |
