#!/bin/bash

##################################################################################
#  Program: ./openerp_install.sh (first do chmod +x openerp_install.sh)
#  Author : Yashodhan S Kulkarni [ Securiace Technologies - www.securiace.com ]
#  Build  : 0.1.5
##################################################################################

read -e -p "\n\nEnter FQDN: " ERP_HOSTNAME
read -e -p "\nEnter System Website User: " ERP_SYS_USER
read -e -p "\nEnter PostgreSQL Database Name: " ERP_DB_NAME
read -e -p "\nEnter PostgreSQL Database Username: " ERP_DB_USER
read -e -p "\nEnter PostgreSQL Database Password: " ERP_DB_PASS
read -e -p "\nEnter OpenERP Type (server OR gevent): " OPENERP_SERVER_TYPE
export ERP_HOSTNAME
export ERP_SYS_USER
export ERP_DB_NAME
export ERP_DB_USER
export ERP_DB_PASS
export OPENERP_SERVER_TYPE

#export ERP_HOSTNAME="erp.sri-marks.com"
#export ERP_SYS_USER="test"
#export ERP_DB_NAME="testdb"
#export ERP_DB_USER="test"
#export ERP_DB_PASS="test"
#export OPENERP_SERVER_TYPE="server"

function start_point() {
    function add_pg_repo () {
        su -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ saucy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -'
    }
    function pull_updates () {
        su -c "apt-get update"
    }
    function install_libs_pgsql () {
        su -c "apt-get install -y python-dev build-essential python-yaml python-geoip libyaml-dev libpq-dev libev4 libev-dev libc6-dev uwsgi nginx bzr git graphviz ghostscript postgresql-client-9.3 libxml2-dev libxslt1-dev libjpeg62-dev zlib1g-dev python-virtualenv python-pip gettext libldap2-dev libsasl2-dev uwsgi-plugin-python postgresql-9.3 openssl build-essential xorg libssl-dev"
    }
    function install_wkhtmltopdf () {
        su -c "unlink /usr/bin/wkhtmltopdf; rm -fr wkhtmltox*; rm -fr /etc/wkhtmltox"
        su -c "wget http://downloads.sourceforge.net/project/wkhtmltopdf/0.12.0/wkhtmltox-linux-amd64_0.12.0-03c001d.tar.xz && tar -xJf wkhtmltox-* && mv wkhtmltox /etc/wkhtmltox"
        su -c "ln -s /etc/wkhtmltox/bin/wkhtmltopdf /usr/bin/wkhtmltopdf"
    }
    function www_config () {
        su -c "mkdir -p /var/www"
        su -c "chown www-data:www-data /var/www -R"
    }
    function erp_user_setup () {
        su -c "adduser --system --home=/srv/openerp/${ERP_HOSTNAME} --group ${ERP_SYS_USER}"
        su -c "chown ${ERP_SYS_USER}:${ERP_SYS_USER} /srv/openerp/${ERP_HOSTNAME} -R"
        su -c 'echo "${ERP_SYS_USER} ALL=NOPASSWD: ALL" >> /etc/sudoers'
        su -c 'echo "www-data ALL=NOPASSWD: ALL" >> /etc/sudoers'
    }
    function erp_db_setup () {
        su - postgres -c "createuser ${ERP_DB_USER} -P" && su - postgres -c "createdb ${ERP_DB_NAME} -O ${ERP_DB_USER}"
    }
    function erp_trunk_bazaar_checkout () {
        su - ${ERP_SYS_USER} -s /bin/bash -c "bzr co lp:openerp-web --lightweight /srv/openerp/${ERP_HOSTNAME}/web && bzr co lp:openobject-server --lightweight /srv/openerp/${ERP_HOSTNAME}/server && bzr co lp:openobject-addons --lightweight /srv/openerp/${ERP_HOSTNAME}/addons && bzr co lp:openobject-addons/extra-trunk --lightweight /srv/openerp/${ERP_HOSTNAME}/addons-extra && bzr co lp:~openerp-community/openobject-addons/trunk-addons-community --lightweight /srv/openerp/${ERP_HOSTNAME}/addons-community"
    }
    function erp_virtual_env_setup () {
#cat > /srv/openerp/${ERP_HOSTNAME}/requirements.txt << EOF
#Babel
#Cython
#Jinja2
#Mako
#MarkupSafe
#Pillow
#PyYAML
#docutils
#feedparser
#gdata
#gevent
#lxml
#EOF

    su -c "virtualenv --no-site-packages /srv/openerp/${ERP_HOSTNAME}/${ERP_SYS_USER}env"
    su -c "/srv/openerp/${ERP_HOSTNAME}/${ERP_SYS_USER}env/bin/pip install -e gdata Cython pypdf lxml -- upgrade"
    #su -c "/srv/openerp/${ERP_HOSTNAME}/${ERP_SYS_USER}env/bin/pip install -r /srv/openerp/${ERP_HOSTNAME}/requirements.txt --upgrade --force"
    
    }
    function erp_py_develop () {
        su -c "/srv/openerp/${ERP_HOSTNAME}/${ERP_SYS_USER}env/bin/python /srv/openerp/${ERP_HOSTNAME}/server/setup.py develop"
        su -c "ln -s /srv/openerp/${ERP_HOSTNAME}/web/addons/* /srv/openerp/${ERP_HOSTNAME}/server/openerp/addons/"
        su -c "ln -s /srv/openerp/${ERP_HOSTNAME}/addons/* /srv/openerp/${ERP_HOSTNAME}/server/openerp/addons/"
    }
    function erp_config_stuff () {
        su -c "mkdir -p /srv/openerp/${ERP_HOSTNAME}/server/config"
        function wsgi_config_file () {
            cat > /srv/openerp/${ERP_HOSTNAME}/server/wsgi.py << EOF
import openerp
openerp.multi_process = True # Nah!                                                     
openerp.conf.server_wide_modules = ['web']

conf = openerp.tools.config
conf['addons_path'] = '/srv/openerp/${ERP_HOSTNAME}/server/openerp/addons'
conf['db_name'] = '${ERP_DB_NAME}'
conf['db_host'] = 'localhost'
conf['db_user'] = '${ERP_DB_USER}'
conf['db_port'] = 5432
conf['db_password'] = '${ERP_DB_PASS}'
conf['dbfilter'] = '${ERP_DB_NAME}'
conf['list_db'] = 'False'
application = openerp.service.wsgi_server.application
openerp.service.server.load_server_wide_modules()
EOF
        }
        function tmp_conf () {
            cat > /srv/openerp/${ERP_HOSTNAME}/server/tmp.conf << EOF
[options]
addons_path=/srv/openerp/${ERP_HOSTNAME}/server/openerp/addons
db_name = ${ERP_DB_NAME}
db_host = localhost
db_user = ${ERP_DB_USER}
db_port = 5432
db_password = ${ERP_DB_PASS}
EOF
        }
        function uwsgi_ini () {
            cat > /srv/openerp/${ERP_HOSTNAME}/server/config/uwsgi.ini << EOF
[uwsgi]
chdir=/srv/openerp/${ERP_HOSTNAME}/server/
uid=www-data
gid=www-data
virtualenv=/srv/openerp/${ERP_HOSTNAME}/${ERP_SYS_USER}env
socket=/srv/openerp/${ERP_HOSTNAME}/uwsgi.sock
wsgi-file=wsgi.py
master=True
vacuum=True
max-requests=5000
buffer-size=32768
# set cheaper algorithm to use, if not set default will be used
cheaper-algo = spare
# minimum number of workers to keep at all times
cheaper = 3
# number of workers to spawn at startup
cheaper-initial = 6
# maximum number of workers that can be spawned
workers = 12
# how many workers should be spawned at a time
cheaper-step = 1
cheaper-rss-limit-soft = 134217728
cheaper-rss-limit-hard = 167772160
cheaper-overload = 10
EOF
            ln -s /srv/openerp/${ERP_HOSTNAME}/server/config/uwsgi.ini /etc/uwsgi/apps-enabled/${ERP_HOSTNAME}.ini
        }
        function nginx_conf () {
            cat > /srv/openerp/${ERP_HOSTNAME}/server/config/nginx.conf << EOF
server {
listen 80;
server_name ${ERP_HOSTNAME};
client_max_body_size 50M;
keepalive_timeout 120;

location / {
include uwsgi_params;
uwsgi_read_timeout 300;
uwsgi_pass unix:/srv/openerp/${ERP_HOSTNAME}/uwsgi.sock;
}
}
EOF
        su -c "ln -s /srv/openerp/${ERP_HOSTNAME}/server/config/nginx.conf /etc/nginx/sites-enabled/${ERP_HOSTNAME}.conf"
        su -c "sed -i 's/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 64;/g' /etc/nginx/nginx.conf"
        }
    wsgi_config_file
    tmp_conf
    uwsgi_ini
    nginx_conf
    }
    function www_chown_takeover () {
        chown -R www-data:www-data /srv/openerp/${ERP_HOSTNAME}
    }
    function erp_init_run () {
        su - www-data -s /bin/bash -c "/srv/openerp/${ERP_HOSTNAME}/server/openerp-${OPENERP_SERVER_TYPE} -c /srv/openerp/${ERP_HOSTNAME}/server/tmp.conf -d ${ERP_DB_NAME}db -u all --stop-after-init"
        #/srv/openerp/${ERP_HOSTNAME}/${ERP_SYS_USER}env/bin/python
    }
    function create_aliases () {
        su -c "touch /root/.bash_aliases"
        cat > /root/.bash_aliases << EOL
# YSK Custom Aliases
alias oe-restartwebservers='su -c "service uwsgi restart && sudo service nginx restart"'
alias oe-wwwfix='su -c "chown -R www-data:www-data /srv/openerp/${ERP_HOSTNAME}"'
alias oe-symlinkfix='su - ${ERP_SYS_USER} -c "cd /srv/openerp/${ERP_HOSTNAME}/server/openerp/addons/ && find . -maxdepth 1 -type l -exec rm -f {} \; ln -s /srv/openerp/${ERP_HOSTNAME}/web/addons/* /srv/openerp/${ERP_HOSTNAME}/server/openerp/addons/ && sudo ln -s /srv/openerp/${ERP_HOSTNAME}/addons/* /srv/openerp/${ERP_HOSTNAME}/server/openerp/addons/"'
alias oe-updatecore='bzr update /srv/openerp/${ERP_HOSTNAME}/web/ && bzr update /srv/openerp/${ERP_HOSTNAME}/server/ && bzr update /srv/openerp/${ERP_HOSTNAME}/addons && bzr update /srv/openerp/${ERP_HOSTNAME}/addons-extra/ && bzr update /srv/openerp/${ERP_HOSTNAME}/addons-community/'
EOL
su -c "source /root/.bashrc"
    }
    function display_final () {
        echo -e -n "\n \n ------------------------------------------------------------------------------- \n \n"
        echo -e -n " | uwsgi.ini file location: /etc/uwsgi/apps-enabled/${ERP_HOSTNAME}.ini \n"
        echo -e -n " | nginx.conf file location: /etc/nginx/sites-enabled/${ERP_HOSTNAME}.conf \n"
        echo -e -n " | tmp.conf file location: /srv/openerp/${ERP_HOSTNAME}/server/tmp.conf \n"
        echo -e -n " | wsgi.py file location: /srv/openerp/${ERP_HOSTNAME}/server/wsgi.py \n"
        echo -e -n " | Addons files location: /srv/openerp/${ERP_HOSTNAME}/server/openerp/addons/ \n"
        echo -e -n " |  \n"
        echo -e -n " |  \n"
        echo -e -n " | Database Details: \n"
        echo -e -n " | Database Server: localhost \n"
        echo -e -n " | Database Name: ${ERP_DB_NAME} \n"
        echo -e -n " | Database User: ${ERP_DB_USER} \n"
        echo -e -n " | Database Pass: ${ERP_DB_PASS} \n"
        echo -e -n " |  \n"
        echo -e -n " |  \n"
        echo -e -n " | ERP Access URL: http://${ERP_HOSTNAME} \n"
        echo -e -n " |  \n"
        echo -e -n " |  \n"
        echo -e -n " | Additonal Commands: \n"
        echo -e -n " | oe-updatecore - Updates OpenERP Web, Server, Addons modules using bazaar/bzr tool \n"
        echo -e -n " | oe-symlinkfix - Corrects Soft Links for OpenERP Addons directories \n"
        echo -e -n " | oe-wwwfix - Corrects Directory ownership of OpenERP instance to www-data system user \n"
        echo -e -n " | oe-restartwebservers - Restarts Uwsgi and Nginx Web Servers \n"
        echo -e -n "\n \n ------------------------------------------------------------------------------- \n \n"
    }
    add_pg_repo
    pull_updates
    install_libs_pgsql
    install_wkhtmltopdf
    www_config
    erp_user_setup
    erp_db_setup
    erp_trunk_bazaar_checkout
    erp_virtual_env_setup
    erp_py_develop
    erp_config_stuff
    www_chown_takeover
    erp_init_run
    create_aliases
    display_final
}

start_point

unset ERP_HOSTNAME
unset ERP_SYS_USER
unset ERP_DB_NAME
unset ERP_DB_USER
unset ERP_DB_PASS
unset OPENERP_SERVER_TYPE
## END SCRIPT
