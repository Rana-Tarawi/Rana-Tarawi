# Use a proper Nginx image
FROM nginx:latest

# Copy HTML file to Nginx
COPY index.html /usr/share/nginx/html/index.html

# Run Nginx 
ENTRYPOINT nginx -g "daemon off;"
