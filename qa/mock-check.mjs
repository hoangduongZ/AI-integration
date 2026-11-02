import { Browser, sleep } from 'file:///C:/hoangdv/index/trunk/agent-kit/skills/taste-skill/scripts/lib/cdp.mjs';
import { mkdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
const browser=await Browser.launch();
const page=await browser.newPage();
const checks=[];
const check=async(name,expression)=>{if(!await page.eval(expression))throw new Error(name);checks.push(name);};
const run=code=>page.eval(code);
const click=selector=>run(`document.querySelector(${JSON.stringify(selector)}).click()`);
const select=async(selector,value)=>run(`{const el=document.querySelector(${JSON.stringify(selector)});el.value=${JSON.stringify(value)};el.dispatchEvent(new Event('change',{bubbles:true}));}`);
const fill=async(selector,value)=>run(`{const el=document.querySelector(${JSON.stringify(selector)});el.value=${JSON.stringify(value)};el.dispatchEvent(new Event('input',{bubbles:true}));}`);
try{
 await page.goto(pathToFileURL(resolve('index.html')).href);
 await run("localStorage.removeItem('ai-integration-mock-v1');location.reload()");await sleep(900);
 await check('Initial metrics match six seeded issues',"document.querySelectorAll('.issue-row').length===6&&document.querySelectorAll('.metric strong')[3].textContent==='6'");
 await check('Recent conversations visible on first load without creating a session',"!!document.querySelector('#chat-history .history-heading')&&!!document.querySelector('.history-empty')&&getSessions().length===0");
 await click('.history-new');await fill('#chat-input','Bản nháp cần mở lại từ màn Vấn đề');await click('[data-page="issues"]');
 await check('Draft remains accessible outside chat',"!!document.querySelector('.history-draft')&&document.querySelector('.history-item').textContent.includes('Bản nháp')");
 await click('[data-session]');await check('History opens chat with correct navigation and draft',"page==='chat'&&document.querySelector('#crumb').textContent==='Trợ lí thông minh'&&document.querySelector('[data-page=chat]').getAttribute('aria-current')==='page'&&document.querySelector('#chat-input').value==='Bản nháp cần mở lại từ màn Vấn đề'");
 await fill('#chat-input','Tôi muốn tra cứu tiến độ hồ sơ');await run("document.querySelector('#chat-form').requestSubmit()");await sleep(800);await click('[data-page="issues"]');await run('location.reload()');await sleep(700);
 await check('Saved recent conversations visible immediately after reload',"page==='issues'&&document.querySelector('.history-item').textContent.includes('tra cứu')");
 await fill('#issue-search','does-not-exist');await check('Empty search state',"document.querySelectorAll('.issue-row').length===0&&!!document.querySelector('.empty')");await click('[data-action="clear-filter"]');
 await select('#role','user');await check('User has only two navigation destinations and own issues',"document.querySelectorAll('.nav-item').length===2&&document.querySelectorAll('.issue-row').length===2&&!document.querySelector('[data-issue=\"VD-1040\"]')");
 await check('History switches to selected account without leaking other sessions',"!!document.querySelector('.history-empty')&&!document.querySelector('[data-session]')");
 await click('[data-issue="VD-1042"]');await click('[data-action="withdraw"]');await check('Withdrawal requires confirmation',"document.querySelector('#dialog').open&&data.issues.find(i=>i.id==='VD-1042').state==='waiting'");await click('#confirm-withdraw');await check('Withdrawal keeps original content and appends history',"data.issues.find(i=>i.id==='VD-1042').state==='withdrawn'&&data.issues.find(i=>i.id==='VD-1042').body.length>30&&data.issues.find(i=>i.id==='VD-1042').history.length===1");
 await click('[data-page="chat"]');
 await check('Empty send button is disabled',"document.querySelector('.send-button').disabled");
 await click('[data-action="chat-sources"]');await check('Sources open on demand',"document.querySelector('#dialog').open&&!!document.querySelector('#dialog .source-item')");await click('[data-close]');
 await fill('#chat-input','Bản nháp đang nhập về hồ sơ');await click('[data-page="issues"]');await click('[data-page="chat"]');
 await check('Draft survives navigation',"document.querySelector('#chat-input').value==='Bản nháp đang nhập về hồ sơ'");
 await click('[data-action="new-chat"]');await check('New conversation preserves previous draft',"!document.querySelector('#chat-input').value&&getSessions().some(s=>s.draft==='Bản nháp đang nhập về hồ sơ')");
 await click('[data-prompt^="Tôi muốn tra cứu"]');await sleep(800);await check('Approved answer has citation',"!!document.querySelector('[data-citation=\"KT-021\"]')");await click('[data-citation="KT-021"]');await check('Citation dialog opens',"document.querySelector('#dialog').open");await click('[data-close]');
 await fill('#chat-input','Tôi muốn xuất danh sách hồ sơ theo ngày tiếp nhận nhưng không tìm thấy thao tác xuất, mong muốn có file Excel để đối soát.');await run("document.querySelector('#chat-form').requestSubmit()");await sleep(800);
 await check('Chat cannot create issue without consent',"data.issues.length===6&&!!document.querySelector('[data-proposal]')");await click('[data-proposal]');await check('Consent field required',"document.querySelector('[name=consent]').required&&!document.querySelector('[name=consent]').checked");
 await run("document.querySelector('[name=consent]').checked=true;document.querySelector('#proposal-form').requestSubmit()");await check('Confirmed issue created and linked',"data.issues.length===7&&data.issues[0].owner==='user'&&!!data.issues[0].consentAt&&!!document.querySelector('[data-issue=\"VD-1043\"]')");
 await click('[data-issue="VD-1043"]');await fill('[name=note]','Bổ sung: tôi sử dụng màn hình danh sách của đơn vị để đối soát hàng tháng.');await run("document.querySelector('#update-form').requestSubmit()");await check('Correction appends history without changing original',"data.issues[0].history.length===1&&data.issues[0].body.includes('Excel')");
 await select('#role','user2');await check('Other user cannot see newly submitted issue',"!document.querySelector('[data-issue=\"VD-1043\"]')");
 await select('#role','technician');await check('Technician cannot access configuration',"document.querySelectorAll('.nav-item').length===3&&!document.querySelector('[data-page=settings]')");await click('[data-page="knowledge"]');await click('[data-knowledge="KT-019"]');await check('Technician cannot approve knowledge',"!document.querySelector('#approve-knowledge')");await click('[data-close]');
 await select('#role','admin');await click('[data-knowledge="KT-019"]');await click('#approve-knowledge');await check('Admin can approve guidance',"data.knowledge.find(k=>k.id==='KT-019').state==='approved'");
 await click('[data-knowledge="KT-021"]');await click('#edit-knowledge');await fill('[name=text]','Mở Danh sách hồ sơ, chọn hồ sơ cần xem và kiểm tra Lịch sử xử lý. Nội dung cập nhật cần được duyệt lại.');await run("document.querySelector('#knowledge-form').requestSubmit()");await check('Editing approved guidance requires approval again',"data.knowledge.find(k=>k.id==='KT-021').state==='pending'");
 await click('[data-page="settings"]');await fill('[name=version]','2026.12');await run("document.querySelector('#settings-form').requestSubmit()");await check('Configuration saves',"data.config.version==='2026.12'");
 await run('location.reload()');await sleep(700);await check('Changes persist after reload',"data.issues.length===7&&data.config.version==='2026.12'");
 mkdirSync('.taste-skill/qa',{recursive:true});
 await run("localStorage.removeItem('ai-integration-mock-v1');location.reload()");await sleep(700);
 for(const width of [1440,768,390]){
  await page.setViewport({width,height:width===1440?900:1000});
  for(const tab of ['issues','chat','knowledge','settings']){
   await click(`[data-page="${tab}"]`);if(tab==='chat')await click('[data-action="new-chat"]');await sleep(100);
   await check(`Shared history available on ${tab} at ${width}px`,"!!document.querySelector('#chat-history .history-heading')&&!!document.querySelector('.history-new')");
   await check(`${tab} at ${width}px has no horizontal overflow`,`document.documentElement.scrollWidth<=${width}`);
   await page.screenshot({path:`.taste-skill/qa/${tab}-${width}.jpg`,fullPage:true});
   if(tab==='chat'){
    await click('[data-prompt^="Tôi muốn tra cứu"]');await sleep(800);
    await check(`History shows active conversation at ${width}px`,"document.querySelector('.history-item.selected').textContent.includes('tra cứu')");
    await page.screenshot({path:`.taste-skill/qa/chat-conversation-${width}.jpg`,fullPage:true});
    await run("{const s=currentSession();for(let n=0;n<8;n++)s.messages.push({author:n%2?'bot':'user',id:crypto.randomUUID(),text:'Tôi cần kiểm tra thông tin hồ sơ và tiến độ tiếp nhận. Vui lòng kiểm tra hướng dẫn áp dụng cho phiên bản hiện tại.'});renderChat();}");
    await check(`Long conversation scrolls with composer visible at ${width}px`,"document.querySelector('#messages').scrollHeight>document.querySelector('#messages').clientHeight&&document.querySelector('#chat-form').getBoundingClientRect().bottom<=innerHeight&&document.querySelector('#chat-form').getBoundingClientRect().top>0");
    await check(`All visible chat controls are named at ${width}px`,"Array.from(document.querySelectorAll('.assistant-screen button')).every(b=>b.getAttribute('aria-label')||Array.from(b.childNodes).some(n=>n.nodeType===3&&n.textContent.trim())||Array.from(b.querySelectorAll('span')).some(n=>getComputedStyle(n).display!=='none'&&n.textContent.trim()))");
   }
  }
 }
 await check('No uncaught JavaScript errors',JSON.stringify(page.consoleErrors.length===0));
 writeFileSync('.taste-skill/qa/results.json',JSON.stringify({passed:checks.length,checks,consoleErrors:page.consoleErrors},null,2));
 console.log(JSON.stringify({passed:checks.length,checks},null,2));
}finally{await browser.close();}
