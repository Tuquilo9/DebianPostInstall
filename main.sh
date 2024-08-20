#!/bin/bash

#Greetings

echo "Thank you for using this script, it will help you to get Debian up and running very fast."
echo "This script expects that no tweaks have been made. It just needs sudo installed"
echo "This script only supports GNOME!"

#Updates

echo "Installing updates (during all the process you'll have to press Y to be sure that only wanted operations occur!)"
set -e
sudo apt update && sudo apt upgrade
set +e

#Gnome install

echo "
Installing GNOME ..."
set -e
sudo apt install gnome-core desktop-base libproxy1-plugin-networkmanager network-manager-gnome file-roller gnome-color-manager shotwell gnome-photos rygel-playbin rygel-tracker simple-scan avahi-daemon gnome-sound-recorder gnome-tweaks libgsf-bin rhythmbox seahorse xdg-user-dirs-gtk cups-pk-helper evolution-plugins gstreamer1.0-libav gstreamer1.0-plugins-ugly rhythmbox-plugins rhythmbox-plugin-cdrecorder
set +e
sudo systemctl disable --now ModemManager
sudo apt autoremove evolution-data-server yelp firefox* libreoffice*

#Flatpak install

echo "
Installing flatpak and add flathub remote ..."
set -e
sudo apt install flatpak gnome-software-plugin-flatpak
set +e
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

#Swapfile creation

read -p "Do you want to create a swapfile (recommended) ? (y/N)" SWAPFILE
if [[ ${SWAPFILE,,} = y || ${SWAPFILE,,} = yes ]]; then
    if sudo swapon --show | grep -q '/swapfile'; then
        echo "A swapfile already exists"
    else
        read -p "What should be the size of the swapfile ? (ex: 2G)" SWAPFILESIZE
        sudo fallocate -l $SWAPFILESIZE /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
fi

#Reduce the delay of GRUB and add plymouth

sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/' /etc/default/grub
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash/' /etc/default/grub
set +e
sudo apt install plymouth plymouth-themes
set -e
sudo /sbin/plymouth-set-default-theme -R spinner
sudo grub-mkconfig -o /boot/grub/grub.cfg

#Set a limit to systemd logs

echo "Setting a limit for systemd's logs (50M)..."
sudo sed -i 's/#SystemMaxUse=/SystemMaxUse=50M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

#Fix /etc/network/interfaces

sudo mv /etc/network/interfaces /etc/network/interfaces.bak
sudo bash -c 'cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
EOF'


#Reduce /root reserved space

read -p "What is the root disk's name (ex: /dev/sda2)?" ROOTDISKNAME
sudo tune2fs -r 1 $ROOTDISKNAME

#Bluetooth

read -p "Do you want to install bluetooth ? (y/N)" BLUETOOTH
if [[ ${BLUETOOTH,,} = y || ${BLUETOOTH,,} = yes ]]; then
    sudo apt install bluez
    sudo systemctl enable --now bluetooth
else
    sudo systemctl disable --now bluetooth
fi

#Build essential

read -p "Do you want to install build-essential ? (y/N)" BUILDESS
if [[ ${BUILDESS,,} = y || ${BUILDESS,,} = yes ]]; then
    sudo apt install build-essential
fi

#Usefull packages

read -p "Do you want to install Fish, Htop and Gnome-extension-manager ? (y/N)" PACKAGEUSE
if [[ ${PACKAGEUSE,,} = y || ${PACKAGEUSE,,} = yes ]]; then
    sudo apt install fish gnome-shell-extension-manager htop
fi

#Ask to install CUPS

read -p "Do you want to install CUPS, it's for printing support ? (y/N)" CUPSINSTALL
if [[ ${CUPSINSTALL,,} = y || ${CUPSINSTALL,,} = yes ]]; then
    sudo apt install cups
    sudo systemctl enable --now cups
fi

#Ask to install ZRAM

read -p "Do you want to install zram ? (y/N)" ZRAMINSTALL
if [[ ${ZRAMINSTALL,,} = y || ${ZRAMINSTALL,,} = yes ]]; then
    set -e
    sudo apt install zram-tools
    set +e
    sudo nano /etc/default/zramswap
    sudo systemctl restart zramswap
fi

#Codecs

echo "Installing codecs ..."
sudo apt install libavcodec-extra

#Firewall

read -p "Do you want to install UFW (a firewall) ? (y/N)" UFWINSTALL
if [[ ${UFWINSTALL,,} = y || ${UFWINSTALL,,} = yes ]]; then
    sudo apt install ufw
    sudo ufw enable
    sudo ufw allow 1716:1764/tcp
    sudo ufw allow 1716:1764/udp
fi

#Install some gnome extensions

echo "Installing some extensions ..."
sudo apt install gnome-shell-extension-dashtodock gnome-shell-extension-gsconnect gnome-shell-extension-appindicator

#Adw GTK3
sudo apt install wget
wget https://github.com/lassekongo83/adw-gtk3/releases/download/v5.3/adw-gtk3v5.3.tar.xz
if ls | grep -q adw-gtk3v5.3.tar.xz > /dev/null; then
    xz -d adw-gtk3v5.3.tar.xz
    if ls | grep -q adw-gtk3v5.3.tar > /dev/null; then
        tar -xf adw-gtk3v5.3.tar
        sudo mv adw-gtk3/ /usr/share/themes
        sudo mv adw-gtk3-dark/ /usr/share/themes
        rm adw-gtk3v5.3.tar.xz adw-gtk3v5.3.tar
    fi
fi

#Install some flatpak apps

flatpak install flathub com.vscodium.codium
flatpak install flathub io.missioncenter.MissionCenter
flatpak install flathub io.gitlab.librewolf-community
flatpak install flathub org.libreoffice.LibreOffice

echo "The first step of the script is finished !"
sleep 1
echo "Please reboot and log into GNOME to do the final tweaks!"

#Put the second script in ~/main_after.sh

cat << 'END' > ~/main_after.sh
dconf write /org/gnome/mutter/focus-change-on-pointer-rest true
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:minimize,maximize,close'"
dconf write /org/gnome/desktop/wm/preferences/focus-mode "'sloppy'"
dconf write /org/gnome/desktop/privacy/remove-old-temp-files true
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

if ls /usr/share/themes | grep -q adw > /dev/null; then
    dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3-dark'"    
fi

dconf write /org/gnome/settings-daemon/plugins/media-keys/volume-step 3
dconf write /org/gnome/shell/extensions/dash-to-dock/isolate-workspaces true
dconf write /org/gnome/shell/extensions/dash-to-dock/show-trash false
dconf write /org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink true
dconf write /org/gnome/shell/app-switcher/current-workspace-only true
dconf write /org/gnome/shell/enabled-extensions "['gsconnect@andyholmes.github.io', 'dash-to-dock@micxgx.gmail.com', 'ubuntu-appindicators@ubuntu.com']"
dconf write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 40

#Remove created files
rm ~/main.sh ~/main_after.sh ~/.config/autostart/main_after.desktop

#Remove evolution, sometimes it reinstalls itself
sudo apt autoremove evolution-data-server

echo "FINISHED, enjoy your system!"
echo "It's recommended to reboot one last time."
sleep 3
END

#Execute it at boot

mkdir -p ~/.config/autostart

cat << 'EOF' > ~/.config/autostart/main_after.desktop
[Desktop Entry]
Type=Application
Exec=bash -c '/home/$USER/main_after.sh'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Main After Script
Comment=PostInstallScript
EOF

chmod +x /home/$USER/main_after.sh
