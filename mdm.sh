#!/bin/bash
RED='\033[0;31m'  # Красный цвет
GRN='\033[0;32m'  # Зелёный цвет
BLU='\033[0;34m'  # Синий цвет
NC='\033[0m'      # Сброс цвета
echo ""
echo -e "Auto Tools for MacOS"  # Auto Tools для MacOS
echo ""
PS3='Пожалуйста, введите ваш выбор: '  # Приглашение к выбору
options=("Bypass on Recovery" "Disable Notification (SIP)" "Disable Notification (Recovery)" "Check MDM Enrollment" "Exit")
select opt in "${options[@]}"; do
    case $opt in
    "Bypass on Recovery")
        echo -e "${GRN}Bypass on Recovery"  # Обход в режиме восстановления
        if [ -d "/Volumes/Macintosh HD - Data" ]; then
            diskutil rename "Macintosh HD - Data" "Data"
        fi
        echo -e "${GRN}Создание нового пользователя"  # Создание нового пользователя
        echo -e "${BLU}Нажмите Enter, чтобы перейти к следующему шагу, если не заполнять, будут использованы значения по умолчанию"
        echo -e "Введите имя пользователя (По умолчанию: MAC)"
        read realName
        realName="${realName:=MAC}"
        echo -e "${BLUE}Введите имя пользователя для входа в систему ${RED}БЕЗ ПРОБЕЛОВ И ЗНАКОВ ${GRN} (По умолчанию: MAC)"
        read username
        username="${username:=MAC}"
        echo -e "${BLUE}Введите пароль (по умолчанию: 1234)"
        read passw
        passw="${passw:=1234}"
        dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default' 
        echo -e "${GREEN}Создание пользователя"  # Создание пользователя
        # Создание пользователя
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
        mkdir "/Volumes/Data/Users/$username"
        dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
        dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
        dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership $username
        echo "0.0.0.0 deviceenrollment.apple.com" >> /Volumes/Macintosh\ HD/etc/hosts
        echo "0.0.0.0 mdmenrollment.apple.com" >> /Volumes/Macintosh\ HD/etc/hosts
        echo "0.0.0.0 iprofiles.apple.com" >> /Volumes/Macintosh\ HD/etc/hosts
        echo -e "${GREEN}Блокировка хостов выполнена успешно${NC}"  # Блокировка хостов выполнена успешно
        touch /Volumes/Data/private/var/db/.AppleSetupDone
        rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
        rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
        touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
        touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
        echo "----------------------"
        break
        ;;
   "Disable Notification (SIP)")
        echo -e "${RED}Пожалуйста, введите ваш пароль для продолжения${NC}"  # Пожалуйста, введите ваш пароль для продолжения
        sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
        sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
        sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
        sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
        break
        ;;
    "Disable Notification (Recovery)")
        rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
        rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
        touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
        touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
        break
        ;;
    "Check MDM Enrollment")
        echo ""
        echo -e "${GRN}Проверка регистрации в MDM. Ошибка - это успех${NC}"  # Проверка регистрации в MDM. Ошибка - это успех
        echo ""
        echo -e "${RED}Пожалуйста, введите ваш пароль для продолжения${NC}"  # Пожалуйста, введите ваш пароль для продолжения
        sudo profiles show -type enrollment
        break
        ;;
    "Exit")
        break
        ;;
    *) echo "Неверный выбор $REPLY" ;;  # Неверный выбор
    esac
done
