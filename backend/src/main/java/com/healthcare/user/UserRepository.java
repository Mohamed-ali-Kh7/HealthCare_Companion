package com.healthcare.user;

import com.healthcare.common.SearchPatterns;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByRole(Role role);

    long countByRole(Role role);

    long countByEnabledFalse();

    default Page<User> search(String q, Role role, Boolean enabled, Pageable pageable) {
        return searchByPattern(SearchPatterns.containsIgnoreCase(q), role, enabled, pageable);
    }

    @Query("""
            select u from User u
            where (:role is null or u.role = :role)
              and (:enabled is null or u.enabled = :enabled)
              and (:pattern is null or lower(u.email) like :pattern)
            """)
    Page<User> searchByPattern(@Param("pattern") String pattern,
                               @Param("role") Role role,
                               @Param("enabled") Boolean enabled,
                               Pageable pageable);
}
