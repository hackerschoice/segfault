# l0pht

Regional Cluster design:
```mermaid
graph TD;
    Shell1-->Host1;
    Shell2-->Host1;
    Shell3-->Host2;
    Shell4-->Host2;
    Shell5-->Host2;
    Host1-->OpenVPN;
    Host2-->OpenVPN;
    OpenVPN -- Leaving Cluster -->NordVPN
    NordVPN-->INTERNETZ
```

Cluster can be deployed in various regions for less latency.

