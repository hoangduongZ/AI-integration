import {readFileSync,readdirSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
// Pass the installed PGlite package directory. No connection to any external DB.
if(!process.argv[2])throw Error('Usage: node qa/sql-check.mjs ABSOLUTE_PGLITE_PACKAGE_DIRECTORY');
const {PGlite}=await import(pathToFileURL(join(resolve(process.argv[2]),'dist/index.js')).href);
const root=resolve(import.meta.dirname,'..');
const sqlDir=join(root,'database/sql');
const checks=[];
const assert=(name,value)=>{if(!value)throw Error(name);checks.push(name);};
const expectError=async(db,name,sql,code)=>{try{await db.exec(sql);}catch(e){assert(name,e.code===code);return;}throw Error('Expected SQL error: '+name);};
const full=new PGlite(),mvp=new PGlite();
try{
 const ddl=readdirSync(sqlDir).filter(f=>/^0\d_.*\.sql$/.test(f)).sort();
 for(const file of ddl){await full.exec(readFileSync(join(sqlDir,file),'utf8'));checks.push('DDL '+file);}
 const sample=readFileSync(join(sqlDir,'20_sample_manual_knowledge.sql'),'utf8');
 await full.exec(sample);await full.exec(sample);
 assert('30 application tables',(await full.query("SELECT count(*)::int n FROM information_schema.tables WHERE table_schema='ai_support' AND table_type='BASE TABLE'")).rows[0].n===30);
 assert('30 UUID primary keys',(await full.query("SELECT count(*)::int n FROM information_schema.table_constraints t JOIN information_schema.key_column_usage k USING(constraint_catalog,constraint_schema,constraint_name,table_catalog,table_schema,table_name) JOIN information_schema.columns c ON c.table_schema=k.table_schema AND c.table_name=k.table_name AND c.column_name=k.column_name WHERE t.table_schema='ai_support' AND t.constraint_type='PRIMARY KEY' AND c.column_name='id' AND c.udt_name='uuid'")).rows[0].n===30);
 assert('30 unique code columns',(await full.query("SELECT count(*)::int n FROM information_schema.table_constraints t JOIN information_schema.key_column_usage k USING(constraint_catalog,constraint_schema,constraint_name,table_catalog,table_schema,table_name) WHERE t.table_schema='ai_support' AND t.constraint_type='UNIQUE' AND k.column_name='code'")).rows[0].n===30);
 assert('No foreign-key constraints',(await full.query("SELECT count(*)::int n FROM information_schema.table_constraints WHERE table_schema='ai_support' AND constraint_type='FOREIGN KEY'")).rows[0].n===0);
 assert('No custom triggers',(await full.query("SELECT count(*)::int n FROM information_schema.triggers WHERE trigger_schema='ai_support'")).rows[0].n===0);
 assert('Sample rerun does not duplicate revisions',(await full.query("SELECT count(*)::int n FROM ai_support.knowledge_revision WHERE code='KT-HOSO-TIENDO-R01'")).rows[0].n===1);
 const row=(await full.query("SELECT k.id, k.code, r.status FROM ai_support.knowledge_item k JOIN ai_support.knowledge_revision r ON r.item_id=k.id WHERE k.code='KT-HOSO-TIENDO'")).rows[0];
 assert('Lookup by readable code joins UUID relationships',row?.code==='KT-HOSO-TIENDO'&&row.status==='draft'&&/^[0-9a-f-]{36}$/.test(row.id));
 await expectError(full,'Duplicate code rejected',"INSERT INTO ai_support.app_user(code,display_name) VALUES('USR-MVP-ADMIN','Other')",'23505');
 await expectError(full,'Blank code rejected',"INSERT INTO ai_support.app_user(code,display_name) VALUES(' ','Other')",'23514');
 await expectError(full,'Invalid role rejected',"INSERT INTO ai_support.app_user(code,display_name,role) VALUES('USR-INVALID','Other','superuser')",'23514');
 await full.exec("INSERT INTO ai_support.chat_session(code,owner_id) VALUES('CHAT-NO-PHYSICAL-FK',gen_random_uuid())");
 assert('Relationship ownership is application-managed',(await full.query("SELECT count(*)::int n FROM ai_support.chat_session s LEFT JOIN ai_support.app_user u ON u.id=s.owner_id WHERE s.code='CHAT-NO-PHYSICAL-FK' AND u.id IS NULL")).rows[0].n===1);
 await expectError(full,'Evidence must select one source',"INSERT INTO ai_support.submission_evidence(code,submission_id,chat_message_id,file_asset_id) VALUES('EVD-INVALID',gen_random_uuid(),gen_random_uuid(),gen_random_uuid())",'23514');
 await expectError(full,'Publishing requires a content hash',"UPDATE ai_support.knowledge_revision SET status='published',published_at=now() WHERE code='KT-HOSO-TIENDO-R01'",'23514');
 await full.exec("UPDATE ai_support.knowledge_revision SET content_hash=repeat('a',64),status='published',published_at=now() WHERE code='KT-HOSO-TIENDO-R01'");
 await expectError(full,'One published manual revision per item and version',"INSERT INTO ai_support.knowledge_revision(code,item_id,revision_no,version_label,title_public,body_public,content_hash,status,published_at,created_by) SELECT 'KT-DUPLICATE-PUBLISHED',item_id,2,version_label,title_public,body_public,content_hash,'published',now(),created_by FROM ai_support.knowledge_revision WHERE code='KT-HOSO-TIENDO-R01'",'23505');
 await expectError(full,'Embedding dimensions are checked',"INSERT INTO ai_support.knowledge_chunk(code,revision_id,chunk_no,body_public,content_hash,embedding_model,embedding_dimensions,embedding) VALUES('CHUNK-INVALID',gen_random_uuid(),1,'Text','hash','test-model',3,ARRAY[1.0,2.0])",'23514');
 for(const file of ['00_schema.sql','01_identity_chat.sql','02_knowledge.sql'])await mvp.exec(readFileSync(join(sqlDir,file),'utf8'));
 await mvp.exec(sample);
 assert('Manual MVP runs without source/release/connector clusters',(await mvp.query("SELECT count(*)::int n FROM information_schema.tables WHERE table_schema='ai_support' AND table_type='BASE TABLE'")).rows[0].n===12);
 assert('MVP knowledge does not require a deployment record',(await mvp.query("SELECT scope_type,status FROM ai_support.knowledge_revision WHERE code='KT-HOSO-TIENDO-R01'")).rows[0].scope_type==='manual');
 const result={engine:'PGlite 0.5.14 (embedded PostgreSQL)',passed:checks.length,checks,externalDatabaseUsed:false};
 mkdirSync(join(root,'.taste-skill/qa'),{recursive:true});
 writeFileSync(join(root,'.taste-skill/qa/sql-validation.json'),JSON.stringify(result,null,2));
 console.log(JSON.stringify(result,null,2));
}finally{await full.close();await mvp.close();}
