// Keep the preview and inspector in one execution environment on Windows.
process.env.PORT='0';
const {server}=await import('./serve.mjs');
if(!server.listening)await new Promise(resolve=>server.once('listening',resolve));
process.argv=[process.execPath,'inspect.mjs',`http://127.0.0.1:${server.address().port}/?screen=chat`,'--app','--out','.taste-skill/chat-inspect'];
try{await import('file:///C:/hoangdv/index/trunk/agent-kit/skills/taste-skill/scripts/inspect.mjs');}
finally{server.close();}
