import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.md':'text/plain; charset=utf-8'};
export const server=createServer(async(req,res)=>{
 try{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(!['/','/index.html','/README.md'].includes(pathname)&&!pathname.startsWith('/assets/')&&!pathname.startsWith('/docs/')){res.writeHead(404);res.end();return;}
  const path=resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!path.startsWith(root+sep)||!mime[extname(path)]){res.writeHead(404);res.end();return;}
  const content=await readFile(path);res.writeHead(200,{'Content-Type':mime[extname(path)],'Cache-Control':'no-store'});res.end(content);
 }catch{res.writeHead(404);res.end();}
}).listen(Number(process.env.PORT||4173),'127.0.0.1',()=>console.log(`http://127.0.0.1:${server.address().port}/?screen=chat`));
