using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.Memory;
using Xunit;

namespace EmployeeDirectory.Test
{
    public class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
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
                    var dict = new Dictionary<string, string?>
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
            // Dispose the test HTTP client created from the factory
            _client?.Dispose();
            _client = null;

            // Remove the temporary storage file if it was created
            if (!string.IsNullOrEmpty(_tempFile) && File.Exists(_tempFile))
            {
                try
                {
                    File.Delete(_tempFile);
                }
                catch
                {
                    // Ignore cleanup failures in the test teardown
                }
            }
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