namespace EmployeeDirectory.Services;

public interface IPhotoStorageService
{
    /// <summary>
    /// Uploads a photo stream to S3 and returns the object key that was stored.
    /// </summary>
    Task<string> UploadAsync(Stream fileStream, string fileName, string contentType, CancellationToken ct = default);

    /// <summary>
    /// Returns a time-limited pre-signed URL so the browser can render a private
    /// object without the bucket needing to be public.
    /// </summary>
    string GetPresignedUrl(string objectKey);
}
