# 🩺 HealthCare Companion

Plateforme e-santé mobile : patients, médecins, pharmaciens et administrateurs partagent un même parcours de soins
(rendez-vous, ordonnances, carnet de traitement avec rappels, disponibilité des médicaments en pharmacie, télésuivi par capteurs).

```text
Flutter (mobile)  ──HTTP/JSON + JWT──▶  Spring Boot (API REST)  ──JPA/Hibernate──▶  MySQL
```

| Couche | Technologies |
|---|---|
| Mobile | Flutter 3.27+, Dart 3, Material 3, Provider, http, flutter_secure_storage |
| Carte / géoloc. | flutter_map (OpenStreetMap, sans clé API), geolocator |
| Capteurs / rappels | pedometer, sensors_plus, flutter_local_notifications |
| API | Java 17+, Spring Boot 3.5, Spring Web, Data JPA, Security, Validation, springdoc (Swagger) |
| Sécurité | JWT (jjwt 0.12, HS256), BCrypt (coût 12), RBAC (`@PreAuthorize`) |
| Base | MySQL 8 (H2 en mémoire pour les tests) |

---

## 1. Démarrage rapide

### 1.0 Lancer l'application en local (Windows, sans MySQL) : 2 terminaux

La base H2 en mémoire remplace MySQL : rien à installer à part Java, Maven et Flutter.

**Le plus simple : le script `start.ps1`** (à la racine du projet). Faites un clic droit dessus, puis
« Exécuter avec PowerShell ». Ou, dans un terminal :

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Le script trouve Java et Maven, ouvre une fenêtre pour le backend et une pour l'application, puis ouvre
http://localhost:5000 dans le navigateur. Pour arrêter, fermez les deux fenêtres « HealthCare ».

**Ou à la main, dans 2 terminaux :**

**Terminal 1 : backend (Spring Boot)**

```powershell
cd backend

$env:JWT_SECRET="dGVzdC1zZWNyZXQta2V5LWZvci1oZWFsdGhjYXJlLWNvbXBhbmlvbi0yNTY="
$env:ADMIN_PASSWORD="Admin12345"
$env:DB_URL="jdbc:h2:mem:healthcare;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1"
$env:DB_USERNAME="sa"
$env:DB_PASSWORD=""
# Optionnel : assistant santé avec l'IA Claude (sinon mode de secours sans IA)
# $env:ANTHROPIC_API_KEY="votre_clé"

mvn spring-boot:run "-Dspring-boot.run.profiles=dev" "-Dspring-boot.run.useTestClasspath=true"
```

Attendre la ligne `Started HealthcareCompanionApplication`. API : http://localhost:8081

- `-Dspring-boot.run.useTestClasspath=true` est **obligatoire** avec H2. Sans cette option, le démarrage échoue
  avec `Failed to load driver class org.h2.Driver`.
- Si `mvn` n'est pas reconnu, utilisez Maven fourni par l'extension Java de VS Code. Si Java n'est pas trouvé, définissez
  `JAVA_HOME` (ex. `$env:JAVA_HOME="C:\Program Files\Java\jdk-17"`).

**Terminal 2 : application (Flutter web)**

```powershell
cd frontend
flutter pub get
flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8081
```

Attendre `is being served at http://localhost:5000`, puis ouvrir **http://localhost:5000** dans Chrome.
Après une modification du code, rechargez avec **Ctrl+Shift+R**.

**À savoir**

- La base H2 est en mémoire : à chaque redémarrage du backend, les données reviennent à l'état de démo.
- « Port 8081 (ou 5000) already in use » : un ancien serveur tourne encore. Pour l'arrêter :
  ```powershell
  Get-NetTCPConnection -LocalPort 8081 -State Listen | % { Stop-Process -Id $_.OwningProcess -Force }
  ```
- Appels audio/vidéo entre deux comptes : ouvrez deux navigateurs (ou une fenêtre de navigation privée) et autorisez
  le micro et la caméra.
- Tests : `mvn test` dans `backend`, `flutter test` dans `frontend`.

### 1.1 Base de données (MySQL, en production)

```sql
CREATE DATABASE healthcare_companion CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'healthcare_user'@'localhost' IDENTIFIED BY 'change_me';
GRANT ALL PRIVILEGES ON healthcare_companion.* TO 'healthcare_user'@'localhost';
```

Les tables sont créées automatiquement au démarrage (`ddl-auto=update`).

### 1.2 Backend

```bash
cd backend
export DB_PASSWORD=change_me
export JWT_SECRET=$(openssl rand -base64 32)   # clé de 256 bits minimum
export ADMIN_PASSWORD=Admin12345               # crée le compte admin au premier démarrage

# Profil "dev" : logs SQL + comptes de démonstration
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

- API : http://localhost:8081
- Swagger UI : http://localhost:8081/swagger-ui.html (bouton **Authorize** → coller le token reçu au login)
- Tests : `mvn clean verify` (base H2 en mémoire, aucun MySQL requis)

Sous Windows (PowerShell) : `$env:DB_PASSWORD="change_me"` etc. Voir `backend/.env.example`.

### 1.3 Comptes de démonstration (profil `dev`)

| Rôle | Email | Mot de passe |
|---|---|---|
| Admin | `admin@healthcare.local` (ou `ADMIN_EMAIL`) | valeur de `ADMIN_PASSWORD` |
| Patient | `patient@demo.tn` | `Demo12345` |
| Médecin | `doctor@demo.tn` | `Demo12345` |
| Pharmacien | `pharmacist@demo.tn` / `pharmacist2@demo.tn` | `Demo12345` |
| Ambulance conventionnée | `ambulance@demo.tn` / `ambulance2@demo.tn` | `Demo12345` |

Le jeu de démo contient : 8 spécialités, 12 médicaments, un planning médecin (lun-ven), deux pharmacies à Tunis avec
stock, un rendez-vous accepté (le médecin peut donc prescrire et voir le télésuivi) et 7 jours de mesures capteurs.

**Comptes supplémentaires** (même mot de passe `Demo12345`), avec des rendez-vous entre eux pour tester la messagerie,
les appels, les ordonnances et les urgences :

| Médecin | Spécialité | Ville | Patients liés |
|---|---|---|---|
| `dr.mansouri@demo.tn` | Cardiologie | Ariana | patient@demo.tn, patient6 |
| `dr.gharbi@demo.tn` | Dermatologie | La Marsa | patient3, patient5 (en attente) |
| `dr.haddad@demo.tn` | Pédiatrie | Sousse | patient7 |
| `dr.jaziri@demo.tn` | Ophtalmologie | Sfax | patient4 (consultation terminée) |
| `dr.belhadj@demo.tn` | Gynécologie | Bizerte | patient5 |
| `dr.chaabane@demo.tn` | ORL | Nabeul | patient4 |
| `dr.karoui@demo.tn` | Psychiatrie | Tunis | — |
| `dr.zouari@demo.tn` | Médecine générale | Ben Arous | patient5, patient2 (en attente) |
| `dr.nouveau@demo.tn` | Cardiologie | Tunis | compte **en attente de validation** par l'admin |

| Patient | Nom | Particularités |
|---|---|---|
| `patient2@demo.tn` | Youssef Hammami | O+, suivi par doctor@demo.tn, télésuivi |
| `patient3@demo.tn` | Salma Jebali | allergie aux arachides |
| `patient4@demo.tn` | Mohamed Ayari | O- |
| `patient5@demo.tn` | Rania Chebbi | AB-, allergies aspirine et ibuprofène, 3 médecins, télésuivi |
| `patient6@demo.tn` | Ahmed Ferchichi | 68 ans, suivi cardiaque, télésuivi |
| `patient7@demo.tn` | Lina Mejri | enfant (2016), intolérance au lactose |

Pharmaciens `pharmacist3@demo.tn` à `pharmacist8@demo.tn` : Ennasr, La Marsa, Bab Saadoun (**de garde**), El Menzah,
Sousse et Sfax, avec des ruptures et des stocks bas.

### 1.4 Application mobile

```bash
cd frontend
flutter create --org com.healthcare --platforms android,ios .   # génère android/ et ios/ (n'écrase pas lib/)
dart run tool/configure_android.dart                            # permissions, HTTP local, rappels, desugaring
flutter pub get
flutter run                                                     # émulateur Android : API sur http://10.0.2.2:8081
```

Sur un téléphone physique, indiquez l'IP de votre PC sur le réseau local :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8081
```

iOS : ajoutez dans `ios/Runner/Info.plist` les clés `NSLocationWhenInUseUsageDescription` et `NSMotionUsageDescription`.

---

## 2. Architecture du backend (package by feature)

```text
com.healthcare
├── common/          BaseEntity (id + audit), exceptions + GlobalExceptionHandler, PageResponse, Clock, Swagger
├── security/        JwtService, JwtAuthFilter, SecurityConfig, SecurityUser, gestionnaires 401/403
├── bootstrap/       DataSeeder (référentiels, admin, données de démo)
├── auth/            Module 1 : inscription (patient / médecin / pharmacien), login, /me
├── user/            Module 1 : comptes, rôles, activation par l'admin, mot de passe
├── patient/         Module 2 : profils patients
├── appointment/     Module 2 : rendez-vous, créneaux libres, CareAccessService (relation de soin)
├── doctor/          Module 3 : profils médecins, planning hebdomadaire
├── speciality/      Module 3 : référentiel des spécialités
├── medicine/        Module 4 : référentiel central des médicaments
├── prescription/    Module 4 : ordonnances + lignes (PrescriptionItem)
├── medication/      Module 4 : carnet de suivi patient + heures de rappel
├── pharmacy/        Module 5 : officines, stocks, recherche de proximité (Haversine)
├── telemonitoring/  Module 6 : SensorData, séries temporelles, résumés journaliers
└── admin/           Module 6 : tableau de bord de supervision
```

Chaque module contient ses couches : `Entity`, `Repository`, `Service` (logique métier, transactions), `Controller`
(HTTP uniquement), `dto/` (records Java). **Règle d'équipe :** un module n'utilise jamais le repository d'un autre
module, il passe par son service. Seules exceptions : `security/` et `bootstrap/` (infrastructure).

### Modèle des médicaments

```text
Medicine (référentiel, admin) ── unicité (nom, dosage, forme)
   ├── PrescriptionItem   posologie, times_per_day, duration_days, instructions
   ├── Medication         carnet patient : dosage, prises/jour, dates, heures de rappel (créé automatiquement depuis l'ordonnance)
   └── Stock              pharmacie × médicament : quantité, prix (BigDecimal, 3 décimales pour le TND) — unicité (pharmacy, medicine)
```

---

## 3. Sécurité

| Mesure | Mise en œuvre |
|---|---|
| Mots de passe | BCrypt (coût 12), politique 8-72 caractères avec lettre + chiffre (BCrypt tronque au-delà de 72 octets) |
| Authentification | JWT HS256 signé, émetteur vérifié, expiration 24 h ; clé < 256 bits refusée au démarrage |
| Révocation | Le filtre recharge l'utilisateur à chaque requête : désactivation et changement de rôle immédiats |
| Autorisation | Règles d'URL (`/api/admin/**`) + `@PreAuthorize` sur chaque endpoint (défense en profondeur) |
| Accès aux données | L'id de l'utilisateur vient toujours du token, jamais d'un paramètre client |
| Confidentialité médicale | `CareAccessService` : un médecin n'accède au dossier, aux ordonnances et aux capteurs d'un patient que s'il a un rendez-vous avec lui |
| Énumération de comptes | Login : message unique « email ou mot de passe incorrect » ; le statut du compte n'est révélé qu'après un mot de passe correct |
| Comptes professionnels | Médecins et pharmaciens créés désactivés, validés par un administrateur |
| Suppression | Pas de suppression de compte : désactivation (l'historique médical est conservé) |
| Mobile | Token dans `flutter_secure_storage` (Keystore / Keychain), déconnexion automatique sur 401 |
| Secrets | Uniquement via variables d'environnement, jamais dans Git |
| Erreurs | Format unique RFC 9457 (`ProblemDetail`) + `code` stable ; aucune trace d'appel envoyée au client |

> Production : servir l'API en **HTTPS** et retirer `usesCleartextTraffic` du manifeste Android.

---

## 4. Endpoints

Toutes les routes exigent un JWT sauf mention « public ». Documentation interactive complète : Swagger UI.

| Méthode | Endpoint | Accès |
|---|---|---|
| POST | `/api/auth/register/patient` · `/doctor` · `/pharmacist` | public |
| POST | `/api/auth/login` | public |
| GET | `/api/auth/me` | connecté |
| PUT | `/api/users/me/password` | connecté |
| GET / PATCH | `/api/users` · `/api/users/{id}/status` | ADMIN |
| GET / PUT | `/api/patients/me` | PATIENT |
| GET | `/api/patients/my-patients` | DOCTOR |
| GET | `/api/patients/{id}` | DOCTOR (relation de soin), ADMIN |
| GET | `/api/specialities` | public |
| POST / PUT / DELETE | `/api/specialities/**` | ADMIN |
| GET | `/api/doctors?q=&specialityId=` · `/api/doctors/{id}` · `/{id}/availabilities` | connecté |
| GET / PUT | `/api/doctors/me` · `/api/doctors/me/availabilities` | DOCTOR |
| GET | `/api/appointments/slots?doctorId=&date=` | connecté |
| POST · GET `/my` · PUT `/{id}/cancel` | `/api/appointments` | PATIENT |
| GET `/doctor` · PUT `/{id}/accept` `/reject` `/complete` | `/api/appointments` | DOCTOR |
| GET | `/api/appointments` | ADMIN |
| GET | `/api/medicines?q=` · `/api/medicines/{id}` | connecté |
| POST / PUT / DELETE | `/api/medicines/**` | ADMIN |
| POST · GET `/doctor` · GET `/patient/{id}` | `/api/prescriptions` | DOCTOR |
| GET | `/api/prescriptions/my` | PATIENT |
| GET | `/api/prescriptions/{id}` | patient concerné, médecin auteur, ADMIN |
| GET / POST / PUT / DELETE | `/api/medications` | PATIENT |
| GET | `/api/pharmacies/nearby?lat=&lng=&radiusKm=` · `/availability?medicineId=&lat=&lng=` | connecté |
| GET | `/api/pharmacies/{id}` · `/api/pharmacies/{id}/stocks` | connecté |
| GET / PUT | `/api/pharmacies/me` · `/api/pharmacies/me/stocks` (upsert) · `/bulk` · DELETE `/{stockId}` | PHARMACIST |
| POST · GET `/my` · `/my/summary` | `/api/sensor-data` | PATIENT |
| GET | `/api/sensor-data/patients/{id}` · `/summary` | DOCTOR (rendez-vous accepté) |
| GET | `/api/admin/dashboard` | ADMIN |
| POST · GET `/my` · PUT `/{id}/cancel` | `/api/ambulance-requests` (urgence sans validation, transport programmé) | PATIENT |
| GET `/doctor` · PUT `/{id}/take-charge` `/approve` `/reject` | `/api/ambulance-requests` | DOCTOR |
| PUT | `/api/ambulance-requests/{id}/close` | PATIENT, DOCTOR référent |
| GET | `/api/stats/patient` · `/api/stats/doctor` | PATIENT · DOCTOR |
| GET | `/api/messages/conversations` · `/unread-count` | PATIENT, DOCTOR |
| GET / POST | `/api/messages/conversations/{contactId}` (`?beforeId=` / `?afterId=`) | PATIENT, DOCTOR (relation de soin) |
| POST | `/api/messages/conversations/{contactId}/voice` (multipart : `file`, `durationMs`) | PATIENT, DOCTOR (relation de soin) |
| GET | `/api/messages/{id}/audio` | les deux participants |
| PUT | `/api/messages/conversations/{contactId}/read` | PATIENT, DOCTOR |
| WebSocket | `/ws/calls?token=<JWT>` : signalisation des appels audio/vidéo (WebRTC) | PATIENT, DOCTOR |

Écarts assumés par rapport à la conception initiale : `PUT /api/doctors/profile` → `PUT /api/doctors/me` (convention
uniforme `/me`) ; `DELETE /api/users/{id}` → `PATCH /api/users/{id}/status` (désactivation).

---

## 5. Application mobile

```text
lib/
├── main.dart / app.dart     injection des dépendances (Provider) ; espace affiché selon le rôle
├── core/                    ApiClient (HTTP + JWT + erreurs), stockage du token, thème, formats,
│                            géolocalisation, rappels (notifications locales), collecte capteurs
├── models/                  objets métier + fromJson
├── services/                un service par domaine : uniquement des appels REST
├── providers/               AuthProvider (session)
├── widgets/                 composants réutilisables (cartes, graphiques, carte, sélecteur de médicament…)
└── screens/                 auth/ · patient/ · doctor/ · pharmacist/ · admin/ · common/
```

Les écrans ne font jamais d'appel HTTP directement : UI → service → `ApiClient`.

| Espace | Fonctions |
|---|---|
| Patient | recherche de médecins, réservation sur créneaux libres, rendez-vous, ordonnances, carnet + rappels, pharmacies proches (carte), « où trouver ce médicament », télésuivi (podomètre, accéléromètre, pouls) |
| Médecin | planning (accepter / refuser / terminer), patients suivis, dossier patient, rédaction d'ordonnance, graphiques de télésuivi, disponibilités hebdomadaires |
| Pharmacien | inventaire (quantité, prix, ruptures), profil d'officine, géolocalisation, garde |
| Admin | tableau de bord, validation et désactivation des comptes, spécialités, médicaments, supervision des rendez-vous |

**Limites connues** : la collecte des capteurs et l'envoi automatique fonctionnent tant que l'application est ouverte
(un vrai service d'arrière-plan demanderait `workmanager` ou un foreground service Android) ; la fréquence cardiaque est
saisie manuellement car la plupart des téléphones n'ont pas ce capteur ; les rappels quotidiens sont replanifiés à chaque
ouverture du carnet.

---

## 6. Assistant santé 🤖 : questions à tester

L'assistant répond 24 h/24 depuis l'écran 🤖 du patient. Quand le médecin est **absent**, il répond aussi
automatiquement dans la messagerie, environ 3 secondes après le dernier message du patient. Il ne remplace jamais le
médecin : chaque réponse se termine par « 🚨 En cas d'urgence : appelez le SAMU au 190, ou contactez directement votre
médecin ».

Sans clé IA (mode de secours), il reconnaît des **mots-clés en français**. Avec `ANTHROPIC_API_KEY`, il comprend toutes
les questions, y compris en darija.

### 6.1 Symptômes : repos, médicament sans ordonnance avec la dose, quand consulter

| Symptôme | Exemple de question |
|---|---|
| Fièvre | « J'ai de la fièvre à 38.5 depuis hier » |
| Maux de tête | « J'ai mal à la tête depuis ce matin » |
| Rhume, toux | « J'ai le nez bouché et je tousse » |
| Mal de gorge | « J'ai mal à la gorge, j'ai du mal à avaler » |
| Diarrhée | « J'ai la diarrhée depuis 2 jours » |
| Nausées, vomissements | « J'ai envie de vomir » |
| Brûlures d'estomac | « J'ai des brûlures d'estomac après les repas » |
| Mal de dos, courbatures | « J'ai mal au dos » / « J'ai des courbatures » |
| Allergie saisonnière | « J'éternue, j'ai les yeux qui piquent à cause du pollen » |

Deux symptômes dans le même message sont combinés : « J'ai de la fièvre et mal à la tête ».

### 6.2 Urgences : appel au SAMU 190, médecin prévenu en 🔴 priorité élevée

- « J'ai une douleur dans la poitrine qui serre »
- « Je n'arrive pas à respirer »
- « Mon père a perdu connaissance »
- « Sa bouche est déformée, il n'arrive plus à parler » (signes d'AVC)
- « Mon fils fait une convulsion »
- « Je saigne beaucoup »
- « J'ai la gorge qui gonfle après un médicament » (allergie grave)
- « J'ai avalé trop de comprimés »
- « Je veux en finir avec la vie »
- « J'ai eu un accident grave »

### 6.3 Questions pratiques

- Rendez-vous : « Comment prendre un rendez-vous ? »
- Ordonnance : « Je veux renouveler mon ordonnance »
- Pharmacie : « Où trouver ce médicament en pharmacie ? » / « Je veux commander un médicament »
- Message au médecin : bouton ✉️ dans l'écran 🤖. Le message arrive dans la messagerie du médecin.

### 6.4 Scénarios de démonstration

| Compte | Action | Résultat attendu |
|---|---|---|
| `patient@demo.tn` | « J'ai de la fièvre et mal à la tête » | paracétamol et ibuprofène, avec « commencez par le paracétamol » |
| `patient5@demo.tn` (allergique à l'aspirine et à l'ibuprofène) | « J'ai mal à la tête » | paracétamol seulement, avec « allergie notée dans votre dossier » |
| `doctor@demo.tn` se met « Absent », puis `patient@demo.tn` lui écrit | « J'ai de la fièvre » | bulle 🤖 « réponse automatique » dans la conversation |

### 6.5 Sécurité et limites

- Uniquement des médicaments **sans ordonnance** (paracétamol, ibuprofène, antiacide, cétirizine, SRO, sérum
  physiologique), jamais d'antibiotique.
- Le dossier est vérifié : allergies, traitement anticoagulant (pas d'ibuprofène), plus de 65 ans (pas d'ibuprofène),
  enfant (dose selon le poids, avis du pharmacien).
- En mode de secours, le darija et les fautes d'orthographe sont mal reconnus. Un message sans mot-clé reçoit une aide
  générale.

---

## 7. Facturation et paiement (CNAM simulée)

Le paiement en ligne et la prise en charge CNAM sont **simulés** : aucune connexion à une banque ni à la CNAM.
Le code est prêt pour une vraie passerelle (Konnect, Flouci, ClicToPay...) : il suffit de fournir une autre
implémentation de `PaymentGateway`.

### 7.1 Parcours

1. **Médecin** (🧾 Facturation) : les consultations terminées apparaissent dans « Consultations à facturer ». Il choisit
   l'acte, le montant et la prise en charge, puis émet la facture. Le patient est notifié en direct.
2. **Patient** (🧾 Mes factures) : il paie par carte, ou au cabinet (le médecin clique alors « Payée en espèces »).
   Le médecin est notifié du paiement en direct.
3. Chacun télécharge la **facture PDF** et le **bulletin de soins CNAM pré-rempli**. Le QR code imprimé ouvre une page
   publique « Facture authentique ».

### 7.2 Prise en charge CNAM (taux simulé : 70 %, réglable avec `CNAM_RATE_PERCENT`)

| Filière | Le patient paie | Part CNAM |
|---|---|---|
| Sans prise en charge | 100 % | — |
| Filière privée (tiers payant) | 30 % (ticket modérateur) | 70 %, réglés au médecin par la caisse |
| Système de remboursement | 100 % | 70 %, remboursés au patient avec le bulletin de soins |

Le patient renseigne son numéro CNAM dans son profil. Sans ce numéro, seule l'option « Sans prise en charge » est possible.

### 7.3 Cartes de test

| Numéro | Résultat |
|---|---|
| `4242 4242 4242 4242` | Paiement accepté |
| `4000 0000 0000 0002` | Refusé par la banque |
| `4000 0000 0000 9995` | Solde insuffisant |

Toute date d'expiration future (ex : `12/30`) et tout CVV à 3 chiffres. Un numéro qui ne passe pas le contrôle de Luhn
est refusé. La carte n'est jamais enregistrée : seuls les 4 derniers chiffres sont conservés.

### 7.4 Données de démo

- `patient@demo.tn` : une facture **payée** (carte, système de remboursement) et une facture **à payer** (9,000 TND en
  filière privée).
- `doctor@demo.tn` : une consultation de Youssef Hammami **à facturer**.

### 7.5 Endpoints

| Méthode | URL | Rôle |
|---|---|---|
| GET | `/api/billing/acts` | PATIENT, DOCTOR |
| GET | `/api/billing/doctor/summary` · `/doctor/to-invoice` · `/doctor/invoices` | DOCTOR |
| POST | `/api/billing/doctor/invoices` | DOCTOR |
| PUT | `/api/billing/doctor/invoices/{id}/cash` | DOCTOR |
| GET | `/api/billing/my/invoices` | PATIENT |
| POST | `/api/billing/my/invoices/{id}/pay` | PATIENT |
| GET | `/verify/invoice/{token}` (page publique du QR code) | public, jeton signé |

---

## 8. Ambulances conventionnées CNAM

Les sociétés d'ambulance conventionnées réalisent les **transports sanitaires programmés** (dialyse, chimiothérapie,
examens, sortie d'hôpital) validés par le médecin. Les **urgences restent pour le SAMU (190)**.

### 8.1 Parcours

1. **Patient** (🚨 Urgence → Transport programmé) : il demande un transport, le **médecin le valide** (cette
   validation tient lieu de prescription de transport).
2. **Patient** : « Choisir une ambulance ». Il voit les sociétés conventionnées qui desservent l'adresse de prise en
   charge, les plus proches d'abord (distance, véhicules en service, téléphone).
3. **Société** (onglet Missions) : elle **accepte** en affectant un véhicule (avec un message facultatif au patient)
   ou **refuse** (le patient choisit alors une autre société).
4. **Suivi en direct** : la société fait avancer le trajet (En route → Sur place → Patient à bord → Arrivé). Le
   patient, son médecin et la société voient la frise et reçoivent une notification à chaque étape. À l'arrivée, la
   demande est clôturée.
5. **Facturation** : la société facture le transport (ambulance ou VSL) avec la prise en charge CNAM. Le patient le
   paie dans 🧾 Mes factures (même module que les consultations, PDF et QR code compris).

### 8.2 Espace de la société (rôle `AMBULANCE_COMPANY`)

| Onglet | Contenu |
|---|---|
| Missions | Demandes à accepter, transports planifiés, en cours et terminés |
| Flotte | Ambulances et VSL : immatriculation, équipage, en service / hors service |
| Facturation | Revenus, transports à facturer, factures émises, encaissement en espèces |
| Ma société | Coordonnées, position de la base, rayon d'intervention, accepter ou non de nouvelles demandes |

Inscription depuis l'écran « Créer un compte » → **Ambulance** (numéro de convention CNAM obligatoire). Le compte est
actif après **validation par l'administrateur** (Admin → Utilisateurs → Ambulances).

### 8.3 Comptes de démo (mot de passe `Demo12345`)

| Compte | Contenu |
|---|---|
| `ambulance@demo.tn` | Ambulances Ennour (Tunis) : 1 ambulance + 1 VSL, une **mission à accepter** (dialyse d'Amira Ben Salah) et un **transport à facturer** (Youssef Hammami) |
| `ambulance2@demo.tn` | Ariana Secours (Ariana) : 1 ambulance |
| `patient@demo.tn` | Son transport de dialyse validé par le Dr Trabelsi, confié à Ennour |

### 8.4 Endpoints

| Méthode | URL | Rôle |
|---|---|---|
| POST | `/api/auth/register/ambulance-company` | public (compte à valider) |
| GET | `/api/transport/companies/nearby?lat=&lng=` | PATIENT, DOCTOR |
| GET / PUT | `/api/transport/companies/me` | AMBULANCE_COMPANY |
| GET / POST / PUT | `/api/transport/vehicles` · `/vehicles/{id}` · `/vehicles/{id}/service` | AMBULANCE_COMPANY |
| PUT | `/api/ambulance-requests/{id}/company` | PATIENT |
| GET | `/api/ambulance-requests/company` | AMBULANCE_COMPANY |
| PUT | `/api/ambulance-requests/{id}/mission/accept` · `/refuse` · `/advance` | AMBULANCE_COMPANY |
| GET / POST / PUT | `/api/billing/company/summary` · `/to-invoice` · `/invoices` · `/invoices/{id}/cash` | AMBULANCE_COMPANY |

Notifications en direct (WebSocket) : message `transport_mission` au patient, au médecin et à la société.
