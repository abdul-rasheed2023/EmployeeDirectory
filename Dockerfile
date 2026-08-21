# --- build stage ---
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Trust the corporate/proxy root CA before any network calls (e.g. dotnet restore)
COPY api.nuget.org.crt /usr/local/share/ca-certificates/api-nuget-org.crt
RUN update-ca-certificates

COPY EmployeeDirectory.csproj ./
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

ARG BUILD_SHA=unknown
LABEL org.opencontainers.image.revision=$BUILD_SHA
LABEL org.opencontainers.image.source="https://github.com/abdul-rasheed2023/EmployeeDirectory"

# --- runtime stage ---
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Run as non-root — required by default on most EKS pod security standards.
RUN useradd -u 1001 -m appuser \
    && mkdir -p /app/App_Data \
    && chown -R appuser:appuser /app

    # 2. INSTALL CURL AS ROOT BEFORE SWITCHING USERS
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

USER appuser

COPY --from=build --chown=appuser:appuser /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production


# 4. Add the healthcheck (It will now run successfully as appuser)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "EmployeeDirectory.dll"]