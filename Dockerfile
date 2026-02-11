# Simple Node.js application Dockerfile
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Create a simple package.json
RUN echo '{
  "name": "simple-app",
  "version": "1.0.0",
  "description": "A simple Node.js app",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  }
}' > package.json

# Create a simple index.js that runs a web server
RUN echo 'const http = require("http");
const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end("<h1>Hello from Docker!</h1><p>App is running successfully!</p>");
});
server.listen(3000, () => console.log("Server running on port 3000"));' > index.js

# Expose port
EXPOSE 3000

# Run the app
CMD ["node", "index.js"]
