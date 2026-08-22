using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.VisualStudio.TestPlatform.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.Memory;
using Xunit;

namespace EmployeeDirectory.Test
{
    public class HealthEndpointTests
    {
        private HttpClient _client;
        private string _tempFile;

        public HealthEndpointTests(WebApplicationFactory<Program> factory)
        {
            _tempFile = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".json");

            var factoryWithConfig = factory.WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((ctx, conf) =>
                {
                    var dict = new Dictionary<string, string>
                    {
                        ["Storage:Provider"] = "Json",
                        ["Storage:JsonFilePath"] = _tempFile
                    };

                    conf.Add(new MemoryConfigurationSource { InitialData = dict });
                });
            });

            _client = factoryWithConfig.CreateClient();
        }

        [Fact]
        public async Task Health_ReturnsOk()
        {
            var response = await _client.GetAsync("/health");
            response.EnsureSuccessStatusCode();
        }

        public void Dispose()
        {
            if (File.Exists(_tempFile))
                File.Delete(_tempFile);
        }

        //[SetUp]
        //    public void Setup()
        //    {
        //    }

        //    [Test]
        //    public void Test1()
        //    {
        //        Assert.Pass();
        //    }
        //}
    }
}