#!/bin/bash

# Monolith-to-Microservices-Transformation Init Script
# Run this to set up the local environment after cloning the repo.
# Assumes: Git, Docker, kubectl, Azure CLI, .NET 8 SDK installed.

set -e  # Exit on any error

echo "🚀 Initializing Monolith-to-Microservices-Transformation Repo..."

# Check prerequisites
command -v dotnet >/dev/null 2>&1 || { echo "❌ .NET 8 SDK not found. Install from https://dotnet.microsoft.com/download/dotnet/8.0"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found. Install from https://www.docker.com"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found. Install from https://www.terraform.io/downloads"; exit 1; }
command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI not found. Install from https://docs.microsoft.com/cli/azure/install-azure-cli"; exit 1; }

# Azure login (interactive)
echo "🔐 Logging into Azure (if not already)..."
az login

# Bootstrap monolith: Always overwrite custom files for consistency
echo "📦 Setting up monolith for .NET 8.0..."
rm -rf monolith
mkdir -p monolith
cd monolith

# Create MVC project in subdir
dotnet new mvc -n InventoryApp --no-https --force
cd InventoryApp

# Add packages for .NET 8
dotnet add package Microsoft.EntityFrameworkCore.SqlServer --version 8.0.8
dotnet add package Microsoft.EntityFrameworkCore.Tools --version 8.0.8

# Patch TargetFramework to net8.0
sed -i 's|<TargetFramework>net9.0</TargetFramework>|<TargetFramework>net8.0</TargetFramework>|g' InventoryApp.csproj

# Create dirs for custom files
mkdir -p Models Data Views/Inventory

# Create custom Model
cat > Models/InventoryItem.cs << 'EOF'
using System.ComponentModel.DataAnnotations;

namespace InventoryApp.Models;

public class InventoryItem
{
    public int Id { get; set; }
    [Required]
    public string Name { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Price { get; set; }
}
EOF

# Create DbContext
cat > Data/InventoryDbContext.cs << 'EOF'
using Microsoft.EntityFrameworkCore;
using InventoryApp.Models;

namespace InventoryApp.Data;

public class InventoryDbContext : DbContext
{
    public InventoryDbContext(DbContextOptions<InventoryDbContext> options) : base(options) { }

    public DbSet<InventoryItem> InventoryItems { get; set; }
}
EOF

# .NET 8 Program.cs (with EF using for UseSqlServer)
cat > Program.cs << 'EOF'
using Microsoft.EntityFrameworkCore;
using InventoryApp.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllersWithViews();
builder.Services.AddDbContext<InventoryDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

// Configure pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();  // Classic static files
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
EOF

# Update appsettings.json
cat > appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=InventoryDb;Trusted_Connection=true;MultipleActiveResultSets=true"
  }
}
EOF

# Create Controller
cat > Controllers/InventoryController.cs << 'EOF'
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using InventoryApp.Data;
using InventoryApp.Models;

namespace InventoryApp.Controllers;

public class InventoryController : Controller
{
    private readonly InventoryDbContext _context;

    public InventoryController(InventoryDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index()
    {
        return View(await _context.InventoryItems.ToListAsync());
    }

    [HttpPost]
    public async Task<IActionResult> Add(InventoryItem item)
    {
        if (ModelState.IsValid)
        {
            _context.Add(item);
            await _context.SaveChangesAsync();
            return RedirectToAction(nameof(Index));
        }
        return View(item);
    }
}
EOF

# Create View (fixed: static labels, manual form fields to avoid model binding issues)
cat > Views/Inventory/Index.cshtml << 'EOF'
@model IEnumerable<InventoryApp.Models.InventoryItem>

@{
    ViewData["Title"] = "Inventory List (Monolith Demo)";
}

<h2>@ViewData["Title"]</h2>

<table class="table">
    <thead>
        <tr>
            <th>Name</th>
            <th>Quantity</th>
            <th>Price</th>
        </tr>
    </thead>
    <tbody>
@foreach (var item in Model) {
        <tr>
            <td>@item.Name</td>
            <td>@item.Quantity</td>
            <td>@item.Price</td>
        </tr>
}
    </tbody>
</table>

<h3>Add Item</h3>
<form asp-action="Add" method="post">
    <div class="form-group">
        <label class="control-label">Name</label>
        <input name="Name" class="form-control" />
    </div>
    <div class="form-group">
        <label class="control-label">Quantity</label>
        <input name="Quantity" class="form-control" type="number" />
    </div>
    <div class="form-group">
        <label class="control-label">Price</label>
        <input name="Price" class="form-control" type="number" step="0.01" />
    </div>
    <div class="form-group">
        <input type="submit" value="Add" class="btn btn-primary" />
    </div>
</form>
EOF

  cd ../..
  echo "✅ Monolith scaffolded/patched for .NET 8.0!"

# Now restore and build monolith
echo "📦 Restoring .NET packages for monolith..."
cd monolith/InventoryApp
dotnet restore
dotnet build
cd ../..

# Bootstrap microservices if needed
if [ ! -f "microservices/inventory-service/inventory-service.csproj" ]; then
  echo "🔧 Bootstrapping microservices..."
  ./bootstrap-microservices.sh
else
  echo "🔧 Microservices already exist, skipping bootstrap."
fi

# EF Migrations for monolith DB
echo "🗄️ Running EF migrations for monolith..."
cd monolith/InventoryApp
if [ ! -d "Migrations" ]; then
  dotnet ef migrations add InitialCreate --startup-project .
  echo "✅ Monolith migration created."
else
  echo "⚠️ Monolith migrations dir exists, skipping add."
fi
dotnet ef database update --startup-project .
echo "✅ Monolith DB updated."
cd ../..

# EF Migrations for inventory-service DB
echo "🗄️ Running EF migrations for inventory-service..."
cd microservices/inventory-service
if [ ! -d "Migrations" ]; then
  dotnet ef migrations add InitialCreate --startup-project .
  echo "✅ Inventory migration created."
else
  echo "⚠️ Inventory migrations dir exists, skipping add."
fi
dotnet ef database update --startup-project .
echo "✅ Inventory DB updated."
cd ../..

# Build and start Docker for microservices
echo "🐳 Building Docker images for microservices..."
cd microservices
docker-compose build
docker-compose up -d
cd ..

# Terraform init for infrastructure
echo "🌐 Initializing Terraform for Azure infra..."
if [ -d "infrastructure/terraform" ]; then
  cd infrastructure/terraform
  terraform init
  cd ../..
else
  echo "⚠️ infrastructure/terraform not found; create it first."
fi

# Apply Kubernetes manifests (assumes AKS; skip for now)
echo "☸️ Kubernetes setup skipped (run manually after Terraform)."

# Set up observability (assumes docker-compose.yml; skip for now)
echo "📊 Observability setup skipped (add docker-compose.yml)."

# Run tests (basic; add more later)
echo "🧪 Running unit tests... (skipping advanced for now)"
# dotnet test --no-restore  # Uncomment when tests dir ready

# Final check
echo "✅ Setup complete! Monolith & Microservices ready."
echo "Test Monolith: cd monolith/InventoryApp && dotnet run (visit https://localhost:5xxx/Inventory)"
echo "Test Microservices: curl http://localhost:5001/inventory (empty; POST to add)"
echo "Swagger: http://localhost:5001/swagger | Logs: docker-compose logs -f"
echo "Next: terraform plan/apply in infrastructure/terraform."