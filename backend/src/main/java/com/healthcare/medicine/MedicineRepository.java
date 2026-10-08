package com.healthcare.medicine;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MedicineRepository extends JpaRepository<Medicine, Long> {

    @Query("""
            select m from Medicine m
            where :q is null
               or lower(m.name) like lower(concat('%', :q, '%'))
               or lower(m.activeIngredient) like lower(concat('%', :q, '%'))
            """)
    Page<Medicine> search(@Param("q") String q, Pageable pageable);

    boolean existsByNameIgnoreCaseAndStrengthIgnoreCaseAndForm(String name, String strength, MedicineForm form);

    boolean existsByNameIgnoreCaseAndStrengthIgnoreCaseAndFormAndIdNot(String name, String strength,
                                                                        MedicineForm form, Long id);
}
