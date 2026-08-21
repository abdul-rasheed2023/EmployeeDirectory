using System.Text.Json;
using EmployeeDirectory.Models;

namespace EmployeeDirectory.Repositories;

/// <summary>
/// Stores employees as a pretty-printed JSON array on local disk instead of a
/// database. Used when Storage:Provider = "Json" — the point is to let you run
/// and click through the app on your machine without standing up MySQL at all.
/// Registered as a singleton and guarded by a semaphore since ASP.NET Core can
/// serve requests concurrently.
/// </summary>
public class JsonEmployeeRepository : IEmployeeRepository
{
    private readonly string _filePath;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly ILogger<JsonEmployeeRepository> _logger;
    private static readonly JsonSerializerOptions SerializerOptions = new() { WriteIndented = true };

    public JsonEmployeeRepository(IConfiguration config, IWebHostEnvironment env, ILogger<JsonEmployeeRepository> logger)
    {
        _logger = logger;

        var configuredPath = config["Storage:JsonFilePath"] ?? "App_Data/employees.json";
        _filePath = Path.IsPathRooted(configuredPath)
            ? configuredPath
            : Path.Combine(env.ContentRootPath, configuredPath);

        var directory = Path.GetDirectoryName(_filePath);
        if (!string.IsNullOrEmpty(directory))
            Directory.CreateDirectory(directory);

        if (!File.Exists(_filePath))
        {
            _logger.LogInformation("No existing data file at {Path} — starting with an empty employee list.", _filePath);
            File.WriteAllText(_filePath, "[]");
        }
    }

    public async Task<List<Employee>> GetAllAsync(CancellationToken ct = default)
    {
        var all = await LoadAsync(ct);
        return all.OrderBy(e => e.LastName).ToList();
    }

    public async Task<Employee?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        var all = await LoadAsync(ct);
        return all.FirstOrDefault(e => e.Id == id);
    }

    public async Task<Employee> AddAsync(Employee employee, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try
        {
            var all = await LoadInternalAsync(ct);
            employee.Id = all.Count == 0 ? 1 : all.Max(e => e.Id) + 1;
            all.Add(employee);
            await SaveInternalAsync(all, ct);
            return employee;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<bool> UpdateAsync(Employee employee, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try
        {
            var all = await LoadInternalAsync(ct);
            var index = all.FindIndex(e => e.Id == employee.Id);
            if (index == -1) return false;

            all[index] = employee;
            await SaveInternalAsync(all, ct);
            return true;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try
        {
            var all = await LoadInternalAsync(ct);
            var removed = all.RemoveAll(e => e.Id == id) > 0;
            if (removed) await SaveInternalAsync(all, ct);
            return removed;
        }
        finally
        {
            _lock.Release();
        }
    }

    // --- helpers ---

    private async Task<List<Employee>> LoadAsync(CancellationToken ct)
    {
        await _lock.WaitAsync(ct);
        try
        {
            return await LoadInternalAsync(ct);
        }
        finally
        {
            _lock.Release();
        }
    }

    // Callers must hold _lock before calling this.
    private async Task<List<Employee>> LoadInternalAsync(CancellationToken ct)
    {
        await using var stream = File.OpenRead(_filePath);
        var data = await JsonSerializer.DeserializeAsync<List<Employee>>(stream, cancellationToken: ct);
        return data ?? new List<Employee>();
    }

    // Callers must hold _lock before calling this.
    private async Task SaveInternalAsync(List<Employee> employees, CancellationToken ct)
    {
        await using var stream = File.Create(_filePath);
        await JsonSerializer.SerializeAsync(stream, employees, SerializerOptions, ct);
    }
}
