using EmployeeDirectory.Data;
using EmployeeDirectory.Models;
using Microsoft.EntityFrameworkCore;

namespace EmployeeDirectory.Repositories;

/// <summary>
/// Talks to RDS MySQL via EF Core. Used when Storage:Provider = "MySql".
/// </summary>
public class EfEmployeeRepository : IEmployeeRepository
{
    private readonly AppDbContext _db;

    public EfEmployeeRepository(AppDbContext db) => _db = db;

    public async Task<List<Employee>> GetAllAsync(CancellationToken ct = default) =>
        await _db.Employees.OrderBy(e => e.LastName).ToListAsync(ct);

    public async Task<Employee?> GetByIdAsync(int id, CancellationToken ct = default) =>
        await _db.Employees.FindAsync(new object?[] { id }, ct);

    public async Task<Employee> AddAsync(Employee employee, CancellationToken ct = default)
    {
        _db.Employees.Add(employee);
        await _db.SaveChangesAsync(ct);
        return employee;
    }

    public async Task<bool> UpdateAsync(Employee employee, CancellationToken ct = default)
    {
        if (!await _db.Employees.AnyAsync(e => e.Id == employee.Id, ct))
            return false;

        _db.Employees.Update(employee);
        await _db.SaveChangesAsync(ct);
        return true;
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken ct = default)
    {
        var employee = await _db.Employees.FindAsync(new object?[] { id }, ct);
        if (employee is null) return false;

        _db.Employees.Remove(employee);
        await _db.SaveChangesAsync(ct);
        return true;
    }
}
