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
