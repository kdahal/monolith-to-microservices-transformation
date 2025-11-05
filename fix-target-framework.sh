#!/bin/bash
set -e

echo "🔧 Patching TargetFramework to net8.0 in all .csproj files..."

# Find and replace in monolith
if [ -d "monolith" ]; then
  find monolith -name "*.csproj" -exec sed -i 's|<TargetFramework>net9.0</TargetFramework>|<TargetFramework>net8.0</TargetFramework>|g' {} \;
  echo "✅ Monolith patched."
fi

# Find and replace in microservices
if [ -d "microservices" ]; then
  find microservices -name "*.csproj" -exec sed -i 's|<TargetFramework>net9.0</TargetFramework>|<TargetFramework>net8.0</TargetFramework>|g' {} \;
  echo "✅ Microservices patched."
fi

echo "✅ All projects now target .NET 8.0. Rebuild with docker-compose build."