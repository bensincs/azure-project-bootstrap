var builder = WebApplication.CreateBuilder(args);

// Log which environment and configuration is being used
Console.WriteLine($"🌍 Environment: {builder.Environment.EnvironmentName}");
Console.WriteLine($"📁 Content Root: {builder.Environment.ContentRootPath}");

// Add services to the container
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

// Configuration info endpoint
app.MapGet("/api/config", (IConfiguration config, IWebHostEnvironment env) => Results.Ok(new
{
    environment = env.EnvironmentName,
    isDevelopment = env.IsDevelopment(),
    isProduction = env.IsProduction(),
    logLevel = config["Logging:LogLevel:Default"],
    aspNetCoreLogLevel = config["Logging:LogLevel:Microsoft.AspNetCore"],
    configurationFiles = new[]
    {
        "appsettings.json (always loaded)",
        $"appsettings.{env.EnvironmentName}.json (environment-specific)"
    }
}))
    .WithName("GetConfig")
    .WithOpenApi();

// Health check endpoint
app.MapGet("/api/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
    .WithName("HealthCheck")
    .WithOpenApi();

// Hello World endpoint
app.MapGet("/api/hello", () => Results.Ok(new
{
    message = "Hello from .NET 9 API!",
    version = "1.0.0",
    timestamp = DateTime.UtcNow,
    environment = app.Environment.EnvironmentName
}))
    .WithName("GetHello")
    .WithOpenApi();

// Hello with name parameter
app.MapGet("/api/hello/{name}", (string name) => Results.Ok(new
{
    message = $"Hello, {name}!",
    timestamp = DateTime.UtcNow
}))
    .WithName("GetHelloWithName")
    .WithOpenApi();

// Root endpoint
app.MapGet("/", () => Results.Ok(new
{
    service = "API Service",
    status = "running",
    version = "1.0.0",
    endpoints = new[]
    {
        "/api/health",
        "/api/hello",
        "/api/hello/{name}",
        "/swagger"
    }
}))
    .WithName("GetRoot")
    .WithOpenApi();

var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
app.Run($"http://0.0.0.0:{port}");
