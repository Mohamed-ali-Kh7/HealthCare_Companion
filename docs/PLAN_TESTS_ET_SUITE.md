# HealthCare Companion — Plan de test et suite du projet

Ce document décrit :

1. comment vérifier tout ce qui est livré (backend + application Flutter) — **Partie A** ;
2. ce qu'il reste à faire, dans l'ordre, avec un critère de fin pour chaque étape — **Partie B** ;
3. les points de validation (jalons) qui jalonnent la suite, avec leurs critères de passage — **Partie C**.

Un scénario est **réussi** si tous ses résultats attendus sont observés et que `adb logcat -s flutter` n'affiche aucune exception.

**Légende des statuts** : ✅ validé · ◐ partiellement vérifié (la partie manquante est précisée) · ☐ à faire · ⚠ anomalie ouverte. Les statuts indiqués correspondent à la vérification du 15/10/2026 sur émulateur Pixel 9 (Android, API 35) avec backend local MySQL.

### Synthèse au 15/10/2026

| Bloc | ✅ | ◐ | ☐ | ⚠ |
|---|---|---|---|---|
| A1 Tests automatisés | 3 | 0 | 1 | 0 |
| A2 Authentification | 1 | 0 | 7 | 0 |
| A3 Patient | 1 | 3 | 9 | 0 |
| A4 Médecin | 7 | 2 | 2 | 0 |
| A5 Pharmacien | 1 | 2 | 3 | 0 |
| A6 Administrateur | 1 | 1 | 4 | 0 |
| A7 Sécurité | 0 | 0 | 5 | 0 |
| A8 Robustesse | 1 | 0 | 3 | 0 |
| Points connus | — | — | — | 1 (carte grise) |

---

## Partie A — Plan de test de l'existant

### A0. Préparation de l'environnement

| Étape | Commande / action | Attendu |
|---|---|---|
| Backend | `cd backend` puis `mvn spring-boot:run "-Dspring-boot.run.profiles=dev"` | Démarre sur le port 8081 ; Swagger sur http://localhost:8081/swagger-ui.html |
| Émulateur | `flutter emulators --launch Pixel_9` | `flutter devices` liste `emulator-5554` |
| GPS à Tunis | `adb emu geo fix 10.1815 36.8065` | Sans cela l'émulateur est en Californie : aucune pharmacie proche |
| Internet émulateur | Ouvrir Chrome dans l'émulateur sur un site quelconque | La page s'affiche (requis pour les tuiles OpenStreetMap) |
| Application | `cd frontend` puis `flutter run` | Écran de connexion |

**Repartir de données propres** : les scénarios modifient la base (rendez-vous acceptés, ordonnances…). Pour rejouer la campagne depuis zéro, lancer le profil `h2` après avoir supprimé `backend/data/`, ou vider la base MySQL `healthcare_companion`. Le `DataSeeder` recrée alors les comptes et données de démo.

**Changer de compte sans passer par l'interface** : `adb shell pm clear com.healthcare.healthcare_companion` (efface le jeton et les permissions).

Comptes de démo (mot de passe `Demo12345`) :

| Compte | Rôle | Données utiles |
|---|---|---|
| `patient@demo.tn` | Patient | Amira Ben Salah, allergie pénicilline, 7 jours de mesures capteurs |
| `doctor@demo.tn` | Médecin | Dr Karim Trabelsi, médecine générale, lun–ven 9h–12h / 14h–17h |
| `pharmacist@demo.tn` | Pharmacien | Pharmacie Centrale, ~650 m du centre de Tunis, stock complet |
| `pharmacist2@demo.tn` | Pharmacien | Pharmacie du Lac, ~6 km, un médicament sur deux |
| `admin@healthcare.local` | Admin | Mot de passe = `ADMIN_PASSWORD` de `backend/.env` |

Le seeder crée un RDV **accepté** (jour ouvré précédent) et un RDV **en attente** (jour ouvré suivant) entre le patient et le médecin.

### A1. Tests automatisés

| # | Commande | Attendu | Statut |
|---|---|---|---|
| A1.1 | `cd backend && mvn clean verify` | 12 tests d'intégration verts (`AuthAndSecurityTest` : 8, `CareJourneyTest` : 4) | ☐ à rejouer après les correctifs frontend |
| A1.2 | `cd frontend && flutter analyze` | `No issues found!` | ✅ |
| A1.3 | `cd frontend && flutter test` | 4 tests verts (validateurs, ProblemDetail, formats) | ✅ |
| A1.4 | `cd frontend && flutter build apk --debug` | `Built build\app\outputs\flutter-apk\app-debug.apk` | ✅ |

### A2. Authentification et inscription

| # | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| A2.1 | Connexion valide | Se connecter avec chaque compte de démo | Ouverture de l'espace du rôle (onglets propres au rôle) | ✅ patient, médecin, pharmacien, admin |
| A2.2 | Mauvais mot de passe | `patient@demo.tn` / `Faux12345` | Message « identifiants invalides », pas de détail sur l'existence du compte | ☐ |
| A2.3 | Inscription patient | « Créer un compte » → Patient → formulaire complet | Compte créé et connecté directement (201 + jeton) | ☐ |
| A2.4 | Inscription médecin | Rôle Médecin, choisir une spécialité | Message « compte en attente de validation » ; la connexion renvoie « compte désactivé » | ☐ |
| A2.5 | Validation du formulaire | Mot de passe `abc` ; email déjà utilisé | Erreur champ par champ ; `EMAIL_ALREADY_USED` affiché proprement | ☐ |
| A2.6 | Persistance de session | Se connecter, tuer l'app, la relancer | Retour direct dans l'espace, sans reconnexion | ☐ |
| A2.7 | Déconnexion | Icône profil → Déconnexion | Retour à l'écran de connexion ; relancer l'app ne reconnecte pas | ☐ |
| A2.8 | Changement de mot de passe | Profil → Mot de passe | Succès ; l'ancien mot de passe ne fonctionne plus | ☐ |

### A3. Parcours patient

| # | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| A3.1 | Recherche médecin | Onglet Médecins, taper « Kar », filtrer par spécialité | Liste filtrée ; Dr Trabelsi visible sous « Médecine générale » | ◐ liste et filtres affichés ; recherche texte non testée |
| A3.2 | Créneaux libres | Ouvrir le médecin, choisir un jour ouvré futur | Créneaux 9h–12h et 14h–17h découpés selon la durée de consultation, sans les créneaux pris | ☐ |
| A3.3 | Réservation | Choisir un créneau, motif, valider | RDV « En attente » dans l'onglet Rendez-vous | ☐ |
| A3.4 | Double réservation | Réserver le même créneau depuis un 2ᵉ patient | Refus `SLOT_UNAVAILABLE` | ☐ |
| A3.5 | Annulation | Annuler un RDV futur | Statut « Annulé » ; le bouton n'existe pas sur un RDV passé | ☐ |
| A3.6 | Carnet | Onglet Traitements → Ajouter un médicament manuellement | Ligne ajoutée avec heures de rappel ; notification reçue à l'heure prévue | ☐ |
| A3.7 | Ordonnances | Traitements → Ordonnances → ouvrir une ordonnance | Détail : médicaments, posologie, durée, notes du médecin | ◐ ordonnance visible dans la liste ; détail non ouvert |
| A3.8 | Pharmacies proches | Onglet Pharmacies, rayons 2 / 5 / 10 / 20 km | 5 km : Pharmacie Centrale (~650 m) ; 10 km : + Pharmacie du Lac ; carte avec tuiles OSM | ◐ liste et distance OK à 5 km ; tuiles grises (voir Points connus) ; 10/20 km non testés |
| A3.9 | Disponibilité médicament | « Trouver un médicament » → Cétirizine | Pharmacies qui l'ont en stock, avec prix en TND (3 décimales) et distance | ☐ |
| A3.10 | Santé | Onglet Santé | Graphiques pas et fréquence cardiaque sur 7 jours, axes lisibles | ✅ après correctif `e35f432` |
| A3.11 | Saisie pouls | « Saisir mon pouls » → 72 puis 400 | 72 accepté et visible ; 400 refusé (hors bornes) | ☐ |
| A3.12 | Collecte auto | Activer la collecte, marcher (ou `adb emu sensor set acceleration …`), Synchroniser | Envoi sans doublon ; un second envoi identique ne crée rien | ☐ |
| A3.13 | Profil | Modifier téléphone, groupe sanguin, allergies | Valeurs enregistrées et visibles par le médecin traitant | ☐ |

### A4. Parcours médecin

| # | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| A4.1 | Demandes | Planning → En attente | Toutes les demandes ouvertes, **y compris celles dont la date est passée** | ✅ après correctif `c1fbf72` |
| A4.2 | Accepter / refuser | Accepter une demande ; en refuser une autre avec un motif | Statuts mis à jour, message de confirmation, aucune exception dans les logs | ◐ acceptation OK (correctif `2c9ee0b`) ; refus non testé |
| A4.3 | Terminer | Accepté → Terminer avec compte rendu | Passe en « Terminé » | ✅ |
| A4.4 | Transition invalide | Via Swagger : `PUT /api/appointments/{id}/accept` sur un RDV terminé | 422 `INVALID_STATUS_TRANSITION` | ☐ |
| A4.5 | Mes patients | Onglet Patients | Seuls les patients ayant un RDV avec ce médecin | ✅ |
| A4.6 | Dossier | Ouvrir le patient | Coordonnées, groupe sanguin, allergies | ✅ |
| A4.7 | Prescription | Prescrire → Cétirizine, 2 prises/jour, 7 jours → Émettre | Bandeau allergie visible ; « Ordonnance enregistrée » | ✅ |
| A4.8 | Effet côté patient | Se connecter en patient → Traitements | Cétirizine « En cours », 2 fois/jour, rappels 08:00 et 20:00, du jour J à J+6 | ✅ (déclenchement réel de la notification : voir A3.6) |
| A4.9 | Télésuivi | Dossier → Télésuivi | Graphiques du patient (accès seulement avec RDV accepté ou terminé) | ✅ affichage ; la restriction d'accès est couverte par A7.3 |
| A4.10 | Disponibilités | Ajouter un créneau samedi 9h–12h, en supprimer un | Les créneaux libres côté patient reflètent le changement | ◐ planning hebdomadaire affiché ; ajout/suppression non testés |
| A4.11 | Profil médecin | Changer la durée de consultation (15 → 30 min) | Les créneaux côté patient sont redécoupés | ☐ |

### A5. Parcours pharmacien

| # | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| A5.1 | Stock | Onglet Stock, filtrer « amox » | Liste filtrée, quantités, prix, date de mise à jour | ◐ liste, prix TND à 3 décimales et dates OK ; filtre non testé |
| A5.2 | Modifier une ligne | Cétirizine → +2 → Enregistrer | Quantité +2, date « Màj » actualisée | ✅ 35 → 37 |
| A5.3 | Référencer | Référencer un médicament absent du stock | Nouvelle ligne ; visible dans « Trouver un médicament » côté patient | ☐ |
| A5.4 | Rupture | Mettre une quantité à 0 | Badge « Rupture » ; la pharmacie disparaît des résultats de disponibilité | ☐ |
| A5.5 | Officine | Mon officine → Pharmacie de garde = oui → Enregistrer | Marqueur rouge sur la carte patient | ☐ |
| A5.6 | Position | « Utiliser ma position actuelle » | Coordonnées mises à jour, carte recentrée | ◐ formulaire et coordonnées affichés ; carte grise, bouton non testé |

### A6. Parcours administrateur

| # | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| A6.1 | Tableau de bord | Onglet Supervision | Compteurs cohérents (total utilisateurs = somme par rôle) | ✅ |
| A6.2 | Validation médecin | Après A2.4 : Comptes → À valider → activer | Le médecin peut se connecter et apparaît dans la recherche patient | ☐ |
| A6.3 | Désactivation | Désactiver le compte pharmacien | Sa session ouverte est rejetée à la requête suivante (révocation immédiate) | ☐ |
| A6.4 | Spécialités | Ajouter, puis supprimer une spécialité inutilisée | OK ; doublon refusé (409 `SPECIALITY_ALREADY_EXISTS`) ; suppression d'une spécialité utilisée refusée (409 `SPECIALITY_IN_USE`) | ◐ liste affichée ; ajout/suppression non testés |
| A6.5 | Médicaments | Ajouter un médicament ; doublon (nom, dosage, forme) ; supprimer un médicament prescrit | Ajout OK ; doublon refusé (409 `MEDICINE_ALREADY_EXISTS`) ; suppression refusée (409 `MEDICINE_IN_USE`) | ☐ |
| A6.6 | Rendez-vous | Onglet Rendez-vous, filtres par statut | Tous les RDV de la plateforme, filtrés correctement | ☐ |

### A7. Sécurité (via Swagger ou curl)


| # | Scénario | Résultat attendu | Statut |
|---|---|---|---|
| A7.1 | Appel sans jeton à `/api/patients/me` | 401 | ☐ |
| A7.2 | Jeton patient sur `/api/admin/dashboard` | 403 `ACCESS_DENIED` | ☐ |
| A7.3 | Médecin sur `/api/patients/{id}` d'un patient sans RDV commun | 403 | ☐ |
| A7.4 | Jeton expiré ou modifié | 401 avec code `TOKEN_EXPIRED` / `TOKEN_INVALID` ; l'app revient à l'écran de connexion | ☐ |
| A7.5 | Pharmacien qui modifie le stock d'une autre pharmacie | Impossible : l'API n'utilise que l'identité du jeton | ☐ |

### A8. Robustesse

| # | Scénario | Résultat attendu | Statut |
|---|---|---|---|
| A8.1 | Couper le backend pendant l'utilisation | Écran d'erreur avec « Réessayer », pas de plantage | ☐ |
| A8.2 | Refuser la localisation | Bandeau « Localisation indisponible : résultats autour du centre de Tunis » | ✅ |
| A8.3 | Refuser les notifications | Le carnet fonctionne, sans rappels | ☐ |
| A8.4 | Rotation de l'écran / mode sombre | Mise en page correcte | ☐ |

### A9. Parcours de bout en bout (ordre d'exécution conseillé)

Pour dérouler la campagne en une session, sur une base propre, en limitant les changements de compte. Chaque étape renvoie aux scénarios détaillés ci-dessus.

| Étape | Compte | Actions | Scénarios couverts |
|---|---|---|---|
| 1 | — | Tests automatisés, build APK | A1.1 → A1.4 |
| 2 | non connecté | Mauvais mot de passe ; inscription d'un 2ᵉ patient ; inscription d'un médecin (reste en attente) | A2.2, A2.3, A2.4, A2.5 |
| 3 | `patient@demo.tn` | Recherche médecin → réservation → annulation d'un RDV ; carnet manuel ; profil ; santé, saisie pouls ; pharmacies et disponibilité ; tuer et relancer l'app | A2.6, A3.1 → A3.13 (sauf A3.4) |
| 4 | 2ᵉ patient (étape 2) | Réserver le créneau déjà pris à l'étape 3 | A3.4 |
| 5 | `doctor@demo.tn` | Refuser une demande, accepter l'autre ; terminer ; dossier ; prescrire ; télésuivi ; disponibilités ; durée de consultation | A4.1 → A4.3, A4.5 → A4.7, A4.9 → A4.11 |
| 6 | `patient@demo.tn` | Vérifier le traitement créé par l'ordonnance et les nouveaux créneaux | A3.7, A4.8 |
| 7 | `pharmacist@demo.tn` | Filtre, modification, référencement, rupture, pharmacie de garde, position | A5.1 → A5.6 |
| 8 | `patient@demo.tn` | Vérifier la rupture et le marqueur rouge sur la carte | A5.3 → A5.5 (côté patient) |
| 9 | `admin@healthcare.local` | Tableau de bord ; valider le médecin de l'étape 2 ; désactiver `pharmacist2` ; référentiels ; RDV | A6.1 → A6.6 |
| 10 | Swagger / curl | Contrôles d'accès, transition invalide | A4.4, A7.1 → A7.5 |
| 11 | tous | Couper le backend, refuser les permissions, rotation, mode sombre ; changement de mot de passe et déconnexion en dernier | A2.7, A2.8, A8.1 → A8.4 |

### Points connus

- **Carte grise (tuiles OSM non chargées)** sur l'émulateur depuis le 15/10, alors qu'elle s'affichait le 10/10 avec le même code. Vérifier d'abord la connexion internet de l'émulateur (A0) ; si Chrome charge les pages et que la carte reste grise, ouvrir un ticket côté application.
- La validation d'un médecin par l'admin (A6.2) crée un compte réel : les comptes ne sont pas supprimables, à faire sur une base de test.

---

## Partie B — Suite du projet

Ordre proposé, du plus utile pour la démonstration au plus optionnel. Chaque étape suit la règle d'équipe : **backend d'abord** (entité → repository → service → contrôleur → DTO → tests), **puis Flutter**, validation entre chaque fichier.

### B1. Refresh token *(priorité haute)*

**Pourquoi** : aujourd'hui la session expire au bout de 24 h et l'utilisateur doit se reconnecter.

| Étape | Contenu |
|---|---|
| Backend | Entité `RefreshToken` (jeton aléatoire stocké **haché**, utilisateur, expiration 30 j, révoqué) ; `RefreshTokenService` (émission, **rotation** à chaque usage, détection de réutilisation → révocation de toute la famille) ; `POST /api/auth/refresh` et `POST /api/auth/logout` ; jeton d'accès raccourci à 15 min |
| Tests backend | Refresh valide ; jeton réutilisé → 401 et famille révoquée ; jeton expiré ; compte désactivé entre-temps |
| Flutter | `TokenStorage` stocke les deux jetons ; `ApiClient` intercepte le 401 `TOKEN_EXPIRED`, appelle `/refresh` une seule fois (verrou pour les requêtes concurrentes) puis rejoue la requête ; déconnexion si le refresh échoue |
| Fin quand | Une session reste ouverte plus de 15 min sans reconnexion ; scénarios A7.4 et A6.3 toujours valides |

### B2. Envoi des capteurs en arrière-plan *(priorité moyenne)*

| Étape | Contenu |
|---|---|
| Flutter | `workmanager` : tâche périodique (15 min, minimum Android) qui lit le podomètre et appelle `POST /api/sensor-data` ; file locale des mesures non envoyées en cas d'échec réseau |
| Android | Permissions et déclaration du worker ; optionnel : service de premier plan pour la collecte continue |
| Fin quand | Application fermée pendant 1 h → mesures visibles côté médecin ; aucun doublon (idempotence déjà assurée par le backend) |

### B3. Validation complète de la campagne A *(avant la démo)*

| Étape | Contenu |
|---|---|
| Exécution | Dérouler A1 → A8 sur une base propre, cocher chaque case |
| Correctifs | Un commit par anomalie, comme pour les trois correctifs du 16/10 |
| Fin quand | Toutes les cases cochées ou anomalies documentées |

### B4. HTTPS pour la démonstration finale *(avant la démo)*

| Étape | Contenu |
|---|---|
| Backend | Certificat (auto-signé en local ou reverse proxy), `server.ssl.*` ou proxy Caddy/Nginx |
| Flutter | `API_BASE_URL` en `https://…` via `--dart-define` ; retirer `android:usesCleartextTraffic="true"` du manifeste |
| Fin quand | L'application fonctionne sans trafic en clair |

### B5. Livrables académiques

| Étape | Contenu |
|---|---|
| Documentation | README à jour (installation, comptes de démo, captures) ; mise à jour du document d'avancement avec le frontend |
| Démo | Script de démonstration de 10 min : patient réserve → médecin accepte et prescrit → rappel → pharmacie trouvée sur la carte → admin supervise |
| Fin quand | Démo répétée de bout en bout sans accroc sur une base fraîche |

### Calendrier indicatif

| Étape | Charge estimée |
|---|---|
| B1 Refresh token | 1 à 1,5 jour |
| B2 Capteurs en arrière-plan | 1 jour |
| B3 Campagne de tests | 0,5 à 1 jour |
| B4 HTTPS | 0,5 jour |
| B5 Livrables | 0,5 à 1 jour |

---

## Partie C — Points de validation

Chaque jalon est un point d'arrêt : on ne passe au suivant qu'une fois ses critères atteints et la preuve fournie. Un jalon non atteint est reporté avec la liste des écarts, jamais validé partiellement.

| Jalon | Contenu | Critères de passage | Preuve attendue | Statut |
|---|---|---|---|---|
| **V0 — Socle livré** | Backend complet, application Flutter compilée et lancée sur émulateur, 4 espaces accessibles | A1.2 → A1.4 verts ; A2.1 validé pour les 4 rôles ; correctifs du 16/10 poussés | Commits `8d2d869`, `2c9ee0b`, `c1fbf72`, `e35f432` sur `main` | ✅ 16/10/2026 |
| **V1 — Campagne de recette** | Partie A déroulée intégralement (parcours A9) | Toutes les cases ✅ ; chaque anomalie corrigée par un commit dédié ou documentée dans « Points connus » ; carte OSM résolue ou expliquée ; A1.1 rejoué vert | Plan coché, captures des écrans clés, liste des commits correctifs | ☐ |
| **V2 — Session durable** | B1 Refresh token | Backend : nouveaux tests d'intégration verts, `mvn clean verify` vert ; Flutter : session ouverte > 15 min sans reconnexion ; jeton rejoué → déconnexion ; A6.3 et A7.4 toujours valides | Sortie `mvn verify`, démonstration du renouvellement (logs ou Swagger) | ☐ |
| **V3 — Télésuivi autonome** | B2 Capteurs en arrière-plan | Application fermée 1 h → mesures visibles dans le télésuivi médecin ; coupure réseau puis retour → mesures envoyées sans doublon | Graphique côté médecin, horodatage des mesures | ☐ |
| **V4 — Prêt pour la démo** | B4 HTTPS + rejeu de A9 sur base fraîche | Aucun trafic en clair (`usesCleartextTraffic` retiré) ; A9 rejoué sans anomalie après B1, B2, B4 (non-régression) | APK de démonstration, plan recoché | ☐ |
| **V5 — Validation finale** | B5 Livrables | README et document d'avancement à jour ; démo de 10 min répétée de bout en bout sans accroc | Document d'avancement, script de démo, enregistrement ou répétition devant l'équipe | ☐ |

**Règles communes à tous les jalons** :

- `flutter analyze` sans avertissement et `mvn clean verify` vert avant toute demande de validation ;
- aucun secret dans le dépôt (`backend/.env` reste ignoré) ;
- chaque nouvel endpoint protégé par rôle et couvert par au moins un test d'intégration ;
- un commit par correctif ou fonctionnalité, poussé sur `main` après validation.
