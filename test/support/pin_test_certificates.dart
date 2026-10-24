import 'dart:convert';
import 'dart:typed_data';

// Certificates made for the pin tests only, with their pins read by the command docs/security.md gives:
// openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary |
// openssl enc -base64
// They protect nothing; only the key of the chain leaf was kept, for a loopback test server.

/// An RSA 2048 certificate.
const rsaCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIIDADCCAeigAwIBAgIUfgzXuUNArWNBEPAqStcoIK53J2AwDQYJKoZIhvcNAQEL
BQAwHzEdMBsGA1UEAwwUcnNhLXBpbi10ZXN0LmludmFsaWQwIBcNMjYxMDI0MDYw
NjI1WhgPMjEyNjA5MzAwNjA2MjVaMB8xHTAbBgNVBAMMFHJzYS1waW4tdGVzdC5p
bnZhbGlkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmwMDuVw1wbhO
8edTzo6Dgs7NAMTMbjwaFQNztwvR/nIbs72UbNIBY46YrME4HfO7buwSWlURouHM
aS8OzyXx2yXBGlcTRn4/gXbkuUb0cres4YNzSZgLqJbSAu58txveyvxc187h4wk3
DXJaidtMwEn6fwYjcYn95T1axUoRlVcu36WOXurelBJWcGNd+Xv32ZDMyXkdz1ha
r9qQHAFP5I6BUsggfV5heVABcQCn+QD6aepKGp5eOdijV5uLhpA7lWIXnSEBLGly
vAzWU/55iKoiBo5iHrjOhNFbj8lHewdAyuTP3RXke/hrv3nYUjH7p5Dy4NJSRmMU
tIPiLgDdPQIDAQABozIwMDAdBgNVHQ4EFgQUYkZ5WrQT96aJNaXrBPA9KQX56tYw
DwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEACsGxjKWbKzsaCMFW
5E69YI420QT4N0lDpIOVW6bozdjWy1Q5hk4bKI2U+ouVzXCDlA8GAiad2TCo8XIm
nkcA9PKKz+fO6O/C+i6m846ESmBqcJ25NXRrAG8AUdbcb/kGCG1+In8YPf2j2W6L
gwB4HyY3O4eoQb6EWzxRdDq7aTBx/AorfoqOs6k9oATgRsU4458XYHcF6exn/DyF
dXKH0iq6HSauqNn3+Z66v43jT2ivenpujMWRpOGbHPooQeZA2HeGQySxwdqeXrZl
USUPCQ8pPtu3T85+evsr9M52kNr1diWrBiAc+XTMDlmszi65FrEWpAO3y5M0F/GF
/n7weA==
-----END CERTIFICATE-----
''';

const rsaCertificatePin = 'JFJ05vzkdaoWOWJCvKNa9lkcvoHOCu0SDjurvTIU0iM=';

/// A P-256 certificate, serial 1.
const ecCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIIBXjCCAQWgAwIBAgIBATAKBggqhkjOPQQDAjAeMRwwGgYDVQQDDBNlYy1waW4t
dGVzdC5pbnZhbGlkMCAXDTI2MTAyNDA2MDYyNVoYDzIxMjYwOTMwMDYwNjI1WjAe
MRwwGgYDVQQDDBNlYy1waW4tdGVzdC5pbnZhbGlkMFkwEwYHKoZIzj0CAQYIKoZI
zj0DAQcDQgAEvkAGhTGXOFkSx+jb3NGXHdSqxvKQb7/UwZ50YGs3AGN8uUtcqhYq
ZOK8p/cYCiuO41Yu4Fy1sc/E7ds/atdejaMyMDAwHQYDVR0OBBYEFHH4zm3XtP+D
cVQIzh4sHCwBCY+9MA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDRwAwRAIg
MIjhFPtKGb8tpkYrSjzlapeU2JbZUP1etoNEAxVujKwCIA0ZwwIcRPr0WFUhAwhF
eKFriUbD0FSJ5CB8wvqBT88v
-----END CERTIFICATE-----
''';

/// The certificate of [ecCertificatePem] renewed over the same key: serial 2 and a new signature.
const ecRenewedCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIIBYDCCAQWgAwIBAgIBAjAKBggqhkjOPQQDAjAeMRwwGgYDVQQDDBNlYy1waW4t
dGVzdC5pbnZhbGlkMCAXDTI2MTAyNDA2MDYyNVoYDzIxMjYwOTMwMDYwNjI1WjAe
MRwwGgYDVQQDDBNlYy1waW4tdGVzdC5pbnZhbGlkMFkwEwYHKoZIzj0CAQYIKoZI
zj0DAQcDQgAEvkAGhTGXOFkSx+jb3NGXHdSqxvKQb7/UwZ50YGs3AGN8uUtcqhYq
ZOK8p/cYCiuO41Yu4Fy1sc/E7ds/atdejaMyMDAwHQYDVR0OBBYEFHH4zm3XtP+D
cVQIzh4sHCwBCY+9MA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSQAwRgIh
AMmjahHb4XKvGl07DZMQtHoxcuYw9SHqnOKjBwbuFk/iAiEAwuXqiGylzgEf271A
UsK4a3B8/UJsq5F3fiPleEscr3c=
-----END CERTIFICATE-----
''';

/// The pin of both [ecCertificatePem] and [ecRenewedCertificatePem], whose key is one.
const ecCertificatePin = 'i5cLE+PBJZGAhVfanuvFHARli0sLe7dHD9Yc1JIZNKg=';

/// The DER bytes of a PEM certificate.
Uint8List derOf(String pem) =>
    base64.decode(pem.split('\n').where((line) => line.isNotEmpty && !line.startsWith('-----')).join());

/// A leaf for localhost and 127.0.0.1, issued by [chainIntermediatePem], which [chainRootPem] issued: the shape of a
/// Caddy or public CA edge, whose server sends the leaf and the intermediate.
const chainLeafPem = '''
-----BEGIN CERTIFICATE-----
MIIBZzCCAQygAwIBAgIBCzAKBggqhkjOPQQDAjAgMR4wHAYDVQQDDBVQaW4gVGVz
dCBJbnRlcm1lZGlhdGUwIBcNMjYxMDI0MDYwODA3WhgPMjEyNjA5MzAwNjA4MDda
MBQxEjAQBgNVBAMMCWxvY2FsaG9zdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IA
BCpJMVtH8C3QAPVFn2atxTQE+gHfhgJvSciZdAS3WBEHs7VQ86WySrkyQHWWh3fQ
diFYIkEx+VnHxPf3Q/Qfl12jQTA/MAwGA1UdEwEB/wQCMAAwGgYDVR0RBBMwEYIJ
bG9jYWxob3N0hwR/AAABMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAoGCCqGSM49BAMC
A0kAMEYCIQCQVGuCDBZ/GHXXWn9J9tdIKfg08qSPbGqH5xBzghQdXAIhAPDegPzp
17T/WWZrTcOE6aM3rMCuJQcxA8VzRFtldNZj
-----END CERTIFICATE-----
''';

const chainLeafPin = 'cuS5J2DS+YNHfGRJVN0FGjoMBXnzkA5K6npKXBHlevc=';

/// The private key of [chainLeafPem], for the test server only.
const chainLeafKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg+IBFlB00CLHaOeeD
J81afiiLV6h4tvvgDs2VkrfUBXqhRANCAAQqSTFbR/At0AD1RZ9mrcU0BPoB34YC
b0nImXQEt1gRB7O1UPOlskq5MkB1lod30HYhWCJBMflZx8T390P0H5dd
-----END PRIVATE KEY-----
''';

const chainIntermediatePem = '''
-----BEGIN CERTIFICATE-----
MIIBTzCB9aADAgECAgEKMAoGCCqGSM49BAMCMBgxFjAUBgNVBAMMDVBpbiBUZXN0
IFJvb3QwIBcNMjYxMDI0MDYwODA3WhgPMjEyNjA5MzAwNjA4MDdaMCAxHjAcBgNV
BAMMFVBpbiBUZXN0IEludGVybWVkaWF0ZTBZMBMGByqGSM49AgEGCCqGSM49AwEH
A0IABFGoy5Ok87pBXF4elSFCwsZj/KobzsQB82HX7AK1GjgJ+LkOrSRY3b2N9nGA
oax5O/BWJEpuuI+vq/TrXKH9n4ijJjAkMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYD
VR0PAQH/BAQDAgEGMAoGCCqGSM49BAMCA0kAMEYCIQCTatj/VJ8ikwaC+J+m5YlX
I49bczuYTPIam8zXoF4EwQIhAIM1tEzVdM2ZJUFjDaU/hP/EXPU5bF2BvUDXmXcD
0b+s
-----END CERTIFICATE-----
''';

const chainIntermediatePin = '8kDY7V8v+ZeIxwKdBIsMsqVR4qDkX3FBvWYQcrNwYzQ=';

const chainRootPem = '''
-----BEGIN CERTIFICATE-----
MIIBdjCCARygAwIBAgIUUioTccoMSKKEl1cdfljRh2TYC/8wCgYIKoZIzj0EAwIw
GDEWMBQGA1UEAwwNUGluIFRlc3QgUm9vdDAgFw0yNjEwMjQwNjA4MDdaGA8yMTI2
MDkzMDA2MDgwN1owGDEWMBQGA1UEAwwNUGluIFRlc3QgUm9vdDBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABOB97WItwTGueTRD0ZZakXzr9Aq52xQhU8d2pBMNY6rV
4xF7niQRxLIOq+rU+47IsghL086MQOpOoo5lpLlu+8ujQjBAMB0GA1UdDgQWBBQX
M4QyH4kTsQsEwbTk//3x93Pz5TAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQE
AwIBBjAKBggqhkjOPQQDAgNIADBFAiEAoHeXrU9TRQcfApYNpgdKW/EV65oovaEc
s+TFCiV0ZRUCIC+pD3QfoT4kUwKtA2fzg01FSSy1Ehshj0ig3q5enOD4
-----END CERTIFICATE-----
''';

const chainRootPin = 'hMmhS73pfrSMATMb6NnfHlHuX6NbotJ3g5VU/T7qXbg=';
