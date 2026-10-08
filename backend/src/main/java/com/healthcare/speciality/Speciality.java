package com.healthcare.speciality;

import com.healthcare.common.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "specialities",
        uniqueConstraints = @UniqueConstraint(name = "uk_specialities_name", columnNames = "name"))
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Speciality extends BaseEntity {

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 500)
    private String description;

    public Speciality(String name, String description) {
        this.name = name;
        this.description = description;
    }
}
