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
