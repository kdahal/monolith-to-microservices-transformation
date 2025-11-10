using Microsoft.EntityFrameworkCore;
using InventoryService.Data;
using InventoryService.Models;

var builder = WebApplication.CreateBuilder(args);

// ------------------------------------
// --- Service Configuration ---
// ------------------------------------
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure DbContext with Connection Resilience (GOOD)
builder.Services.AddDbContext<InventoryDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"), b => b.EnableRetryOnFailure(
        maxRetryCount: 10,
        maxRetryDelay: TimeSpan.FromSeconds(10),
        errorNumbersToAdd: null)));

var app = builder.Build();

// ------------------------------------
// --- Middleware Configuration ---
// ------------------------------------
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// --- Database Initialization (Running the fixed helper method) ---
await EnsureDatabaseCreated(app);

// ------------------------------------
// --- API Endpoints ---
// ------------------------------------
// This line relies on the table being created by the above logic
app.MapGet("/inventory", async (InventoryDbContext db) => await db.InventoryItems.ToListAsync());

app.MapPost("/inventory", async (InventoryItem item, InventoryDbContext db) => {
    db.InventoryItems.Add(item);
    await db.SaveChangesAsync();
    return Results.Created($"/inventory/{item.Id}", item);
});

app.Run();

// ------------------------------------
// --- Fixed Helper Method ---
// ------------------------------------
// This method handles database creation and migration on startup with retries.
async Task EnsureDatabaseCreated(IHost app)
{
    // Use a scope for dependency injection
    using (var scope = app.Services.CreateScope())
    {
        var services = scope.ServiceProvider;
        const int maxRetries = 10;
        
        for (int i = 0; i < maxRetries; i++)
        {
            try
            {
                var context = services.GetRequiredService<InventoryDbContext>();
                
                // CRITICAL FIX: Only call Migrate(). 
                // Migrate() handles both database creation and applying schema changes.
                Console.WriteLine("Applying database migrations...");
                await context.Database.MigrateAsync(); // Using async version
                
                // Seed the database after migration (if applicable)
                // InventoryDbContextSeed.SeedAsync(context).Wait(); 
                
                Console.WriteLine("Database migration and seeding complete.");
                break; // Success! Exit the loop
            }
            catch (Microsoft.Data.SqlClient.SqlException ex)
            {
                // Only retry on connection errors
                if (ex.Number == 40 || ex.Message.Contains("Could not open a connection"))
                {
                    Console.WriteLine($"Database connection failed. Retrying in 5 seconds... ({i + 1}/{maxRetries})");
                    // Wait synchronously (safe here as it's outside the main request pipeline)
                    System.Threading.Thread.Sleep(5000); 
                }
                else
                {
                    // Log and re-throw non-recoverable errors (e.g., table missing due to bad migration)
                    Console.WriteLine("A non-recoverable SQL or migration error occurred: " + ex.Message);
                    throw;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("An unexpected application error occurred during migration: " + ex.Message);
                throw;
            }
        }
    }
}