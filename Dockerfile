# --- build stage ---
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Trust the corporate/proxy root CA before any network calls
COPY api.nuget.org.crt /usr/local/share/ca-certificates/api-nuget-org.crt
RUN update-ca-certificates

COPY EmployeeDirectory.csproj ./
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# --- runtime stage ---
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Re-declare the ARG here so the runtime stage can use it for labels
ARG BUILD_SHA=unknown
LABEL org.opencontainers.image.revision=$BUILD_SHA
LABEL org.opencontainers.image.source="https://github.com/abdul-rasheed2023/EmployeeDirectory"

# Run as non-root — required by default on most EKS pod security standards.
RUN useradd -u 1001 -m appuser \
    && mkdir -p /app/App_Data \
    && chown -R appuser:appuser /app

# Install curl for healthcheck
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

USER appuser

# Copy published files from build stage
COPY --from=build --chown=appuser:appuser /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Healthcheck definition
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD curl -f http://localhost:8080/health || exit 1

# Explicit Entrypoint execution
ENTRYPOINT ["dotnet", "EmployeeDirectory.dll"]
