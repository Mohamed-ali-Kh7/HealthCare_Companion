package com.healthcare.bootstrap;

import com.healthcare.appointment.Appointment;
import com.healthcare.appointment.AppointmentRepository;
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
import java.util.List;
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

        log.info("Données de démo créées (mot de passe commun : app.seed.demo-password) : "
                + "patient@demo.tn, doctor@demo.tn, pharmacist@demo.tn, pharmacist2@demo.tn");
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
