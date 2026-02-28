cd cloud-init
sudo python3 -m http.server 80 & 
sleep 2 && curl http://127.0.0.1/work-1.yaml
