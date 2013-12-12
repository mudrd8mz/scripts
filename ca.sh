#!/bin/bash

##
# CA Authority Manager
# An easy way to create and manage your own certificate authority
# Author: Matthew Spurrier
# Web: http://www.digitalsparky.com/
# Github: http://www.github.com/digitalsparky
##

##
# START CONFIGURATION
##

COUNTRYCODE="AU"
STATEORPROVINCE="Western Australia"
LOCALITY="Perth"
ORGANISATION="New CA"
CAPATH="./newCA"
KEYSTRENGTH=8192
DAYS=3650
CADAYS=365000

##
# END CONFIGURATION
##


##
# START DEFAULT VARIABLES
##

CERTPATH="${CAPATH}/certs"
CSRPATH="${CAPATH}/csr"
KEYPATH="${CAPATH}/private"
CRLPATH="${CAPATH}/crl"
OPENSSLCONF="${CAPATH}/openssl.my.cnf"
OPENSSL="$(which openssl)"
CACERT="${CERTPATH}/ca.crt"
CAKEY="${KEYPATH}/ca.key"
CASERIAL="${CAPATH}/serial"
CAINDEX="${CAPATH}/index.txt"
GENKEY=0
GENCSR=0
SIGNCSR=0

##
# END DEFAULT VARIABLES
##

##
# START FUNCTIONS
##

# Help
printHelp() {
    cat <<EOF
Usage:

$0 -n <common-name> <options>
common-name: the FQDN or identifying name for the certificate (ie: your name, or host.example.com)
options:
    -k:     generate an rsa key for the common-name
    -c:     generate a certificate signing request for the common-name (requires key)
    -s:     sign a certificate signing request against the CA
    
Example:

$0 -n example.com -k -c -s
Generates the rsa key, and signing request, then signs the request with the certificate authority

$0 -n example.com -k
Generates only the rsa key for the common-name

$0 -n example.com -k -c
Generates the rsa key and certificate signing request based on that key

$0 -n example.com -c
Generates an rsa key based on a pre-existing key only
This requires the key to exist in the private directory, eg:
${KEYPATH}/example.com.key

$0 -n example.com -s
Signs an existing csr with the certificate authority
This requires the csr to exist in the csr directory, eg:
${CSRPATH}/example.com.csr
EOF
    exit 1
}

# Check Options
checkOptions() {
    while getopts ":n:kcs" opt; do
        case "${opt}" in
            k)
                GENKEY=1
                ;;
            c)
                GENCSR=1
                ;;
            s)
                SIGNCSR=1
                ;;
            n)
                CN="${OPTARG}"
                CNKEY="${KEYPATH}/${CN}.key"
                CNCERT="${CERTPATH}/${CN}.crt"
                CNCSR="${CSRPATH}/${CN}.csr"
                ;;
            \?)
                echo "Option -${OPTARG} does not exist." >&2
                exit 1
                ;;
            :)
                echo "Options -${OPTARG} requires an argument." >&2
                exit 1
                ;;
        esac
    done
}

# Check Install Environment
checkInstall() {
    if [ ! -x "${OPENSSL}" ]; then
        echo "OpenSSL is not installed, unable to continue"
        exit 1
    fi
    if [ ! -d "${CAPATH}" ]; then
        mkdir -p "${CAPATH}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create CA Path ${CAPATH}"
            exit 1
        fi
    fi
    if [ ! -d "${CERTPATH}" ]; then
        mkdir -p "${CERTPATH}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create Certificate Path ${CERTPATH}"
            exit 1
        fi
    fi
    if [ ! -d "${CSRPATH}" ]; then
        mkdir -p "${CSRPATH}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create CSR Path ${CSRPATH}"
            exit 1
        fi
    fi
    if [ ! -d "${KEYPATH}" ]; then
        mkdir -p "${KEYPATH}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create Key Path ${KEYPATH}"
            exit 1
        fi
    fi
    if [ ! -d "${CRLPATH}" ]; then
        mkdir -p "${CRLPATH}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create CRL Path ${CRLPATH}"
            exit 1
        fi
    fi
    if [ ! -f "${OPENSSLCONF}" ]; then generateConfig; fi
    if [ ! -f "${CACERT}" ]; then generateCA; fi
    if [ ! -f "${CAKEY}" ]; then generateCA; fi
}

# Generate Key
genKey() {
    checkKeyAbsent
    "${OPENSSL}" genrsa -out "${CNKEY}" "${KEYSTRENGTH}" 
}

# Generate Certificate Signing Request (CSR)
genCSR() {
    checkCSRAbsent
    checkKeyExists
    "${OPENSSL}" req -config "${OPENSSLCONF}" -new -key "${CNKEY}" -out "${CNCSR}"
}

# Sign CSR against CA
signCSR() {
    checkCertAbsent
    checkCSRExists
    "${OPENSSL}" x509 -req -in "${CNCSR}" -CA "${CACERT}" -CAkey "${CAKEY}" -CAserial "${CASERIAL}" -out "${CNCERT}" -days "${DAYS}"
}

checkKeyAbsent() {
    if [ -f "${CNKEY}" ]; then
        echo "Key file for ${CN} already exists."
        echo "Please remove it or adjust your options."
        echo "File: ${CNKEY}"
        exit 1
    fi
}

checkKeyExists() {
    if [ ! -f "${CNKEY}" ]; then
        echo "Key file for ${CN} does not exist."
        echo "Please copy it to the following location or adjust your options."
        echo "File: ${CNKEY}"
        exit 1
    fi
}

checkCSRExists() {
    if [ ! -f "${CNCSR}" ]; then
        echo "CSR file for ${CN} does not exist."
        echo "Please copy it to the following location or adjust your options."
        echo "File: ${CNKEY}"
        exit 1
    fi
}

checkCSRAbsent() {
    if [ -f "${CNCSR}" ]; then
        echo "CSR file for ${CN} already exists."
        echo "Please remove it or adjust your options"
        echo "File: ${CNCSR}"
        exit 1
    fi
}

checkCertAbsent() {
    if [ -f "${CNCERT}" ]; then
        echo "Certificate file for ${CN} already exists."
        echo "Please remove it to re-sign"
        echo "File: ${CNCERT}"
        exit 1
    fi
}

generateCA() {
    echo "Generating Certificate Authority"
    if [ -f "${CACERT}" ] && [ ! -f "${CAKEY}" ]; then
        echo "CA Cert exists but CA Key is missing, please move the CA Key back in place, or delete the CA Cert and run again to generate a new pair"
        echo "CA Cert File: ${CACERT}"
        echo "CA Key File: ${CAKEY}"
        exit 1
    fi
    if [ ! -f "${CACERT}" ] && [ -f "${CAKEY}" ]; then
        echo "CA Key exists but CA Cert is missing, please move the CA Cert back in place, or delete the CA Key and run again to generate a new pair"
        echo "CA Cert File: ${CACERT}"
        echo "CA Key File: ${CAKEY}"
        exit 1
    fi
    "${OPENSSL}" req -config "${OPENSSLCONF}" -new -x509 -extensions v3_ca -keyout "${CAKEY}" -out "${CACERT}" -days "${CADAYS}"
    if [ "$?" -gt 0 ]; then
        echo "Failed to create Certificate Authority files..."
        exit 1
    fi
}

generateConfig() {
    if [ ! -f "${CAINDEX}" ]; then
        touch "${CAINDEX}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create CA index file ${CAINDEX}"
            exit 1
        fi
    fi
    if [ ! -f "${CASERIAL}" ]; then
        echo "01" > "${CASERIAL}"
        if [ "$?" -gt 0 ]; then
            echo "Failed to create CA serial file ${CASERIAL}"
            exit 1
        fi
    fi
    cat <<EOF > "${OPENSSLCONF}"
HOME			                = .
RANDFILE		                = \$ENV::HOME/.rnd
oid_section		                = new_oids
[ new_oids ]
tsa_policy1                     = 1.2.3.4.1
tsa_policy2                     = 1.2.3.4.5.6
tsa_policy3                     = 1.2.3.4.5.7
[ ca ]
default_ca	                    = CA_default
[ CA_default ]
dir		                        = ${CAPATH}
certs		                    = ${CERTPATH}
crl_dir		                    = ${CRLPATH}
database	                    = ${CAINDEX}
new_certs_dir	                = ${CERTPATH}
certificate	                    = ${CACERT}
serial		                    = ${CASERIAL}
crlnumber	                    = ${CAPATH}/crlnumber
crl		                        = ${CAPATH}/crl.pem
private_key	                    = ${CAKEY}
RANDFILE	                    = ${KEYPATH}/.rand
x509_extensions	                = usr_cert
name_opt 	                    = ca_default
cert_opt 	                    = ca_default
default_days	                = ${DAYS}
default_crl_days                = 30
default_md	                    = default
preserve	                    = no
policy		                    = policy_match
[ policy_match ]
countryName		                = match
stateOrProvinceName	            = match
organizationName	            = match
organizationalUnitName	        = optional
commonName		                = supplied
emailAddress		            = optional
[ policy_anything ]
countryName		                = optional
stateOrProvinceName	            = optional
localityName		            = optional
organizationName	            = optional
organizationalUnitName	        = optional
commonName		                = supplied
emailAddress		            = optional
[ req ]
default_bits		            = ${KEYSTRENGTH}
default_keyfile 	            = privkey.pem
distinguished_name	            = req_distinguished_name
attributes		                = req_attributes
x509_extensions	                = v3_ca
string_mask                     = utf8only
[ req_distinguished_name ]
countryName			            = Country Name (2 letter code)
countryName_default		        = ${COUNTRYCODE}
countryName_min			        = 2
countryName_max			        = 2
stateOrProvinceName		        = State or Province Name (full name)
stateOrProvinceName_default	    = ${STATEORPROVINCE}
localityName			        = Locality Name (eg, city)
localityName_default		    = ${LOCALITY}
0.organizationName		        = Organization Name (eg, company)
0.organizationName_default	    = ${ORGANISATION}
organizationalUnitName		    = Organizational Unit Name (eg, section)
commonName			            = Common Name (e.g. server FQDN or YOUR name)
commonName_max			        = 64
emailAddress			        = Email Address
emailAddress_max		        = 64
[ req_attributes ]
challengePassword		        = A challenge password
challengePassword_min		    = 4
challengePassword_max		    = 20
unstructuredName		        = An optional company name
[ usr_cert ]
basicConstraints                = CA:FALSE
nsComment			            = "OpenSSL Generated Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer
[ v3_req ]
basicConstraints                = CA:FALSE
keyUsage                        = nonRepudiation, digitalSignature, keyEncipherment
[ v3_ca ]
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer
basicConstraints                = CA:true
[ crl_ext ]
authorityKeyIdentifier          = keyid:always
[ proxy_cert_ext ]
basicConstraints                = CA:FALSE
nsComment			            = "OpenSSL Generated Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer
proxyCertInfo                   = critical,language:id-ppl-anyLanguage,pathlen:3,policy:foo
[ tsa ]
default_tsa                     = tsa_config1
[ tsa_config1 ]
dir		                        = ${CAPATH}
serial		                    = ${CAPATH}/tsaserial
crypto_device	                = builtin
signer_cert	                    = ${CAPATH}/tsacert.pem
certs		                    = ${CACERT}
signer_key	                    = ${CAPATH}/private/tsakey.pem
default_policy	                = tsa_policy1
other_policies	                = tsa_policy2, tsa_policy3
digests		                    = md5, sha1
accuracy	                    = secs:1, millisecs:500, microsecs:100
clock_precision_digits          = 0
ordering		                = yes
tsa_name		                = yes
ess_cert_id_chain	            = no
EOF
    if [ "$?" -gt 0 ]; then
        echo "Failed to create openssl configuration file ${OPENSSLCONF}"
        exit 1
    fi
}

##
# END FUNCTIONS
##

##
# START OPERATIONS
##

checkOptions "$@"
checkInstall

if [ -z "${CN}" ]; then
    printHelp
fi
if [ "${GENKEY}" -eq 1 ]; then
    genKey
fi
if [ "${GENCSR}" -eq 1 ]; then
    genCSR
fi
if [ "${SIGNCSR}" -eq 1 ]; then
    signCSR
fi
if [ "${GENKEY}" -eq 0 ] && [ "${GENCSR}" -eq 0 ] && [ "${SIGNCSR}" -eq 0 ]; then
    printHelp
fi


##
# END OPERATIONS
##

exit 0
