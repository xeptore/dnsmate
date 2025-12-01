# DNSMate

Minimal one-click DNS changer for Windows 10 & 11 preloaded with common DNS providers for gaming and daily use. No installation, no local file storage, no unnecessary downloads, no data collection, just what you'd expect it to do.

## Usage

Run the following command in PowerShell:

```ps1
irm "https://xeptore.dev/dnsmate" | iex
```

## Notes

- Providers prefix with `$` require payment. Enabling them without payment and activation beforehand, may cause corrupting the DNS resolution on your machine.
- After applying a DNS provider, visiting some websites to make sure its working for you **before closing DNSMate** in order to be able to revert back to a working DNS provider – e.g., Cloudflare or Google.
