package com.integration.AI.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.health.contributor.Health;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class MvpSchemaHealthIndicatorTests {

    private final JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
    private final MvpSchemaHealthIndicator indicator = new MvpSchemaHealthIndicator(jdbcTemplate);

    @Test
    void reportsUpWhenMvpTablesExist() {
        when(jdbcTemplate.queryForObject(anyString(), eq(String.class))).thenReturn("");

        assertThat(indicator.health().getStatus().getCode()).isEqualTo("UP");
    }

    @Test
    void reportsDownWhenMvpTableIsMissing() {
        when(jdbcTemplate.queryForObject(anyString(), eq(String.class)))
                .thenReturn("ai_support.knowledge_item");

        Health health = indicator.health();
        assertThat(health.getStatus().getCode()).isEqualTo("DOWN");
        assertThat(health.getDetails()).containsEntry("missingTables", "ai_support.knowledge_item");
    }
}
