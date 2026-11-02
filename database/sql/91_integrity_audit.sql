-- Kiểm tra toàn vẹn quan hệ logic sau khi cài đủ 00–06 và 10. Chỉ đọc dữ liệu.
-- Kết quả rỗng nghĩa là chưa phát hiện vi phạm trong những quan hệ/quy tắc được liệt kê.
-- Không thay thế kiểm tra quyền, transaction, hash chuẩn và vòng đời tại backend.
WITH violations AS (
    SELECT 'chat_session.owner_id' AS violation, count(*) AS violation_count
    FROM ai_support.chat_session x
    LEFT JOIN ai_support.app_user p ON p.id = x.owner_id
    WHERE x.owner_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chat_message.session_id' AS violation, count(*) AS violation_count
    FROM ai_support.chat_message x
    LEFT JOIN ai_support.chat_session p ON p.id = x.session_id
    WHERE x.session_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chat_message.reply_to_message_id' AS violation, count(*) AS violation_count
    FROM ai_support.chat_message x
    LEFT JOIN ai_support.chat_message p ON p.id = x.reply_to_message_id
    WHERE x.reply_to_message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chat_message.release_id' AS violation, count(*) AS violation_count
    FROM ai_support.chat_message x
    LEFT JOIN ai_support.product_release p ON p.id = x.release_id
    WHERE x.release_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'message_citation.message_id' AS violation, count(*) AS violation_count
    FROM ai_support.message_citation x
    LEFT JOIN ai_support.chat_message p ON p.id = x.message_id
    WHERE x.message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'message_citation.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.message_citation x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'message_citation.chunk_id' AS violation, count(*) AS violation_count
    FROM ai_support.message_citation x
    LEFT JOIN ai_support.knowledge_chunk p ON p.id = x.chunk_id
    WHERE x.chunk_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'message_citation.run_id' AS violation, count(*) AS violation_count
    FROM ai_support.message_citation x
    LEFT JOIN ai_support.ai_run p ON p.id = x.run_id
    WHERE x.run_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'file_asset.uploaded_by' AS violation, count(*) AS violation_count
    FROM ai_support.file_asset x
    LEFT JOIN ai_support.app_user p ON p.id = x.uploaded_by
    WHERE x.uploaded_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'app_setting_revision.changed_by' AS violation, count(*) AS violation_count
    FROM ai_support.app_setting_revision x
    LEFT JOIN ai_support.app_user p ON p.id = x.changed_by
    WHERE x.changed_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'prompt_template_revision.created_by' AS violation, count(*) AS violation_count
    FROM ai_support.prompt_template_revision x
    LEFT JOIN ai_support.app_user p ON p.id = x.created_by
    WHERE x.created_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.request_message_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.chat_message p ON p.id = x.request_message_id
    WHERE x.request_message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.response_message_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.chat_message p ON p.id = x.response_message_id
    WHERE x.response_message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.job_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.background_job p ON p.id = x.job_id
    WHERE x.job_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.submission_attempt_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.submission_attempt p ON p.id = x.submission_attempt_id
    WHERE x.submission_attempt_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.knowledge_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.knowledge_revision_id
    WHERE x.knowledge_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.setting_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.app_setting_revision p ON p.id = x.setting_revision_id
    WHERE x.setting_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_run.prompt_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x
    LEFT JOIN ai_support.prompt_template_revision p ON p.id = x.prompt_revision_id
    WHERE x.prompt_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_retrieval_result.run_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_retrieval_result x
    LEFT JOIN ai_support.ai_run p ON p.id = x.run_id
    WHERE x.run_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_retrieval_result.chunk_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_retrieval_result x
    LEFT JOIN ai_support.knowledge_chunk p ON p.id = x.chunk_id
    WHERE x.chunk_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_retrieval_result.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_retrieval_result x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ai_retrieval_result.model_id' AS violation, count(*) AS violation_count
    FROM ai_support.ai_retrieval_result x
    LEFT JOIN ai_support.embedding_model p ON p.id = x.model_id
    WHERE x.model_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chat_feedback.message_id' AS violation, count(*) AS violation_count
    FROM ai_support.chat_feedback x
    LEFT JOIN ai_support.chat_message p ON p.id = x.message_id
    WHERE x.message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chat_feedback.user_id' AS violation, count(*) AS violation_count
    FROM ai_support.chat_feedback x
    LEFT JOIN ai_support.app_user p ON p.id = x.user_id
    WHERE x.user_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'audit_event.actor_id' AS violation, count(*) AS violation_count
    FROM ai_support.audit_event x
    LEFT JOIN ai_support.app_user p ON p.id = x.actor_id
    WHERE x.actor_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_item.created_by' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_item x
    LEFT JOIN ai_support.app_user p ON p.id = x.created_by
    WHERE x.created_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision.item_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision x
    LEFT JOIN ai_support.knowledge_item p ON p.id = x.item_id
    WHERE x.item_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision.created_by' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision x
    LEFT JOIN ai_support.app_user p ON p.id = x.created_by
    WHERE x.created_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision.approved_by' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision x
    LEFT JOIN ai_support.app_user p ON p.id = x.approved_by
    WHERE x.approved_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_review.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_review x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_review.reviewer_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_review x
    LEFT JOIN ai_support.app_user p ON p.id = x.reviewer_id
    WHERE x.reviewer_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision_asset.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_asset x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision_asset.asset_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_asset x
    LEFT JOIN ai_support.file_asset p ON p.id = x.asset_id
    WHERE x.asset_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_chunk.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_chunk x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_provenance.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_provenance x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_provenance.source_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_provenance x
    LEFT JOIN ai_support.source_revision p ON p.id = x.source_revision_id
    WHERE x.source_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_provenance.source_record_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_provenance x
    LEFT JOIN ai_support.source_record_revision p ON p.id = x.source_record_revision_id
    WHERE x.source_record_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_provenance.issue_report_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_provenance x
    LEFT JOIN ai_support.issue_report p ON p.id = x.issue_report_id
    WHERE x.issue_report_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_submission.owner_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_submission x
    LEFT JOIN ai_support.app_user p ON p.id = x.owner_id
    WHERE x.owner_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_submission.origin_chat_message_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_submission x
    LEFT JOIN ai_support.chat_message p ON p.id = x.origin_chat_message_id
    WHERE x.origin_chat_message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_submission.origin_source_record_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_submission x
    LEFT JOIN ai_support.source_record p ON p.id = x.origin_source_record_id
    WHERE x.origin_source_record_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'submission_attempt.submission_id' AS violation, count(*) AS violation_count
    FROM ai_support.submission_attempt x
    LEFT JOIN ai_support.issue_submission p ON p.id = x.submission_id
    WHERE x.submission_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'submission_attempt.confirmed_by' AS violation, count(*) AS violation_count
    FROM ai_support.submission_attempt x
    LEFT JOIN ai_support.app_user p ON p.id = x.confirmed_by
    WHERE x.confirmed_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'submission_evidence.submission_id' AS violation, count(*) AS violation_count
    FROM ai_support.submission_evidence x
    LEFT JOIN ai_support.issue_submission p ON p.id = x.submission_id
    WHERE x.submission_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'submission_evidence.chat_message_id' AS violation, count(*) AS violation_count
    FROM ai_support.submission_evidence x
    LEFT JOIN ai_support.chat_message p ON p.id = x.chat_message_id
    WHERE x.chat_message_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'submission_evidence.source_record_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.submission_evidence x
    LEFT JOIN ai_support.source_record_revision p ON p.id = x.source_record_revision_id
    WHERE x.source_record_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'submission_evidence.file_asset_id' AS violation, count(*) AS violation_count
    FROM ai_support.submission_evidence x
    LEFT JOIN ai_support.file_asset p ON p.id = x.file_asset_id
    WHERE x.file_asset_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue.assignee_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue x
    LEFT JOIN ai_support.app_user p ON p.id = x.assignee_id
    WHERE x.assignee_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue.created_by' AS violation, count(*) AS violation_count
    FROM ai_support.issue x
    LEFT JOIN ai_support.app_user p ON p.id = x.created_by
    WHERE x.created_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_report.issue_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_report x
    LEFT JOIN ai_support.issue p ON p.id = x.issue_id
    WHERE x.issue_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_report.submission_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_report x
    LEFT JOIN ai_support.issue_submission p ON p.id = x.submission_id
    WHERE x.submission_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_report.accepted_attempt_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_report x
    LEFT JOIN ai_support.submission_attempt p ON p.id = x.accepted_attempt_id
    WHERE x.accepted_attempt_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_report.withdrawn_by' AS violation, count(*) AS violation_count
    FROM ai_support.issue_report x
    LEFT JOIN ai_support.app_user p ON p.id = x.withdrawn_by
    WHERE x.withdrawn_by IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'report_event.report_id' AS violation, count(*) AS violation_count
    FROM ai_support.report_event x
    LEFT JOIN ai_support.issue_report p ON p.id = x.report_id
    WHERE x.report_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'report_event.actor_id' AS violation, count(*) AS violation_count
    FROM ai_support.report_event x
    LEFT JOIN ai_support.app_user p ON p.id = x.actor_id
    WHERE x.actor_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'report_event.file_asset_id' AS violation, count(*) AS violation_count
    FROM ai_support.report_event x
    LEFT JOIN ai_support.file_asset p ON p.id = x.file_asset_id
    WHERE x.file_asset_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_event.issue_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_event x
    LEFT JOIN ai_support.issue p ON p.id = x.issue_id
    WHERE x.issue_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'issue_event.actor_id' AS violation, count(*) AS violation_count
    FROM ai_support.issue_event x
    LEFT JOIN ai_support.app_user p ON p.id = x.actor_id
    WHERE x.actor_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'release_source.release_id' AS violation, count(*) AS violation_count
    FROM ai_support.release_source x
    LEFT JOIN ai_support.product_release p ON p.id = x.release_id
    WHERE x.release_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'release_source.source_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.release_source x
    LEFT JOIN ai_support.source_revision p ON p.id = x.source_revision_id
    WHERE x.source_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision_release.revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_release x
    LEFT JOIN ai_support.knowledge_revision p ON p.id = x.revision_id
    WHERE x.revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision_release.release_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_release x
    LEFT JOIN ai_support.product_release p ON p.id = x.release_id
    WHERE x.release_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'knowledge_revision_release.item_id' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_release x
    LEFT JOIN ai_support.knowledge_item p ON p.id = x.item_id
    WHERE x.item_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'source_connection.platform_id' AS violation, count(*) AS violation_count
    FROM ai_support.source_connection x
    LEFT JOIN ai_support.source_platform p ON p.id = x.platform_id
    WHERE x.platform_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'source_channel.connection_id' AS violation, count(*) AS violation_count
    FROM ai_support.source_channel x
    LEFT JOIN ai_support.source_connection p ON p.id = x.connection_id
    WHERE x.connection_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'source_record.channel_id' AS violation, count(*) AS violation_count
    FROM ai_support.source_record x
    LEFT JOIN ai_support.source_channel p ON p.id = x.channel_id
    WHERE x.channel_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'source_record.current_revision_id' AS violation, count(*) AS violation_count
    FROM ai_support.source_record x
    LEFT JOIN ai_support.source_record_revision p ON p.id = x.current_revision_id
    WHERE x.current_revision_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ingestion_event.connection_id' AS violation, count(*) AS violation_count
    FROM ai_support.ingestion_event x
    LEFT JOIN ai_support.source_connection p ON p.id = x.connection_id
    WHERE x.connection_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'ingestion_event.raw_payload_asset_id' AS violation, count(*) AS violation_count
    FROM ai_support.ingestion_event x
    LEFT JOIN ai_support.file_asset p ON p.id = x.raw_payload_asset_id
    WHERE x.raw_payload_asset_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'source_record_revision.record_id' AS violation, count(*) AS violation_count
    FROM ai_support.source_record_revision x
    LEFT JOIN ai_support.source_record p ON p.id = x.record_id
    WHERE x.record_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'source_record_revision.ingestion_event_id' AS violation, count(*) AS violation_count
    FROM ai_support.source_record_revision x
    LEFT JOIN ai_support.ingestion_event p ON p.id = x.ingestion_event_id
    WHERE x.ingestion_event_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'background_job_attempt.job_id' AS violation, count(*) AS violation_count
    FROM ai_support.background_job_attempt x
    LEFT JOIN ai_support.background_job p ON p.id = x.job_id
    WHERE x.job_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chunk_embedding.chunk_id' AS violation, count(*) AS violation_count
    FROM ai_support.chunk_embedding x
    LEFT JOIN ai_support.knowledge_chunk p ON p.id = x.chunk_id
    WHERE x.chunk_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chunk_embedding.model_id' AS violation, count(*) AS violation_count
    FROM ai_support.chunk_embedding x
    LEFT JOIN ai_support.embedding_model p ON p.id = x.model_id
    WHERE x.model_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chunk_embedding.embedding_run_id' AS violation, count(*) AS violation_count
    FROM ai_support.chunk_embedding x
    LEFT JOIN ai_support.ai_run p ON p.id = x.embedding_run_id
    WHERE x.embedding_run_id IS NOT NULL AND p.id IS NULL
    UNION ALL
    SELECT 'chat_message.reply_same_session' AS violation, count(*) AS violation_count
    FROM ai_support.chat_message x JOIN ai_support.chat_message p ON p.id = x.reply_to_message_id
    WHERE p.session_id <> x.session_id OR p.sender_type <> 'user' OR x.sender_type <> 'assistant'
    UNION ALL
    SELECT 'message_citation.chunk_revision' AS violation, count(*) AS violation_count
    FROM ai_support.message_citation x JOIN ai_support.knowledge_chunk p ON p.id = x.chunk_id
    WHERE p.revision_id <> x.revision_id
    UNION ALL
    SELECT 'message_citation.run_response' AS violation, count(*) AS violation_count
    FROM ai_support.message_citation x JOIN ai_support.ai_run p ON p.id = x.run_id
    JOIN ai_support.chat_message m ON m.id = x.message_id
    WHERE p.response_message_id IS DISTINCT FROM x.message_id OR m.sender_type <> 'assistant'
    UNION ALL
    SELECT 'ai_run.chat_messages' AS violation, count(*) AS violation_count
    FROM ai_support.ai_run x JOIN ai_support.chat_message q ON q.id = x.request_message_id
    LEFT JOIN ai_support.chat_message a ON a.id = x.response_message_id
    WHERE x.purpose = 'chat' AND (q.sender_type <> 'user' OR (a.id IS NOT NULL AND (a.sender_type <> 'assistant' OR a.session_id <> q.session_id OR a.reply_to_message_id IS DISTINCT FROM q.id)))
    UNION ALL
    SELECT 'chat_feedback.owner' AS violation, count(*) AS violation_count
    FROM ai_support.chat_feedback x JOIN ai_support.chat_message m ON m.id = x.message_id
    JOIN ai_support.chat_session s ON s.id = m.session_id
    WHERE m.sender_type <> 'assistant' OR s.owner_id <> x.user_id
    UNION ALL
    SELECT 'ai_retrieval_result.chunk_revision' AS violation, count(*) AS violation_count
    FROM ai_support.ai_retrieval_result x JOIN ai_support.knowledge_chunk c ON c.id = x.chunk_id
    WHERE c.revision_id <> x.revision_id OR c.content_hash <> x.chunk_hash
    UNION ALL
    SELECT 'knowledge_revision.approval_evidence' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision r
    WHERE r.status IN ('approved', 'published') AND NOT EXISTS (
        SELECT 1 FROM ai_support.knowledge_review k WHERE k.revision_id = r.id
        AND k.reviewer_id = r.approved_by AND k.action IN ('approve', 'publish') AND k.reviewed_hash = r.content_hash
    )
    UNION ALL
    SELECT 'knowledge_revision.origin_provenance' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision r
    WHERE (r.origin_kind = 'source_job' AND NOT EXISTS (SELECT 1 FROM ai_support.knowledge_provenance p WHERE p.revision_id = r.id AND p.source_revision_id IS NOT NULL))
    OR (r.origin_kind = 'connector' AND NOT EXISTS (SELECT 1 FROM ai_support.knowledge_provenance p WHERE p.revision_id = r.id AND p.source_record_revision_id IS NOT NULL))
    OR (r.origin_kind = 'issue' AND NOT EXISTS (SELECT 1 FROM ai_support.knowledge_provenance p WHERE p.revision_id = r.id AND p.issue_report_id IS NOT NULL))
    UNION ALL
    SELECT 'knowledge_revision.release_mapping' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision r
    WHERE r.status = 'published' AND r.applicability_scope = 'release' AND NOT EXISTS (
        SELECT 1 FROM ai_support.knowledge_revision_release m WHERE m.revision_id = r.id AND m.is_current
    )
    UNION ALL
    SELECT 'knowledge_review.approved_hash' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_review x JOIN ai_support.knowledge_revision r ON r.id = x.revision_id
    WHERE x.action IN ('approve', 'publish') AND x.reviewed_hash IS DISTINCT FROM r.content_hash
    UNION ALL
    SELECT 'knowledge_revision_release.item_scope' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_release x JOIN ai_support.knowledge_revision r ON r.id = x.revision_id
    WHERE x.item_id <> r.item_id OR r.applicability_scope <> 'release'
    UNION ALL
    SELECT 'knowledge_revision_release.source_manifest' AS violation, count(*) AS violation_count
    FROM ai_support.knowledge_revision_release x JOIN ai_support.knowledge_provenance p ON p.revision_id = x.revision_id
    WHERE p.source_revision_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ai_support.release_source rs WHERE rs.release_id = x.release_id AND rs.source_revision_id = p.source_revision_id
    )
    UNION ALL
    SELECT 'source_record.current_revision_owner' AS violation, count(*) AS violation_count
    FROM ai_support.source_record x JOIN ai_support.source_record_revision r ON r.id = x.current_revision_id
    WHERE r.record_id <> x.id
    UNION ALL
    SELECT 'source_record_revision.event_connection' AS violation, count(*) AS violation_count
    FROM ai_support.source_record_revision x JOIN ai_support.source_record r ON r.id = x.record_id
    JOIN ai_support.source_channel c ON c.id = r.channel_id
    JOIN ai_support.ingestion_event e ON e.id = x.ingestion_event_id
    WHERE c.connection_id <> e.connection_id
    UNION ALL
    SELECT 'issue_submission.chat_owner' AS violation, count(*) AS violation_count
    FROM ai_support.issue_submission x JOIN ai_support.chat_message m ON m.id = x.origin_chat_message_id
    JOIN ai_support.chat_session s ON s.id = m.session_id
    WHERE x.source_type = 'ai_chat' AND s.owner_id <> x.owner_id
    UNION ALL
    SELECT 'issue_report.accepted_attempt' AS violation, count(*) AS violation_count
    FROM ai_support.issue_report x JOIN ai_support.submission_attempt a ON a.id = x.accepted_attempt_id
    JOIN ai_support.issue_submission s ON s.id = x.submission_id
    WHERE a.submission_id <> x.submission_id OR a.decision <> 'pass'
    OR (s.source_type = 'ai_chat' AND (a.confirmed_by IS DISTINCT FROM s.owner_id OR a.confirmed_at IS NULL OR a.consent_payload_hash IS DISTINCT FROM a.payload_hash))
    UNION ALL
    SELECT 'issue_report.withdrawal_owner' AS violation, count(*) AS violation_count
    FROM ai_support.issue_report x JOIN ai_support.issue_submission s ON s.id = x.submission_id
    WHERE x.state = 'withdrawn' AND (s.source_type <> 'ai_chat' OR x.withdrawn_by IS DISTINCT FROM s.owner_id)
    UNION ALL
    SELECT 'background_job.running_attempt' AS violation, count(*) AS violation_count
    FROM ai_support.background_job j
    WHERE j.status = 'running' AND NOT EXISTS (
        SELECT 1 FROM ai_support.background_job_attempt a WHERE a.job_id = j.id
        AND a.attempt_no = j.attempt_count AND a.lease_token = j.lease_token
        AND a.worker_id = j.lease_owner AND a.status = 'running'
    )
    UNION ALL
    SELECT 'chunk_embedding.model_dimensions' AS violation, count(*) AS violation_count
    FROM ai_support.chunk_embedding x JOIN ai_support.embedding_model m ON m.id = x.model_id
    WHERE x.dimensions <> m.dimensions
    UNION ALL
    SELECT 'chunk_embedding.stale_ready' AS violation, count(*) AS violation_count
    FROM ai_support.chunk_embedding x JOIN ai_support.knowledge_chunk c ON c.id = x.chunk_id
    WHERE x.status = 'ready' AND x.embedded_content_hash <> c.content_hash
)
SELECT violation, violation_count
FROM violations
WHERE violation_count > 0
ORDER BY violation;
