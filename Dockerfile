# Use NGINX base image
FROM nginx:alpine

# Copy HTML files to the NGINX default directory
COPY ./src /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start NGINX server
CMD ["nginx", "-g", "daemon off;"]