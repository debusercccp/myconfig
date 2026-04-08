import sys
from socket import *

myHost = '0.0.0.0'
myPort = 50007

sockobj = socket(AF_INET, SOCK_STREAM)
sockobj.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)

try:
    sockobj.bind((myHost, myPort))
except OSError:
    print(f"Port {myPort} is still busy. Try 'fuser -k {myPort}/tcp'")
    sys.exit(1)

sockobj.listen(5)
print(f"Server listening on {myPort}...")

while True:
    connection, address = sockobj.accept()
    print('Server connected by', address)
    i = 0
    try:
        while True:
            data = connection.recv(1024)
            if not data: break
            
            connection.send(b'Echo=>' + data)
            
            # Fixed the print/send logic
            log_msg = f"i: {i}\n"
            print(log_msg, end='')
            connection.send(log_msg.encode('utf-8'))
            i += 1
    finally:
        connection.close()
