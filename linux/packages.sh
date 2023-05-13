#!/bin/bash
# shellcheck disable=SC2317

FAILURE=1
SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

#silent pushd
pushd() {
	command pushd "$@" >/dev/null
}

function prompt_exit() {
	echo " "
	read -n1 -srp $'Press any key to continue...\n' _
	exit $SUCCESS
}

function install_logiops() {
	sudo apt install build-essential cmake libevdev-dev libudev-dev libconfig++-dev
	mkdir -p logiops/build
	pushd logiops/build
	cmake .. && make && sudo make install
	popd
	sudo /usr/bin/cp -fr logid.cfg /etc/logid.cfg
}

function install_powershell() {
	snap install powershell --classic
	../win10/packages.ps1 default-modules
}

function install_nerdfonts() {
	declare -a fonts=(
		Hack
		Meslo
	)

	version='2.1.0'
	fonts_dir="${HOME}/.local/share/fonts"

	if [[ ! -d $fonts_dir ]]; then
		mkdir -p "$fonts_dir"
	fi

	for font in "${fonts[@]}"; do
		zip_file="${font}.zip"
		download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${zip_file}"
		echo "Downloading $download_url"
		wget "$download_url"
		sudo unzip "$zip_file" -d "$fonts_dir"
		rm "$zip_file"
	done

	sudo find "$fonts_dir" -name '*Windows Compatible*' -delete

	fc-cache -fv
}

function install_nvm() {
	sudo apt --yes install build-essential libssl-dev
	# shellcheck disable=SC1091
	export NVM_DIR="$HOME/.nvm" && (
		git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
		cd "$NVM_DIR"
		# shellcheck disable=SC2046
		# shellcheck disable=SC2006
		git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
	) && \. "$NVM_DIR/nvm.sh"
}

function install_platformio() {
	python3 -c "$(curl -fsSL https://raw.githubusercontent.com/platformio/platformio/master/scripts/get-platformio.py)"
	ln -s ~/.platformio/penv/bin/platformio ~/.local/bin/platformio
	ln -s ~/.platformio/penv/bin/pio ~/.local/bin/pio
	ln -s ~/.platformio/penv/bin/piodebuggdb ~/.local/bin/piodebuggdb
	curl -fsSL https://raw.githubusercontent.com/platformio/platformio-core/develop/platformio/assets/system/99-platformio-udev.rules | sudo tee /etc/udev/rules.d/99-platformio-udev.rules
	sudo usermod -a -G dialout "$USER"
	sudo usermod -a -G plugdev "$USER"
	sudo service udev restart
}

function install_insync() {
	# see https://www.insynchq.com/downloads/linux
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
	# shellcheck disable=SC1091
	source /etc/lsb-release
	echo "deb http://apt.insync.io/ubuntu $DISTRIB_CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
	sudo apt update
	sudo apt install insync
}

function install_keepass_plugins() {
	pushd /usr/lib/keepass2/Plugins
	sudo wget https://github.com/xatupal/KeeTheme/releases/latest/download/KeeTheme.dll
	sudo wget https://github.com/xatupal/KeeTheme/releases/latest/download/KeeTheme.plgx
	sudo mkdir DarkenKP
	pushd DarkenKP
	sudo wget https://github.com/BradyThe/DarkenKP/releases/latest/download/KeeTheme.ini
}

# Script will run in its own path no matter where it's called from.
pushd "$(dirname "$0")"

if [ "$1" == "test" ]; then
	echo "---=== TEST CLAUSE OR PLACEHOLDER ===---"
	echo "  Will not actually install anything."
	prompt_exit

elif [ "$1" == "install-logiops" ]; then
	install_logiops
	prompt_exit

elif [ "$1" == "install-powershell" ]; then
	install_powershell
	prompt_exit

elif [ "$1" == "install-nerdfonts" ]; then
	install_nerdfonts
	prompt_exit

elif [ "$1" == "install-rust" ]; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	prompt_exit

elif [ "$1" == "install-nvm" ]; then
	install_nvm
	prompt_exit

elif [ "$1" == "check-nvm" ]; then
	if [[ $(command -v nvm) ]]; then
		echo "nvm present"
		exit $SUCCESS
	else
		exit $FAILURE
	fi

elif [ "$1" == "install-platformio" ]; then
	install_platformio
	prompt_exit

elif [ "$1" == "install-insync" ]; then
	install_insync
	prompt_exit

elif [ "$1" == "check-insync" ]; then
	if [[ $(command -v insync) ]]; then
		echo "insync present"
		exit $SUCCESS
	else
		exit $FAILURE
	fi

elif [ "$1" == "install-keepass-plugins" ]; then
	install_keepass_plugins
	prompt_exit

else
	echo "ERROR: Bad command or insufficient parameters!"
	echo " "
	exit $FAILURE
fi

popd
