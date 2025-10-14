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

// User info endpoint - returns user details from APIM headers
app.MapGet("/api/user/me", (HttpContext context) =>
{
    // Get user claims from APIM headers
    var email = context.Request.Headers["X-User-Email"].FirstOrDefault();
    var oid = context.Request.Headers["X-User-OID"].FirstOrDefault();
    var name = context.Request.Headers["X-User-Name"].FirstOrDefault();
    var groupsHeader = context.Request.Headers["X-User-Groups"].FirstOrDefault();
    var rolesHeader = context.Request.Headers["X-User-Roles"].FirstOrDefault();

    // Parse groups and roles (they come as JSON arrays or comma-separated)
    string[]? groups = null;
    string[]? roles = null;

    try
    {
        if (!string.IsNullOrEmpty(groupsHeader))
        {
            groups = System.Text.Json.JsonSerializer.Deserialize<string[]>(groupsHeader);
        }
    }
    catch
    {
        // If not JSON, try splitting by comma
        groups = groupsHeader?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    try
    {
        if (!string.IsNullOrEmpty(rolesHeader))
        {
            roles = System.Text.Json.JsonSerializer.Deserialize<string[]>(rolesHeader);
        }
    }
    catch
    {
        // If not JSON, try splitting by comma
        roles = rolesHeader?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    return Results.Ok(new
    {
        email = email ?? "unknown",
        oid = oid ?? "unknown",
        name = name ?? "unknown",
        groups = groups ?? Array.Empty<string>(),
        roles = roles ?? Array.Empty<string>(),
        groupCount = groups?.Length ?? 0,
        roleCount = roles?.Length ?? 0,
        timestamp = DateTime.UtcNow
    });
})
    .WithName("GetCurrentUser")
    .WithOpenApi()
    .WithDescription("Returns current user information including groups and roles from Azure AD");

// Admin-only endpoint example - checks for Admin role
app.MapGet("/api/admin/test", (HttpContext context) =>
{
    var rolesHeader = context.Request.Headers["X-User-Roles"].FirstOrDefault();
    var name = context.Request.Headers["X-User-Name"].FirstOrDefault();
    
    string[]? roles = null;
    try
    {
        if (!string.IsNullOrEmpty(rolesHeader))
        {
            roles = System.Text.Json.JsonSerializer.Deserialize<string[]>(rolesHeader);
        }
    }
    catch
    {
        roles = rolesHeader?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    // Check if user has Admin role
    var isAdmin = roles?.Contains("Admin", StringComparer.OrdinalIgnoreCase) ?? false;

    if (!isAdmin)
    {
        return Results.Json(
            new { error = "Forbidden", message = "This endpoint requires Admin role" },
            statusCode: 403
        );
    }

    return Results.Ok(new
    {
        message = $"Welcome, Admin {name}!",
        adminFeatures = new[]
        {
            "User Management",
            "System Configuration",
            "Audit Logs",
            "Advanced Analytics"
        },
        timestamp = DateTime.UtcNow
    });
})
    .WithName("AdminTest")
    .WithOpenApi()
    .WithDescription("Admin-only endpoint - requires Admin role");

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
        "/api/user/me",
        "/api/admin/test",
        "/swagger"
    }
}))
    .WithName("GetRoot")
    .WithOpenApi();

var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
app.Run($"http://0.0.0.0:{port}");
