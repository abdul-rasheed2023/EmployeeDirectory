using System.ComponentModel.DataAnnotations;

namespace EmployeeDirectory.Models;

public class Employee
{
    public int Id { get; set; }

    [Required, StringLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [Required, StringLength(100)]
    public string LastName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(200)]
    public string Email { get; set; } = string.Empty;

    [Required, StringLength(100)]
    public string Department { get; set; } = string.Empty;

    // S3 object key (not the full URL) — the pre-existing S3 -> Lambda -> DynamoDB
    // pipeline reacts to ObjectCreated events on this same bucket, so uploading here
    // also feeds that pipeline for free.
    public string? PhotoKey { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
