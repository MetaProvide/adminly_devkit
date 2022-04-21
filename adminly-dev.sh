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
		git -C "$1" pull --all
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
	get_git_repo git@github.com:MetaProvide/adminly_clients.git ../adminly_clients
	get_git_repo git@github.com:SergeyMosin/Appointments.git ../Appointments
	print "Installing dependencies for Adminly Devkit"
	get_dependencies "."
	print "Installing dependencies for Adminly Core"
	get_dependencies "../adminly_core"
	print "Installing dependencies for Adminly Dashboard"
	get_dependencies "../adminly_dashboard"
	print "Installing dependencies for Adminly Clients"
	get_dependencies "../adminly_clients"
}

function update ()
{
	print "Updating git repos"
	update_git_repo "../adminly_core"
	update_git_repo "../adminly_dashboard"
	update_git_repo "../Appointments"
	print "Updating dependencies for Adminly Devkit"
	update_dependencies "."
	print "Updating dependencies for Adminly Core"
	update_dependencies ../adminly_core
	print "Updating dependencies for Adminly Dashboard"
	update_dependencies ../adminly_dashboard
	print "Updating dependencies for Adminly Clients"
	update_dependencies ../adminly_clients
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
	print "Enabling background jobs with cron"
	docker-compose exec -u www-data nextcloud php occ background:cron
	print "Disabling unneeded apps"
	docker-compose exec -u www-data nextcloud php occ app:disable activity dashboard photos firstrunwizard recommendations
	print "Install needed apps from Nextcloud app store"
	docker-compose exec -u www-data nextcloud php occ app:install calendar
	docker-compose exec -u www-data nextcloud php occ app:install appointments
	docker-compose exec -u www-data nextcloud php occ app:install spreed
	print "Configuring Nextcloud"
	# Configure user settings
	docker-compose exec -u www-data nextcloud php occ user:setting -q testsson settings display_name "Testsson Test"
	docker-compose exec -u www-data nextcloud php occ user:setting testsson settings email "test@example.com"
	# Configure theming settings
	docker-compose exec -u www-data nextcloud php occ theming:config name "Adminly"
	docker-compose exec -u www-data nextcloud php occ theming:config slogan "Platform with Human Touch"
	docker-compose exec -u www-data nextcloud php occ theming:config url "https://adminly.org"
	# Disable rich workspaces
	docker-compose exec -u www-data nextcloud php occ config:app:set text workspace_available --value=0
	# Enable Adminly apps
	docker-compose exec -u www-data nextcloud php occ app:enable adminly_core adminly_dashboard adminly_clients
	# Set Adminly Dashboard as the default app
	docker-compose exec -u www-data nextcloud php occ config:system:set --value="adminly_dashboard,files" defaultapp
	# Create Appointment slots calendar
	if ! docker-compose exec -u www-data nextcloud php occ dav:list-calendars testsson | grep -c "appointment-slots" > /dev/null ; then
		docker-compose exec -u www-data nextcloud php occ dav:create-calendar testsson appointment-slots
	fi
	# Update Display name and colour for the calendars
	docker-compose exec mariadb mysql -u nextcloud -pnextcloud nextcloud \
		-e "UPDATE oc_calendars SET displayname = 'Main Calendar', calendarcolor = '#0082c9' WHERE principaluri = 'principals/users/testsson' AND uri = 'personal';";
	docker-compose exec mariadb mysql -u nextcloud -pnextcloud nextcloud \
		-e "UPDATE oc_calendars SET displayname = 'Appointment Slots', calendarcolor = '#8d12ac' WHERE principaluri = 'principals/users/testsson' AND uri = 'appointment-slots';";
	# Configure Appointments
	if docker-compose exec mariadb mysql -u nextcloud -pnextcloud nextcloud -e "SELECT * from oc_appointments_pref;" | grep -c "testsson" > /dev/null ; then
		docker-compose exec mariadb mysql -u nextcloud -pnextcloud nextcloud \
			-e "UPDATE oc_appointments_pref
				SET org_info = '{\"organization\":\"Testsson\",\"email\":\"test@example.com\",\"address\":\"Test heaven\",\"phone\":\"123456789\"}',
					calendar_settings = '{\"mainCalId\":\"-1\",\"destCalId\":\"-1\",\"nrSrcCalId\":\"3\",\"nrDstCalId\":\"1\",\"nrPushRec\":true,\"nrRequireCat\":false,\"nrAutoFix\":false,\"tmmDstCalId\":\"-1\",\"tmmMoreCals\":[],\"tmmSubscriptions\":[],\"tmmSubscriptionsSync\":\"0\",\"prepTime\":\"15\",\"bufferBefore\":0,\"bufferAfter\":0,\"whenCanceled\":\"mark\",\"allDayBlock\":true,\"privatePage\":false,\"tsMode\":\"1\"}',
					email_options = '{\"icsFile\":true,\"skipEVS\":false,\"attMod\":true,\"attDel\":true,\"meReq\":true,\"meConfirm\":true,\"meCancel\":true,\"vldNote\":\"\",\"cnfNote\":\"\",\"icsNote\":\"\"}',
					pages = '{\"p0\":{\"enabled\":1,\"label\":\"\"}}',
					page_options = '{\"formTitle\":\"\",\"nbrWeeks\":\"12\",\"showEmpty\":false,\"startFNED\":false,\"showWeekends\":false,\"time2Cols\":false,\"endTime\":true,\"hidePhone\":false,\"showTZ\":true,\"gdpr\":\"\",\"gdprNoChb\":false,\"pageTitle\":\"Book your appointment\",\"pageSubTitle\":\"Mindfulness\",\"metaNoIndex\":true,\"pageStyle\":\"\"}',
					appt_talk = '{\"enabled\":true,\"delete\":true,\"emailText\":\"\",\"lobby\":true,\"password\":false,\"nameFormat\":0,\"formFieldEnable\":true,\"formLabel\":\"\",\"formPlaceholder\":\"\",\"formTxtReal\":\"\",\"formTxtVirtual\":\"\",\"formTxtTypeChange\":\"\"}',
					reminders = '{\"data\":[{\"seconds\":\"3600\",\"actions\":true},{\"seconds\":\"0\",\"actions\":true},{\"seconds\":\"0\",\"actions\":true}],\"friday\":false,\"moreText\":\"\"}'
				WHERE user_id = 'testsson';";
	else
		docker-compose exec mariadb mysql -u nextcloud -pnextcloud nextcloud \
			-e "INSERT INTO oc_appointments_pref
				SET user_id = 'testsson',
					org_info = '{\"organization\":\"Testsson\",\"email\":\"test@example.com\",\"address\":\"Test heaven\",\"phone\":\"123456789\"}',
					calendar_settings = '{\"mainCalId\":\"-1\",\"destCalId\":\"-1\",\"nrSrcCalId\":\"3\",\"nrDstCalId\":\"1\",\"nrPushRec\":true,\"nrRequireCat\":false,\"nrAutoFix\":false,\"tmmDstCalId\":\"-1\",\"tmmMoreCals\":[],\"tmmSubscriptions\":[],\"tmmSubscriptionsSync\":\"0\",\"prepTime\":\"15\",\"bufferBefore\":0,\"bufferAfter\":0,\"whenCanceled\":\"mark\",\"allDayBlock\":true,\"privatePage\":false,\"tsMode\":\"1\"}',
					email_options = '{\"icsFile\":true,\"skipEVS\":false,\"attMod\":true,\"attDel\":true,\"meReq\":true,\"meConfirm\":true,\"meCancel\":true,\"vldNote\":\"\",\"cnfNote\":\"\",\"icsNote\":\"\"}',
					pages = '{\"p0\":{\"enabled\":1,\"label\":\"\"}}',
					page_options = '{\"formTitle\":\"\",\"nbrWeeks\":\"12\",\"showEmpty\":false,\"startFNED\":false,\"showWeekends\":false,\"time2Cols\":false,\"endTime\":true,\"hidePhone\":false,\"showTZ\":true,\"gdpr\":\"\",\"gdprNoChb\":false,\"pageTitle\":\"Book your appointment\",\"pageSubTitle\":\"Mindfulness\",\"metaNoIndex\":true,\"pageStyle\":\"\"}',
					appt_talk = '{\"enabled\":true,\"delete\":true,\"emailText\":\"\",\"lobby\":true,\"password\":false,\"nameFormat\":0,\"formFieldEnable\":true,\"formLabel\":\"\",\"formPlaceholder\":\"\",\"formTxtReal\":\"\",\"formTxtVirtual\":\"\",\"formTxtTypeChange\":\"\"}',
					reminders = '{\"data\":[{\"seconds\":\"3600\",\"actions\":true},{\"seconds\":\"0\",\"actions\":true},{\"seconds\":\"0\",\"actions\":true}],\"friday\":false,\"moreText\":\"\"}';";
	fi
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

function dummy_data ()
{
	print "Inserting dummy Adminly Clients data"
	docker-compose exec mariadb mysql -u nextcloud -pnextcloud nextcloud \
		-e "INSERT INTO oc_adminly_clients (provider_id, email, name, description)
			VALUES
				('testsson', 'test0@example.com', 'Matthew Barnes', 'Some description'),
				('testsson', 'test1@example.com', 'Poppy Archer', 'Some description'),
				('testsson', 'test2@example.com', 'Mohammed Clark', 'Some description'),
				('testsson', 'test3@example.com', 'Jordan Holmes', 'Some description'),
				('testsson', 'test4@example.com', 'Sean Blake', 'Some description'),
				('testsson', 'test5@example.com', 'Oscar Mitchell', 'Some description'),
				('testsson', 'test6@example.com', 'Eva Hopkins', 'Some description'),
				('testsson', 'test7@example.com', 'Isabella Cooke', 'Some description'),
				('testsson', 'test8@example.com', 'Brooke Bibi', 'Some description'),
				('testsson', 'test9@example.com', 'Toby Burgess', 'Some description');";
}

function display_help ()
{
	echo "Adminly dev script"
	echo "======================================="
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
	echo "dummy-data         Inserts dummy data into the database"
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
	"dummy-data")
		dummy_data
		;;
	"help")
		display_help
		;;
	"")
		display_help
		;;
esac
