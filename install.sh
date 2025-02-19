#!/bin/bash

# Variables de configuración
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo.conf"
ODOO_PORT="8069"
DOMAIN_NAME="tudominio.com"  # Cambia esto por tu dominio o IP

# Actualizar sistema
echo "📦 Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias necesarias
echo "📌 Instalando dependencias..."
sudo apt install -y python3 python3-pip python3-venv \
                    python3-dev libxml2-dev libxslt1-dev \
                    libldap2-dev libsasl2-dev libtiff5-dev \
                    libjpeg8-dev libopenjp2-7-dev libpq-dev \
                    libffi-dev libssl-dev libwebp-dev \
                    libjpeg-dev zlib1g-dev libfreetype6-dev \
                    liblcms2-dev libharfbuzz-dev libfribidi-dev \
                    libxcb1-dev build-essential libpng-dev \
                    git curl wget nodejs npm redis nginx postgresql \
                    apache2 libapache2-mod-proxy-uwsgi \
                    libapache2-mod-proxy-http \
                    libapache2-mod-proxy-html

# Crear usuario Odoo
echo "👤 Creando usuario Odoo..."
sudo useradd -m -d $ODOO_HOME -U -r -s /bin/bash $ODOO_USER

# Instalar PostgreSQL y configurar base de datos
echo "🗄️ Configurando PostgreSQL..."
sudo -u postgres createuser -s $ODOO_USER

# Descargar Odoo 17 CE
echo "📥 Descargando Odoo 17 CE..."
sudo git clone --depth 1 --branch 17.0 https://github.com/odoo/odoo.git $ODOO_HOME

# Configurar entorno virtual de Python
echo "🐍 Creando entorno virtual..."
sudo -u $ODOO_USER python3 -m venv $ODOO_HOME/venv
source $ODOO_HOME/venv/bin/activate
pip install -r $ODOO_HOME/requirements.txt
deactivate

# Crear directorio de addons
echo "📂 Creando directorios de addons..."
sudo mkdir -p $ODOO_HOME/custom_addons
sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME/

# Configurar archivo de configuración de Odoo
echo "⚙️ Configurando Odoo..."
cat <<EOF | sudo tee $ODOO_CONFIG
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = $ODOO_HOME/addons,$ODOO_HOME/custom_addons
xmlrpc_port = $ODOO_PORT
EOF
sudo chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
sudo chmod 640 $ODOO_CONFIG

# Crear servicio systemd para Odoo
echo "🚀 Creando servicio systemd para Odoo..."
cat <<EOF | sudo tee /etc/systemd/system/odoo.service
[Unit]
Description=Odoo 17 Service
After=network.target postgresql.service

[Service]
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo-bin --config=$ODOO_CONFIG
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar servicio Odoo
sudo systemctl daemon-reload
sudo systemctl enable --now odoo

# Configurar Apache como Proxy Reverso
echo "🌍 Configurando Apache como proxy reverso..."
cat <<EOF | sudo tee /etc/apache2/sites-available/odoo.conf
<VirtualHost *:80>
    ServerName $DOMAIN_NAME

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:$ODOO_PORT/
    ProxyPassReverse / http://127.0.0.1:$ODOO_PORT/

    <Directory />
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/odoo_error.log
    CustomLog \${APACHE_LOG_DIR}/odoo_access.log combined
</VirtualHost>
EOF

# Activar módulos de Apache y reiniciar
sudo a2enmod proxy proxy_http proxy_balancer proxy_connect rewrite
sudo a2ensite odoo.conf
sudo systemctl restart apache2

echo "✅ Instalación completada. Accede a Odoo en: http://$DOMAIN_NAME"
