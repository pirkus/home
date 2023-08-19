# home
configs and dot files

## To even start the install
Turn on PXE network in BIOS

Kernel params needed
```
nomodeset nvd_load=YES nvme_load=YES nvme_core.default_ps_max_latency_us=0
```

## To install arch
If pacman is crapping itself try:
pacman-key --populate archlinux

pacman -Sy archlinux-keyring

## After arch is installed
```
sudo pacman -Syu base-devel git linux-headers ly xorg-server nvidia zsh zsh-autosuggestions starship i3wm i3lock i3status i3blocks firefox rofi emacs thunar mc jq wget perl python xfce4-terminal curl openssh unzip
```

## Change shell
```
chsh -s /bin/zsh
```

## Enable ly
```
sudo systemctl enable ly.service
```

## Enable high resolution shell
```
su -
```
add "console-mode max" to /boot/loader/loader.conf

this should work too (not tried yet) - !!! MUST BE SUDO!!!!
```
echo "console-mode max" >> /boot/loader/loader.conf
```

## Make hung processes not block reboot or shutdown
edit "/etc/systemd/system.conf"

uncoment: DefaultTimeoutStopSec and set it to 5 or (not tried yet):
```
echo "DefaultTimeoutStopSec=5" >> /etc/systemd/system.conf
```
