using Microsoft.EntityFrameworkCore;
using InventoryService.Data;
using InventoryService.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddDbContext<InventoryDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"), b => b.EnableRetryOnFailure(
        maxRetryCount: 10,
        maxRetryDelay: TimeSpan.FromSeconds(10),
        errorNumbersToAdd: null)));

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