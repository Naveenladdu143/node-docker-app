FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including dev dependencies if needed)
RUN npm install

# Copy application code
COPY . .

# Stage 2: Runtime
FROM node:20-alpine

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/app.js ./

# Change ownership to non-root user
USER appuser

# Expose the application port
EXPOSE 3000

# Start the app
CMD ["node", "app.js"]

