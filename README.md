git clone https://github.com/i2b2/i2b2-docker.git

**Steps for Setting Up i2b2 Postgres (Ubuntu)**
 
1. Navigate to the i2b2-docker directory.
2. Execute the following command to start the i2b2:
```
cd pg
docker-compose up -d i2b2-web
```

3. Wait for WildFly to start.
4. Open a web browser and navigate to the following URL:
```
http://localhost/webclient
```
5. Log in to the i2b2 web application using the default credentials:
   - Username: demo
   - Password: demouser
