#!/bin/bash
function GetRandomPort() {
	if ! [ "$INSTALLED_LSOF" == true ]; then
		echo "Installing lsof package. Please wait."
		if [[ $distro =~ "CentOS" ]]; then
			yum -y -q install lsof
		elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
			apt-get -y install lsof >/dev/null
		fi
		local RETURN_CODE
		RETURN_CODE=$?
		if [ $RETURN_CODE -ne 0 ]; then
			echo "$(tput setaf 3)Warning!$(tput sgr 0) lsof package did not installed successfully. The randomized port may be in use."
		else
			INSTALLED_LSOF=true
		fi
	fi
	PORT=$((RANDOM % 16383 + 49152))
	if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
		GetRandomPort
	fi
}
function GenerateService() {
	local ARGS_STR
	ARGS_STR="-u nobody -H $PORT"
	for i in "${SECRET_ARY[@]}"; do # Add secrets
		ARGS_STR+=" -S $i"
	done
	if [ -n "$TAG" ]; then
		ARGS_STR+=" -P $TAG "
	fi
	if [ -n "$TLS_DOMAIN" ]; then
		ARGS_STR+=" -D $TLS_DOMAIN "
	fi
	if [ "$HAVE_NAT" == "y" ]; then
		ARGS_STR+=" --nat-info $PRIVATE_IP:$PUBLIC_IP "
	fi
	NEW_CORE=$((CPU_CORES - 1))
	ARGS_STR+=" -M $NEW_CORE $CUSTOM_ARGS --aes-pwd proxy-secret proxy-multi.conf"
	SERVICE_STR="[Unit]
Description=MTProxy
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/MTProxy/objs/bin
ExecStart=/opt/MTProxy/objs/bin/mtproto-proxy $ARGS_STR
Restart=on-failure
StartLimitBurst=0
[Install]
WantedBy=multi-user.target"
}
#User must run the script as root
if [[ "$EUID" -ne 0 ]]; then
	echo "Please run this script as root"
	exit 1
fi
regex='^[0-9]+$'
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
clear
if [ -d "/opt/MTProxy" ]; then
	echo "شما قبلا MTProxy را نصب کرده اید! میخوای چیکار کنی؟"
	echo "  1) پیوندهای اتصال را نشان دهید"
	echo "  2) تگ را تغییر دهید"
	echo "  3) یک سکرت کد اضافه کنید"
	echo "  4) یک سرکت کد را باطل کنید"
	echo "  5) تعداد CPU های درگیر را تغییر دهید"
	echo "  6) تنظیمات NAT را تغییر دهید"
	echo "  7) آرگومان های سفارشی را تغییر دهید"
	echo "  8) قوانین فایروال را ایجاد کنید"
	echo "  9) پراکسی را حذف کنید"
	echo "  10) درباره"
	echo "  *) خروج"
	read -r -p "لطفا یک عدد وارد کنید: " OPTION
	source /opt/MTProxy/objs/bin/mtconfig.conf #Load Configs
	case $OPTION in
	#Show connections
	1)
		clear
		echo "$(tput setaf 3)دریافت آدرس IP شما$(tput sgr 0)"
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		CURL_EXIT_STATUS=$?
		if [ $CURL_EXIT_STATUS -ne 0 ]; then
			PUBLIC_IP="ای پی شما"
		fi
		HEX_DOMAIN=$(printf "%s" "$TLS_DOMAIN" | xxd -pu)
		HEX_DOMAIN="$(echo $HEX_DOMAIN | tr '[A-Z]' '[a-z]')"
		for i in "${SECRET_ARY[@]}"; do
			if [ -z "$TLS_DOMAIN" ]; then
				echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
			else
				echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=ee$i$HEX_DOMAIN"
			fi
		done
		;;
	#Change TAG
	2)
		if [ -z "$TAG" ]; then
			echo "به نظر می رسد برچسب آگهی شما خالی است. برچسب AD را در https://t.me/mtproxybot دریافت کنید و آن را در اینجا وارد کنید:"
		else
			echo "برچسب فعلی $TAG است. اگر می خواهید آن را حذف کنید، کافی است اینتر را فشار دهید. در غیر این صورت تگ جدید را تایپ کنید:"
		fi
		read -r TAG
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^TAG=.*/TAG=\"$TAG\"/" mtconfig.conf
		echo "Done"
		;;
	#Add secret
	3)
		if [ "${#SECRET_ARY[@]}" -ge 16 ]; then
			echo "$(tput setaf 1)ارور$(tput sgr 0) شما نمی توانید بیش از 16 راز داشته باشید"
			exit 1
		fi
		echo "آیا می خواهید سکرت کد را به صورت دستی تنظیم کنید یا تصادفی ایجاد کنم؟"
		echo "   1) سکرت کد را به صورت دستی وارد کنید"
		echo "   2) سکرت کد را تصادفی ایجاد میکنم"
		read -r -p "لطفا یکی را انتخاب کنید [1-2]: " -e -i 2 OPTION
		case $OPTION in
		1)
			echo "یک رشته 32 کاراکتری پر شده با 0-9 و a-f (هگزادسیمال) وارد کنید: "
			read -r SECRET
			#Validate length
			SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
			if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
				echo "$(tput setaf 1)ارور:$(tput sgr 0) کاراکترهای هگزا دسیمال را وارد کنید و Secret باید 32 کاراکتر باشد."
				exit 1
			fi
			;;
		2)
			SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
			echo "خوب من یکی درست کردم: $SECRET"
			;;
		*)
			echo "$(tput setaf 1)گزینه نامعتبر$(tput sgr 0)"
			exit 1
			;;
		esac
		SECRET_ARY+=("$SECRET")
		#Add secret to config
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		SECRET_ARY_STR=${SECRET_ARY[*]}
		sed -i "s/^SECRET_ARY=.*/SECRET_ARY=($SECRET_ARY_STR)/" mtconfig.conf
		echo "Done"
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		CURL_EXIT_STATUS=$?
		if [ $CURL_EXIT_STATUS -ne 0 ]; then
			PUBLIC_IP="YOUR_IP"
		fi
		echo
		echo "اکنون می توانید با این سکرت کد به این لینک به سرور خود متصل شوید:"
		echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$SECRET"
		;;
	#Revoke Secret
	4)
		NUMBER_OF_SECRETS=${#SECRET_ARY[@]}
		if [ "$NUMBER_OF_SECRETS" -le 1 ]; then
			echo "نمی توان آخرین سکرت کد را حذف کرد."
			exit 1
		fi
		echo "یک سکرت کد را برای لغو انتخاب کنید:"
		COUNTER=1
		for i in "${SECRET_ARY[@]}"; do
			echo "  $COUNTER) $i"
			COUNTER=$((COUNTER + 1))
		done
		read -r -p "یک کاربر را با شاخص آن برای لغو انتخاب کنید: " USER_TO_REVOKE
		if ! [[ $USER_TO_REVOKE =~ $regex ]]; then
			echo "$(tput setaf 1)ارور:$(tput sgr 0) ورودی یک عدد معتبر نیست"
			exit 1
		fi
		if [ "$USER_TO_REVOKE" -lt 1 ] || [ "$USER_TO_REVOKE" -gt "$NUMBER_OF_SECRETS" ]; then
			echo "$(tput setaf 1)ارور:$(tput sgr 0) عدد نامعتبر"
			exit 1
		fi
		USER_TO_REVOKE1=$((USER_TO_REVOKE - 1))
		SECRET_ARY=("${SECRET_ARY[@]:0:$USER_TO_REVOKE1}" "${SECRET_ARY[@]:$USER_TO_REVOKE}")
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2 || exit 2
		SECRET_ARY_STR=${SECRET_ARY[*]}
		sed -i "s/^SECRET_ARY=.*/SECRET_ARY=($SECRET_ARY_STR)/" mtconfig.conf
		echo "Done"
		;;	
	#Change CPU workers
	5)
		CPU_CORES=$(nproc --all)
		echo "من متوجه شده ام که سرور شما دارای $CPU_CORES هسته است. اگر بخواهید می توانم پروکسی را برای اجرا در تمام هسته های شما پیکربندی کنم. این باعث می شود تا همزمان تعداد افراد مصتل به پروکسی 10000*$CPU_CORES شود. به دلایلی، پروکسی به احتمال زیاد در بیش از 16 هسته از کار می افتد. پس لطفا عددی بین 1 تا 16 انتخاب کنید."
		read -r -p "چند تا از سی پی یو های سرورتون رو میخوایید درگیر کنید؟ " -e -i "$CPU_CORES" CPU_CORES
		if ! [[ $CPU_CORES =~ $regex ]]; then #Check if input is number
			echo "$(tput setaf 1)ارو:$(tput sgr 0) ورودی یک عدد معتبر نیست"
			exit 1
		fi
		if [ "$CPU_CORES" -lt 1 ]; then #Check range of workers
			echo "$(tput setaf 1)ارو:$(tput sgr 0) عدد بیش از 1 را وارد کنید."
			exit 1
		fi
		if [ "$CPU_CORES" -gt 16 ]; then
			echo "(tput setaf 3)اخطار:$(tput sgr 0) مقادیر بیشتر از 16 می توانند بعداً مشکلاتی ایجاد کنند. با مسئولیت خود ادامه دهید."
		fi
		#Save
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^CPU_CORES=.*/CPU_CORES=$CPU_CORES/" mtconfig.conf
		echo "Done"
		;;
	#Change NAT types
	6)
		#Try to autodetect private ip: https://github.com/angristan/openvpn-install/blob/master/openvpn-install.sh#L230
		IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
		HAVE_NAT="n"
		if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			HAVE_NAT="y"
		fi
		read -r -p "آیا شما به NAT نیاز دارید؟ (اگر از AWS استفاده می کنید احتمالا به این نیاز دارید) (y/n) " -e -i "$HAVE_NAT" HAVE_NAT
		if [[ "$HAVE_NAT" == "y" || "$HAVE_NAT" == "Y" ]]; then
			PUBLIC_IP="$(curl https://api.ipify.org -sS)"
			read -r -p "لطفا IP عمومی خود را وارد کنید: " -e -i "$PUBLIC_IP" PUBLIC_IP
			if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
				echo "من متوجه شده ام که $IP آدرس IP خصوصی شماست. لطفا آن را تأیید کنید."
			else
				IP=""
			fi
			read -r -p "لطفا IP خصوصی خود را وارد کنید: " -e -i "$IP" PRIVATE_IP
		fi
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^HAVE_NAT=.*/HAVE_NAT=\"$HAVE_NAT\"/" mtconfig.conf
		sed -i "s/^PUBLIC_IP=.*/PUBLIC_IP=\"$PUBLIC_IP\"/" mtconfig.conf
		sed -i "s/^PRIVATE_IP=.*/PRIVATE_IP=\"$PRIVATE_IP\"/" mtconfig.conf
		echo "Done"
		;;
	#Change other args
	7)
		echo "اگر می خواهید از آرگومان های سفارشی برای اجرای پروکسی استفاده کنید، آنها را در اینجا وارد کنید. در غیر این صورت فقط enter را فشار دهید."
		read -r -e -i "$CUSTOM_ARGS" CUSTOM_ARGS
		#Save
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^CUSTOM_ARGS=.*/CUSTOM_ARGS=\"$CUSTOM_ARGS\"/" mtconfig.conf
		echo "Done"
		;;
	#Firewall rules
	8)
		if [[ $distro =~ "CentOS" ]]; then
			echo "firewall-cmd --zone=public --add-port=$PORT/tcp"
			echo "firewall-cmd --runtime-to-permanent"
		elif [[ $distro =~ "Ubuntu" ]]; then
			echo "ufw allow $PORT/tcp"
		elif [[ $distro =~ "Debian" ]]; then
			echo "iptables -A INPUT -p tcp --dport $PORT --jump ACCEPT"
			echo "iptables-save > /etc/iptables/rules.v4"
		fi
		read -r -p "آیا می‌خواهید این قوانین را اعمال کنید؟[y/n] " -e -i "y" OPTION
		if [ "$OPTION" == "y" ] || [ "$OPTION" == "Y" ]; then
			if [[ $distro =~ "CentOS" ]]; then
				firewall-cmd --zone=public --add-port="$PORT"/tcp
				firewall-cmd --runtime-to-permanent
			elif [[ $distro =~ "Ubuntu" ]]; then
				ufw allow "$PORT"/tcp
			elif [[ $distro =~ "Debian" ]]; then
				iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
				iptables-save >/etc/iptables/rules.v4
			fi
		fi
		;;
	#Uninstall proxy
	9)
		read -r -p "من هنوز برخی از بسته‌ها مانند \"Development Tools\" را نگه می‌دارم. آیا می خواهید MTProto-Proxy را حذف نصب کنید؟(y/n) " OPTION
		case $OPTION in
		"y" | "Y")
			cd /opt/MTProxy || exit 2
			systemctl stop MTProxy
			systemctl disable MTProxy
			if [[ $distro =~ "CentOS" ]]; then
				firewall-cmd --remove-port="$PORT"/tcp
				firewall-cmd --runtime-to-permanent
			elif [[ $distro =~ "Ubuntu" ]]; then
				ufw delete allow "$PORT"/tcp
			elif [[ $distro =~ "Debian" ]]; then
				iptables -D INPUT -p tcp --dport "$PORT" --jump ACCEPT
				iptables-save >/etc/iptables/rules.v4
			fi
			rm -rf /opt/MTProxy /etc/systemd/system/MTProxy.service
			systemctl daemon-reload
			sed -i '\|cd /opt/MTProxy/objs/bin && bash updater.sh|d' /etc/crontab
			if [[ $distro =~ "CentOS" ]]; then
				systemctl restart crond
			elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
				systemctl restart cron
			fi
			echo "باشه تموم شد"
			;;
		esac
		;;
	# About
	10)
		echo "اسکریپت MTProtoInstaller توسط SalaRNd"
		echo "منبع در https://github.com/TelegramMessenger/MTProxy"
		echo "مخزن اسکریپت Github: https://github.com/SalaRNd/MTPoto-Proxy-Easy-Installer"
		;;
	esac
	exit
fi
SECRET_ARY=()
if [ "$#" -ge 2 ]; then
	AUTO=true
	# Parse arguments like: https://stackoverflow.com/4213397
	while [[ "$#" -gt 0 ]]; do
		case $1 in
			-s|--secret) SECRET_ARY+=("$2"); shift ;;
		 	-p|--port) PORT=$2; shift ;;
			-t|--tag) TAG=$2; shift ;;
			--workers) CPU_CORES=$2; shift ;;
			--disable-updater) ENABLE_UPDATER="n" ;;
			--tls) TLS_DOMAIN="$2"; shift ;;
			--custom-args) CUSTOM_ARGS="$2"; shift;;
			--no-nat) HAVE_NAT="n" ;;
			--no-bbr) ENABLE_BBR="n" ;;
		esac
		shift
	done
	#Check secret
	if [[ ${#SECRET_ARY[@]} -eq 0 ]];then
		echo "$(tput setaf 1)ارور:$(tput sgr 0) لطفا حداقل یک سکرت کد را وارد کنید"
		exit 1
	fi
	for i in "${SECRET_ARY[@]}"; do
		if ! [[ $i =~ ^[0-9a-f]{32}$ ]]; then
			echo "$(tput setaf 1)ارور:$(tput sgr 0) کاراکترهای هگزا دسیمال را وارد کنید و Secret باید 32 کاراکتر باشد. خطا در راز $i"
			exit 1
		fi
	done
	#Check port
	if [ -z ${PORT+x} ]; then #Check random port
		GetRandomPort
		echo "من $PORT را به عنوان پورت شما انتخاب کرده ام."
	fi
	if ! [[ $PORT =~ $regex ]]; then #Check if the port is valid
		echo "$(tput setaf 1)ارور:$(tput sgr 0) ورودی یک عدد معتبر نیست"
		exit 1
	fi
	if [ "$PORT" -gt 65535 ]; then
		echo "$(tput setaf 1)ارور:$(tput sgr 0): تعداد باید کمتر از 65536 باشد"
		exit 1
	fi
	#Check NAT
	if [[ "$HAVE_NAT" != "n" ]]; then
		PRIVATE_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		HAVE_NAT="n"
		if echo "$PRIVATE_IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			HAVE_NAT="y"
		fi
	fi
	#Check other stuff
	if [ -z ${CPU_CORES+x} ]; then CPU_CORES=$(nproc --all); fi
	if [ -z ${ENABLE_UPDATER+x} ]; then ENABLE_UPDATER="y"; fi
	if [ -z ${TLS_DOMAIN+x} ]; then TLS_DOMAIN="www.cloudflare.com"; fi
	if [ -z ${ENABLE_BBR+x} ]; then ENABLE_UPDATER="y"; fi
else
	#Variables
	SECRET=""
	TAG=""
	echo "به نصب کننده آسان MTProto-Proxy خوش آمدید!"
	echo "ایجاد شده توسط SalaRNd"
	echo "من mtprotoproxy، مخزن رسمی را نصب خواهم کرد"
	echo "منبع در https://github.com/TelegramMessenger/MTProxy و https://github.com/krepver/MTProxy"
	echo "مخزن اسکریپت Github: https://github.com/SalaRNd/MTPoto-Proxy-Easy-Installer"
	echo "حالا اطلاعاتی از شما جمع آوری میکنم..."
	echo ""
	echo ""
	#Proxy Port
	read -r -p "یک پورت را برای پروکسی انتخاب کنید (عدد یک برای تصادفی کردن): " -e -i "443" PORT
	if [[ $PORT -eq -1 ]]; then #Check random port
		GetRandomPort
		echo "من $PORT را به عنوان پورت شما انتخاب کرده ام."
	fi
	if ! [[ $PORT =~ $regex ]]; then #Check if the port is valid
		echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
		exit 1
	fi
	if [ "$PORT" -gt 65535 ]; then
		echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
		exit 1
	fi
	while true; do
		echo "آیا می خواهید سکرت کد را به صورت دستی تنظیم کنید یا تصادفی ایجاد کنم؟"
		echo "   1) سکرت کد را به صورت دستی وارد کنید"
		echo "   2) سکرت کد را تصادفی ایجاد میکنم"
		read -r -p "لطفا یکی را انتخاب کنید [1-2]: " -e -i 2 OPTION
		case $OPTION in
		1)
			echo "یک رشته 32 کاراکتری پر شده با 0-9 و a-f (هگزادسیمال) وارد کنید: "
			read -r SECRET
			#Validate length
			SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
			if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
				echo "$(tput setaf 1)ارور:$(tput sgr 0) کاراکترهای هگزا دسیمال را وارد کنید و Secret باید 32 کاراکتر باشد."
				exit 1
			fi
			;;
		2)
			SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
			echo "باشه من یکی درست کردم: $SECRET"
			;;
		*)
			echo "$(tput setaf 1)گزینه نامعتبر$(tput sgr 0)"
			exit 1
			;;
		esac
		SECRET_ARY+=("$SECRET")
		read -r -p "آیا می خواهید سکرت کد دیگری اضافه کنید؟ (y/n) " -e -i "n" OPTION
		case $OPTION in
		'y' | "Y")
			if [ "${#SECRET_ARY[@]}" -ge 16 ]; then
				echo "$(tput setaf 1)Error$(tput sgr 0) شما نمی توانید بیش از 16 سکرت کد داشته باشید"
				break
			fi
			;;

		'n' | "N")
			break
			;;
		*)
			echo "$(tput setaf 1)گزینه نامعتبر$(tput sgr 0)"
			exit 1
			;;
		esac
	done
	#Now setup the tag
	read -r -p "آیا می خواهید پروکسی خود را اسپانسری کنید؟ (y/n) " -e -i "n" OPTION
	if [[ "$OPTION" == "y" || "$OPTION" == "Y" ]]; then
		echo "$(tput setaf 1)توجه داشته باشید:$(tput sgr 0) کاربران و مدیران عضو کانال، کانال اسپانسری را در بالای صفحه نمی بینند."
		echo "در تلگرام به @MTProxybot Bot رفته و IP و $PORT این سرور را به عنوان پورت وارد کنید. سپس به عنوان سکرت کد $SECRET را وارد کنید"
		echo "ربات رشته ای به نام TAG به شما می دهد. در اینجا واردش کن:"
		read -r TAG
	fi
	#Get CPU Cores
	CPU_CORES=$(nproc --all)
	echo "من متوجه شده ام که سرور شما دارای $CPU_CORES هسته است. اگر بخواهید می توانم پروکسی را برای اجرا در تمام هسته های شما پیکربندی کنم. این باعث می شود تا همزمان تعداد افراد مصتل به پروکسی 10000*$CPU_CORES شود. به دلایلی، پروکسی به احتمال زیاد در بیش از 16 هسته از کار می افتد. پس لطفا عددی بین 1 تا 16 انتخاب کنید."
	read -r -p "چند تا از سی پی یو های سرورتون رو میخوایید درگیر کنید؟ " -e -i "$CPU_CORES" CPU_CORES
	if ! [[ $CPU_CORES =~ $regex ]]; then #Check if input is number
		echo "$(tput setaf 1)ارور:$(tput sgr 0) ورودی یک عدد معتبر نیست"
		exit 1
	fi
	if [ "$CPU_CORES" -lt 1 ]; then #Check range of workers
		echo "$(tput setaf 1)ارور:$(tput sgr 0) عدد بیش از 1 را وارد کنید."
		exit 1
	fi
	if [ "$CPU_CORES" -gt 16 ]; then
		echo "$(tput setaf 3)اخطار:$(tput sgr 0) مقادیر بیشتر از 16 می توانند بعداً مشکلاتی ایجاد کنند. با مسئولیت خود ادامه دهید."
	fi
	#Secret and config updater
	read -r -p "آیا می خواهید به روز رسانی پیکربندی خودکار را فعال کنید؟ من \"proxy-secret\" و \"proxy-multi.conf\" را هر روز در نیمه شب (12:00 صبح) به روز می کنم. توصیه می کنم این را فعال کنید.[y/n] " -e -i "y" ENABLE_UPDATER
	#Change host mask
	read -r -p "آدرس را انتخاب کنید که فکر می کند در حال بازدید از آن هستید. برای غیرفعال کردن Fake-TLS یک رشته خالی ارسال کنید. فعال کردن این گزینه به طور خودکار اسرار 'dd' را غیرفعال می کند (توصیه میشود یک URL دلخواه وارد کنید): " -e -i "s10.salarnd.com" TLS_DOMAIN
	#Use nat status for proxies behind NAT
	#Try to autodetect private ip: https://github.com/angristan/openvpn-install/blob/master/openvpn-install.sh#L230
	IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	HAVE_NAT="n"
	if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		HAVE_NAT="y"
	fi
	read -r -p "آیا شما به NAT نیاز دارید؟ (اگر از AWS استفاده می کنید احتمالا به این نیاز دارید) (y/n) " -e -i "$HAVE_NAT" HAVE_NAT
	if [[ "$HAVE_NAT" == "y" || "$HAVE_NAT" == "Y" ]]; then
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		read -r -p "لطفا IP عمومی خود را وارد کنید: " -e -i "$PUBLIC_IP" PUBLIC_IP
		if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			echo "من متوجه شده ام که $IP آدرس IP خصوصی شماست. لطفا آن را تأیید کنید."
		else
			IP=""
		fi
		read -r -p "لطفا IP خصوصی خود را وارد کنید: " -e -i "$IP" PRIVATE_IP
	fi
	#Other arguments
	echo "اگر می خواهید از آرگومان های سفارشی برای اجرای پروکسی استفاده کنید، آنها را در اینجا وارد کنید. در غیر این صورت فقط enter را فشار دهید."
	read -r CUSTOM_ARGS
	#Install
	read -n 1 -s -r -p "برای نصب هر کلیدی را فشار دهید..."
	clear
fi
#Now install packages
if [[ $distro =~ "CentOS" ]]; then
	yum -y install epel-release
	yum -y install openssl-devel zlib-devel curl ca-certificates sed cronie vim-common
	yum -y groupinstall "Development Tools"
elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
	apt-get update
	apt-get -y install git curl build-essential libssl-dev zlib1g-dev sed cron ca-certificates vim-common
fi
timedatectl set-ntp on #Make the time accurate by enabling ntp
#Clone and build
cd /opt || exit 2
git clone -b gcc10 https://github.com/krepver/MTProxy.git
cd MTProxy || exit 2
make            #Build the proxy
BUILD_STATUS=$? #Check if build was successful
if [ $BUILD_STATUS -ne 0 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) Build failed with exit code $BUILD_STATUS"
	echo "Deleting the project files..."
	rm -rf /opt/MTProxy
	echo "Done"
	exit 3
fi
cd objs/bin || exit 2
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
STATUS_SECRET=$?
if [ $STATUS_SECRET -ne 0 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) Cannot download proxy-secret from Telegram servers."
fi
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
STATUS_SECRET=$?
if [ $STATUS_SECRET -ne 0 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) Cannot download proxy-multi.conf from Telegram servers."
fi
#Setup mtconfig.conf
echo "PORT=$PORT" >mtconfig.conf
echo "CPU_CORES=$CPU_CORES" >>mtconfig.conf
echo "SECRET_ARY=(${SECRET_ARY[*]})" >>mtconfig.conf
echo "TAG=\"$TAG\"" >>mtconfig.conf
echo "CUSTOM_ARGS=\"$CUSTOM_ARGS\"" >>mtconfig.conf
echo "TLS_DOMAIN=\"$TLS_DOMAIN\"" >>mtconfig.conf
echo "HAVE_NAT=\"$HAVE_NAT\"" >>mtconfig.conf
echo "PUBLIC_IP=\"$PUBLIC_IP\"" >>mtconfig.conf
echo "PRIVATE_IP=\"$PRIVATE_IP\"" >>mtconfig.conf
#Setup firewall
echo "Setting firewalld rules"
if [[ $distro =~ "CentOS" ]]; then
	SETFIREWALL=true
	if ! yum -q list installed firewalld &>/dev/null; then
		echo ""
		if [ "$AUTO" = true ]; then
			OPTION="y"
		else
			read -r -p "به نظر می رسد \"firewalld\" نصب نشده است آیا می خواهید آن را نصب کنید؟ (y/n) " -e -i "y" OPTION
		fi
		case $OPTION in
		"y" | "Y")
			yum -y install firewalld
			systemctl enable firewalld
			;;
		*)
			SETFIREWALL=false
			;;
		esac
	fi
	if [ "$SETFIREWALL" = true ]; then
		systemctl start firewalld
		firewall-cmd --zone=public --add-port="$PORT"/tcp
		firewall-cmd --runtime-to-permanent
	fi
elif [[ $distro =~ "Ubuntu" ]]; then
	if dpkg --get-selections | grep -q "^ufw[[:space:]]*install$" >/dev/null; then
		ufw allow "$PORT"/tcp
	else
		if [ "$AUTO" = true ]; then
			OPTION="y"
		else
			echo
			read -r -p "به نظر می رسد \"UFW\" (فایروال) نصب نشده است آیا می خواهید آن را نصب کنید؟ (y/n) " -e -i "y" OPTION
		fi
		case $OPTION in
		"y" | "Y")
			apt-get install ufw
			ufw enable
			ufw allow ssh
			ufw allow "$PORT"/tcp
			;;
		esac
	fi
	#Use BBR on user will
	if ! [ "$(sysctl -n net.ipv4.tcp_congestion_control)" = "bbr" ] && { [[ $(lsb_release -r -s) =~ "20" ]] || [[ $(lsb_release -r -s) =~ "19" ]] || [[ $(lsb_release -r -s) =~ "18" ]]; }; then
		if [ "$AUTO" != true ]; then
			echo
			read -r -p "آیا می خواهید از BBR استفاده کنید؟ BBR ممکن است به پراکسی شما کمک کند سریعتر اجرا شود. (y/n) " -e -i "y" ENABLE_BBR
		fi
		case $ENABLE_BBR in
		"y" | "Y")
			echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf
			echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf
			sysctl -p
			;;
		esac
	fi
elif [[ $distro =~ "Debian" ]]; then
	apt-get install -y iptables iptables-persistent
	iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
	iptables-save >/etc/iptables/rules.v4
fi
#Setup service files
cd /etc/systemd/system || exit 2
GenerateService
echo "$SERVICE_STR" >MTProxy.service
systemctl daemon-reload
systemctl start MTProxy
systemctl is-active --quiet MTProxy #Check if service is active
SERVICE_STATUS=$?
if [ $SERVICE_STATUS -ne 0 ]; then
	echo "$(tput setaf 3)Warning: $(tput sgr 0)Building looks successful but the sevice is not running."
	echo "Check status with \"systemctl status MTProxy\""
fi
systemctl enable MTProxy
#Setup cornjob
if [ "$ENABLE_UPDATER" = "y" ] || [ "$ENABLE_UPDATER" = "Y" ]; then
	echo '#!/bin/bash
systemctl stop MTProxy
cd /opt/MTProxy/objs/bin
curl -s https://core.telegram.org/getProxySecret -o proxy-secret1
STATUS_SECRET=$?
if [ $STATUS_SECRET -eq 0 ]; then
  cp proxy-secret1 proxy-secret
fi
rm proxy-secret1
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf1
STATUS_CONF=$?
if [ $STATUS_CONF -eq 0 ]; then
  cp proxy-multi.conf1 proxy-multi.conf
fi
rm proxy-multi.conf1
systemctl start MTProxy
echo "Updater runned at $(date). Exit codes of getProxySecret and getProxyConfig are $STATUS_SECRET and $STATUS_CONF" >> updater.log' >/opt/MTProxy/objs/bin/updater.sh
	echo "" >>/etc/crontab
	echo "0 0 * * * root cd /opt/MTProxy/objs/bin && bash updater.sh" >>/etc/crontab
	if [[ $distro =~ "CentOS" ]]; then
		systemctl restart crond
	elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
		systemctl restart cron
	fi
fi
#Show proxy links
tput setaf 3
printf "%$(tput cols)s" | tr ' ' '#'
tput sgr 0
echo "These are the links for proxy:"
PUBLIC_IP="$(curl https://api.ipify.org -sS)"
CURL_EXIT_STATUS=$?
[ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
HEX_DOMAIN=$(printf "%s" "$TLS_DOMAIN" | xxd -pu)
HEX_DOMAIN="$(echo $HEX_DOMAIN | tr '[A-Z]' '[a-z]')"
for i in "${SECRET_ARY[@]}"; do
	if [ -z "$TLS_DOMAIN" ]; then
		echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
	else
		echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=ee$i$HEX_DOMAIN"
	fi
done
