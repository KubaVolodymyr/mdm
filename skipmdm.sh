#!/bin/bash

# Глобальные константы
readonly DEFAULT_SYSTEM_VOLUME="Macintosh HD" # Название по умолчанию системного тома
readonly DEFAULT_DATA_VOLUME="Macintosh HD - Data" # Название по умолчанию тома данных

# Форматирование текста
RED='\033[1;31m'   # Красный цвет
GREEN='\033[1;32m' # Зеленый цвет
BLUE='\033[1;34m'  # Синий цвет
YELLOW='\033[1;33m' # Желтый цвет
PURPLE='\033[1;35m' # Фиолетовый цвет
CYAN='\033[1;36m'  # Голубой цвет
NC='\033[0m'       # Без цвета (стандартный)

# Проверяет, существует ли том с данным именем
checkVolumeExistence() {
	local volumeLabel="$*"
	diskutil info "$volumeLabel" >/dev/null 2>&1
}

# Возвращает имя тома с заданным типом
getVolumeName() {
	local volumeType="$1"

	# Получение идентификатора контейнера APFS
	apfsContainer=$(diskutil list internal physical | grep 'Container' | awk -F'Container ' '{print $2}' | awk '{print $1}')
	# Получение информации о томе
	volumeInfo=$(diskutil ap list "$apfsContainer" | grep -A 5 "($volumeType)")
	# Извлечение имени тома из информации о томе
	volumeNameLine=$(echo "$volumeInfo" | grep 'Name:')
	# Удаление лишних символов для получения чистого имени тома
	volumeName=$(echo "$volumeNameLine" | cut -d':' -f2 | cut -d'(' -f1 | xargs)

	echo "$volumeName"
}

# Определяет путь к тому с заданным именем по умолчанию и типом тома
defineVolumePath() {
	local defaultVolume=$1
	local volumeType=$2

	if checkVolumeExistence "$defaultVolume"; then
		echo "/Volumes/$defaultVolume"
	else
		local volumeName
		volumeName="$(getVolumeName "$volumeType")"
		echo "/Volumes/$volumeName"
	fi
}

# Монтирует том по заданному пути
mountVolume() {
	local volumePath=$1

	if [ ! -д "$volumePath" ]; then
		diskutil mount "$volumePath"
	fi
}

echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo -e "${YELLOW}*Проверка MDM - Skip MDM Auto for MacOS *${NC}"
echo -e "${CYAN}*-------------------*---------------------*${NC}"
echo ""

PS3='Пожалуйста, введите ваш выбор: '
options=("Автопропуск в Режиме Восстановления" "Проверить Регистрацию MDM" "Перезагрузить" "Выход")

select opt in "${options[@]}"; do
case $opt in
"Autoypass on Recovery")
	echo -e "\n\t${GREEN}Обход в режиме восстановления${NC}\n"

	# Монтирование томов
	echo -e "${BLUE}Монтирование томов...${NC}"
	# Монтирование системного тома
	systemVolumePath=$(defineVolumePath "$DEFAULT_SYSTEM_VOLUME" "System")
	mountVolume "$systemVolumePath"

	# Монтирование тома данных
	dataVolumePath=$(defineVolumePath "$DEFAULT_DATA_VOLUME" "Data")
	mountVolume "$dataVolumePath"

	echo -e "${GREEN}Подготовка томов завершена${NC}\n"

	# Создание пользователя
	echo -e "${BLUE}Проверка наличия пользователя${NC}"
	dscl_path="$dataVolumePath/private/var/db/dslocal/nodes/Default"
	localUserDirPath="/Local/Default/Users"
	defaultUID="501"
	if ! dscl -f "$dscl_path" localhost -list "$localUserDirPath" UniqueID | grep -q "\<$defaultUID\>"; then
		echo -e "${CYAN}Создать нового пользователя${NC}"
		echo -e "${CYAN}Нажмите Enter для продолжения, обратите внимание: если оставить пустым, будет выбран пользователь по умолчанию${NC}"
		echo -e "${CYAN}Введите полное имя (по умолчанию: Apple)${NC}"
		read -rp "Полное имя: " fullName
		fullName="${fullName:=Apple}"

		echo -e "${CYAN}Введите имя пользователя${NC} ${RED}ПИШИТЕ БЕЗ ПРОБЕЛОВ${NC} ${GREEN}(по умолчанию: Apple)${NC}"
		read -rp "Имя пользователя: " username
		username="${username:=Apple}"

		echo -e "${CYAN}Введите пароль пользователя (по умолчанию: 1234)${NC}"
		read -rsp "Пароль: " userPassword
		userPassword="${userPassword:=1234}"

		echo -e "\n${BLUE}Создание пользователя${NC}"
		dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username"
		dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UserShell "/bin/zsh"
		dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" RealName "$fullName"
		dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" UniqueID "$defaultUID"
		dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" PrimaryGroupID "20"
		mkdir "$dataVolumePath/Users/$username"
		dscl -f "$dscl_path" localhost -create "$localUserDirPath/$username" NFSHomeDirectory "/Users/$username"
		dscl -f "$dscl_path" localhost -passwd "$localUserDirPath/$username" "$userPassword"
		dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"
		echo -e "${GREEN}Пользователь создан${NC}\n"
	else
		echo -e "${BLUE}Пользователь уже создан${NC}\n"
	fi

	# Блокировка хостов MDM
	echo -e "${BLUE}Блокировка хостов MDM...${NC}"
	hostsPath="$systemVolumePath/etc/hosts"
	blockedDomains=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")
	for domain in "${blockedDomains[@]}"; do
		echo "0.0.0.0 $domain" >>"$hostsPath"
	done
	echo -e "${GREEN}Хосты успешно заблокированы${NC}\n"

	# Удаление конфигурационных профилей
	echo -e "${BLUE}Удаление конфигурационных профилей...${NC}"
	configProfilesSettingsPath="$systemVolumePath/var/db/ConfigurationProfiles/Settings"
	touch "$dataVolumePath/private/var/db/.AppleSetupDone"
	rm -rf "$configProfilesSettingsPath/.cloudConfigHasActivationRecord"
	rm -rf "$configProfilesSettingsPath/.cloudConfigRecordFound"
	touch "$configProfilesSettingsPath/.cloudConfigProfileInstalled"
	touch "$configProfilesSettingsPath/.cloudConfigRecordNotFound"
	echo -e "${GREEN}Конфигурационные профили удалены${NC}\n"
	
	echo -e "${GREEN}------ Автопропуск успешно выполнен / Автопропуск завершён ------${NC}"
	echo -e "${CYAN}------ Закройте терминал. Перезагрузите MacBook и наслаждайтесь! ------${NC}"
	break
	;;
	
	# Проверка регистрации MDM
	if [ ! -f /usr/bin/profiles ]; then
		echo -e "\n\t${RED}Не используйте эту опцию в режиме восстановления${NC}\n"
		continue
	fi
	
	if ! sudo profiles show -type enrollment >/dev/null 2>&1; then
		echo -e "\n\t${GREEN}Успех${NC}\n"
	else
		echo -e "\n\t${RED}Не удалось${NC}\n"
	fi
	;;
	
	# Перезагрузка
	echo -e "\n\t${BLUE}Перезагрузка...${NC}\n"
	reboot
	;;
	
	# Выход
	echo -e "\n\t${BLUE}Выход...${NC}\n"
	exit
	;;
	
	# Неверная опция
	*)
	echo "Неверная опция $REPLY"
	;;
	esac
done
