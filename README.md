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
```shell
sudo pacman -Syu \
  base-devel git \
  linux-headers nvidia nvidia-settings lib32-nvidia-utils nvidia-prime \
  greetd greetd-tuigreet xorg-server xorg-xauth xorg-xmodmap xorg-xrandr xorg-xset \
  zsh zsh-autosuggestions starship grml-zsh-config \
  i3-wm i3lock i3status i3blocks rofi dunst \
  firefox emacs thunar xfce4-terminal mc \
  curl wget jq openssh unzip nano less perl python \
  noto-fonts noto-fonts-emoji ttf-nerd-fonts-symbols-mono \
  alsa-utils pipewire pipewire-alsa pipewire-pulse wireplumber \
  udiskie udisks2 gvfs gvfs-smb \
  acpi sysstat brightnessctl upower \
  tlp tlp-rdw powertop thermald cpupower acpid \
  rustup \
  imagemagick maim xclip \
  vulkan-tools vkd3d lib32-vkd3d \
  gamemode lib32-gamemode \
  mangohud lib32-mangohud \
  steam \
  galculator
```

```shell
paru -S pinta xautolock openrazer-daemon openrazer-driver razergenie auto-cpufreq nbfc
```

## greetd - nano /etc/greetd/config.toml
```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --cmd i3"
user = "greeter"
```

## Start services
```shell
sudo systemctl enable greetd.service
sudo systemctl enable tlp.service
sudo systemctl enable acpid.service
sudo systemctl enable thermald.service
sudo systemctl enable fstrim.timer
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

## Enable tap to click on touchpad
Save file to "/etc/X11/xorg.conf.d/30-touchpad.conf"
```
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lmr"
EndSection
```

## Allow nvidia GPUs to sleep
```shell
sudo systemctl enable nvidia-persistenced.service
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

## VPN
Move conf files to /etc/wireguard/some-conf.conf
```shell
wg-quick up some-conf
```

## Multiple displays
```sh
xrandr --output eDP-1 --mode 2560x1600 -r 240.00 --output HDMI-1-0 --mode 4096x2160 --right-of eDP-1
```

## Razer power saving
### sudo nano /etc/tlp.conf (add/modify)
```apacheconf
# CPU scaling
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# AMD pstate (CRITICAL)
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Boost control (big battery impact)
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Optional extra savings
PCIE_ASPM_ON_BAT=powersupersave
USB_AUTOSUSPEND=1
```

### Auto switch on plug/unplug
Create event:
```shell
sudo mkdir -p /etc/acpi/events /etc/acpi/actions
```
```shell
sudo nano /etc/acpi/events/ac_adapter
```
```apacheconf
event=ac_adapter
action=/etc/acpi/actions/power-mode.sh
```

Create script:
```shell
sudo nano /etc/acpi/actions/power-mode.sh
```

```bash
#!/bin/sh

online="$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -n1)"

if [ "$online" = "1" ]; then
  /usr/bin/tlp ac
  /usr/bin/cpupower frequency-set -g performance
else
  /usr/bin/tlp bat
  /usr/bin/cpupower frequency-set -g powersave
fi
```
`sudo chmod +x /etc/acpi/actions/power-mode.sh`

## Yubikey login
```shell
sudo pacman -Syu pam-u2f
```
Add yubikey to a mapping file:
```shell
pamu2fcfg | sudo tee -a /etc/u2f_mappings

# (At this point, press the button. You should see a long string of numbers.
# If you don't, make sure you have `udev` setup correctly.)

sudo -i
echo >> /etc/u2f_mappings
```
Append to your display manager's of choice pam.d file in `/etc/pam.d` (ly & sudo in our case):
```shell
sudo echo "auth sufficient pam_u2f.so authfile=/etc/u2f_mappings cue" >>
```
