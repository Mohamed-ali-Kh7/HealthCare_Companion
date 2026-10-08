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

### 1.1 Base de données

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

- API : http://localhost:8080
- Swagger UI : http://localhost:8080/swagger-ui.html (bouton **Authorize** → coller le token reçu au login)
- Tests : `mvn clean verify` (base H2 en mémoire, aucun MySQL requis)

Sous Windows (PowerShell) : `$env:DB_PASSWORD="change_me"` etc. Voir `backend/.env.example`.

### 1.3 Comptes de démonstration (profil `dev`)

| Rôle | Email | Mot de passe |
|---|---|---|
| Admin | `admin@healthcare.local` (ou `ADMIN_EMAIL`) | valeur de `ADMIN_PASSWORD` |
| Patient | `patient@demo.tn` | `Demo12345` |
| Médecin | `doctor@demo.tn` | `Demo12345` |
| Pharmacien | `pharmacist@demo.tn` / `pharmacist2@demo.tn` | `Demo12345` |

Le jeu de démo contient : 8 spécialités, 12 médicaments, un planning médecin (lun-ven), deux pharmacies à Tunis avec
stock, un rendez-vous accepté (le médecin peut donc prescrire et voir le télésuivi) et 7 jours de mesures capteurs.

### 1.4 Application mobile

```bash
cd frontend
flutter create --org com.healthcare --platforms android,ios .   # génère android/ et ios/ (n'écrase pas lib/)
dart run tool/configure_android.dart                            # permissions, HTTP local, rappels, desugaring
flutter pub get
flutter run                                                     # émulateur Android : API sur http://10.0.2.2:8080
```

Sur un téléphone physique, indiquez l'IP de votre PC sur le réseau local :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
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
