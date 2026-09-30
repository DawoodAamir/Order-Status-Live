import contextlib
"""Local reference order service. Tokens and state belong to this sample only."""
import json,os,secrets,sqlite3,time
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
DB=os.getenv('ORDER_DATABASE',str(Path(__file__).parent/'data/orders.sqlite'))
Path(DB).parent.mkdir(parents=True,exist_ok=True)
@contextlib.contextmanager
def connect():
 db=sqlite3.connect(DB,timeout=10);db.row_factory=sqlite3.Row
 try:
  with db:yield db
 finally:db.close()
with connect() as db:
 db.execute('CREATE TABLE IF NOT EXISTS orders(id TEXT PRIMARY KEY,stage INTEGER,revision INTEGER,updatedAt REAL)')
 db.execute('INSERT OR IGNORE INTO orders VALUES (?,?,?,?)',('OS-2048',0,0,time.time()))
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*_):pass
 def dispatch(self):
  try:
   token=self.headers.get('Authorization','').removeprefix('Bearer ')
   operator=secrets.compare_digest(token,os.getenv('ORDER_OPERATOR_TOKEN','sample-operator'))
   reader=secrets.compare_digest(token,os.getenv('ORDER_READ_TOKEN','sample-reader'))
   if not (operator or reader):return self.reply(401,{'error':'Invalid token.'})
   if self.path!='/orders/OS-2048':return self.reply(404,{'error':'Not found.'})
   with connect() as db:
    db.execute('BEGIN IMMEDIATE');row=dict(db.execute('SELECT * FROM orders WHERE id=?',('OS-2048',)).fetchone())
    if self.command=='POST':
     if not operator:return self.reply(403,{'error':'Operator token required.'})
     size=int(self.headers.get('Content-Length',0))
     if not 0<size<10000:return self.reply(413,{'error':'Invalid request size.'})
     body=json.loads(self.rfile.read(size))
     if not isinstance(body,dict) or type(body.get('stage')) is not int or body.get('stage')!=row['stage']+1 or row['stage']==4:return self.reply(400,{'error':'Advance exactly one stage.'})
     if body.get('revision')!=row['revision']:return self.reply(409,{'error':'Order changed; reload before updating.'})
     row.update(stage=body['stage'],revision=row['revision']+1,updatedAt=time.time())
     db.execute('UPDATE orders SET stage=?,revision=?,updatedAt=? WHERE id=?',(row['stage'],row['revision'],row['updatedAt'],row['id']))
   self.reply(200,row)
  except (ValueError,TypeError,KeyError):self.reply(400,{'error':'Invalid request.'})
 def reply(self,status,obj):
  raw=json.dumps(obj).encode();self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(raw)
 do_GET=dispatch
 do_POST=dispatch
if __name__=='__main__':ThreadingHTTPServer(('127.0.0.1',8092),Handler).serve_forever()
