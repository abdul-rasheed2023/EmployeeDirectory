## First Container Run — [today's date]

**Result:** Container started successfully on first attempt, no blocking issues.

**Storage provider confirmed:** Json (via env var precedence — 
confirmed env vars override appsettings/launchSettings as intended).

**Non-blocking warnings observed:**
1. DataProtection keys not persisted outside container — acceptable for 
   local/single-instance use, will break session/auth consistency once 
   running multiple replicas in Kubernetes. Fix deferred to Month 3 
   (Kubernetes hardening).
2. HTTP_PORTS/HTTPS_PORTS overridden by ASPNETCORE_URLS — investigate 
   Dockerfile ENV configuration, not urgent, revisit before adding HTTPS.

**Verification:** curl to localhost:8080 confirmed app responds.