import {readFileSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL} from 'node:url';

if (!process.argv[2]) throw Error('Usage: node qa/sql-check.mjs PGLITE_PACKAGE_DIRECTORY [PGLITE_PGVECTOR_PACKAGE_DIRECTORY]');
const engineDir=resolve(process.argv[2]);
const vectorDir=resolve(process.argv[3] || join(dirname(engineDir),'pglite-pgvector'));
const {PGlite}=await import(pathToFileURL(join(engineDir,'dist/index.js')).href);
const {vector}=await import(pathToFileURL(join(vectorDir,'dist/index.js')).href);
const root=resolve(process.env.AI_SQL_ROOT || resolve(import.meta.dirname,'..'));
const sqlDir=join(root,'database/sql');
const files=['00_schema.sql','01_identity_chat.sql','02_knowledge.sql','03_issues.sql','04_releases_sources.sql','05_external_connectors.sql','06_background_jobs.sql','10_vector.sql'];
const expectedTables=[
 'app_user','chat_session','chat_message','message_citation','file_asset','app_setting_revision',
 'prompt_template_revision','ai_run','chat_feedback','audit_event','ai_retrieval_result',
 'knowledge_item','knowledge_revision','knowledge_review','knowledge_revision_asset','knowledge_chunk','knowledge_provenance',
 'issue_submission','submission_attempt','submission_evidence','issue','issue_report','report_event','issue_event',
 'product_release','source_revision','release_source','knowledge_revision_release',
 'source_platform','source_connection','source_channel','source_record','ingestion_event','source_record_revision',
 'background_job','background_job_attempt','embedding_model','chunk_embedding'
];
const checks=[];
const assert=(name,value)=>{if(!value)throw Error(name);checks.push(name);};
const db=new PGlite({extensions:{vector}});
const q=(sql,params=[])=>db.query(sql,params);
const one=async(sql,params=[])=>(await q(sql,params)).rows[0];
const add=async(table,fields)=>{
 const keys=Object.keys(fields);
 return one(`INSERT INTO ai_support.${table} (${keys.join(',')}) VALUES (${keys.map((_,i)=>'$'+(i+1)).join(',')}) RETURNING *`,Object.values(fields));
};
const expectError=async(name,sql,params=[],code='23514')=>{
 try{await q(sql,params);}catch(e){assert(name,e.code===code);return;}
 throw Error('Expected SQL error: '+name);
};
const hash='a'.repeat(64), hash2='b'.repeat(64), now=new Date().toISOString();
try {
 for(const file of files){await db.exec(readFileSync(join(sqlDir,file),'utf8'));checks.push('DDL '+file);}
 const names=(await q("SELECT table_name FROM information_schema.tables WHERE table_schema='ai_support' AND table_type='BASE TABLE' ORDER BY table_name")).rows.map(x=>x.table_name);
 assert('All 38 intended tables exist',JSON.stringify(names)===JSON.stringify([...expectedTables].sort()));
 const descriptions=await one("SELECT count(*)::int total,count(col_description(c.oid,a.attnum))::int commented FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid WHERE n.nspname='ai_support' AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped");
 assert('Every column has a database comment',descriptions.total===descriptions.commented);
 assert('Every table has a database comment',(await one("SELECT count(*)::int n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='ai_support' AND c.relkind='r' AND obj_description(c.oid,'pg_class') IS NOT NULL")).n===38);
 assert('No foreign keys',(await one("SELECT count(*)::int n FROM information_schema.table_constraints WHERE table_schema='ai_support' AND constraint_type='FOREIGN KEY'")).n===0);
 assert('No hidden custom triggers',(await one("SELECT count(*)::int n FROM information_schema.triggers WHERE trigger_schema='ai_support'")).n===0);
 const healthSource=readFileSync(join(root,'backend/src/main/java/com/integration/AI/config/MvpSchemaHealthIndicator.java'),'utf8');
 const healthSql=healthSource.match(/MISSING_SCHEMA_COMPONENTS_SQL = """([\s\S]*?)""";/)?.[1];
 if(!healthSql)throw Error('Cannot extract schema health SQL');
 assert('Backend health accepts the complete schema',(await one(healthSql)).coalesce==='');
 await db.exec('BEGIN');
 try {
  await db.exec('DROP TABLE ai_support.background_job_attempt');
  assert('Backend health detects a missing restored module table',(await one(healthSql)).coalesce.includes('ai_support.background_job_attempt'));
 } finally {await db.exec('ROLLBACK');}
 const sample=readFileSync(join(sqlDir,'20_sample_manual_knowledge.sql'),'utf8');
 await db.exec(sample);await db.exec(sample);
 const admin=await one("SELECT * FROM ai_support.app_user WHERE code='USR-MVP-ADMIN'");
 const rev=await one("SELECT * FROM ai_support.knowledge_revision WHERE code='KT-HOSO-TIENDO-R01'");
 assert('Sample rerun is idempotent and draft',(await one("SELECT count(*)::int n FROM ai_support.knowledge_revision WHERE code='KT-HOSO-TIENDO-R01'")).n===1&&rev.status==='draft');
 await expectError('Duplicate code rejected',"INSERT INTO ai_support.app_user(code,display_name) VALUES('USR-MVP-ADMIN','Duplicate')",[],'23505');
 await expectError('Invalid user role rejected',"INSERT INTO ai_support.app_user(code,display_name,role) VALUES('INVALID','Invalid','root')");
 await expectError('Partial auth identity rejected',"INSERT INTO ai_support.app_user(code,display_name,auth_issuer) VALUES('PARTIAL','Invalid','issuer')");
 const user=await add('app_user',{code:'USER',display_name:'Người dùng kiểm tra'});
 const session=await add('chat_session',{code:'CHAT',owner_id:user.id});
 const question=await add('chat_message',{code:'Q',session_id:session.id,sequence_no:1,sender_type:'user',body_public:'Hỏi',client_request_key:'r1'});
 const answer=await add('chat_message',{code:'A',session_id:session.id,sequence_no:2,sender_type:'assistant',body_public:'Trả lời',reply_to_message_id:question.id,processing_status:'completed'});
 await expectError('Duplicate client request rejected',"INSERT INTO ai_support.chat_message(code,session_id,sequence_no,sender_type,client_request_key) VALUES('Q2',$1,3,'user','r1')",[session.id],'23505');
 await expectError('Assistant cannot supply a client request key',"INSERT INTO ai_support.chat_message(code,session_id,sequence_no,sender_type,client_request_key) VALUES('A2',$1,3,'assistant','wrong')",[session.id]);
 const config=await add('app_setting_revision',{code:'CONFIG1',revision_no:1,settings:'{}',change_reason:'Kiểm tra',changed_by:admin.id,is_current:true});
 await expectError('One current app configuration',"INSERT INTO ai_support.app_setting_revision(code,revision_no,settings,change_reason,changed_by,is_current) VALUES('CONFIG2',2,'{}','test',$1,true)",[admin.id],'23505');
 const prompt=await add('prompt_template_revision',{code:'PROMPT1',template_key:'chat_answer',revision_no:1,template:'{}',content_hash:hash,status:'active',created_by:admin.id});
 await expectError('One active prompt per template key',"INSERT INTO ai_support.prompt_template_revision(code,template_key,revision_no,template,content_hash,status,created_by) VALUES('PROMPT2','chat_answer',2,'{}',$1,'active',$2)",[hash,admin.id],'23505');
 const run=await add('ai_run',{request_message_id:question.id,response_message_id:answer.id,provider:'test',model:'test-chat',prompt_version:'v1',prompt_revision_id:prompt.id,setting_revision_id:config.id,status:'succeeded',finished_at:now,started_at:now});
 await expectError('Completed AI run requires completion time',"INSERT INTO ai_support.ai_run(request_message_id,provider,model,prompt_version,setting_revision_id,status) VALUES($1,'test','test','v1',$2,'succeeded')",[question.id,config.id]);
 await expectError('Published knowledge requires approval',"UPDATE ai_support.knowledge_revision SET status='published',published_at=now(),content_hash=$1 WHERE id=$2",[hash,rev.id]);
 await q("UPDATE ai_support.knowledge_revision SET status='published',approved_by=$1,approved_at=now(),published_at=now(),content_hash=$2 WHERE id=$3",[admin.id,hash,rev.id]);
 await add('knowledge_review',{code:'REVIEW',revision_id:rev.id,reviewer_id:admin.id,action:'publish',reviewed_hash:hash});
 await expectError('Only one global publication per item',"INSERT INTO ai_support.knowledge_revision(code,item_id,revision_no,title_public,body_public,status,content_hash,approved_by,approved_at,published_at,created_by) VALUES('GLOBAL2',$1,2,'Title','Body','published',$2,$3,now(),now(),$3)",[rev.item_id,hash,admin.id],'23505');
 await expectError('Invalid content hash rejected',"UPDATE ai_support.knowledge_revision SET content_hash='bad' WHERE id=$1",[rev.id]);
 const chunk1=await add('knowledge_chunk',{code:'CH1',revision_id:rev.id,chunk_no:1,body_public:'Nội dung phù hợp',content_hash:hash,index_status:'ready'});
 const chunk2=await add('knowledge_chunk',{code:'CH2',revision_id:rev.id,chunk_no:2,body_public:'Nội dung khác',content_hash:hash2,index_status:'ready'});
 const model=await add('embedding_model',{provider:'test',model_key:'embed',dimensions:3});
 await add('chunk_embedding',{chunk_id:chunk1.id,model_id:model.id,dimensions:3,embedding:'[1,0,0]',embedded_content_hash:hash});
 await add('chunk_embedding',{chunk_id:chunk2.id,model_id:model.id,dimensions:3,embedding:'[0,1,0]',embedded_content_hash:hash2});
 await expectError('Vector dimensions checked',"INSERT INTO ai_support.chunk_embedding(chunk_id,model_id,dimensions,embedding,embedded_content_hash) VALUES(gen_random_uuid(),$1,3,'[1,0]',$2)",[model.id,hash]);
 await expectError('Zero vector rejected',"INSERT INTO ai_support.chunk_embedding(chunk_id,model_id,dimensions,embedding,embedded_content_hash) VALUES(gen_random_uuid(),$1,3,'[0,0,0]',$2)",[model.id,hash]);
 const hiddenItem=await add('knowledge_item',{code:'ADMIN-K',content_type:'guide',title:'Chỉ admin',created_by:admin.id});
 const hiddenRev=await add('knowledge_revision',{code:'ADMIN-R',item_id:hiddenItem.id,revision_no:1,title_public:'Nội bộ',body_public:'Nội bộ',audience_roles:['admin'],created_by:admin.id,status:'published',approved_by:admin.id,approved_at:now,published_at:now,content_hash:hash});
 await add('knowledge_review',{code:'ADMIN-REVIEW',revision_id:hiddenRev.id,reviewer_id:admin.id,action:'publish',reviewed_hash:hash});
 const hiddenChunk=await add('knowledge_chunk',{code:'ADMIN-C',revision_id:hiddenRev.id,chunk_no:1,body_public:'Nội bộ',content_hash:hash,index_status:'ready'});
 await add('chunk_embedding',{chunk_id:hiddenChunk.id,model_id:model.id,dimensions:3,embedding:'[1,0,0]',embedded_content_hash:hash});
 const draftItem=await add('knowledge_item',{code:'DRAFT-K',title:'Nháp',created_by:admin.id});
 const draftRev=await add('knowledge_revision',{code:'DRAFT-R',item_id:draftItem.id,revision_no:1,title_public:'Nháp',body_public:'Nháp',created_by:admin.id});
 const draftChunk=await add('knowledge_chunk',{code:'DRAFT-C',revision_id:draftRev.id,chunk_no:1,body_public:'Nháp',content_hash:hash,index_status:'ready'});
 await add('chunk_embedding',{chunk_id:draftChunk.id,model_id:model.id,dimensions:3,embedding:'[1,0,0]',embedded_content_hash:hash});
 const guide=readFileSync(join(root,'database/README.md'),'utf8');
 const documentedSearch=guide.match(/```sql\n(SELECT c\.id AS chunk_id[\s\S]*?)\n```/)?.[1];
 if(!documentedSearch)throw Error('Missing documented RAG search query');
 const searchSql=documentedSearch.replaceAll(':query_embedding','$1').replaceAll(':model_id','$2').replaceAll(':role','$3').replaceAll(':release_id','$4');
 const results=(await q(searchSql,['[1,0,0]',model.id,'user',null])).rows;
 assert('Exact cosine retrieval ranks expected chunk first',results[0].chunk_id===chunk1.id&&Number(results[0].distance)===0);
 assert('Retrieval excludes draft and unauthorized chunks',results.length===2&&!results.some(x=>[hiddenChunk.id,draftChunk.id].includes(x.chunk_id)));
 await add('ai_retrieval_result',{run_id:run.id,chunk_id:chunk1.id,revision_id:rev.id,model_id:model.id,retrieval_method:'vector',rank:1,score:0,selected_for_context:true,chunk_hash:hash});
 await add('message_citation',{code:'CITE',message_id:answer.id,run_id:run.id,revision_id:rev.id,chunk_id:chunk1.id,public_excerpt:'Nội dung phù hợp',public_label:'Hướng dẫn',position:1});
 await add('chat_feedback',{message_id:answer.id,user_id:user.id,rating:'positive'});
 const source=await add('source_revision',{code:'SRC1',repository_key:'backend',commit_sha:'c'.repeat(40),manifest_hash:hash,pipeline_version:'pipeline-v1',manifest_uri:'s3://test/manifest.json',status:'indexed',indexed_at:now});
 await expectError('Repository snapshot requires an immutable Git SHA',"UPDATE ai_support.source_revision SET commit_sha='main' WHERE id=$1",[source.id]);
 const release=await add('product_release',{code:'REL1',environment:'production',deployment_key:'deploy-1',display_version:'1.0',deployed_at:now,is_current:true});
 await add('release_source',{code:'MANIFEST1',release_id:release.id,service_key:'backend',source_revision_id:source.id});
 const sourceItem=await add('knowledge_item',{code:'SOURCE-K',content_type:'function_snapshot',title:'Chức năng từ source',created_by:admin.id});
 const sourceRev=await add('knowledge_revision',{code:'SOURCE-R1',item_id:sourceItem.id,revision_no:1,origin_kind:'source_job',applicability_scope:'release',title_public:'Chức năng',body_public:'Hành vi đã kiểm tra',created_by:admin.id,status:'published',approved_by:admin.id,approved_at:now,published_at:now,content_hash:hash});
 await add('knowledge_review',{code:'SOURCE-REVIEW1',revision_id:sourceRev.id,reviewer_id:admin.id,action:'publish',reviewed_hash:hash});
 await add('knowledge_provenance',{code:'PROV-SRC',revision_id:sourceRev.id,source_revision_id:source.id,source_hash:hash});
 await add('knowledge_revision_release',{code:'MAP1',revision_id:sourceRev.id,item_id:sourceItem.id,release_id:release.id});
 const sourceRev2=await add('knowledge_revision',{code:'SOURCE-R2',item_id:sourceItem.id,revision_no:2,origin_kind:'source_job',applicability_scope:'release',title_public:'Chức năng 2',body_public:'Bản khác',created_by:admin.id,status:'published',approved_by:admin.id,approved_at:now,published_at:now,content_hash:hash});
 await expectError('One current revision per item/release',"INSERT INTO ai_support.knowledge_revision_release(code,revision_id,item_id,release_id) VALUES('MAP2',$1,$2,$3)",[sourceRev2.id,sourceItem.id,release.id],'23505');
 const release2=await add('product_release',{code:'REL-STAGE',environment:'staging',deployment_key:'deploy-stage',display_version:'1.1',deployed_at:now,is_current:true});
 await add('release_source',{code:'MANIFEST2',release_id:release2.id,service_key:'backend',source_revision_id:source.id});
 await add('knowledge_review',{code:'SOURCE-REVIEW2',revision_id:sourceRev2.id,reviewer_id:admin.id,action:'publish',reviewed_hash:hash});
 await add('knowledge_provenance',{code:'PROV-SRC2',revision_id:sourceRev2.id,source_revision_id:source.id,source_hash:hash});
 await add('knowledge_revision_release',{code:'MAP-STAGE',revision_id:sourceRev2.id,item_id:sourceItem.id,release_id:release2.id});
 assert('Release revisions may share a display label',sourceRev.version_label===sourceRev2.version_label);
 await expectError('One current release per environment',"INSERT INTO ai_support.product_release(code,environment,deployment_key,display_version,deployed_at,is_current) VALUES('REL2','production','deploy-2','2.0',now(),true)",[],'23505');
 const platform=await add('source_platform',{code:'DOCUMENT',display_name:'Tài liệu'});
 const connection=await add('source_connection',{code:'CONN',platform_id:platform.id,namespace_key:'space-1',adapter_key:'docs',adapter_version:'1',policy_version:'1',collection_status:'active',authorization_reference:'approval',authorization_verified_at:now});
 const channel=await add('source_channel',{code:'CHANNEL',connection_id:connection.id,external_channel_id:'folder-1',channel_type:'folder',display_name:'Tài liệu',collection_status:'active'});
 const record=await add('source_record',{code:'REC',channel_id:channel.id,external_record_id:'doc-1',record_type:'document',state:'pending'});
 const event=await add('ingestion_event',{code:'EVENT',connection_id:connection.id,event_key:'event-1',event_type:'record.created',payload_hash:hash,adapter_version:'1',policy_version:'1'});
 const recordRev=await add('source_record_revision',{code:'REC-R1',record_id:record.id,ingestion_event_id:event.id,operation:'create',body_internal:'Nguồn',content_hash:hash,ordering_status:'verified'});
 await q("UPDATE ai_support.source_record SET current_revision_id=$1,state='active' WHERE id=$2",[recordRev.id,record.id]);
 await add('knowledge_provenance',{code:'PROV-EXT',revision_id:sourceRev.id,source_record_revision_id:recordRev.id,source_hash:hash});
 const sourceChunk=await add('knowledge_chunk',{code:'SOURCE-CH1',revision_id:sourceRev.id,chunk_no:1,body_public:'Snapshot source production',content_hash:hash,index_status:'ready'});
 const sourceChunk2=await add('knowledge_chunk',{code:'SOURCE-CH2',revision_id:sourceRev2.id,chunk_no:1,body_public:'Snapshot source staging',content_hash:hash,index_status:'ready'});
 await add('chunk_embedding',{chunk_id:sourceChunk.id,model_id:model.id,dimensions:3,embedding:'[1,0,0]',embedded_content_hash:hash});
 await add('chunk_embedding',{chunk_id:sourceChunk2.id,model_id:model.id,dimensions:3,embedding:'[1,0,0]',embedded_content_hash:hash});
 const releaseResults=(await q(searchSql,['[1,0,0]',model.id,'user',release.id])).rows;
 assert('Retrieval uses only the requested release mapping',releaseResults.some(x=>x.chunk_id===sourceChunk.id)&&!releaseResults.some(x=>x.chunk_id===sourceChunk2.id));
 assert('Release-scoped knowledge excluded without a release',!(await q(searchSql,['[1,0,0]',model.id,'user',null])).rows.some(x=>[sourceChunk.id,sourceChunk2.id].includes(x.chunk_id)));
 await db.exec('BEGIN');
 try {
  await q("UPDATE ai_support.source_connection SET collection_status='revoked' WHERE id=$1",[connection.id]);
  assert('Retrieval excludes knowledge from a revoked connector',!(await q(searchSql,['[1,0,0]',model.id,'user',release.id])).rows.some(x=>x.chunk_id===sourceChunk.id));
 } finally {await db.exec('ROLLBACK');}
 await expectError('Duplicate ingestion event rejected',"INSERT INTO ai_support.ingestion_event(code,connection_id,event_key,event_type,payload_hash,adapter_version,policy_version) VALUES('EVENT2',$1,'event-1','record.created',$2,'1','1')",[connection.id,hash],'23505');
 await expectError('Source record namespace unique',"INSERT INTO ai_support.source_record(code,channel_id,external_record_id,record_type) VALUES('REC2',$1,'doc-1','document')",[channel.id],'23505');
 const submission=await add('issue_submission',{code:'SUB',owner_id:user.id,origin_chat_message_id:question.id,proposal_title:'Vấn đề',proposal_body:'Mô tả'});
 const attempt=await add('submission_attempt',{code:'ATT',submission_id:submission.id,request_key:'send-1',submitted_payload:'{}',payload_hash:hash,confirmed_by:user.id,confirmed_at:now,consent_payload_hash:hash,decision:'pass',decided_at:now});
 const issue=await add('issue',{code:'ISSUE',title_internal:'Tổng hợp',created_by:admin.id});
 const report=await add('issue_report',{code:'REPORT',issue_id:issue.id,submission_id:submission.id,accepted_attempt_id:attempt.id});
 await add('submission_evidence',{code:'EVID',submission_id:submission.id,chat_message_id:question.id});
 await add('report_event',{code:'REPORT-EV',report_id:report.id,actor_id:user.id,event_type:'correction',body_public:'Bổ sung'});
 await add('issue_event',{code:'ISSUE-EV',issue_id:issue.id,actor_id:admin.id,event_type:'created'});
 await expectError('Evidence selects exactly one source',"INSERT INTO ai_support.submission_evidence(code,submission_id,chat_message_id,file_asset_id) VALUES('BAD-EV',$1,$2,gen_random_uuid())",[submission.id,question.id]);
 await expectError('Consent hash must match submitted payload',"INSERT INTO ai_support.submission_attempt(code,submission_id,request_key,submitted_payload,payload_hash,confirmed_by,confirmed_at,consent_payload_hash) VALUES('BAD-CONSENT',$1,'send-2','{}',$2,$3,now(),$4)",[submission.id,hash,user.id,hash2]);
 const external=await add('issue_submission',{code:'EXT-SUB',source_type:'external',origin_source_record_id:record.id,proposal_title:'Nguồn ngoài',proposal_body:'Tình huống'});
 const externalAttempt=await add('submission_attempt',{code:'EXT-ATT',submission_id:external.id,request_key:'external-1',submitted_payload:'{}',payload_hash:hash,decision:'pass',decided_at:now});
 await add('issue_report',{code:'EXT-REPORT',issue_id:issue.id,submission_id:external.id,accepted_attempt_id:externalAttempt.id});
 const lease=crypto.randomUUID();
 const job=await add('background_job',{code:'JOB',job_type:'source_sync',dedupe_key:'source-commit-1',status:'running',attempt_count:1,max_attempts:3,lease_owner:'worker-1',lease_token:lease,lease_until:new Date(Date.now()+60000).toISOString()});
 const jobAttempt=await add('background_job_attempt',{job_id:job.id,attempt_no:1,worker_id:'worker-1',lease_token:lease});
 await expectError('Running job requires complete lease',"INSERT INTO ai_support.background_job(code,job_type,dedupe_key,status,lease_owner,lease_until) VALUES('BAD-JOB','test','bad-job','running','worker',now())");
 await expectError('Job attempt limit checked',"UPDATE ai_support.background_job SET attempt_count=4 WHERE id=$1",[job.id]);
 await expectError('Running job requires an incremented attempt',"UPDATE ai_support.background_job SET attempt_count=0 WHERE id=$1",[job.id]);
 const newer=crypto.randomUUID();
 await q("UPDATE ai_support.background_job SET lease_token=$1,lease_owner='worker-2',attempt_count=2 WHERE id=$2",[newer,job.id]);
 assert('Fencing token prevents stale worker update',(await q("UPDATE ai_support.background_job SET status='succeeded' WHERE id=$1 AND lease_token=$2 RETURNING id",[job.id,lease])).rows.length===0);
 await q("UPDATE ai_support.background_job_attempt SET status='failed',finished_at=now(),error_code='LEASE_LOST' WHERE id=$1",[jobAttempt.id]);
 await add('background_job_attempt',{job_id:job.id,attempt_no:2,worker_id:'worker-2',lease_token:newer});
 await add('ai_run',{purpose:'source_analysis',job_id:job.id,provider:'test',model:'test-chat',prompt_version:'source-v1',setting_revision_id:config.id});
 checks.push('Source job AI calls do not require a chat message');
 await add('audit_event',{actor_type:'user',actor_id:admin.id,action:'review.completed',target_type:'knowledge_revision',target_id:rev.id});
 const audit=readFileSync(join(sqlDir,'91_integrity_audit.sql'),'utf8');
 const violations=()=>q(audit);
 const clean=(await violations()).rows;
 assert('All logical links and cross-table rules clean for valid fixtures',clean.length===0);
 const corrupt=async(name,fn,label)=>{await db.exec('BEGIN');try{await fn();assert(name,(await violations()).rows.some(x=>x.violation===label&&Number(x.violation_count)>0));}finally{await db.exec('ROLLBACK');}};
 await corrupt('Audit detects orphan ownership',()=>add('chat_session',{code:'ORPHAN',owner_id:crypto.randomUUID()}),'chat_session.owner_id');
 await corrupt('Audit detects embedding/model dimension mismatch',()=>q('UPDATE ai_support.embedding_model SET dimensions=4 WHERE id=$1',[model.id]),'chunk_embedding.model_dimensions');
 await corrupt('Audit detects stale ready embedding',()=>q('UPDATE ai_support.chunk_embedding SET embedded_content_hash=$1 WHERE chunk_id=$2',[hash2,chunk1.id]),'chunk_embedding.stale_ready');
 await corrupt('Audit detects wrong accepted attempt',()=>q('UPDATE ai_support.submission_attempt SET submission_id=$1 WHERE id=$2',[external.id,attempt.id]),'issue_report.accepted_attempt');
 await corrupt('Audit detects wrong source/release manifest',()=>q('DELETE FROM ai_support.release_source WHERE release_id=$1',[release.id]),'knowledge_revision_release.source_manifest');
 await corrupt('Audit detects citation bound to another response',()=>q('UPDATE ai_support.message_citation SET message_id=$1 WHERE code=$2',[question.id,'CITE']),'message_citation.run_response');
 const engine=JSON.parse(readFileSync(join(engineDir,'package.json'),'utf8')).version;
 const extension=await one("SELECT extversion FROM pg_extension WHERE extname='vector'");
 console.log(JSON.stringify({engine:'PGlite '+engine,pgvector:extension.extversion,tables:38,columns:descriptions.total,passed:checks.length,checks,externalDatabaseUsed:false},null,2));
} catch(error) {
 console.error(JSON.stringify({failed:error.message,code:error.code,passed:checks.length,lastPassed:checks.at(-1)},null,2));
 process.exitCode=1;
} finally {await db.close();}
