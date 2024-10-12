# Usa una imagen base de Ubuntu
FROM ubuntu:24.04

# Establece las variables de entorno necesarias
#Desactivar preguntas interactivas
ENV DEBIAN_FRONTEND=noninteractive

#Asignacion de Variables - hora
ENV TZ=America/Santiago
#Asignacion de Variables - Version
ENV VERSION_NAGIOS          4.5.6
ENV VERSION_NAGIOS_PLUGINS  2.3.3
ENV VERSION_ADAGIOS         1.6.3
ENV VERSION_GRAPHIOS        2.0.3
ENV VERSION_GRAPHITE        1.1.3
ENV VERSION_GRAFANA         11.2.2
ENV VERSION_NCPA            2.1.3
ENV VERSION_NRDP            1.5.2
ENV VERSION_NRPE            3.2.1
ENV VERSION_PNP_NAGIOS      0.6.26
#Asignacion de Variables - Cuentas
ENV NAGIOS_USER             nagios
ENV NAGIOS_PASS             nagios
ENV NAGIOS_GROUP            nagios
ENV NRDP_TOKEN              non775maguni0acc
ENV NCPA_TOKEN              fgr24bp10es06sdendd
ENV MYSQL_USER              nagios
ENV MYSQL_PASSWORD          nagios
ENV MYSQL_ADDRESS           nagios_mysql
ENV MYSQL_DATABASE          nagios
#RED
ENV IP_LAN                  192.168.1.0
ENV IP_LOCH                 127.0.0.1
ENV IP_SUB                  24
# plantillas
ENV TEMPLC                  templates/_correo
ENV TEMPLN                  templates/_nagios
ENV TEMPLR                  templates/_nrpe
ENV TEMPLG                  templates/_grafana
# Establecer el timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#######################################################################################
# Actualizar lista de paquetes e instalar dependencias
RUN apt-get update && \
        apt-get install -y \
        # para Comunes
        wget \
        libssl-dev \
        build-essential \
        apache2 \
        php \
        # para Nagios
        perl \
        libgd-dev \
        libpng-dev \
        libjpeg-dev \
        unzip \
        vim \
        snmp \
        libnet-snmp-perl \
        # para NRPE
        openssl \
        xinetd \
        libpq-dev \
        # para PNP4Nagios
        php-gd \
        rrdtool \
        librrds-perl \
        libtime-hires-perl \
        make \
        gcc \
        libapache2-mod-php \
         # para Grafana  
        software-properties-common \
        apt-transport-https \
        libfontconfig1 \
        musl \
        # para Correo
        postfix \
        mailutils \
        libsasl2-modules \
        sasl2-bin \
        #
        curl \
        php-cli \
        unzip \
        git \
        supervisor \
        # 
        && \
        apt-get clean &&  rm -rf /var/lib/apt/lists/*

####################################################################################### Nagios
# Crear el grupo y el usuario para Nagios
RUN groupadd -g 1001 ${NAGIOS_GROUP} && \
    useradd -u 1001 -m -g ${NAGIOS_GROUP} ${NAGIOS_USER} && \
    usermod -aG ${NAGIOS_GROUP} www-data

RUN cd /tmp
# Instalar Nagios Core
RUN wget --no-check-certificate https://assets.nagios.com/downloads/nagioscore/releases/nagios-${VERSION_NAGIOS}.tar.gz && \
    tar xzf nagios-${VERSION_NAGIOS}.tar.gz -C /tmp && \
    cd /tmp/nagios-${VERSION_NAGIOS} && \
    ./configure --with-command-group=${NAGIOS_GROUP} && \
    make all && \
    make install && \
    make install-init && \
    make install-commandmode && \
    make install-config && \
    make install-webconf

# Instalar plugins de Nagios
RUN wget https://nagios-plugins.org/download/nagios-plugins-${VERSION_NAGIOS_PLUGINS}.tar.gz && \
    tar xzf nagios-plugins-${VERSION_NAGIOS_PLUGINS}.tar.gz -C /tmp && \
    cd /tmp/nagios-plugins-${VERSION_NAGIOS_PLUGINS} && \
    ./configure --with-nagios-user=${NAGIOS_USER} --with-nagios-group=${NAGIOS_GROUP} && \
    make && \
    make install

 # Eliminar archivo de instalación para seguridad
RUN rm -rf /tmp/nagios-${VERSION_NAGIOS}* /tmp/nagios-plugins-${VERSION_NAGIOS_PLUGINS}* 

# Configurar usuario de Nagios para la interfaz web
RUN htpasswd -b -c /usr/local/nagios/etc/htpasswd.users ${NAGIOS_USER} ${NAGIOS_PASS}
# Configurar Nagios
RUN a2enmod rewrite && \
    a2enmod cgi && \
    service apache2 restart

####################################################################################### PNP4Nagios

# Descargar y descomprimir PNP4Nagios
RUN wget --no-check-certificate https://downloads.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-${VERSION_PNP_NAGIOS}.tar.gz && \
    tar xzf pnp4nagios-${VERSION_PNP_NAGIOS}.tar.gz -C /tmp && \
    cd /tmp/pnp4nagios-${VERSION_PNP_NAGIOS} && \
    ./configure && \
    make all && \
    make fullinstall

# Eliminar archivo de instalación para seguridad
RUN rm -f /usr/local/pnp4nagios/share/install.php

# Copiar plantillas de configuración para nagios.cfg, commands.cfg, templates.cfg y localhost.cfg
COPY ${TEMPLN}.nagios.j2 /usr/local/nagios/etc/nagios.cfg
COPY ${TEMPLN}.commands.j2 /usr/local/nagios/etc/objects/commands.cfg
COPY ${TEMPLN}.templates.j2 /usr/local/nagios/etc/objects/templates.cfg
COPY ${TEMPLN}.localhost.j2 /usr/local/nagios/etc/objects/localhost.cfg

# Configurar la vista previa de los gráficos en Nagios
COPY ${TEMPLN}.status-header.j2 /usr/local/nagios/share/ssi/status-header.ssi

# Procesar la plantilla (suponiendo que tienes jinja2-cli instalado)
# RUN jinja2 /usr/local/nagios/etc/templates/PNP4NAGIOS.nagios.j2 > /usr/local/nagios/etc/nagios.cfg

####################################################################################### GRAFANA
# Descargar e instalar Grafana manualmente
RUN wget https://dl.grafana.com/oss/release/grafana_${VERSION_GRAFANA}_amd64.deb -P /tmp && \
    dpkg -i /tmp/grafana_${VERSION_GRAFANA}_amd64.deb && \
    rm /tmp/grafana_${VERSION_GRAFANA}_amd64.deb

# Instalar plugin PNP4Nagios para Grafana
RUN grafana-cli plugins install sni-pnp-datasource

# Descargar API de PNP4Nagios para Grafana
RUN wget https://github.com/lingej/pnp-metrics-api/raw/master/application/controller/api.php -P /usr/local/pnp4nagios/share/application/controllers/

# Eliminar archivo de instalación para seguridad
RUN rm -rf /tmp/grafana_${VERSION_GRAFANA}_amd64.deb

# Copiar la configuración de PNP4Nagios para Grafana
COPY ${TEMPLG}.pnp4nagios.j2 /etc/apache2/conf-available/pnp4nagios.conf
# Habilitar la configuración de PNP4Nagios y recargar Apache
RUN a2enconf pnp4nagios && \
    apache2ctl -k restart

####################################################################################### CORREO

# Copiar los archivos de configuración para Postfix
COPY ${TEMPLC}.postfix1.j2 /etc/postfix/sasl_passwd
COPY ${TEMPLC}.postfix2.j2 /etc/postfix/main.cf

# Establecer permisos en los archivos de configuración
RUN chmod 600 /etc/postfix/sasl_passwd && \
    chmod 644 /etc/postfix/main.cf

# Procesar archivo sasl_passwd (descomentar si previamente se configura)
# Crear el archivo de base de datos necesario para Postfix
RUN postmap /etc/postfix/sasl_passwd

####################################################################################### NRPE
# Descargar y descomprimir NRPE ${VERSION_NRPE}.
RUN wget https://github.com/NagiosEnterprises/nrpe/archive/nrpe-${VERSION_NRPE}.tar.gz && \
    tar xzf nrpe-${VERSION_NRPE}.tar.gz  -C /tmp &&\
    cd /tmp/nrpe-${VERSION_NRPE} && \
    ./configure --enable-command-args && \
    make all && \
    make install-groups-users && \
    make install && \
    make install-config && \
    make install-init

# Eliminar archivo de instalación para seguridad
RUN rm -rf /tmp/nrpe-${VERSION_NRPE}*

# Añadir puerto NRPE al archivo de servicios
RUN echo "nrpe    5666/tcp" >> /etc/services

# Configurar acceso para la red LAN
RUN sed -i 's/^allowed_hosts=${IP_LOCH},::1/allowed_hosts=${IP_LOCH},${IP_LAN}\/${IP_SUB}/' /usr/local/nagios/etc/nrpe.cfg

# Permitir ejecución de comandos con argumentos
RUN sed -i 's/^dont_blame_nrpe=0/dont_blame_nrpe=1/' /usr/local/nagios/etc/nrpe.cfg

######################################################################################
# Exponer el puerto 80 interfaz web, 25 para Postfix (SMTP), 5666 para NRPE y 12489 para NSClient
EXPOSE 80 25 3000 5666 12489

# Iniciar Apache, Nagios, Postfix y mantener el contenedor en ejecución
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]