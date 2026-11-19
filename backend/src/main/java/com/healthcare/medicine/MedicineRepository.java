package com.healthcare.medicine;

import com.healthcare.common.SearchPatterns;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MedicineRepository extends JpaRepository<Medicine, Long> {

    default Page<Medicine> search(String q, Pageable pageable) {
        return searchByPattern(SearchPatterns.containsIgnoreCase(q), pageable);
    }

    @Query("""
            select m from Medicine m
            where :pattern is null
               or lower(m.name) like :pattern
               or lower(m.activeIngredient) like :pattern
            """)
    Page<Medicine> searchByPattern(@Param("pattern") String pattern, Pageable pageable);

    boolean existsByNameIgnoreCaseAndStrengthIgnoreCaseAndForm(String name, String strength, MedicineForm form);

    boolean existsByNameIgnoreCaseAndStrengthIgnoreCaseAndFormAndIdNot(String name, String strength,
                                                                        MedicineForm form, Long id);
}
