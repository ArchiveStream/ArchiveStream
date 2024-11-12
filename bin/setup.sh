#!/usr/bin/env bash
# ArchiveStream Setup Script (Ubuntu/Debian/FreeBSD/macOS)
#   - Project Homepage: https://github.com/ArchiveStream/ArchiveStream
#   - Install Documentation: https://github.com/ArchiveStream/ArchiveStream/wiki/Install
# Script Usage:
#    curl -fsSL 'https://raw.githubusercontent.com/ArchiveStream/ArchiveStream/dev/bin/setup.sh' | bash
#           (aka https://docker-compose.archivestream.io)

### Bash Environment Setup
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# set -o xtrace
# set -x
# shopt -s nullglob
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
# IFS=$'\n'

clear

if [ $(id -u) -eq 0 ]; then
    echo
    echo "[X] You cannot run this script as root. You must run it as a non-root user with sudo ability."
    echo "    Create a new non-privileged user 'archivestream' if necessary."
    echo "      adduser archivestream && usermod -a archivestream -G sudo && su archivestream"
    echo "    https://www.digitalocean.com/community/tutorials/how-to-create-a-new-sudo-enabled-user-on-ubuntu-20-04-quickstart"
    echo "    https://www.vultr.com/docs/create-a-sudo-user-on-freebsd"
    echo "    Then re-run this script as the non-root user."
    echo
    exit 2
fi

if (which docker > /dev/null && docker pull archivestream/archivestream:latest); then
    echo "[+] Initializing an ArchiveStream data folder at ~/archivestream/data using Docker Compose..."
    mkdir -p ~/archivestream/data || exit 1
    cd ~/archivestream
    if [ -f "./index.sqlite3" ]; then
        mv -i ~/archivestream/* ~/archivestream/data/
    fi
    curl -fsSL 'https://raw.githubusercontent.com/ArchiveStream/ArchiveStream/stable/docker-compose.yml' > docker-compose.yml
    mkdir -p ./etc
    curl -fsSL 'https://raw.githubusercontent.com/ArchiveStream/ArchiveStream/stable/etc/sonic.cfg' > ./etc/sonic.cfg
    docker compose run --rm archivestream init --setup
    echo
    echo "[+] Starting ArchiveStream server using: docker compose up -d..."
    docker compose up -d
    sleep 7
    which open > /dev/null && open "http://127.0.0.1:8000" || true
    echo
    echo "[√] Server started on http://0.0.0.0:8000 and data directory initialized in ~/archivestream/data. Usage:"
    echo "    cd ~/archivestream"
    echo "    docker compose ps"
    echo "    docker compose down"
    echo "    docker compose pull"
    echo "    docker compose up"
    echo "    docker compose run archivestream manage createsuperuser"
    echo "    docker compose run archivestream add 'https://example.com'"
    echo "    docker compose run archivestream list"
    echo "    docker compose run archivestream help"
    exit 0
elif (which docker > /dev/null && docker pull archivestream/archivestream:latest); then
    echo "[+] Initializing an ArchiveStream data folder at ~/archivestream/data using Docker..."
    mkdir -p ~/archivestream/data || exit 1
    cd ~/archivestream
    if [ -f "./index.sqlite3" ]; then
        mv -i ~/archivestream/* ~/archivestream/data/
    fi
    cd ./data
    docker run -v "$PWD":/data -it --rm archivestream/archivestream:latest init --setup
    echo
    echo "[+] Starting ArchiveStream server using: docker run -d archivestream/archivestream..."
    docker run -v "$PWD":/data -it -d -p 8000:8000 --name=archivestream archivestream/archivestream:latest
    sleep 7
    which open > /dev/null && open "http://127.0.0.1:8000" || true
    echo
    echo "[√] Server started on http://0.0.0.0:8000 and data directory initialized in ~/archivestream/data. Usage:"
    echo "    cd ~/archivestream/data"
    echo "    docker ps --filter name=archivestream"
    echo "    docker kill archivestream"
    echo "    docker pull archivestream/archivestream"
    echo "    docker run -v $PWD:/data -d -p 8000:8000 --name=archivestream archivestream/archivestream"
    echo "    docker run -v $PWD:/data -it archivestream/archivestream manage createsuperuser"
    echo "    docker run -v $PWD:/data -it archivestream/archivestream add 'https://example.com'"
    echo "    docker run -v $PWD:/data -it archivestream/archivestream list"
    echo "    docker run -v $PWD:/data -it archivestream/archivestream help"
    exit 0
fi

echo
echo "[!] It's highly recommended to use ArchiveStream with Docker, but Docker wasn't found."
echo
echo "    ⚠️ If you want to use Docker, press [Ctrl-C] to cancel now. ⚠️"
echo "        Get Docker: https://docs.docker.com/get-docker/"
echo "        After you've installed Docker, run this script again."
echo
echo "Otherwise, install will continue with apt/brew/pkg + pip in 12s... (press [Ctrl+C] to cancel)"
echo
sleep 12 || exit 1
echo "Proceeding with system package manager..."
echo

echo "[i] ArchiveStream Setup Script 📦"
echo
echo "    This is a helper script which installs the ArchiveStream dependencies on your system using brew/apt/pip3."
echo "    You may be prompted for a sudo password in order to install the following:"
echo
echo "        - archivestream"
echo "        - python3, pip, nodejs, npm            (languages used by ArchiveStream, and its extractor modules)"
echo "        - curl, wget, git, youtube-dl, yt-dlp  (used for extracting title, favicon, git, media, and more)"
echo "        - chromium                             (skips this if any Chrome/Chromium version is already installed)"
echo
echo "    If you'd rather install these manually as-needed, you can find detailed documentation here:"
echo "        https://github.com/ArchiveStream/ArchiveStream/wiki/Install"
echo
echo "Continuing in 12s... (press [Ctrl+C] to cancel)"
echo
sleep 12 || exit 1
echo "Proceeding to install dependencies..."
echo

# On Linux:
if which apt-get > /dev/null; then
    echo "[+] Adding ArchiveStream apt repo and signing key to sources..."
    if ! (sudo apt install -y software-properties-common && sudo add-apt-repository -u ppa:archivestream/archivestream); then
        echo "deb http://ppa.launchpad.net/archivestream/archivestream/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/archivestream.list
        echo "deb-src http://ppa.launchpad.net/archivestream/archivestream/ubuntu focal main" | sudo tee -a /etc/apt/sources.list.d/archivestream.list
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C258F79DCC02E369
        sudo apt-get update -qq
    fi
    echo
    echo "[+] Installing ArchiveStream system dependencies using apt..."
    sudo apt-get install -y git python3 python3-pip python3-distutils wget curl yt-dlp ffmpeg git nodejs npm ripgrep
    sudo apt-get install -y libgtk2.0-0 libgtk-3-0 libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb libgbm-dev || sudo apt-get install -y chromium || sudo apt-get install -y chromium-browser || true
    sudo apt-get install -y archivestream
    sudo apt-get --only-upgrade install -y archivestream
    echo
    echo "[+] Installing ArchiveStream python dependencies using pip3..."
    sudo python3 -m pip install --upgrade --ignore-installed archivestream yt-dlp playwright
# On Mac:
elif which brew > /dev/null; then
    echo "[+] Installing ArchiveStream system dependencies using brew..."
    brew tap archivestream/archivestream
    brew update
    brew install python3 node git wget curl yt-dlp ripgrep
    brew install --fetch-HEAD -f archivestream
    echo
    echo "[+] Installing ArchiveStream python dependencies using pip3..."
    python3 -m pip install --upgrade --ignore-installed archivestream yt-dlp playwright
elif which pkg > /dev/null; then
    echo "[+] Installing ArchiveStream system dependencies using pkg and pip (python3.9)..."
    sudo pkg install -y python3 py39-pip py39-sqlite3 npm wget curl youtube_dl ffmpeg git ripgrep
    sudo pkg install -y chromium
    echo
    echo "[+] Installing ArchiveStream python dependencies using pip..."
    # don't use sudo here so that pip installs in $HOME/.local instead of into /usr/local
    python3 -m pip install --upgrade --ignore-installed archivestream yt-dlp playwright
else
    echo "[!] Warning: Could not find aptitude/homebrew/pkg! May not be able to install all dependencies automatically."
    echo
    echo "    If you're on macOS, make sure you have homebrew installed:     https://brew.sh/"
    echo "    If you're on Linux, only Ubuntu/Debian/BSD systems are officially supported with this script."
    echo "    If you're on Windows, this script is not officially supported (Docker is recommeded instead)."
    echo
    echo "See the README.md for Manual Setup & Troubleshooting instructions if you you're unable to run ArchiveStream after this script completes."
fi

echo

if ! (python3 --version && python3 -m pip --version && python3 -m django --version); then
    echo "[X] Python 3 pip was not found on your system!"
    echo "    You must first install Python >= 3.7 (and pip3):"
    echo "      https://www.python.org/downloads/"
    echo "      https://wiki.python.org/moin/BeginnersGuide/Download"
    echo "    After installing, run this script again."
    exit 1
fi

if ! (python3 -m django --version && python3 -m pip show archivestream && which -a archivestream); then
    echo "[X] Django and ArchiveStream were not found after installing!"
    echo "    Check to see if a previous step failed."
    echo
    exit 1
fi

# echo
# echo "[+] Upgrading npm and pip..."
# sudo npm i -g npm || true
# sudo python3 -m pip install --upgrade pip setuptools || true

echo
echo "[+] Installing Chromium binary using playwright..."
python3 -m playwright install --with-deps chromium || true
echo

echo
echo "[+] Initializing ArchiveStream data folder at ~/archivestream/data..."
mkdir -p ~/archivestream/data || exit 1
cd ~/archivestream
if [ -f "./index.sqlite3" ]; then
    mv -i ~/archivestream/* ~/archivestream/data/
fi
cd ./data
: | python3 -m archivestream init --setup || true   # pipe in empty command to make sure stdin is closed
# init shows version output at the end too
echo
echo "[+] Starting ArchiveStream server using: nohup archivestream server &..."
nohup python3 -m archivestream server 0.0.0.0:8000 > ./logs/server.log 2>&1 &
sleep 7
which open > /dev/null && open "http://127.0.0.1:8000" || true
echo
echo "[√] Server started on http://0.0.0.0:8000 and data directory initialized in ~/archivestream/data. Usage:"
echo "    cd ~/archivestream/data                               # see your data dir"
echo "    archivestream server --quick-init 0.0.0.0:8000        # start server process"
echo "    archivestream manage createsuperuser                  # add an admin user+pass"
echo "    ps aux | grep archivestream                           # see server process pid"
echo "    pkill -f archivestream                                # stop the server"
echo "    pip install --upgrade archivestream; archivestream init  # update versions"
echo "    archivestream add 'https://example.com'"              # archive a new URL
echo "    archivestream list                                    # see URLs archived"
echo "    archivestream help                                    # see more help & examples"
