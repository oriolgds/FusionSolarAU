# Security Policy

## Supported Versions

We provide security updates for the following versions of the application:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it to our security team immediately. We take all security issues seriously and will address them as quickly as possible.

### How to Report

Please report security issues by emailing [security@fusion-solar-au.com](mailto:security@fusion-solar-au.com). You should receive a response within 48 hours. If for some reason you do not receive a response, please follow up via email to ensure we received your original message.

### Security Best Practices

1. **Authentication & Authorization**
   - All authentication is handled through Firebase Authentication
   - Use strong, unique passwords for all accounts
   - Enable two-factor authentication where available
   - Never share access tokens or API keys

2. **Data Protection**
   - All sensitive data is encrypted in transit using TLS 1.2+
   - Local storage uses secure storage mechanisms (Flutter Secure Storage)
   - Firebase Security Rules are implemented to protect database access

3. **Dependencies**
   - All dependencies are regularly updated to their latest secure versions
   - Vulnerable dependencies are addressed within 30 days of disclosure
   - Dependencies are audited using `flutter pub outdated` and `dart pub outdated`

4. **Code Security**
   - Regular code reviews are conducted for all changes
   - Static code analysis is performed using the Dart analyzer
   - Sensitive information is never hardcoded in the source code

### Incident Response

In the event of a security incident:

1. Our team will acknowledge receipt of your report within 48 hours
2. We will investigate the issue and determine the impact and affected systems
3. A fix will be developed and tested
4. The fix will be released in a timely manner
5. Users will be notified of the security update through the appropriate channels

### Secure Development Lifecycle

- All code changes require code review before merging
- Security testing is part of our CI/CD pipeline
- Regular security audits are performed on the codebase
- Third-party security assessments are conducted periodically

### Responsible Disclosure

We follow responsible disclosure guidelines. Please allow us a reasonable amount of time to correct the issue before publishing any information about the vulnerability. We will credit security researchers who report issues to us responsibly.

### Security Updates

Security updates are released as patch versions (e.g., 1.0.0 → 1.0.1). We recommend always running the latest version of the application to ensure you have all security fixes.

### Contact

For any security-related questions or concerns, please contact [security@fusion-solar-au.com](mailto:security@fusion-solar-au.com).

---
*Last Updated: June 26, 2025*
