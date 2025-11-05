#!/bin/bash
set -e

echo "🔧 Bootstrapping microservices for .NET 8.0 (clean slate)..."

# Clean previous attempts
rm -rf microservices
mkdir -p microservices/{inventory-service,order-service,user-service}

cd microservices

# Create projects with default template (.NET 9), we'll patch to 8.0 after
for service in inventory-service order-service user-service; do
  echo "Scaffolding $service..."
  dotnet new webapi -n $service --no-https --force
  cd $service

  # Add .NET 8-compatible packages (after scaffold)
  if [ "$service" = "inventory-service" ] || [ "$service" = "user-service" ]; then
    dotnet add package Microsoft.EntityFrameworkCore.SqlServer --version 8.0.8
    dotnet add package Microsoft.EntityFrameworkCore.Tools --version 8.0.8
  fi
  if [ "$service" = "order-service" ]; then
    dotnet add package Azure.Messaging.EventHubs --version 5.12.2  # Latest stable for .NET 8
  fi
  dotnet add package System.Net.Http.Json --version 8.0.0

  # Patch TargetFramework to net8.0
  sed -i 's|<TargetFramework>net9.0</TargetFramework>|<TargetFramework>net8.0</TargetFramework>|g' $service.csproj

  # Remove .NET 9-specific OpenApi package and add .NET 8 Swagger
  dotnet remove package Microsoft.AspNetCore.OpenApi
  dotnet add package Swashbuckle.AspNetCore --version 6.5.0

  cd ..
done

cd ..

# Inventory Service Files
mkdir -p microservices/inventory-service/{Models,Data}

cat > microservices/inventory-service/Program.cs << 'EOF'
using Microsoft.EntityFrameworkCore;
using InventoryService.Data;
using InventoryService.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddDbContext<InventoryDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapGet("/inventory", async (InventoryDbContext db) => await db.InventoryItems.ToListAsync());
app.MapPost("/inventory", async (InventoryItem item, InventoryDbContext db) => {
    db.InventoryItems.Add(item);
    await db.SaveChangesAsync();
    return Results.Created($"/inventory/{item.Id}", item);
});

app.Run();
EOF

cat > microservices/inventory-service/Models/InventoryItem.cs << 'EOF'
namespace InventoryService.Models;

public class InventoryItem
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Price { get; set; }
}
EOF

cat > microservices/inventory-service/Data/InventoryDbContext.cs << 'EOF'
using Microsoft.EntityFrameworkCore;
using InventoryService.Models;

namespace InventoryService.Data;

public class InventoryDbContext : DbContext
{
    public InventoryDbContext(DbContextOptions<InventoryDbContext> options) : base(options) { }
    public DbSet<InventoryItem> InventoryItems { get; set; }
}
EOF

cat > microservices/inventory-service/appsettings.json << 'EOF'
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=InventoryMicro;Trusted_Connection=true;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# Order Service (Fixed: Use 'using' not 'await using' for EventDataBatch)
cat > microservices/order-service/Program.cs << 'EOF'
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton<EventHubProducerClient>(sp => 
    new EventHubProducerClient(builder.Configuration["EventHub:ConnectionString"], "order-events"));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapPost("/orders", async (OrderRequest req, EventHubProducerClient client) => {
    var eventData = new EventData(System.Text.Encoding.UTF8.GetBytes(System.Text.Json.JsonSerializer.Serialize(req)));
    using var batch = await client.CreateBatchAsync();
    if (!batch.TryAdd(eventData))
    {
        return Results.BadRequest("Failed to add event to batch.");
    }
    await client.SendAsync(batch);
    return Results.Ok("Order event published!");
});

app.Run();

public record OrderRequest(string ItemName, int Quantity);
EOF

cat > microservices/order-service/appsettings.json << 'EOF'
{
  "EventHub": {
    "ConnectionString": "Endpoint=sb://your-eventhub.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=yourkey"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# User Service
cat > microservices/user-service/Program.cs << 'EOF'
using System.Net.Http.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHttpClient();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapGet("/users/{id}", async (HttpClient http, int id) => {
    // Mock HRIS call
    var user = await http.GetFromJsonAsync<User>($"https://jsonplaceholder.typicode.com/users/{id}");
    return Results.Ok(user);
});

app.Run();

public record User(string Name, string Email);
EOF

cat > microservices/user-service/appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# Dockerfiles (unchanged, .NET 8 base is good)
for service in inventory-service order-service user-service; do
  cat > microservices/$service/Dockerfile << EOF
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["$service.csproj", "."]
RUN dotnet restore "$service.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "$service.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "$service.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "$service.dll"]
EOF
done

# Restore all to verify (local check before Docker)
echo "🧪 Local restore test..."
for service in inventory-service order-service user-service; do
  cd microservices/$service
  dotnet restore
  dotnet build
  cd ../..
done

echo "✅ Microservices bootstrapped for .NET 8.0! Ready for docker-compose build."