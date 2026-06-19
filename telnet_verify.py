import telnetlib
import time
import sys

HOST = '192.168.1.155'
PORT = 8085

try:
    print(f'Connecting to {HOST}:{PORT}...')
    tn = telnetlib.Telnet(HOST, PORT, timeout=5)
    
    # Read output for 5 seconds
    start_time = time.time()
    output = []
    
    while time.time() - start_time < 5:
        try:
            line = tn.read_very_eager().decode('utf-8', errors='replace')
            if line:
                output.append(line)
            time.sleep(0.5)
        except Exception as e:
            pass
            
    tn.close()
    
    if output:
        print(''.join(output))
    else:
        print('No output received from telnet.')
        
except Exception as e:
    print(f'Failed to connect or read: {e}')
