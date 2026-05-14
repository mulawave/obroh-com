#!/bin/bash

# Obroh.com Development Server Starter
# Starts all three services: backend (5000), website (3000), admin (3001)

set -e

echo "🚀 Starting Obroh.com Development Environment"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "backend/src/server.ts" ]; then
    echo "❌ Error: Please run this script from the obroh.com root directory"
    exit 1
fi

# Function to start a service in background
start_service() {
    local name=$1
    local path=$2
    local script=$3
    local port=$4
    
    echo "📦 Starting $name on port $port..."
    
    (
        cd "$path"
        echo "🔄 Installing dependencies for $path..."
        npm install
        if [ $? -ne 0 ]; then
            echo "❌ Failed to install dependencies in $path"
            exit 1
        fi
        echo "✅ Dependencies installed for $path"
        echo "🚀 Starting $script..."
        npm run "$script"
    ) &
    
    local pid=$!
    echo "✅ $name started (PID: $pid)"
    echo "$pid" > "/tmp/obroh-$name.pid"
    return $pid
}

# Create logs directory
mkdir -p logs

# Start all three services
echo ""
echo "🔧 Starting services..."

start_service "Backend API" "backend" "dev" "5000" &
BACKEND_PID=$!

start_service "Website Frontend" "website" "dev" "3000" &
WEBSITE_PID=$!

start_service "Admin Panel" "admin" "dev" "3001" &
ADMIN_PID=$!

echo ""
echo "⏳ Waiting for services to start..."

# Wait a bit for services to initialize
sleep 8

echo ""
echo "📊 Service Status:"
echo "-------------------"

# Function to check if service is running
check_service() {
    local pid=$1
    local name=$2
    if kill -0 "$pid" 2>/dev/null; then
        echo "✅ $name is running (PID: $pid)"
    else
        echo "❌ $name failed to start"
    fi
}

check_service $BACKEND_PID "Backend API"
check_service $WEBSITE_PID "Website Frontend"
check_service $ADMIN_PID "Admin Panel"

echo ""
echo "🌐 Development URLs:"
echo "-------------------"
echo "🔗 Website:     http://localhost:3000"
echo "🔗 Admin Panel: http://localhost:3001"
echo "🔗 Backend API: http://localhost:5000"
echo "🔗 API Health:  http://localhost:5000/api/health"

echo ""
echo "📝 To stop all services, run:"
echo "kill \$BACKEND_PID \$WEBSITE_PID \$ADMIN_PID"
echo "Or run: ./stop-dev.sh"

echo ""
echo "🎉 Development environment ready!"
echo "Press Ctrl+C to stop all services"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "👋 Stopping all services..."
    kill $BACKEND_PID $WEBSITE_PID $ADMIN_PID 2>/dev/null || true
    rm -f /tmp/obroh-*.pid
    echo "✅ All services stopped"
    exit 0
}

# Trap Ctrl+C to cleanup
trap cleanup INT

# Wait for services
wait
