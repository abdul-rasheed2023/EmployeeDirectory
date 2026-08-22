using Amazon.S3;
using Amazon.S3.Model;

namespace EmployeeDirectory.Services;

public class S3PhotoStorageService : IPhotoStorageService
{
    private readonly IAmazonS3 _s3;
    private readonly string _bucketName;
    private readonly ILogger<S3PhotoStorageService> _logger;

    public S3PhotoStorageService(IAmazonS3 s3, IConfiguration config, ILogger<S3PhotoStorageService> logger)
    {
        _s3 = s3;
        _logger = logger;

        // Same bucket the existing S3 -> Lambda -> DynamoDB pipeline already watches.
        // Set via PHOTO_BUCKET_NAME env var (matches the Terraform output from the
        // `data` module in the 3-tier project).
        _bucketName = config["PhotoStorage:BucketName"]
            ?? throw new InvalidOperationException("PhotoStorage:BucketName is not configured.");
    }

    public async Task<string> UploadAsync(Stream fileStream, string fileName, string contentType, CancellationToken ct = default)
    {
        var objectKey = $"employee-photos/{Guid.NewGuid()}-{Path.GetFileName(fileName)}";

        var request = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = objectKey,
            InputStream = fileStream,
            ContentType = contentType,
            // Server-side encryption at rest; bucket itself stays private (no ACL grants).
            ServerSideEncryptionMethod = ServerSideEncryptionMethod.AES256
        };

        await _s3.PutObjectAsync(request, ct);
        _logger.LogInformation("Uploaded photo to s3://{Bucket}/{Key}", _bucketName, objectKey);

        return objectKey;}

    public string GetPresignedUrl(string objectKey)
    {
        var request = new GetPreSignedUrlRequest
        {
            BucketName = _bucketName,
            Key = objectKey,
            Expires = DateTime.UtcNow.AddMinutes(15),
            Verb = HttpVerb.GET
        };

        return _s3.GetPreSignedURL(request);
    }
}
