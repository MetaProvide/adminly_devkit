#!/usr/bin/env bash
#==============================================================================
# adminly-dev.sh - v0.1.0
#
# Tooling script for Adminly development
#
# @copyright Copyright (C) 2022  Magnus Walbeck <magnus@metaprovide.org>
#
# @author Magnus Walbeck <magnus@metaprovide.org>
#
# @license GNU AGPL version 3 or any later version
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#==============================================================================

#=======================================
# Helper functions
#=======================================

function print ()
{
	echo "$1"
	sleep 0.5
}

function get_git_repo ()
{
	if [ ! -d "$2" ] ; then
		git clone "$1" "$2"
	fi
}

function update_git_repo ()
{
	if [ -d "$1" ] ; then
		git -C "$1" pull
	else
		print "Repo doesn't exist!"
	fi
}

function get_dependencies ()
{
	if [ -f "${1}/composer.json" ] ; then
		print "Installing composer dependencies"
		composer install -q -n -d "$1"
	fi

	if [ -f "${1}/package.json" ] ; then
		print "Installing NPM dependencies"
		npm install --silent -C "$1"
	fi

	if [ -f "${1}/webpack.config.js" ] ; then
		print "Running Webpack"
		npm run dev -C "$1"
	fi
}

function update_dependencies ()
{
	get_dependencies "$1"
}

#=======================================
# Action functions
#=======================================

function init ()
{
	print "Initialising Adminly dev environment"
	print "Cloning git repos"
	get_git_repo git@github.com:MetaProvide/adminly_core.git ../adminly_core
	get_git_repo git@github.com:MetaProvide/adminly_dashboard.git ../adminly_dashboard
	print "Installing dependencies for Adminly Devkit"
	get_dependencies "."
	print "Installing dependencies for Adminly Core"
	get_dependencies "../adminly_core"
	print "Installing dependencies for Adminly Dashboard"
	get_dependencies "../adminly_dashboard"
}

function update ()
{
	print "Updating git repos"
	update_git_repo "../adminly_core"
	update_git_repo "../adminly_dashboard"
	print "Updating dependencies for Adminly Devkit"
	update_dependencies "."
	print "Updating dependencies for Adminly Core"
	update_dependencies ../adminly_core
	print "Updating dependencies for Adminly Dashboard"
	update_dependencies ../adminly_dashboard
}

function setup ()
{
	print "Setting up Adminly dev environment"
	docker-compose up -d
	docker-compose exec nextcloud chown www-data /var/www/html/custom_apps
	print "Waiting for Nextcloud to initialise"
	while ! docker-compose exec -u www-data nextcloud php occ status | grep -c "installed: true" > /dev/null
	do
		sleep 1
	done
	print "Disabling unneeded apps"
	docker-compose exec -u www-data nextcloud php occ app:disable activity dashboard photos firstrunwizard recommendations
	print "Install needed apps from Nextcloud app store"
	docker-compose exec -u www-data nextcloud php occ app:install calendar
	docker-compose exec -u www-data nextcloud php occ app:install side_menu
	print "Configuring Nextcloud"
	# Configure theming settings
	docker-compose exec -u www-data nextcloud php occ theming:config name "Adminly"
	docker-compose exec -u www-data nextcloud php occ theming:config slogan "Platform with Human Touch"
	docker-compose exec -u www-data nextcloud php occ theming:config url "https://adminly.org"
	# Disable rich workspaces
	docker-compose exec -u www-data nextcloud php occ config:app:set text workspace_available --value=0
	# Configure side menu / custom menu
	docker-compose exec -u www-data nextcloud php occ config:app:set side_menu always-displayed --value=1
	# Enable Adminly apps
	docker-compose exec -u www-data nextcloud php occ app:enable adminly_core adminly_dashboard
	print "Done!"
}

function destroy ()
{
	echo "Tearing down Adminly dev environment and deleting volumes"
	docker-compose down
	docker volume rm adminly_devkit_mariadb
	docker volume rm adminly_devkit_nextcloud
}

function up ()
{
	docker-compose up -d
}

function down ()
{
	docker-compose down
}

function full_init()
{
	init
	setup
}

function display_help ()
{
	echo "Adminly dev script"
	echo "======================================="
	echo
	echo "Script for managing the Adminly dev environment"
	echo
	echo "Syntax: ./adminly-dev.sh [action]"
	echo
	echo "Actions:"
	echo "---------------------------------------"
	echo "help               Display this help"
	echo "init               Git clones and then installs dependencies for all Adminly repos"
	echo "setup              Spins up the docker containers and configures Nextcloud"
	echo "full-init          Runs init followed by setup"
	echo "update             Git pulls and updates dependencies for all Adminly repos"
	echo "destroy            Brings down the docker containers and deletes related docker volumes"
	echo "up                 Brings up the docker containers"
	echo "down               Brings down the docker containers"
	echo
	echo "======================================="
}

#=======================================
# Script
#=======================================

HISTIGNORE='*'

case "$1" in
	"init")
		init
		;;
	"setup")
		setup
		;;
	"full-init")
		full_init
		;;
	"update")
		update
		;;
	"destroy")
		destroy
		;;
	"up")
		up
		;;
	"down")
		down
		;;
	"help")
		display_help
		;;
	"")
		display_help
		;;
esac