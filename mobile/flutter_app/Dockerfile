# Flutter Web Production Image (Lightweight Nginx Alpine)
FROM nginx:alpine

# Copy static Web / PWA build artifacts
COPY build/web /usr/share/nginx/html

# Copy custom Nginx configuration with API reverse-proxying
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
