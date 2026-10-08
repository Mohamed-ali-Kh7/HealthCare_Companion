package com.healthcare.user;

import com.healthcare.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "users",
        uniqueConstraints = @UniqueConstraint(name = "uk_users_email", columnNames = "email"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED) // requis par JPA, interdit ailleurs
public class User extends BaseEntity {

    @Column(nullable = false, length = 150)
    private String email;

    @Column(nullable = false, length = 72) // hash BCrypt = 60 caractères
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    /** false = compte désactivé par l'admin ou en attente de validation (médecin, pharmacien). */
    @Column(nullable = false)
    private boolean enabled = true;

    public User(String email, String passwordHash, Role role, boolean enabled) {
        this.email = email;
        this.password = passwordHash;
        this.role = role;
        this.enabled = enabled;
    }

    @PrePersist
    @PreUpdate
    private void normalizeEmail() {
        if (email != null) {
            email = email.trim().toLowerCase();
        }
    }
}
