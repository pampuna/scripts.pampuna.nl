from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from datetime import datetime, timedelta, timezone

class Certificate:
    @staticmethod
    def generate(cert_path, key_path, server):
        private_key = rsa.generate_private_key(public_exponent=65537,key_size=2048,backend=default_backend())
        builder = x509.CertificateBuilder(
            subject_name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, server)]),
            issuer_name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, server) ]),
            public_key=private_key.public_key(),
            serial_number=x509.random_serial_number(),
            not_valid_before=datetime.now(timezone.utc),
            not_valid_after=datetime.now(timezone.utc) + timedelta(days=1)
        )
        san = x509.SubjectAlternativeName([ x509.DNSName(server) ])
        builder = builder.add_extension(san, critical=False)

        # Self Sign the certificate and write it to cert_path
        certificate = builder.sign(private_key=private_key, algorithm=hashes.SHA256(), backend=default_backend())
        with open(cert_path, "wb") as cert_file: 
            cert_file.write(certificate.public_bytes(encoding=serialization.Encoding.PEM))

        # Write the private key to key_path
        with open(key_path, "wb") as key_file:
            key_file.write(private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
        ))
