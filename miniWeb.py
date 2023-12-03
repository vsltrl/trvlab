from http.server import BaseHTTPRequestHandler, HTTPServer
import requests

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = "http://" + self.path[1:]
        try:
            response = requests.get(url)
            if response.status_code == 200:
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b'Success')
            else:
                self.send_response(400)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b'Failure')
        except requests.exceptions.RequestException:
            self.send_response(400)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Failure')

def run(server_class=HTTPServer, handler_class=RequestHandler, port=8080):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print('Starting server...')
    httpd.serve_forever()

run()
