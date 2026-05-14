#!/bin/bash

# Obroh.com Development Server Stopper
# Stops all three services

echo "🛑 Stopping Obroh.com Development Environment"
echo "=========================================="

# Kill processes by PID files if they exist
for name in "Backend API" "Website Frontend" "Admin Panel"; do
    if [ -f "/tmp/obroh-$name.pid" ]; then
        pid=$(cat "/tmp/obroh-$name.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "🛑 Stopping $name (PID: $pid)"
            kill "$pid"
        else
            echo "⚠️  $name process not running"
        fi
        rm -f "/tmp/obroh-$name.pid"
    fi
done

# Also kill by common process names
echo "🔍 Checking for remaining Node processes..."
pkill -f "npm run dev" 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true

echo "✅ All services stopped"
