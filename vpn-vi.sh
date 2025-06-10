#!/bin/sh

echo connect to viessmann vpn

/home/kmpi/devel/bin/openconnect.sh -c vpn.viessmann.net \
	--cafile '/home/kmpi/certs/cafile' \
	--servercert sha256:816c005ed53913fa169862713c037059920f98fd0fa450a12d642c75d3740b6b \
        -c 'pkcs11:model=PKCS%2315;manufacturer=www.atos.net%2fcardos;serial=8BE35A3A313FF23C;token=CardOS%20PKCS%2315%20Default%20Profile;id=%da%ad%a3%eb%6a%3d%6e%8b%0a%2c%28%0f%72%27%53%c4%1b%bd%81%bf;object=6768911-a2a7-4c58-2f441a3a00d67e7;type=cert'

# my cert
# 'pkcs11:model=PKCS%2315;manufacturer=www.atos.net%2fcardos;serial=8BE35A3A313FF23C;token=CardOS%20PKCS%2315%20Default%20Profile;id=%da%ad%a3%eb%6a%3d%6e%8b%0a%2c%28%0f%72%27%53%c4%1b%bd%81%bf;object=6768911-a2a7-4c58-2f441a3a00d67e7;type=cert'


