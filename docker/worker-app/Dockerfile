# docker/worker-app/Dockerfile
# Lightweight Debian 12 base image for the Flask application
FROM debian:12-slim

# Install Python 3 and curl (curl used for manual health checks)
RUN apt-get update && apt-get install -y python3 python3-pip curl

# Set working directory inside the container
WORKDIR /app

# Copy only the application source file
COPY app.py .

# Install Flask — --break-system-packages required on Debian 12+
RUN pip3 install flask --break-system-packages

# Expose Flask's default port
EXPOSE 5000

# Start the Flask development server bound to all interfaces
CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0"]
