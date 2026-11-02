import {existsSync,readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
const files=['index.html','assets/css/app.css','assets/js/app.js','README.md','docs/overview.html','docs/nghiep-vu.md','docs/tech-stack.md','docs/mock-guide.md','docs/ui-ux-review.md'];
let links=0;
for(const file of files){
 if(!existsSync(file))throw Error(`Missing ${file}`);
 if(!/\.(html|md)$/.test(file))continue;
 const text=readFileSync(file,'utf8');
 const refs=file.endsWith('.html')?[...text.matchAll(/(?:href|src)="([^"]+)"/g)].map(m=>m[1]):[...text.matchAll(/\]\(([^)]+)\)/g)].map(m=>m[1]);
 for(const ref of refs){
  if(/^(https?:|mailto:|#)/.test(ref))continue;
  const target=decodeURIComponent(ref.split(/[?#]/)[0]);
  if(!existsSync(resolve(dirname(file),target)))throw Error(`Broken link: ${file} -> ${ref}`);
  links++;
 }
}
process.env.PORT='0';
const {server}=await import('./serve.mjs');
if(!server.listening)await new Promise(resolve=>server.once('listening',resolve));
try{
 const base=`http://127.0.0.1:${server.address().port}`;
 for(const path of ['/','/assets/css/app.css','/assets/js/app.js','/docs/overview.html','/docs/nghiep-vu.md','/docs/tech-stack.md','/docs/mock-guide.md','/docs/ui-ux-review.md']){
  const response=await fetch(base+path);if(response.status!==200)throw Error(`HTTP ${response.status}: ${path}`);
 }
 console.log(JSON.stringify({files:files.length,localLinks:links,httpRoutes:8,result:'PASS'}));
}finally{server.close();}
