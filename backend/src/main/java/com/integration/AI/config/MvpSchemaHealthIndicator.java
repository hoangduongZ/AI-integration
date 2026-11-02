package com.integration.AI.config;

import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component("mvpSchema")
public class MvpSchemaHealthIndicator implements HealthIndicator {

    private static final String MISSING_SCHEMA_COMPONENTS_SQL = """
            WITH required(name) AS (VALUES
                ('ai_support.app_user'),
                ('ai_support.chat_session'),
                ('ai_support.chat_message'),
                ('ai_support.message_citation'),
                ('ai_support.file_asset'),
                ('ai_support.app_setting_revision'),
                ('ai_support.prompt_template_revision'),
                ('ai_support.ai_run'),
                ('ai_support.chat_feedback'),
                ('ai_support.audit_event'),
                ('ai_support.ai_retrieval_result'),
                ('ai_support.knowledge_item'),
                ('ai_support.knowledge_revision'),
                ('ai_support.knowledge_review'),
                ('ai_support.knowledge_revision_asset'),
                ('ai_support.knowledge_chunk'),
                ('ai_support.knowledge_provenance'),
                ('ai_support.issue_submission'),
                ('ai_support.submission_attempt'),
                ('ai_support.submission_evidence'),
                ('ai_support.issue'),
                ('ai_support.issue_report'),
                ('ai_support.report_event'),
                ('ai_support.issue_event'),
                ('ai_support.product_release'),
                ('ai_support.source_revision'),
                ('ai_support.release_source'),
                ('ai_support.knowledge_revision_release'),
                ('ai_support.source_platform'),
                ('ai_support.source_connection'),
                ('ai_support.source_channel'),
                ('ai_support.source_record'),
                ('ai_support.ingestion_event'),
                ('ai_support.source_record_revision'),
                ('ai_support.background_job'),
                ('ai_support.background_job_attempt'),
                ('ai_support.embedding_model'),
                ('ai_support.chunk_embedding')
            ), missing AS (
                SELECT name FROM required WHERE to_regclass(name) IS NULL
                UNION ALL
                SELECT 'extension:vector'
                WHERE NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector')
            )
            SELECT COALESCE(string_agg(name, ', ' ORDER BY name), '') FROM missing
            """;

    private final JdbcTemplate jdbcTemplate;

    public MvpSchemaHealthIndicator(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Health health() {
        try {
            String missingComponents = jdbcTemplate.queryForObject(MISSING_SCHEMA_COMPONENTS_SQL, String.class);
            if (missingComponents == null || missingComponents.isBlank()) {
                return Health.up().build();
            }
            return Health.down().withDetail("missingComponents", missingComponents).build();
        } catch (DataAccessException exception) {
            return Health.down(exception).build();
        }
    }
}
