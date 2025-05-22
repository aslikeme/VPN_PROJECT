# VPN_PROJECT
Данный проект позволяет организовать простую впн-инфраструктуру с центром сертификации, мониторингом и резервным копированием и может быть масштабирован до нужной конфигурации.

## Состав ВМ:
- CA:\
         Руководство администратора    	                       # инструкция \
    • artefacts:  				               # скрипты и пакеты \
	-caDeploy.sh \
	-caIPtablesRules.sh \
	-config-file-for-easyrsa.deb \
- VPN: \
	Руководство администратора	          		# инструкция \
    • artefacts:				                # скрипты и пакеты \
	-vpnDeploy.sh \
	-vpnIPtablesRules.sh \
	-openvpn-server-config.deb \ 
	-openvpn-exporter_0.1-1.deb \
- Monitoring: \
	Руководство администратора	         # инструкция \
	Система мониторинга \
    • artefacts:				               # скрипты и пакеты \
	-monitoringDeploy.sh \
	-monIPtablesRules.sh \
	-alertmanager-rules_0.1-1.deb \

\
- Backup-1: \
	Руководство администратора	        # инструкция \
	Система резервного копирования	    # описание системы рез.копирования \
    • artefacts:				              # скрипты и пакеты \
	-bkp1-Deploy.sh \
	-bkpIPtablesRules.sh \
	-rsync_to_cron_ca.sh  \
-rsync_to_cron_mon.sh \
-rsync_to_cron_vpn.sh \
\
- Backup-2:\
 Руководство администратора	          # инструкция \
    • artefacts:				              # скрипты и пакеты \
	-bkp1-Deploy.sh \
	-bkpIPtablesRules.sh \
	-rsync_to_cron_ca.sh \
-rsync_to_cron_mon.sh \
-rsync_to_cron_vpn.sh \
\
user files: \
	Руководство пользователя VPN	      # инструкция \
    • artefacts:				              # скрипты и пакеты \
	-userDeploy.sh \
	-makeConfig.sh \
	-openvpn-client-config.deb \
-config-file-for-easyrsa.deb \
\
Развитие инфраструктуры			          # описание развития инфраструктуры \

