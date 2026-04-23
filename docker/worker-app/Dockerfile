# Use a lightweight Debian image
FROM debian:12-slim

# Install Python and curl
RUN apt-get update && apt-get install -y python3 python3-pip curl

# Set the working directory
WORKDIR /app

# Copy the application code
COPY app.py .

# Install Flask
RUN pip3 install flask --break-system-packages

# Expose port 5000 for the Flask app
EXPOSE 5000

# Run the application
CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0"]