import importlib.util,json,os,tempfile,threading,unittest,uuid
from urllib.request import Request,urlopen
from urllib.error import HTTPError
from http.server import ThreadingHTTPServer
from pathlib import Path
TEMP=tempfile.TemporaryDirectory()
os.environ["ORDER_DATABASE"]=str(Path(TEMP.name)/"test.sqlite")
spec=importlib.util.spec_from_file_location("service",Path(__file__).with_name("server.py"));service=importlib.util.module_from_spec(spec);spec.loader.exec_module(service)
class APITests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.server=ThreadingHTTPServer(('127.0.0.1',0),service.Handler);cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start();cls.origin='http://127.0.0.1:'+str(cls.server.server_port)
 @classmethod
 def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.thread.join();TEMP.cleanup()
 def request(self,path,body=None,token=None,method=None):
  raw=json.dumps(body).encode() if body is not None else None;req=Request(self.origin+path,data=raw,method=method or ('POST' if body is not None else 'GET'),headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
  try:
   with urlopen(req,timeout=5) as response:return response.status,json.load(response)
  except HTTPError as error:
   try:return error.code,json.load(error)
   finally:error.close()

 def setUp(self):
  with service.connect() as db:db.execute('UPDATE orders SET stage=0,revision=0')
 def testReaderCannotAdvanceAndStaleOperatorIsRejected(self):
  self.assertEqual(self.request('/orders/OS-2048')[0],401);self.assertEqual(self.request('/orders/OS-2048',{'stage':1,'revision':0},'sample-reader')[0],403)
  status,order=self.request('/orders/OS-2048',{'stage':1,'revision':0},'sample-operator');self.assertEqual(status,200);self.assertEqual(order['revision'],1)
  self.assertEqual(self.request('/orders/OS-2048',{'stage':2,'revision':0},'sample-operator')[0],409)
 def testStatesCannotSkipOrGoBackwards(self):
  self.assertEqual(self.request('/orders/OS-2048',{'stage':3,'revision':0},'sample-operator')[0],400)
  for stage in range(1,5):self.assertEqual(self.request('/orders/OS-2048',{'stage':stage,'revision':stage-1},'sample-operator')[0],200)
  self.assertEqual(self.request('/orders/OS-2048',{'stage':5,'revision':4},'sample-operator')[0],400)
if __name__=='__main__':unittest.main()
