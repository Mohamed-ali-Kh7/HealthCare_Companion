package com.healthcare.doctor;

import com.healthcare.common.BaseEntity;
import com.healthcare.speciality.Speciality;
import com.healthcare.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "doctors",
        uniqueConstraints = @UniqueConstraint(name = "uk_doctors_user", columnNames = "user_id"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Doctor extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "first_name", nullable = false, length = 80)
    private String firstName;

    @Column(name = "last_name", nullable = false, length = 80)
    private String lastName;

    @Column(length = 30)
    private String phone;

    @Column(nullable = false, length = 255)
    private String address;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "speciality_id", nullable = false)
    private Speciality speciality;

    @Column(length = 1000)
    private String bio;

    /** Durée d'une consultation : sert de pas pour générer les créneaux. */
    @Column(name = "consultation_duration_minutes", nullable = false)
    private int consultationDurationMinutes = 30;

    /** Absent / indisponible (congé, garde...) : les patients le voient dans la messagerie et peuvent passer par l'assistant. */
    @Column(nullable = false)
    private boolean away = false;

    @Column(name = "away_message", length = 300)
    private String awayMessage;

    /** Date de retour prévue (incluse comme dernier jour d'absence) ; null = jusqu'à nouvel ordre. */
    @Column(name = "away_until")
    private java.time.LocalDate awayUntil;

    public void setAway(boolean away, String message, java.time.LocalDate until) {
        this.away = away;
        this.awayMessage = away ? message : null;
        this.awayUntil = away ? until : null;
    }

    /** Absent ce jour-là : une absence dont la date de fin est passée n'est plus prise en compte. */
    public boolean isAwayOn(java.time.LocalDate day) {
        return away && (awayUntil == null || !day.isAfter(awayUntil));
    }

    public Doctor(User user, String firstName, String lastName, String phone,
                  String address, Speciality speciality) {
        this.user = user;
        this.firstName = firstName;
        this.lastName = lastName;
        this.phone = phone;
        this.address = address;
        this.speciality = speciality;
    }
}
