package com.healthcare.bootstrap;

import com.healthcare.appointment.Appointment;
import com.healthcare.ambulance.AmbulanceRequest;
import com.healthcare.ambulance.AmbulanceRequestRepository;
import com.healthcare.appointment.AppointmentRepository;
import com.healthcare.transport.AmbulanceCompany;
import com.healthcare.transport.AmbulanceCompanyRepository;
import com.healthcare.transport.AmbulanceVehicle;
import com.healthcare.transport.AmbulanceVehicleRepository;
import com.healthcare.transport.VehicleType;
import com.healthcare.billing.CareAct;
import com.healthcare.billing.CnamCoverage;
import com.healthcare.billing.Invoice;
import com.healthcare.billing.InvoiceRepository;
import com.healthcare.billing.PaymentMethod;
import com.healthcare.doctor.Doctor;
import com.healthcare.doctor.DoctorAvailability;
import com.healthcare.doctor.DoctorAvailabilityRepository;
import com.healthcare.doctor.DoctorRepository;
import com.healthcare.medicine.Medicine;
import com.healthcare.medicine.MedicineForm;
import com.healthcare.medicine.MedicineRepository;
import com.healthcare.patient.Patient;
import com.healthcare.patient.PatientRepository;
import com.healthcare.pharmacy.Pharmacy;
import com.healthcare.pharmacy.PharmacyRepository;
import com.healthcare.pharmacy.Stock;
import com.healthcare.pharmacy.StockRepository;
import com.healthcare.speciality.Speciality;
import com.healthcare.speciality.SpecialityRepository;
import com.healthcare.journal.SymptomEntry;
import com.healthcare.journal.SymptomEntryRepository;
import com.healthcare.telemonitoring.SensorData;
import com.healthcare.telemonitoring.SensorDataRepository;
import com.healthcare.telemonitoring.SensorType;
import com.healthcare.user.Role;
import com.healthcare.user.User;
import com.healthcare.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * Données initiales au démarrage (idempotent : rien n'est recréé si déjà présent).
 * - toujours : référentiels (spécialités, médicaments) + compte admin si ADMIN_PASSWORD est défini ;
 * - profil dev (app.seed.demo-data=true) : comptes et données de démonstration.
 *
 * Infrastructure de démarrage : accède directement aux repositories (comme security/).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DataSeeder implements ApplicationRunner {

    private static final String DEMO_PATIENT_EMAIL = "patient@demo.tn";

    private final UserRepository userRepository;
    private final SpecialityRepository specialityRepository;
    private final MedicineRepository medicineRepository;
    private final PatientRepository patientRepository;
    private final DoctorRepository doctorRepository;
    private final DoctorAvailabilityRepository availabilityRepository;
    private final PharmacyRepository pharmacyRepository;
    private final StockRepository stockRepository;
    private final AppointmentRepository appointmentRepository;
    private final SensorDataRepository sensorDataRepository;
    private final SymptomEntryRepository symptomEntryRepository;
    private final InvoiceRepository invoiceRepository;
    private final AmbulanceCompanyRepository companyRepository;
    private final AmbulanceVehicleRepository vehicleRepository;
    private final AmbulanceRequestRepository ambulanceRequestRepository;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    @Value("${app.seed.admin-email}")
    private String adminEmail;
    @Value("${app.seed.admin-password:}")
    private String adminPassword;
    @Value("${app.seed.demo-data:false}")
    private boolean demoData;
    @Value("${app.seed.demo-password}")
    private String demoPassword;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        seedSpecialities();
        seedMedicines();
        seedAdmin();
        if (demoData) {
            seedDemoData();
            seedExtraDemoData();
        }
    }

    // ---------------------------------------------------------------- Référentiels

    private void seedSpecialities() {
        if (specialityRepository.count() > 0) {
            return;
        }
        specialityRepository.saveAll(List.of(
                new Speciality("Médecine générale", "Suivi global et premier recours"),
                new Speciality("Cardiologie", "Cœur et système cardiovasculaire"),
                new Speciality("Dermatologie", "Peau, cheveux et ongles"),
                new Speciality("Pédiatrie", "Santé de l'enfant et de l'adolescent"),
                new Speciality("Ophtalmologie", "Yeux et vision"),
                new Speciality("Gynécologie", "Santé de la femme"),
                new Speciality("ORL", "Oreille, nez et gorge"),
                new Speciality("Psychiatrie", "Santé mentale")));
        log.info("Référentiel des spécialités initialisé");
    }

    private void seedMedicines() {
        if (medicineRepository.count() > 0) {
            return;
        }
        String generic = "Générique";
        medicineRepository.saveAll(List.of(
                new Medicine("Paracétamol", "Paracétamol", MedicineForm.TABLET, "500 mg", generic),
                new Medicine("Paracétamol", "Paracétamol", MedicineForm.TABLET, "1000 mg", generic),
                new Medicine("Ibuprofène", "Ibuprofène", MedicineForm.TABLET, "400 mg", generic),
                new Medicine("Amoxicilline", "Amoxicilline", MedicineForm.TABLET, "1 g", generic),
                new Medicine("Amoxicilline", "Amoxicilline", MedicineForm.SYRUP, "250 mg/5 ml", generic),
                new Medicine("Oméprazole", "Oméprazole", MedicineForm.CAPSULE, "20 mg", generic),
                new Medicine("Metformine", "Metformine", MedicineForm.TABLET, "850 mg", generic),
                new Medicine("Amlodipine", "Amlodipine", MedicineForm.TABLET, "5 mg", generic),
                new Medicine("Atorvastatine", "Atorvastatine", MedicineForm.TABLET, "20 mg", generic),
                new Medicine("Salbutamol", "Salbutamol", MedicineForm.INHALER, "100 µg/dose", generic),
                new Medicine("Cétirizine", "Cétirizine", MedicineForm.TABLET, "10 mg", generic),
                new Medicine("Vitamine D3", "Cholécalciférol", MedicineForm.DROPS, "10 000 UI/ml", generic)));
        log.info("Référentiel des médicaments initialisé");
    }

    private void seedAdmin() {
        if (userRepository.existsByRole(Role.ADMIN)) {
            return;
        }
        if (adminPassword == null || adminPassword.isBlank()) {
            log.warn("Aucun administrateur : définissez ADMIN_PASSWORD (et ADMIN_EMAIL) pour en créer un au démarrage");
            return;
        }
        userRepository.save(new User(adminEmail, passwordEncoder.encode(adminPassword), Role.ADMIN, true));
        log.info("Compte administrateur créé : {}", adminEmail);
    }

    // ---------------------------------------------------------------- Démo

    private void seedDemoData() {
        if (userRepository.existsByEmail(DEMO_PATIENT_EMAIL)) {
            return;
        }
        String hash = passwordEncoder.encode(demoPassword);
        Speciality generalMedicine = specialityRepository.findAllByOrderByNameAsc().stream()
                .filter(s -> s.getName().equals("Médecine générale")).findFirst().orElseThrow();

        // Patient
        User patientUser = userRepository.save(new User(DEMO_PATIENT_EMAIL, hash, Role.PATIENT, true));
        Patient patient = new Patient(patientUser, "Amira", "Ben Salah", "+216 20 000 001", LocalDate.of(1995, 4, 12));
        patient.setBloodGroup("A+");
        patient.setAllergies("Pénicilline");
        patient = patientRepository.save(patient);

        // Médecin + planning (lun-ven 09:00-12:00 et 14:00-17:00)
        User doctorUser = userRepository.save(new User("doctor@demo.tn", hash, Role.DOCTOR, true));
        Doctor doctor = doctorRepository.save(new Doctor(doctorUser, "Karim", "Trabelsi", "+216 71 000 002",
                "12 avenue Habib Bourguiba, Tunis", generalMedicine));
        List<DoctorAvailability> week = new ArrayList<>();
        for (DayOfWeek day : List.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY,
                DayOfWeek.THURSDAY, DayOfWeek.FRIDAY)) {
            week.add(new DoctorAvailability(doctor, day, LocalTime.of(9, 0), LocalTime.of(12, 0)));
            week.add(new DoctorAvailability(doctor, day, LocalTime.of(14, 0), LocalTime.of(17, 0)));
        }
        availabilityRepository.saveAll(week);

        // Pharmacies (Tunis) + stocks
        List<Medicine> medicines = medicineRepository.findAll();
        Pharmacy central = createDemoPharmacy("pharmacist@demo.tn", hash, "Pharmacie Centrale (démo)",
                "Rue de Marseille, Tunis", 36.8008, 10.1800);
        Pharmacy lac = createDemoPharmacy("pharmacist2@demo.tn", hash, "Pharmacie du Lac (démo)",
                "Les Berges du Lac, Tunis", 36.8380, 10.2400);
        Random random = new Random(42);
        for (int i = 0; i < medicines.size(); i++) {
            Medicine m = medicines.get(i);
            stockRepository.save(new Stock(central, m, 5 + random.nextInt(50), price(random)));
            if (i % 2 == 0) {
                stockRepository.save(new Stock(lac, m, random.nextInt(20), price(random)));
            }
        }

        // Relation de soin : un rendez-vous passé accepté + un rendez-vous futur en attente
        LocalDate today = LocalDate.now(clock);
        Appointment past = new Appointment(patient, doctor, previousWeekday(today).atTime(10, 0), "Fatigue persistante");
        past.accept();
        appointmentRepository.save(past);
        appointmentRepository.save(new Appointment(patient, doctor, nextWeekday(today).atTime(9, 30),
                "Contrôle de tension"));

        // Télésuivi : 7 jours de pas et de fréquence cardiaque
        ZoneId zone = clock.getZone();
        List<SensorData> readings = new ArrayList<>();
        for (int d = 6; d >= 0; d--) {
            LocalDate day = today.minusDays(d);
            readings.add(new SensorData(patient, SensorType.STEPS, 3000 + random.nextInt(7000),
                    day.atTime(20, 0).atZone(zone).toInstant()));
            for (int h : new int[]{8, 14, 21}) {
                readings.add(new SensorData(patient, SensorType.HEART_RATE, 62 + random.nextInt(25),
                        day.atTime(h, 0).atZone(zone).toInstant()));
            }
        }
        sensorDataRepository.saveAll(readings);

        // Journal de symptômes : 14 jours, épisode de fièvre et de douleur il y a une semaine, en amélioration
        List<SymptomEntry> journal = new ArrayList<>();
        for (int d = 13; d >= 0; d--) {
            if (d == 3 || d == 10) {
                continue; // jours non remplis : le graphique doit le montrer honnêtement
            }
            boolean ill = d >= 5 && d <= 8;
            SymptomEntry e = new SymptomEntry(patient, today.minusDays(d));
            e.update(ill ? 5 + random.nextInt(3) : 1 + random.nextInt(3),
                    ill ? 2 : 3 + random.nextInt(3),
                    ill ? 5.0 + random.nextInt(3) * 0.5 : 6.5 + random.nextInt(4) * 0.5,
                    ill ? 38.0 + random.nextInt(9) / 10.0 : 36.6 + random.nextInt(4) / 10.0,
                    d == 7 ? "Fièvre et courbatures, maux de tête le soir" : null);
            journal.add(e);
        }
        symptomEntryRepository.saveAll(journal);

        log.info("Données de démo créées (mot de passe commun : app.seed.demo-password) : "
                + "patient@demo.tn, doctor@demo.tn, pharmacist@demo.tn, pharmacist2@demo.tn");
    }

    // ---------------------------------------------------------------- Démo étendue (tests manuels)

    private static final List<DayOfWeek> WEEKDAYS = List.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY,
            DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY);

    /**
     * Médecins de chaque spécialité, patients variés, pharmacies dans plusieurs villes et relations de soin
     * entre eux (messagerie, appels, ordonnances, urgences). Ajouté aussi à une base de démo déjà existante.
     * Les patients liés à doctor@demo.tn ont un nom classé après « Ben Salah » : patient@demo.tn reste
     * le premier de sa liste (sur lequel s'appuient les tests).
     */
    private void seedExtraDemoData() {
        if (userRepository.existsByEmail("dr.mansouri@demo.tn")) {
            return;
        }
        String hash = passwordEncoder.encode(demoPassword);
        Map<String, Speciality> specialities = new HashMap<>();
        specialityRepository.findAll().forEach(s -> specialities.put(s.getName(), s));
        Patient amira = patientRepository.findByUserId(
                userRepository.findByEmail(DEMO_PATIENT_EMAIL).orElseThrow().getId()).orElseThrow();
        Doctor karim = doctorRepository.findByUserId(
                userRepository.findByEmail("doctor@demo.tn").orElseThrow().getId()).orElseThrow();

        // --- Médecins (une spécialité chacun, plannings différents)
        Doctor mansouri = createDemoDoctor("dr.mansouri@demo.tn", hash, "Leila", "Mansouri", "+216 71 100 201",
                "15 avenue de la République, Ariana", specialities.get("Cardiologie"),
                "Cardiologue, suivi de l'hypertension et des maladies coronariennes.", 30,
                List.of(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY, DayOfWeek.FRIDAY), LocalTime.of(8, 30), LocalTime.of(12, 30));
        Doctor gharbi = createDemoDoctor("dr.gharbi@demo.tn", hash, "Sami", "Gharbi", "+216 71 100 202",
                "8 rue Taieb Mhiri, La Marsa", specialities.get("Dermatologie"),
                "Dermatologie médicale et esthétique.", 20,
                List.of(DayOfWeek.TUESDAY, DayOfWeek.THURSDAY), LocalTime.of(9, 0), LocalTime.of(13, 0));
        addAvailability(gharbi, List.of(DayOfWeek.TUESDAY, DayOfWeek.THURSDAY), LocalTime.of(15, 0), LocalTime.of(18, 0));
        Doctor haddad = createDemoDoctor("dr.haddad@demo.tn", hash, "Nadia", "Haddad", "+216 73 100 203",
                "Avenue Léopold Sédar Senghor, Sousse", specialities.get("Pédiatrie"),
                "Pédiatre : suivi du nourrisson, vaccinations, maladies infantiles.", 30,
                WEEKDAYS, LocalTime.of(8, 0), LocalTime.of(12, 0));
        Doctor jaziri = createDemoDoctor("dr.jaziri@demo.tn", hash, "Mehdi", "Jaziri", "+216 74 100 204",
                "Route de Tunis km 2, Sfax", specialities.get("Ophtalmologie"),
                "Ophtalmologue : vue, glaucome, cataracte.", 30,
                List.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY),
                LocalTime.of(14, 0), LocalTime.of(18, 0));
        Doctor belhadj = createDemoDoctor("dr.belhadj@demo.tn", hash, "Sonia", "Belhadj", "+216 72 100 205",
                "Boulevard du 7 Novembre, Bizerte", specialities.get("Gynécologie"),
                "Gynécologue-obstétricienne.", 30,
                List.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.THURSDAY), LocalTime.of(9, 0), LocalTime.of(12, 0));
        addAvailability(belhadj, List.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.THURSDAY),
                LocalTime.of(14, 0), LocalTime.of(16, 0));
        Doctor chaabane = createDemoDoctor("dr.chaabane@demo.tn", hash, "Youssef", "Chaabane", "+216 72 100 206",
                "Avenue Habib Thameur, Nabeul", specialities.get("ORL"),
                "ORL : sinusites, audition, ronflement.", 20,
                List.of(DayOfWeek.WEDNESDAY, DayOfWeek.FRIDAY), LocalTime.of(9, 0), LocalTime.of(17, 0));
        createDemoDoctor("dr.karoui@demo.tn", hash, "Ines", "Karoui", "+216 71 100 207",
                "Rue du Lac Biwa, Les Berges du Lac, Tunis", specialities.get("Psychiatrie"),
                "Psychiatre : anxiété, dépression, troubles du sommeil.", 45,
                List.of(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY), LocalTime.of(10, 0), LocalTime.of(16, 0));
        Doctor zouari = createDemoDoctor("dr.zouari@demo.tn", hash, "Hatem", "Zouari", "+216 71 100 208",
                "Avenue de France, Ben Arous", specialities.get("Médecine générale"),
                "Médecin généraliste de famille.", 20,
                WEEKDAYS, LocalTime.of(8, 0), LocalTime.of(13, 0));
        // Compte médecin en attente de validation par l'administrateur (test de l'écran admin)
        User pendingUser = userRepository.save(new User("dr.nouveau@demo.tn", hash, Role.DOCTOR, false));
        doctorRepository.save(new Doctor(pendingUser, "Walid", "Nasri", "+216 71 100 209",
                "Rue de Rome, Tunis", specialities.get("Cardiologie")));

        // --- Patients (âges, groupes sanguins et allergies variés)
        Patient hammami = createDemoPatient("patient2@demo.tn", hash, "Youssef", "Hammami", "+216 22 100 302",
                LocalDate.of(1988, 9, 3), "O+", null);
        Patient jebali = createDemoPatient("patient3@demo.tn", hash, "Salma", "Jebali", "+216 23 100 303",
                LocalDate.of(2001, 1, 21), "B+", "Arachides");
        Patient ayari = createDemoPatient("patient4@demo.tn", hash, "Mohamed", "Ayari", "+216 24 100 304",
                LocalDate.of(1972, 6, 14), "O-", null);
        Patient chebbi = createDemoPatient("patient5@demo.tn", hash, "Rania", "Chebbi", "+216 25 100 305",
                LocalDate.of(1979, 11, 30), "AB-", "Aspirine, Ibuprofène");
        Patient ferchichi = createDemoPatient("patient6@demo.tn", hash, "Ahmed", "Ferchichi", "+216 26 100 306",
                LocalDate.of(1958, 3, 8), "A-", null);
        Patient mejri = createDemoPatient("patient7@demo.tn", hash, "Lina", "Mejri", "+216 27 100 307",
                LocalDate.of(2016, 7, 19), "A+", "Lactose");

        // --- Relations de soin (rendez-vous) : ouvrent messagerie, appels, dossier et ordonnances
        LocalDate today = LocalDate.now(clock);
        acceptedAppointment(hammami, karim, workingDayBefore(today, 3), LocalTime.of(10, 0), "Douleurs lombaires");
        pendingAppointment(jebali, karim, workingDayAfter(today, 2), LocalTime.of(14, 30), "Certificat médical");
        acceptedAppointment(amira, mansouri, workingDayBefore(today, 5), LocalTime.of(9, 0), "Palpitations");
        completedAppointment(ferchichi, mansouri, workingDayBefore(today, 20), LocalTime.of(9, 30),
                "Bilan cardiaque", "ECG normal, contrôle dans 3 mois");
        acceptedAppointment(ferchichi, mansouri, workingDayAfter(today, 4), LocalTime.of(10, 0), "Contrôle tension");
        acceptedAppointment(jebali, gharbi, workingDayBefore(today, 2), LocalTime.of(9, 20), "Eczéma");
        pendingAppointment(chebbi, gharbi, workingDayAfter(today, 3), LocalTime.of(15, 0), "Grain de beauté à vérifier");
        acceptedAppointment(mejri, haddad, workingDayBefore(today, 1), LocalTime.of(8, 30), "Fièvre et toux");
        completedAppointment(ayari, jaziri, workingDayBefore(today, 10), LocalTime.of(15, 0),
                "Baisse de la vue", "Prescription de lunettes");
        acceptedAppointment(chebbi, belhadj, workingDayBefore(today, 6), LocalTime.of(9, 30), "Suivi annuel");
        acceptedAppointment(ayari, chaabane, workingDayBefore(today, 4), LocalTime.of(11, 0), "Sinusite");
        pendingAppointment(hammami, zouari, workingDayAfter(today, 1), LocalTime.of(8, 40), "Vaccin grippe");
        acceptedAppointment(chebbi, zouari, workingDayBefore(today, 2), LocalTime.of(9, 0), "Angine");

        // --- Facturation : une facture réglée, une à payer, une consultation à facturer (Dr Trabelsi)
        amira.setCnamNumber("12345678 / 00");
        patientRepository.save(amira);
        hammami.setCnamNumber("87654321 / 01");
        patientRepository.save(hammami);
        Appointment angine = completedAppointment(amira, karim, workingDayBefore(today, 15), LocalTime.of(9, 0),
                "Angine", "Angine virale, traitement symptomatique");
        Invoice paidInvoice = new Invoice("F-" + today.getYear() + "-000001", angine, CareAct.CONSULTATION,
                new BigDecimal("45.000"), CnamCoverage.REIMBURSEMENT, amira.getCnamNumber(), 70);
        paidInvoice.markPaid(PaymentMethod.CARD, "SIM-DEMO000001", "4242",
                workingDayBefore(today, 15).atTime(10, 0).atZone(clock.getZone()).toInstant());
        invoiceRepository.save(paidInvoice);
        Appointment controle = completedAppointment(amira, karim, workingDayBefore(today, 4), LocalTime.of(11, 0),
                "Contrôle après angine", "Guérison complète");
        invoiceRepository.save(new Invoice("F-" + today.getYear() + "-000002", controle, CareAct.FOLLOW_UP,
                new BigDecimal("30.000"), CnamCoverage.PRIVATE_SECTOR, amira.getCnamNumber(), 70));
        completedAppointment(hammami, karim, workingDayBefore(today, 1), LocalTime.of(16, 0),
                "Douleurs lombaires (suivi)", "Amélioration, kinésithérapie conseillée");

        // --- Ambulances conventionnées : deux sociétés, leur flotte, une mission à accepter et une à facturer
        AmbulanceCompany ennour = createDemoCompany("ambulance@demo.tn", hash, "Ambulances Ennour (démo)",
                "CNAM-AMB-0142", "25 rue de Rome, Tunis", "Tunis", "+216 71 300 401", 36.8040, 10.1790);
        AmbulanceVehicle ennourAmbulance = vehicleRepository.save(new AmbulanceVehicle(ennour, "215 TU 3344",
                VehicleType.AMBULANCE, "Hichem Saidi", "+216 98 300 402"));
        vehicleRepository.save(new AmbulanceVehicle(ennour, "198 TU 7781", VehicleType.VSL, "Mourad Kefi",
                "+216 98 300 403"));
        AmbulanceCompany ariana = createDemoCompany("ambulance2@demo.tn", hash, "Ariana Secours (démo)",
                "CNAM-AMB-0217", "8 avenue Habib Bourguiba, Ariana", "Ariana", "+216 71 300 501", 36.8625, 10.1956);
        vehicleRepository.save(new AmbulanceVehicle(ariana, "201 TU 1203", VehicleType.AMBULANCE, "Nabil Jlassi",
                "+216 98 300 502"));

        // Transport validé par le Dr Trabelsi, confié à Ennour : en attente d'acceptation
        AmbulanceRequest dialyse = AmbulanceRequest.scheduled(amira, karim, 36.8065, 10.1815,
                "12 rue de Marseille, Tunis", "Séance de dialyse au CHU Charles Nicolle",
                workingDayAfter(today, 2).atTime(8, 0));
        dialyse.approve("Transport assis possible, prévoir le retour à 12 h");
        dialyse.assignCompany(ennour, clock.instant());
        ambulanceRequestRepository.save(dialyse);

        // Transport effectué hier par Ennour : à facturer
        AmbulanceRequest kine = AmbulanceRequest.scheduled(hammami, karim, 36.8190, 10.1660,
                "5 rue Ibn Khaldoun, Tunis", "Retour à domicile après kinésithérapie",
                workingDayBefore(today, 1).atTime(17, 30));
        kine.approve(null);
        kine.assignCompany(ennour, clock.instant());
        kine.acceptMission(ennourAmbulance, "Équipe de Hichem", clock.instant());
        for (int step = 0; step < 4; step++) {
            kine.advanceMission(clock.instant());
        }
        ambulanceRequestRepository.save(kine);

        // --- Télésuivi sur 7 jours (graphiques côté patient et côté médecin)
        Random random = new Random(7);
        seedSensors(hammami, random, 6000, 6000);   // actif
        seedSensors(ferchichi, random, 1500, 2500); // peu actif, suivi cardiaque
        seedSensors(chebbi, random, 4000, 4000);

        // --- Pharmacies (plusieurs quartiers et villes, une de garde, ruptures de stock)
        List<Medicine> medicines = medicineRepository.findAll();
        List<Pharmacy> pharmacies = List.of(
                createDemoPharmacy("pharmacist3@demo.tn", hash, "Pharmacie Ennasr (démo)",
                        "Avenue Hédi Nouira, Ennasr 2, Ariana", 36.8606, 10.1647),
                createDemoPharmacy("pharmacist4@demo.tn", hash, "Pharmacie de La Marsa (démo)",
                        "Place du Saf-Saf, La Marsa", 36.8782, 10.3247),
                createDemoPharmacy("pharmacist5@demo.tn", hash, "Pharmacie Bab Saadoun (démo)",
                        "Place Bab Saadoun, Tunis", 36.8070, 10.1650),
                createDemoPharmacy("pharmacist6@demo.tn", hash, "Pharmacie El Menzah (démo)",
                        "Avenue Mohamed V, El Menzah 6", 36.8410, 10.1820),
                createDemoPharmacy("pharmacist7@demo.tn", hash, "Pharmacie Sousse Centre (démo)",
                        "Avenue Habib Bourguiba, Sousse", 35.8256, 10.6411),
                createDemoPharmacy("pharmacist8@demo.tn", hash, "Pharmacie Sfax Médina (démo)",
                        "Rue Bab Jebli, Sfax", 34.7406, 10.7603));
        Pharmacy onDuty = pharmacies.get(2);
        onDuty.setOnDuty(true);
        onDuty.setOpeningHours("24 h/24 (de garde)");
        for (int p = 0; p < pharmacies.size(); p++) {
            for (int i = 0; i < medicines.size(); i++) {
                // Chaque pharmacie a sa propre sélection ; quelques ruptures (0) et stocks bas
                if ((i + p) % 3 == 0) {
                    continue;
                }
                int quantity = (i + p) % 7 == 0 ? 0 : ((i + p) % 5 == 0 ? 3 : 10 + random.nextInt(60));
                stockRepository.save(new Stock(pharmacies.get(p), medicines.get(i), quantity, price(random)));
            }
        }

        log.info("Données de démo étendues créées : dr.*@demo.tn (8 médecins + 1 en attente), "
                + "patient2..patient7@demo.tn, pharmacist3..pharmacist8@demo.tn");
    }

    private Doctor createDemoDoctor(String email, String hash, String firstName, String lastName, String phone,
                                    String address, Speciality speciality, String bio, int consultationMinutes,
                                    List<DayOfWeek> days, LocalTime start, LocalTime end) {
        User user = userRepository.save(new User(email, hash, Role.DOCTOR, true));
        Doctor doctor = new Doctor(user, firstName, lastName, phone, address, speciality);
        doctor.setBio(bio);
        doctor.setConsultationDurationMinutes(consultationMinutes);
        doctor = doctorRepository.save(doctor);
        addAvailability(doctor, days, start, end);
        return doctor;
    }

    private void addAvailability(Doctor doctor, List<DayOfWeek> days, LocalTime start, LocalTime end) {
        availabilityRepository.saveAll(days.stream()
                .map(day -> new DoctorAvailability(doctor, day, start, end))
                .toList());
    }

    private AmbulanceCompany createDemoCompany(String email, String hash, String name, String convention,
                                              String address, String city, String phone, double lat, double lng) {
        User user = userRepository.save(new User(email, hash, Role.AMBULANCE_COMPANY, true));
        return companyRepository.save(new AmbulanceCompany(user, name, convention, address, city, phone, lat, lng));
    }

    private Patient createDemoPatient(String email, String hash, String firstName, String lastName, String phone,
                                      LocalDate birthDate, String bloodGroup, String allergies) {
        User user = userRepository.save(new User(email, hash, Role.PATIENT, true));
        Patient patient = new Patient(user, firstName, lastName, phone, birthDate);
        patient.setBloodGroup(bloodGroup);
        patient.setAllergies(allergies);
        return patientRepository.save(patient);
    }

    private void acceptedAppointment(Patient patient, Doctor doctor, LocalDate day, LocalTime time, String reason) {
        Appointment appointment = new Appointment(patient, doctor, day.atTime(time), reason);
        appointment.accept();
        appointmentRepository.save(appointment);
    }

    private Appointment completedAppointment(Patient patient, Doctor doctor, LocalDate day, LocalTime time,
                                             String reason, String note) {
        Appointment appointment = new Appointment(patient, doctor, day.atTime(time), reason);
        appointment.accept();
        appointment.complete(note);
        return appointmentRepository.save(appointment);
    }

    private void pendingAppointment(Patient patient, Doctor doctor, LocalDate day, LocalTime time, String reason) {
        appointmentRepository.save(new Appointment(patient, doctor, day.atTime(time), reason));
    }

    private void seedSensors(Patient patient, Random random, int minSteps, int stepRange) {
        ZoneId zone = clock.getZone();
        LocalDate today = LocalDate.now(clock);
        List<SensorData> readings = new ArrayList<>();
        for (int d = 6; d >= 0; d--) {
            LocalDate day = today.minusDays(d);
            readings.add(new SensorData(patient, SensorType.STEPS, minSteps + random.nextInt(stepRange),
                    day.atTime(20, 0).atZone(zone).toInstant()));
            for (int h : new int[]{8, 14, 21}) {
                readings.add(new SensorData(patient, SensorType.HEART_RATE, 60 + random.nextInt(30),
                        day.atTime(h, 0).atZone(zone).toInstant()));
            }
        }
        sensorDataRepository.saveAll(readings);
    }

    /** n-ième jour ouvré avant {@code date}. */
    private static LocalDate workingDayBefore(LocalDate date, int n) {
        LocalDate d = date;
        for (int i = 0; i < n; i++) {
            d = previousWeekday(d);
        }
        return d;
    }

    /** n-ième jour ouvré après {@code date}. */
    private static LocalDate workingDayAfter(LocalDate date, int n) {
        LocalDate d = date;
        for (int i = 0; i < n; i++) {
            d = nextWeekday(d);
        }
        return d;
    }

    private Pharmacy createDemoPharmacy(String email, String hash, String name, String address,
                                       double lat, double lng) {
        User user = userRepository.save(new User(email, hash, Role.PHARMACIST, true));
        Pharmacy pharmacy = new Pharmacy(user, name, address, "+216 71 000 100", lat, lng);
        pharmacy.setOpeningHours("Lun-Sam 08:00-20:00");
        return pharmacyRepository.save(pharmacy);
    }

    private static BigDecimal price(Random random) {
        return BigDecimal.valueOf(1500 + random.nextInt(15000), 3); // 1,500 à 16,500 TND
    }

    private static LocalDate previousWeekday(LocalDate date) {
        LocalDate d = date.minusDays(1);
        while (d.getDayOfWeek() == DayOfWeek.SATURDAY || d.getDayOfWeek() == DayOfWeek.SUNDAY) {
            d = d.minusDays(1);
        }
        return d;
    }

    private static LocalDate nextWeekday(LocalDate date) {
        LocalDate d = date.plusDays(1);
        while (d.getDayOfWeek() == DayOfWeek.SATURDAY || d.getDayOfWeek() == DayOfWeek.SUNDAY) {
            d = d.plusDays(1);
        }
        return d;
    }
}
