# Etapa 1: Compilación de la aplicación React con Node.js
FROM node:18-alpine AS build
WORKDIR /app

# Copiar los archivos de dependencias de node
COPY package*.json ./

# Instalar las dependencias de producción y desarrollo necesarias para compilar con Vite
run npm install

# Copiar todo el código fuente del frontend
COPY . .

# Compilar el frontend (genera la carpeta /dist con el código estático optimizado)
run npm run build

# Etapa 2: Servidor web de producción utilizando Nginx
FROM nginx:1.23-alpine

# Copiar los archivos compilados desde la etapa anterior al directorio público de Nginx
COPY --from=build /app/dist /usr/share/nginx/html

# Exponer el puerto HTTP estándar
EXPOSE 80

# Iniciar Nginx en primer plano
CMD ["nginx", "-g", "daemon off;"]