package com.healthcare.patient;

import com.healthcare.common.BaseEntity;
import com.healthcare.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "patients",
        uniqueConstraints = @UniqueConstraint(name = "uk_patients_user", columnNames = "user_id"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Patient extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "first_name", nullable = false, length = 80)
    private String firstName;

    @Column(name = "last_name", nullable = false, length = 80)
    private String lastName;

    @Column(length = 30)
    private String phone;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    /** Informations utiles au médecin pour préparer la consultation. */
    @Column(name = "blood_group", length = 5)
    private String bloodGroup;

    @Column(length = 500)
    private String allergies;

    public Patient(User user, String firstName, String lastName, String phone, LocalDate dateOfBirth) {
        this.user = user;
        this.firstName = firstName;
        this.lastName = lastName;
        this.phone = phone;
        this.dateOfBirth = dateOfBirth;
    }
}
