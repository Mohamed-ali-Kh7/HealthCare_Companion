package com.healthcare.common;

import java.util.Locale;

/**
 * Motifs LIKE construits côté Java plutôt qu'en JPQL (concat('%', :q, '%')).
 * Un paramètre nul à l'intérieur de concat() n'est pas typé : PostgreSQL le refuse (lower(bytea)),
 * et un cast explicite provoque un conflit de collation sous MySQL. Un motif passé tel quel fonctionne partout.
 */
public final class SearchPatterns {

    private SearchPatterns() {
    }

    /** "Kar" -> "%kar%" (à comparer avec lower(colonne)) ; null reste null (= pas de filtre). */
    public static String containsIgnoreCase(String q) {
        return q == null ? null : "%" + q.toLowerCase(Locale.ROOT) + "%";
    }
}
