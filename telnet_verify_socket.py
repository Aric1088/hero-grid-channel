import socket
import time

HOST = '192.168.1.155'
PORT = 8085

try:
    print(f'Connecting to {HOST}:{PORT}...')
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect((HOST, PORT))
    s.setblocking(0)
    
    start_time = time.time()
    output = []
    
    while time.time() - start_time < 5:
        try:
            data = s.recv(4096)
            if data:
                output.append(data.decode('utf-8', errors='replace'))
        except BlockingIOError:
            pass
        except Exception as e:
            pass
        time.sleep(0.5)
        
    s.close()
    
    if output:
        print(''.join(output))
    else:
        print('No output received from telnet.')
except Exception as e:
    print(f'Failed to connect or read: {e}')
