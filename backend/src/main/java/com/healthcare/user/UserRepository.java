package com.healthcare.user;

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

    @Query("""
            select u from User u
            where (:role is null or u.role = :role)
              and (:enabled is null or u.enabled = :enabled)
              and (:q is null or lower(u.email) like lower(concat('%', :q, '%')))
            """)
    Page<User> search(@Param("q") String q,
                      @Param("role") Role role,
                      @Param("enabled") Boolean enabled,
                      Pageable pageable);
}
