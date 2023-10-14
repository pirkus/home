# home
configs and dot files

## To even start the install
Turn on PXE network in BIOS

Kernel params needed
```shell
nomodeset nvd_load=YES nvme_load=YES nvme_core.default_ps_max_latency_us=0
```

## To install arch
If pacman is crapping itself try:
```shell
pacman-key --populate archlinux
```
```shell
pacman -Sy archlinux-keyring
```
## After arch is installed
```
sudo pacman -Syu base-devel git linux-headers ly xorg-server nvidia zsh zsh-autosuggestions starship i3-wm i3lock i3status i3blocks firefox rofi emacs thunar mc jq wget perl python xfce4-terminal curl openssh unzip noto-fonts noto-fonts-emoji alsa-utils xorg-xmodmap scrot vkd3d lib32-vkd3d lib32-gamemode gamemode vulkan-tools xorg-xrandr mangohud steam nerd-fonts galculator
```

## Install yay
```shell
pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

## Checkout home from git
```shell
git init .
git remote add -t \* -f origin <repository-url>
git checkout master
```

## Change shell
```shell
chsh -s /bin/zsh
```

## Enable ly
```shell
sudo systemctl enable ly.service
```

## Enable high resolution shell
```shell
su -
```
add "console-mode max" to /boot/loader/loader.conf

this should work too (not tried yet) - !!! MUST BE SUDO!!!!
```shell
echo "console-mode max" >> /boot/loader/loader.conf
```

## Make hung processes not block reboot or shutdown
edit "/etc/systemd/system.conf"

uncoment: DefaultTimeoutStopSec and set it to 5 or (not tried yet):
```shell
echo "DefaultTimeoutStopSec=5" >> /etc/systemd/system.conf
```

## /etc/pacman.conf
```apacheconf
[options]
# The following paths are commented out with their default values listed.
# If you wish to use different paths, uncomment and update the paths.
#RootDir     = /
#DBPath      = /var/lib/pacman/
#CacheDir    = /var/cache/pacman/pkg/
#LogFile     = /var/log/pacman.log
#GPGDir      = /etc/pacman.d/gnupg/
#HookDir     = /etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
#CleanMethod = KeepInstalled
#UseDelta    = 0.7
Architecture = auto

# Pacman won't upgrade packages listed in IgnorePkg and members of IgnoreGroup
#IgnorePkg   =
#IgnoreGroup =

#NoUpgrade   =
#NoExtract   =

# Misc options
#UseSyslog
Color
#TotalDownload
CheckSpace
VerbosePkgLists
ILoveCandy

# By default, pacman accepts packages signed by keys that its local keyring
# trusts (see pacman-key and its man page), as well as unsigned packages.
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
#RemoteFileSigLevel = Required

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
```
