using EmployeeDirectory.Models;
using EmployeeDirectory.Repositories;
using EmployeeDirectory.Services;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeDirectory.Controllers;

public class EmployeesController : Controller
{
    private readonly IEmployeeRepository _repository;
    private readonly IPhotoStorageService _photoStorage;

    public EmployeesController(IEmployeeRepository repository, IPhotoStorageService photoStorage)
    {
        _repository = repository;
        _photoStorage = photoStorage;
    }

    // GET /Employees
    public async Task<IActionResult> Index()
    {
        var employees = await _repository.GetAllAsync();
        return View(employees);
    }

    // GET /Employees/Details/5
    public async Task<IActionResult> Details(int id)
    {
        var employee = await _repository.GetByIdAsync(id);
        if (employee is null) return NotFound();

        ViewBag.PhotoUrl = employee.PhotoKey is not null
            ? _photoStorage.GetPresignedUrl(employee.PhotoKey)
            : null;

        return View(employee);
    }

    // GET /Employees/Create
    public IActionResult Create() => View();

    // POST /Employees/Create
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(
        [Bind("FirstName,LastName,Email,Department")] Employee employee,
        IFormFile? photo)
    {
        if (!ModelState.IsValid) return View(employee);

        if (photo is { Length: > 0 })
        {
            await using var stream = photo.OpenReadStream();
            employee.PhotoKey = await _photoStorage.UploadAsync(stream, photo.FileName, photo.ContentType);
        }

        await _repository.AddAsync(employee);
        return RedirectToAction(nameof(Index));
    }

    // GET /Employees/Edit/5
    public async Task<IActionResult> Edit(int id)
    {
        var employee = await _repository.GetByIdAsync(id);
        if (employee is null) return NotFound();
        return View(employee);
    }

    // POST /Employees/Edit/5
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(
        int id,
        [Bind("Id,FirstName,LastName,Email,Department,PhotoKey")] Employee employee,
        IFormFile? photo)
    {
        if (id != employee.Id) return NotFound();
        if (!ModelState.IsValid) return View(employee);

        if (photo is { Length: > 0 })
        {
            await using var stream = photo.OpenReadStream();
            employee.PhotoKey = await _photoStorage.UploadAsync(stream, photo.FileName, photo.ContentType);
        }

        var updated = await _repository.UpdateAsync(employee);
        if (!updated) return NotFound();

        return RedirectToAction(nameof(Index));
    }

    // GET /Employees/Delete/5
    public async Task<IActionResult> Delete(int id)
    {
        var employee = await _repository.GetByIdAsync(id);
        if (employee is null) return NotFound();
        return View(employee);
    }

    // POST /Employees/Delete/5
    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        await _repository.DeleteAsync(id);
        return RedirectToAction(nameof(Index));
    }
}
