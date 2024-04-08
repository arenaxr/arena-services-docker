from python:3-alpine3.13

# install bash, compiler (build-base), envsubst (gettext), curl, wget, openssl, git, node and other dependencies
RUN apk add --update --no-cache bash build-base libffi-dev gettext curl wget libressl-dev openssl openssl-dev git nodejs npm musl-dev libffi-dev musl-dev cargo perl-utils && \
    rm -rf /var/cache/apk/*

RUN pip install --no-cache --upgrade pip setuptools wheel
RUN pip install certbot-nginx

RUN mkdir /utils
WORKDIR /utils

COPY . .
RUN pip install -r /utils/requirements.txt

