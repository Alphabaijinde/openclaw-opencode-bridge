# Security Policy

## Supported Versions

Security fixes are provided for the latest `main` branch state and the most recent release tag.

## Reporting a Vulnerability

Please avoid posting unpatched vulnerabilities in public issues.

Preferred disclosure flow:

1. Open a private security advisory in GitHub (if enabled), or
2. Contact maintainers privately (project security contact), and include:
   - affected endpoint/feature
   - reproduction steps
   - impact assessment
   - suggested fix (optional)

We will acknowledge reports as quickly as possible and coordinate a patch + disclosure timeline.

## Security Expectations

- Never commit credentials, provider keys, cookies, or `auth.json`.
- Run bridge behind trusted network boundaries in production.
- Use HTTPS/TLS at ingress.
- Keep `BRIDGE_API_KEY` enabled in non-local environments.

