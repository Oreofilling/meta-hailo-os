FILESEXTRAPATHS:prepend := "${THISDIR}/files:"


# Use customer keys and signed certificate chain instead of Hailo development keys.
# Place in this directory (or in files/hailo15-ne503/ for this machine):
#   - cert_chain.bin        (customer certificate chain from Hailo, chip-specific)
#   - customer_keypair.pem  (private key you generate; send customer_pubkey.pem to Hailo to get cert_chain.bin)
#
#   openssl genrsa -out customer_keypair.pem 3072
#   openssl rsa -in customer_keypair.pem -out customer_pubkey.pem -pubout

CUSTOMER_CERT = "cert_chain.bin"
CUSTOMER_KEY  = "customer_keypair.pem"

# Override SRC_URI so cert/key come from file://
SRC_URI = "file://${CUSTOMER_CERT} \
           file://${CUSTOMER_KEY} \
           ${BASE_URI}/LICENSE;name=lic \
           "

# Checksums for local cert/key (run: sha256sum cert_chain.bin customer_keypair.pem to update)
SRC_URI[cert.sha256sum] = "5fd8dcf6665ddd3777a24671a5e3f48c5e38e17c72550cfaa218d190818b6cbc"
SRC_URI[key.sha256sum] = "287a7259e059b34a7f35a8c7530c0519227d87608ecd1b92f082dcdc0e936b18"