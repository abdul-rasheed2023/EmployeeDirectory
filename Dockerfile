# --- build stage ---
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY api.nuget.org.crt /usr/local/share/ca-certificates/api-nuget-org.crt
RUN update-ca-certificates

COPY EmployeeDirectory.csproj ./
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

RUN mkdir -p /app/publish/App_Data && chown -R 1654:1654 /app/publish/App_Data

# --- runtime stage ---
FROM mcr.microsoft.com/dotnet/aspnet:8.0-noble-chiseled AS runtime
WORKDIR /app

ARG BUILD_SHA=unknown
LABEL org.opencontainers.image.revision=$BUILD_SHA
LABEL org.opencontainers.image.source="https://github.com/abdul-rasheed2023/EmployeeDirectory"

COPY --from=build --chown=1654:1654 /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
#   CMD curl -f http://localhost:8080/health || exit 1
# ^ Removed for chiseled base (no shell/curl available). Replaced by
# Kubernetes liveness/readiness probes hitting /health from outside
# the container — see Month 3 Deployment work.

ENTRYPOINT ["dotnet", "EmployeeDirectory.dll"]