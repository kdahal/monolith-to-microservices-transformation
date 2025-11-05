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
