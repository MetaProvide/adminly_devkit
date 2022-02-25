# This file is licensed under the Affero General Public License version 3 or
# later. See the LICENSE file.

app_name=adminly_devkit
build_directory=$(CURDIR)/build
sign_directory=$(build_directory)/sign
cert_directory=$(HOME)/.nextcloud/certificates

all: dev-setup prettier stylelint

dev-setup: npm-init

npm-init:
	npm ci

prettier:
	npm run prettier

prettier-fix:
	npm run prettier:fix

stylelint:
	npm run stylelint

stylelint-fix:
	npm run stylelint:fix
