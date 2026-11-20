package com.healthcare.bootstrap;

import jakarta.persistence.EntityManagerFactory;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.hibernate.metamodel.mapping.BasicValuedModelPart;
import org.hibernate.type.SqlTypes;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * PostgreSQL : Hibernate crée pour chaque enum stockée en texte une contrainte
 * {@code CHECK (col IN ('A','B',...))} à la création de la table, mais {@code ddl-auto=update}
 * ne la met jamais à jour. Ajouter une valeur à l'enum (ex. Role.AMBULANCE_COMPANY) rend alors
 * toute insertion de la nouvelle valeur impossible sur une base existante (Neon).
 * <p>
 * Au démarrage, avant {@link DataSeeder}, on recrée chaque contrainte d'enum qui ne couvre pas
 * toutes les valeurs actuelles. Sans effet sur une base à jour ou sur un autre SGBD.
 */
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
@RequiredArgsConstructor
public class EnumCheckConstraintSync implements ApplicationRunner {

    private final EntityManagerFactory entityManagerFactory;
    private final JdbcTemplate jdbcTemplate;

    private record EnumColumn(String table, String column, List<String> values) {}

    @Override
    public void run(ApplicationArguments args) {
        String product = jdbcTemplate.execute((java.sql.Connection c) -> c.getMetaData().getDatabaseProductName());
        if (product == null || !product.toLowerCase().contains("postgres")) {
            return;
        }
        for (EnumColumn col : enumColumns()) {
            sync(col);
        }
    }

    /** Colonnes d'entités mappées sur une enum Java stockée en texte (@Enumerated(STRING)). */
    private List<EnumColumn> enumColumns() {
        List<EnumColumn> result = new ArrayList<>();
        SessionFactoryImplementor sf = entityManagerFactory.unwrap(SessionFactoryImplementor.class);
        sf.getMappingMetamodel().forEachEntityDescriptor(persister ->
                persister.forEachAttributeMapping(attr -> {
                    if (!(attr instanceof BasicValuedModelPart basic)) return;
                    Class<?> javaType = basic.getJdbcMapping().getJavaTypeDescriptor().getJavaTypeClass();
                    int sqlType = basic.getJdbcMapping().getJdbcType().getDefaultSqlTypeCode();
                    if (!javaType.isEnum() || !SqlTypes.isCharacterType(sqlType)) return;
                    List<String> values = Arrays.stream(javaType.getEnumConstants())
                            .map(e -> ((Enum<?>) e).name())
                            .toList();
                    result.add(new EnumColumn(basic.getContainingTableExpression(), basic.getSelectionExpression(), values));
                }));
        return result;
    }

    private void sync(EnumColumn col) {
        List<Map<String, Object>> checks = jdbcTemplate.queryForList("""
                SELECT c.conname AS name, pg_get_constraintdef(c.oid) AS def
                FROM pg_constraint c
                JOIN pg_class t ON t.oid = c.conrelid
                JOIN pg_namespace n ON n.oid = t.relnamespace
                JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = c.conkey[1]
                WHERE c.contype = 'c' AND cardinality(c.conkey) = 1
                  AND n.nspname = current_schema() AND t.relname = ? AND a.attname = ?
                """, col.table(), col.column());

        for (Map<String, Object> check : checks) {
            String name = (String) check.get("name");
            String def = (String) check.get("def");
            List<String> missing = col.values().stream().filter(v -> !def.contains("'" + v + "'")).toList();
            if (missing.isEmpty()) continue;

            String allowed = col.values().stream().map(v -> "'" + v + "'").collect(Collectors.joining(", "));
            jdbcTemplate.execute("ALTER TABLE " + col.table() + " DROP CONSTRAINT \"" + name + "\"");
            jdbcTemplate.execute("ALTER TABLE " + col.table() + " ADD CONSTRAINT \"" + name + "\" CHECK ("
                    + col.column() + " IN (" + allowed + "))");
            log.info("Contrainte {} sur {}.{} mise à jour (valeurs ajoutées : {})", name, col.table(), col.column(), missing);
        }
    }
}
