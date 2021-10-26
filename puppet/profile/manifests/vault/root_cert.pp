# Provide root certificate
class profile::vault::root_cert {
  file { '/usr/local/share/ca-certificates/extra':
    ensure  => directory,
  }

  file { '/usr/local/share/ca-certificates/extra/vault-pki-root.crt':
    ensure  => present,
    content => '-----BEGIN CERTIFICATE-----
MIIDITCCAgmgAwIBAgIUTZ/BBUe+nK41F+rw35jkecJ/qwQwDQYJKoZIhvcNAQEL
BQAwGDEWMBQGA1UEAxMNVmF1bHQgUm9vdCBDQTAeFw0yMTEwMjUwMzU2MjlaFw0z
MTA5MDMwMzU2NTlaMBgxFjAUBgNVBAMTDVZhdWx0IFJvb3QgQ0EwggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDJpHVqHN4MwPKBHFR1NNbyUd7TptmP8HLi
ge59ZBsFu6uurXo9WNHuvBjvJ1nCcExXw1Ni6+6Q+bM6jywIBMljrEyAFgmNvHOh
GC93ENXoCTFMRz/AH8UslKeXrfsVjVgajfUdu5xDpXMEzwcv16CnODt2cpA8efZx
59G9BAmY1mNkUtKyxhAleAQLFihtbxdr5P2inK0ahmQnsI2nuHQh/3ZHQpKoL6e9
1jYkDXNGrEz5SuFhexuWgu0uIx/ZDyAsN7HZapLPpJ/HoVtjeEJFdYtgIkzG+l12
PJRLy6wowrao8MwAJdf40YDr9QTGha03O9nI+Xnc+kdj7OtXCYdFAgMBAAGjYzBh
MA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRZnkxW
sNXKK5L7RrbgDiC+xKR79jAfBgNVHSMEGDAWgBRZnkxWsNXKK5L7RrbgDiC+xKR7
9jANBgkqhkiG9w0BAQsFAAOCAQEAbxI3LkdGUu5oATm8MslL92tzzBK0CLETBQcn
h06VjCi/EVlHFJQWB8StJLFUNSHBg9kMJES5dHWQYV69ytJVDLv8HsokGUM19WyH
EyX4f+Swxjmk2v92xhqalevcvdRsXaHu57EnqdXnYg1H1SK52AAJH0rufaAKKhDK
6C7k9T7EyBBRQFUtlQa6eekQ382jXdxygZ9DMEbA1AfZAt0fCmgkjF33mspoj3G5
0AwVkOJfiE1aOg+KsI5eRXfS3GEyYGRO/kKOnaqG0FVOwv/iQno6fqPZfkrp+rLh
EpvRP5b86ahUT2NDUTwa6WT+fyNqkPjXc73w5u+DtMOmHtYbQw==
-----END CERTIFICATE-----',
  }
}
