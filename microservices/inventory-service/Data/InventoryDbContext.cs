using Microsoft.EntityFrameworkCore;
using InventoryService.Models;

namespace InventoryService.Data;

public class InventoryDbContext : DbContext
{
    public InventoryDbContext(DbContextOptions<InventoryDbContext> options) : base(options) { }
    
    public DbSet<InventoryItem> InventoryItems { get; set; }

    // --- RECOMMENDED FIX FOR DECIMAL WARNING ---
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Explicitly set the SQL Server data type for the Price property 
        // to prevent the "silently truncated" warning and ensure precision.
        modelBuilder.Entity<InventoryItem>()
            .Property(i => i.Price)
            .HasColumnType("decimal(18, 4)"); 

        base.OnModelCreating(modelBuilder);
    }
}