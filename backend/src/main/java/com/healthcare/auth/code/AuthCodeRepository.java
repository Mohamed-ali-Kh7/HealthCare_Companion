package com.healthcare.auth.code;

import com.healthcare.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AuthCodeRepository extends JpaRepository<AuthCode, Long> {

    Optional<AuthCode> findFirstByUserAndPurposeAndConsumedFalseOrderByIdDesc(User user, CodePurpose purpose);

    Optional<AuthCode> findFirstByUserAndPurposeOrderByIdDesc(User user, CodePurpose purpose);

    List<AuthCode> findByUserAndPurposeAndConsumedFalse(User user, CodePurpose purpose);
}
