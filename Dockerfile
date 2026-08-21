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

# --- runtime stage ---
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Run as non-root — required by default on most EKS pod security standards.
RUN useradd -u 1001 -m appuser \
    && mkdir -p /app/App_Data \
    && chown -R appuser:appuser /app

USER appuser

COPY --from=build --chown=appuser:appuser /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "EmployeeDirectory.dll"]