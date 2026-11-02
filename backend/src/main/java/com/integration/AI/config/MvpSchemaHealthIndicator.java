package com.integration.AI.config;

import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component("mvpSchema")
public class MvpSchemaHealthIndicator implements HealthIndicator {

    private static final String MISSING_TABLES_SQL = """
            SELECT COALESCE(string_agg(required.name, ', ' ORDER BY required.name), '')
            FROM (VALUES
                ('ai_support.app_user'),
                ('ai_support.chat_session'),
                ('ai_support.chat_message'),
                ('ai_support.message_citation'),
                ('ai_support.file_asset'),
                ('ai_support.app_setting_revision'),
                ('ai_support.knowledge_item'),
                ('ai_support.knowledge_revision'),
                ('ai_support.knowledge_review'),
                ('ai_support.knowledge_revision_asset'),
                ('ai_support.knowledge_chunk'),
                ('ai_support.knowledge_provenance')
            ) AS required(name)
            WHERE to_regclass(required.name) IS NULL
            """;

    private final JdbcTemplate jdbcTemplate;

    public MvpSchemaHealthIndicator(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Health health() {
        try {
            String missingTables = jdbcTemplate.queryForObject(MISSING_TABLES_SQL, String.class);
            if (missingTables == null || missingTables.isBlank()) {
                return Health.up().build();
            }
            return Health.down().withDetail("missingTables", missingTables).build();
        } catch (DataAccessException exception) {
            return Health.down(exception).build();
        }
    }
}
