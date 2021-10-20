# Provide root certificate
class profile::vault_root_cert {
  file { '/usr/local/share/ca-certificates/extra':
    ensure  => directory,
  }

  file { '/usr/local/share/ca-certificates/extra/vault-pki-root.crt':
    ensure  => present,
    content => '-----BEGIN CERTIFICATE-----
MIIDITCCAgmgAwIBAgIUUBkxXYgKpKgGIkaiPs7HXAe8g3AwDQYJKoZIhvcNAQEL
BQAwGDEWMBQGA1UEAxMNVmF1bHQgUm9vdCBDQTAeFw0yMTEwMTkwOTQ1MTFaFw0z
MTA4MjgwOTQ1NDBaMBgxFjAUBgNVBAMTDVZhdWx0IFJvb3QgQ0EwggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQO+JNnOfptnPjfBBFusLOi1WxiieACS8AOt
sDOiS6P4tDCiAl6Up8AgGPhXXQdA83M1IpTftQgLxfznNAsIMEKFZxL8tEB66Of9
XGBmi/HKvDqD365eijvvOdnyCJ5SDvAq35I/qjbBUMtE3v2AwhOMn72/ddtfdoxQ
FIhCuJPEgtUZj/mfLJeTW20JueXj106FHbvRCRAWTTLP88nDua+lUJUVGd9Dh3qx
bwPeNQevQdzMOanMsYJ+VLbaq1F2tBINzHoxJh/s0hkdw4E3CSCGAKdvEDsEnKfP
S+Zy3ku68pBHRyO77Tse3PK1D63rxzdlbdTrfOW1+6jZ9x5RNLwjAgMBAAGjYzBh
MA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQEen4+
9RKb4lxl9f+rwmgf4iYoljAfBgNVHSMEGDAWgBQEen4+9RKb4lxl9f+rwmgf4iYo
ljANBgkqhkiG9w0BAQsFAAOCAQEAjlFE2WVYyME7ReS5sPWLODmdiy48aOfecRQX
NLlv+0kMDViySUFcmUDfqsSjuKKhS8c+EM9IzdiLmOUT0MMcoAR/oXLzKjA3Ydh6
Us/tJfwzfORXFe48iDI9shtqGrmaIm14rzdfmxjqZOt0t8p1RUEpVjcS4Bu2COjG
DABDrc7Od44Q9d+sQCEEwvnqAPwXPJIg/otRY9gTynzsiOBOvAPSZGP//oIl65ad
J54qcxHPuApnjaNCwisszUw4+6RBk+q/qdbjjYdMFGmFMvTbwwxbWqjXxHBBUKtx
M/3jjwSueLuEAUYcfs5exuhr65WOE47C4fSkepWRAfsm6itthg==
-----END CERTIFICATE-----',
  }
}
