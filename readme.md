docker-letsencrypt-certgen
==========================

**[Work in progress]**

Generate, renew, revoke RSA and/or ECDSA SSL certificates from [LetsEncrypt CA](https://letsencrypt.org/) using [certbot](https://certbot.eff.org/) and [acme.sh](https://github.com/Neilpang/acme.sh) clients in automated fashion.

Goal
----
This project might be one you're looking for, if:

- you need to obtain new SSL certificate for your new shiny domain/website
- you need simple domain validated (DV) certificate, and you don't want to pay money to Certificate Authorities (CA), like DigiCert or Symantec for humble DV certificates.
- you've heard about [LetsEncrypt CA](https://letsencrypt.org/), which allows to automate issueance of free DV certificates, but you're lazy enough to learn in-depth and don't want to spent much time there.
- you need to have both RSA and ECDSA certificates
- you're learning LetsEncrypt and want to check out [certbot](https://certbot.eff.org/) and [acme.sh](https://github.com/Neilpang/acme.sh) clients usage primers
- you're using Docker to deploy/run your app and services, and you're going to automate process of certificate issueance and/or renewal (e.g as a part of CI/CD process).

So, this Docker image provides a simple single entrypoint to obtain and manage SSL certificates from LetsEncrypt CA. It encapsulates two popular ACME clients: [certbot](https://certbot.eff.org/) and [acme.sh](https://github.com/Neilpang/acme.sh), which are used to obtain RSA and/or ECDSA certificates respectively.

Following single responsibilty principle, this image cares only about how to talk to LetsEncrypt CA to provide you with a certificate, and it's completely unaware and not coupled with web server software or any other infrastructure service. This approach makes it a more versatile tool and unlocks greater number of use cases. 

You can use it ad-hoc at a build time, at a run-time prior to Nginx/Apache startup, or by running it from cron job to renew certificates on regular basis. LetsEncrypt stuff stays within a single container, and you don't need to pollute your Nginx/Apache container.


Features
--------

Here is a list of notable features:

- automate issueance and managing LetsEncrypt SSL certificates
- generate DV certificates for 1..N domains
- support multi-domain SAN (Subject alternative names) certificates
- generate RSA and/or ECDSA certificate with configurable key params: RSA key length (2048, 3072, 4096) and elliptic curve for EC key (prime256v1, secp384r1)
- choose DV challenge verification method: standalone or webroot
- renew certificates when they're about to expire or force renewal
- revoke certificates by contacting LetsEncrypt CA
- use either LetsEncrypt staging or production server

Prerequisites
-------------
It's assumed you already have a domain name, a server, and a working DNS configuration with at least "A" record mapping name to your server's IP address.

In a standalone mode, you need to run this image on that server, with 80 port opened by firewall, so ACME http-01 challenge verification succeeds.

Getting started
---------------
Let's say I have `foobbz.site` domain, DigitalOcean droplet with running Docker Engine (188.166.168.213), and DNS "A" record "foobbz.site"->"188.166.168.213".

Let's issue new RSA (2048 bit length) and ECDSA (prime256v1 curve) certificate for single domain "foobbz.site":

```
docker run \
  -v /var/ssl:/var/ssl \
  -p 80:80 \
  -e DOMAINS=foobbz.site \
  --rm \
  samoshkin/letsencrypt-certgen issue
```

Once done, container stops and is automatically removed (--rm). Certificates, keys and related files are stored in `/var/ssl/foobbz.site`:

```
# tree /var/ssl

/var/ssl
└── foobbz.site
    ├── certs
    │   ├── cert.ecc.pem
    │   ├── cert.rsa.pem
    │   ├── chain.ecc.pem
    │   ├── chain.rsa.pem
    │   ├── fullchain.ecc.pem
    │   └── fullchain.rsa.pem
    └── private
        ├── privkey.ecc.pem
        └── privkey.rsa.pem
```

All files are encoded in PEM format.

- `cert.rsa.pem`, `cert.ecc.pem` - generated certificate (RSA or ECDSA)
- `chain.[type].pem` - chain of intermediate CA certificates (e.g. Fake LE Intermediate X1)
- `fullchain.[type].pem` - generated certificate bundled with intermediate CA certificates. Suitable for Nginx configuration directive `ssl_certificate`, which should point to a bundle, instead of individual certificate.
- `privkey.[type].pem` - private key file

Given that, you can then mount `/var/ssl:/etc/nginx/ssl` into Nginx container and configure it to use RSA or ECDSA key or even both.

```
# RSA certificates
ssl_certificate       /etc/nginx/ssl/foobbz.site/certs/fullchain.rsa.pem;
ssl_certificate_key   /etc/nginx/ssl/foobbz.site/private/privkey.rsa.pem;

# ECDSA certificates
ssl_certificate       /etc/nginx/ssl/foobbz.site/certs/fullchain.ecc.pem;
ssl_certificate_key   /etc/nginx/ssl/foobbz.site/private/privkey.ecc.pem;
```

Multiple certificates and multi-domain SAN certificates
-------------------------------------------------

You're not limited to certificate with single domain only. You can generate several individual certificates for different domains. Or you can have single multi-domain SAN (Subject Alternate Names) certificate. Or both.

Prepare `domains.txt` file. Each line represents individual certificate to be issued. First name within each line is a common name, subsequent comma-separated names are certificate alternative names.

```
# cat /root/domains.txt

foobbz.site,www.foobbz.site,web.foobbz.site
foobbz2.site,www.foobbz.site
```

Tell container to pick up domains list from `domains.txt`. `$DOMAINS` variable is double-purpose: it indicates either domains list as a string or points to a file with a domains list.

```
docker run \
  -v /var/ssl:/var/ssl \
  -v /root/domains.txt:/etc/domains.txt \
  -p 80:80 \
  -e DOMAINS=/etc/domains.txt \
  --rm \
  samoshkin/letsencrypt-certgen issue
```



As a result, we have 2 individual certificates generated:

```
ls /var/ssl

foobbz.site
foobbz2.site
```

And let's check out how multiple domains are stored in the certificate in X.509 SAN extension.

```
docker run -v /var/ssl:/var/ssl --entrypoint sh --rm -it alpine
/ # apk --update add openssl
/ # openssl x509 -in /var/ssl/foobbz.site/certs/cert.rsa.pem -noout -text
```

```
Issuer: CN=Fake LE Intermediate X1
Subject: CN=foobbz.site
...
X509v3 extensions:
  X509v3 Subject Alternative Name:
    DNS:foobbz.site, DNS:web.foobbz.site, DNS:www.foobbz.site
```

Volumes and managing your certificates
--------------------------------------
Each LetsEncrypt client (certbot, acme.sh) manages its own place to store certificates, keys, account keys and various settings. You need to ensure this location is stored outside of the container for persistency.

```
docker volume create --name ssl
docker volume create --name acme
docker volume create --name letsencrypt

docker run \
  -v ssl:/var/ssl \
  -v acme:/etc/acme \
  -v letsencrypt:/etc/letsencrypt \
  -p 80:80 \
  -e DOMAINS=foobbz.site \
  --rm \
  samoshkin/letsencrypt-certgen issue
```

`/etc/acme` and `/etc/letsencrypt` are just internal storages of `acme.sh` and `certbot` clients, which are used under the hood. They contain certificates, keys, various settings, but we don't use them directly as their structure varies and is a subject to change. Therefore, `/var/ssl` volume serves as a target drop location for certificates and keys. You should mount `/var/ssl` into any container, that needs certificates (e.g. Nginx).

Once you enabled persistency for "certbot" and "acme.sh" clients internal storage, you can perform management actions, like renewing, revoking or deleting a certificate.

LetsEncrypt CA issues short-lived certificates which are only valid for 90 days. While renewing, it will check certificate validity period. If it's not due to expire (more than 1 month before expiration date), existing certificate will be kept. You can force renewal:

```
docker run \
  -v ssl:/var/ssl \
  -v acme:/etc/acme \
  -v letsencrypt:/etc/letsencrypt \
  -p 80:80 \
  -e DOMAINS=foobbz.site \
  -e FORCE_RENEWAL=1 \
  --rm \
  samoshkin/letsencrypt-certgen renew
```

Use `revoke` or `delete` commands to trigger respective actions. Use `$DOMAINS` variable to specify particular domain to revoke or delete. It's ok to tell just common name, no need to specify all alternative names, as you did for `issue` command.

When revoking certificate, it will not remove files neither from internal storages, nor from `/var/ssl` volume. On the other hand, deleting certificate removes from both locations, but do not revoke certificate by contacting LetsEncrypt CA.

Challenge verification method: standalone vs webroot
-----------------------------------------------------

When issuing certificate, CA needs to verify domain ownership. This project uses simple `http-01` method.

Here is how it works. LetsEncrypt client creates a special file. CA contacts `foobbz.site` domain on port 80 with `GET /.well-known/acme-challenge` request for that file. If request succeeds, it proves the domain ownership.

In standalone mode, during challenge verification `certbot` or `acme.sh` spin up an embedded web server, which listens on port 80 and is capable of serving that file. This is a default setting.

If you already have a running web server on port 80, you can opt for `webroot` mode. `acme.sh` or `certbot` will just store the file at predefined location, and your web server will handle serving it from that location at particular url.

Create a dedicated volume:
```
docker volume create --name acme_challenge_webroot
```

When running Nginx container, make sure to mount it:
```
docker run \
  -v ssl:/etc/nginx/ssl
  -v acme_challenge_webroot:/var/www/acme_challenge_webroot
  -p 80:80 \
  -p 443:443 \
  --name web
  my-nginx-container
```

Configure Nginx to serve `/.well-known/acme-challenge` requests from that volume:

```
server {
    listen  80;
    server_name foobbz.site www.foobbz.site;

    location ^~ /.well-known/acme-challenge {
      allow all;
      root /var/www/acme_challenge_webroot;
      default_type text/plain;
    }
}
```

Finally, run this image in `webroot` mode to issue/renew certificates. Tip: you can do this from cron job to renew on regular basis. Note, when using `webroot` method, there is no need to expose 80 port on this container any more.

```
docker run \
  -v ssl:/var/ssl \
  -v acme:/etc/acme \
  -v letsencrypt:/etc/letsencrypt \
  -v acme_challenge_webroot:/var/acme_challenge_webroot \
  -e DOMAINS=foobbz.site \
  -e CHALLENGE_MODE=webroot \
  --rm \
  samoshkin/letsencrypt-certgen renew
```

Main use case for `webroot` method, is the ability to renew certificates, without a need to stop you existing web server and running applications.


RSA and ECDSA certificates
--------------------------
`certbot` is not capable of generating ECDSA yet (except from custom CSR). So, `cerbot` is used for RSA, whereas `acme.sh` is for ECDSA.

Default is to generate both. But you can disable one or another using `$RSA_ENABLED` and `$ECDSA_ENABLED` environment variables.

Also, you can configure RSA key length: 2048, 3072 or 4096. For ECDSA key, you can tell elliptic curve: prime256v1 (ec-256), secp384r1 (ec-384), secp521r1 (ec-521, not yet supported by LetsEncrypt CA).

For example:

```
docker run \
  -v ssl:/var/ssl \
  -p 80:80 \
  -e DOMAINS=foobbz.site \
  -e RSA_ENABLED=0
  -e ECDSA_KEY_LENGTH=ec-384
  --rm \
  samoshkin/letsencrypt-certgen renew
```

Note, that ECDSA certificates are still signed by LetsEncrypt's RSA certificate chain (Fake LE Intermediate X1, Fake LE Root X1). LetsEncrypt does not use dedicated EC certificates to sign for complete EC chain.

Using LetsEncrypt staging server
--------------------------------
Be aware, that LetsEncrypt CA production servers put strict [rate limits](https://letsencrypt.org/docs/rate-limits/):

- certificates per Registered Domain (20 per week)
- up to 100 alternative names per certificate
- duplicate certificate limit of 5 certificates per week

While you're trying and experimenting, it's better to use LetsEncrypt [staging environment](https://letsencrypt.org/docs/staging-environment/) with much relaxed limits:

- The Certificates per Registered Domain limit is 30,000 per week.
- The Duplicate Certificate limit is 30,000 per week.
- The Failed Validations limit is 60 per hour.
- The Accounts per IP Address limit is 50 accounts per three 3 hour period per IP.

Using staging server is a default option here. To switch to production servers, set `STAGING=0` environment variable.

`/var/ssl` volume permissions and ownership
-------------------------------------------
When using sharing volumes, permissions and ownership issue needs to be resolved.

It's a good practice to restrict permissions for private key files, so it's not world accessible (`umask 007`), or even group accessible (`umask 077`). On the other hand, we need to make sure that SSL certificates/keys can be read when mounted into another container, which runs as a less-priviledged non-root user (Nginx running as nginx:nginx).

The solution is to set group ownership to a dedicated GID, and let less-priviledged user in other containers join that group to access files. When running container, you can override GID (default is `1337`):

```
docker run \
  -v ssl:/var/ssl \
  -p 80:80 \
  -e DOMAINS=foobbz.site \
  -e SSL_GROUP_ID=1561
  --rm \
  samoshkin/letsencrypt-certgen renew
```

Check out permissions and ownership of created certificates:

```
tree -pug /var/ssl

/var/ssl
└── [drwxr-xr-x root     1561]  foobbz.site
    ├── [drwxr-xr-x root     1561]  certs
    │   ├── [-rw-r--r-- root     1561]  cert.ecc.pem
    │   ├── [-rw-r--r-- root     1561]  cert.rsa.pem
    │   ├── [-rw-r--r-- root     1561]  chain.ecc.pem
    │   ├── [-rw-r--r-- root     1561]  chain.rsa.pem
    │   ├── [-rw-r--r-- root     1561]  fullchain.ecc.pem
    │   └── [-rw-r--r-- root     1561]  fullchain.rsa.pem
    └── [drwxr-x--- root     1561]  private
        ├── [-rw-r----- root     1561]  privkey.ecc.pem
        └── [-rw-r----- root     1561]  privkey.rsa.pem
```

You can see that all files has `root:1561` ownership. Note, it's not required to create a real group in `/etc/group`, it's enough to just assign numeric GIDs.

`/var/ssl/foobbz.site/private` directory has `750` perm mode, and key files inside it are `640`. So it's not world accessible, and only user with a dedicated group membership can read those files.

Docker compose sugar
--------------------
When trying or experimenting with this image, it becomes tough to type long `docker run` commands. Use `docker-compose` instead:

```
docker-compose build && docker-compose run --rm -p 80:80 certgen issue
```

And `docker-compose.yml` file looks like:

```
version: '2'

services:
  certgen:
    image: samoshkin/letsencrypt-certgen
    environment:
      - DOMAINS=foobbz.site,www.foobbz.site,web.foobbz.site
      - VERBOSE=1
    volumes:
      - letsencrypt:/etc/letsencrypt
      - acme:/etc/acme
      - ssl:/var/ssl
      - acme_challenge_webroot:/var/acme_challenge_webroot
volumes:
  letsencrypt:
  acme:
  ssl:
  acme_challenge_webroot:
```


