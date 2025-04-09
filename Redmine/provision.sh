#!/usr/bin/env bash
dnf update -y

cat <<EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

dnf install -y postgresql-server postgresql-contrib postgresql-devel git httpd gcc gcc-c++ make elasticsearch 

dnf install -y zlib-devel curl-devel redhat-rpm-config ImageMagick ImageMagick-devel

dnf install -y java-11-openjdk java-11-openjdk-devel wget openssl-devel

dnf install -y ruby ruby-devel rubygems nodejs 
dnf install -y mod_passenger

npm install -g yarn

postgresql-setup --initdb
systemctl enable --now postgresql

sudo -i -u postgres psql <<EOF
CREATE DATABASE redmine ENCODING UTF8;
CREATE USER redmine WITH PASSWORD 'Secret1';
GRANT ALL PRIVILEGES ON DATABASE redmine TO redmine;
\q
EOF

#echo "host    redmine    redmine    127.0.0.1/32    md5" >> /var/lib/pgsql/data/pg_hba.conf
#echo "host    redmine    redmine    ::1/128         md5" >> /var/lib/pgsql/data/pg_hba.conf

mv /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bak

cat <<EOF >> /var/lib/pgsql/data/pg_hba.conf
# "local" is for Unix domain socket connections only
local   all             all                                    md5
# IPv4 local connections:
host    all             all             127.0.0.1/32           md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     md5
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
host    redmine    redmine    127.0.0.1/32    md5
host    redmine    redmine    ::1/128         md5
EOF

systemctl restart postgresql

wget https://www.redmine.org/releases/redmine-5.0.5.tar.gz
tar -xvzf redmine-5.0.5.tar.gz
mv redmine-5.0.5 /var/www/redmine

#cd /var/www/redmine/plugins
#git clone https://github.com/Restream/redmine_elasticsearch.git

chown -R apache:apache /var/www/redmine
chmod -R 755 /var/www/redmine

cd /var/www/redmine
cp config/database.yml.example config/database.yml

cat <<EOF > config/database.yml
# PostgreSQL configuration
production:
  adapter: postgresql
  database: redmine
  host: localhost
  username: redmine
  password: "Secret1"
EOF

gem install bundler
gem install pg
#gem install puma -v '5.6.5' # specify version to avoid compatibility issues
#gem install elasticsearch-model
#gem install elasticsearch-rails
#gem install resque 



sed -i -e '69,70d' -e '73,77d' /var/www/redmine/Gemfile
echo "gem 'concurrent-ruby', '1.3.4'" | sudo tee -a /var/www/redmine/Gemfile 


#bundle install --without development test
bundle config set without 'development test'
bundle install 
bundle exec rake generate_secret_token

RAILS_ENV=production bundle exec rake redmine:plugins:migrate
RAILS_ENV=production bundle exec rake db:migrate
#RAILS_ENV=production bundle exec rake assets:precompile

cat <<EOF > /etc/httpd/conf.d/redmine.conf
<VirtualHost *:80>
    ServerName redmine.local
    DocumentRoot /var/www/redmine/public

    <Directory /var/www/redmine/public>
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>

    ErrorLog /var/log/httpd/redmine_error.log
    CustomLog /var/log/httpd/redmine_access.log combined
</VirtualHost>
EOF

systemctl enable --now httpd

echo "127.0.0.1 redmine.local" | sudo tee -a /etc/hosts
