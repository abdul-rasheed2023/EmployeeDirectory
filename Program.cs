using Amazon.S3;
using EmployeeDirectory.Data;
using EmployeeDirectory.Repositories;
using EmployeeDirectory.Services;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// --- MVC ---
builder.Services.AddControllersWithViews();

// --- Storage provider switch ---
// "MySql" -> EF Core against RDS/MySQL (what actually runs in EKS).
// "Json"  -> flat JSON file on local disk, no database required at all.
// Controlled by config key Storage:Provider, i.e. env var Storage__Provider.
// Defaults to Json so a fresh clone runs with zero external dependencies.
var storageProvider = builder.Configuration["Storage:Provider"];
if (string.IsNullOrEmpty(storageProvider))
{
    throw new InvalidOperationException("Storage:Provider must be configured.");
}
var useMySql = storageProvider.Equals("MySql", StringComparison.OrdinalIgnoreCase);
Console.WriteLine($"[startup] Storage:Provider resolved to '{storageProvider}' (source: appsettings, env vars, or launchSettings — env vars win if both are set)");

string? connectionString = null;

if (useMySql)
{
    connectionString = builder.Configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException(
            "Storage:Provider is 'MySql' but ConnectionStrings:Default is not configured.");

    // NOTE: ServerVersion.AutoDetect is intentionally NOT called here.
    // AddDbContext registers this lambda lazily — it only runs when AppDbContext
    // is first resolved from DI, which happens on the first incoming request,
    // not at startup. A try/catch here would never fire. Real connectivity
    // verification happens after app.Build(), below, where it actually runs
    // at startup and can be caught.
    builder.Services.AddDbContext<AppDbContext>(options =>
        options.UseMySql(connectionString, new MySqlServerVersion(new Version(8, 4, 11))));

    builder.Services.AddScoped<IEmployeeRepository, EfEmployeeRepository>();

    builder.Services.AddHealthChecks()
        .AddMySql(connectionString, name: "mysql", tags: new[] { "ready" });
}
else
{
    // Singleton: it owns an in-memory list backed by a JSON file, so it needs
    // to be the same instance across requests.
    builder.Services.AddSingleton<IEmployeeRepository, JsonEmployeeRepository>();

    // Nothing external to check — readiness just confirms the app is up.
    builder.Services.AddHealthChecks()
        .AddCheck("json-storage", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy(),
            tags: new[] { "ready" });
}

// --- AWS S3 client ---
// No explicit credentials configured here on purpose: the AWS SDK's default
// credential chain handles this correctly in every environment we care about —
// local dev via `aws configure` / SSO profile, EC2 via instance profile, and
// (the point of this whole exercise) EKS via IRSA-injected env vars once the
// pod's service account is annotated with the IAM role ARN.
builder.Services.AddDefaultAWSOptions(builder.Configuration.GetAWSOptions());
builder.Services.AddAWSService<IAmazonS3>();
builder.Services.AddScoped<IPhotoStorageService, S3PhotoStorageService>();

builder.Host.UseSerilog((context, config) => config
    .WriteTo.Console(new Serilog.Formatting.Json.JsonFormatter())
    .Enrich.FromLogContext());

var app = builder.Build();

// --- Startup connectivity check (MySql only) ---
// Verifies the database is reachable before the app starts serving traffic.
// Deliberately does NOT run migrations here — schema changes are a separate,
// explicit step (`dotnet ef database update`, or a one-shot Job/CI step in
// EKS), not something every replica does on boot. This block only answers
// "can I connect", nothing more.
if (useMySql)
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    const int maxRetries = 6;
    const int delaySeconds = 5;

    for (int i = 1; i <= maxRetries; i++)
    {
        try
        {
            Console.WriteLine($"[startup] Verifying database connectivity (Attempt {i}/{maxRetries})...");
            var canConnect = await db.Database.CanConnectAsync();
            if (canConnect)
            {
                Console.WriteLine("[startup] Database connectivity confirmed.");
                break;
            }

            Console.WriteLine($"[startup] Database not reachable yet (attempt {i}/{maxRetries}).");
            if (i == maxRetries)
            {
                throw new InvalidOperationException(
                    "Storage:Provider is 'MySql' but the database was not reachable after multiple attempts. " +
                    "Either start MySQL (docker compose --profile mysql up) or switch back to " +
                    "Storage:Provider=Json for local dev without a database.");
            }
            await Task.Delay(TimeSpan.FromSeconds(delaySeconds));
        }
        catch (MySqlException ex) when (i < maxRetries)
        {
            Console.WriteLine($"[startup] Database not ready yet. Retrying in {delaySeconds}s... ({ex.Message})");
            await Task.Delay(TimeSpan.FromSeconds(delaySeconds));
        }
        catch (MySqlException ex)
        {
            throw new InvalidOperationException(
                "Storage:Provider is 'MySql' but couldn't reach the database after multiple attempts. " +
                "Either start MySQL (docker compose --profile mysql up) or switch back to " +
                "Storage:Provider=Json for local dev without a database. " +
                "If the database IS reachable, check whether migrations have been applied: " +
                "dotnet ef database update.",
                ex);
        }
    }
}
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Employees}/{action=Index}/{id?}");

// Liveness: is the process up? No dependency checks — a DB blip shouldn't
// cause k8s to kill and restart a perfectly healthy pod.
app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = _ => false
});

// Readiness: can this pod actually serve traffic right now?
app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});

app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    timestamp = DateTime.UtcNow
}));

app.Run();