# Security Policy

ThrottleNet interacts with low-level macOS traffic shaping mechanisms (`dnctl`, `pfctl`) and utilizes an administrator helper to configure packet filtering rules without persistent elevated prompts. Because security and stability are paramount, we take vulnerability reports seriously.

## Supported Versions

Only the latest release of ThrottleNet is actively supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Security Architecture & Guarantees

1. **Isolated Packet Filter Anchors**: ThrottleNet restricts all rule injections to its isolated anchor (`throttlenet/<pid>`). It never alters root system PF rules or general network routing tables.
2. **Deterministic Cleanup**: On app exit, or when rules are cleared, ThrottleNet flushes its anchors and pipe configurations from `pfctl` and `dnctl`.
3. **Privilege Scope**: The privileged helper script executes only predefined `pfctl` and `dnctl` operations necessary for bandwidth rate limiting.

## Reporting a Vulnerability

If you discover a security vulnerability or privilege escalation issue in ThrottleNet, please report it privately:

- **Email**: Send details to [moeezali2375@gmail.com](mailto:moeezali2375@gmail.com).
- **Include**:
  - Description of the vulnerability.
  - Steps or proof-of-concept to reproduce the behavior.
  - Potential impact on the host system.

Please **do not** report security vulnerabilities via public GitHub issues. We will respond within 48 hours to acknowledge receipt and coordinate a patch and release.
