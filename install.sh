#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

export SEC=/root/sec
export GO111MODULE=on
export GOPATH=$(go env GOPATH)
export GOROOT=$(go env GOROOT)
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

curr_dir=$(pwd)

mkdir -p $SEC

cd $SEC

echo -e "${GREEN}installing required tools${NC}"

apt install -y build-essential git unzip python3 python3-pip git gcc make libpcap-dev wget

echo -e "${GREEN}installing subfinder${NC}"

go get -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder

echo -e "${GREEN}installing amass${NC}"

go get -v github.com/OWASP/Amass/v3/...

cd $SEC

wget -O amass_config.ini https://raw.githubusercontent.com/OWASP/Amass/master/examples/config.ini

echo -e "${GREEN}installing asset finder${NC}"

go get -u github.com/tomnomnom/assetfinder

echo -e "${GREEN}getting commonspeak wordlists${NC}"

cd $SEC

git clone https://github.com/assetnote/commonspeak2-wordlists.git

cp $curr_dir/commonspeak.py $SEC/commonspeak2-wordlists/subdomains/

echo -e "${GREEN}installing massdns${NC}"

cd $SEC

git clone https://github.com/blechschmidt/massdns.git

cd massdns

make

echo -e "${GREEN}installing altdns${NC}"

pip3 install py-altdns

mkdir -p $SEC/altdns && cd $SEC/altdns

wget https://raw.githubusercontent.com/infosec-au/altdns/master/words.txt

res=$(python3 -c 'import sys; print(sys.version_info[:])')

IFS=',' read -ra ADDR <<< "$res"

ver=$(echo ${ADDR[1]} | xargs)

#making altdns compatible with python3 https://github.com/infosec-au/altdns/issues/31
sed -i 's/from Queue import/from queue import/g' "/usr/local/lib/python3."$ver"/dist-packages/altdns/__main__.py"
sed -i 's/if len(result) is 1/if len(result) == 1/g' "/usr/local/lib/python3."$ver"/dist-packages/altdns/__main__.py"
sed -i 's/is not/!=/g' "/usr/local/lib/python3."$ver"/dist-packages/altdns/__main__.py"

echo -e "${GREEN}getting cloudflare clean ip script${NC}"

cd $SEC

wget https://gist.githubusercontent.com/LuD1161/bd4ac4377de548990b47b0af8d03dc78/raw/85b0ea69b321ad66d4b34faf2f9b880d25f2409f/clean_ips.py

echo -e "${GREEN}installing httprobe${NC}"

go get -u github.com/tomnomnom/httprobe

echo -e "${GREEN}installing masscan${NC}"

cd $SEC

git clone https://github.com/robertdavidgraham/masscan

cd masscan

make

cp bin/masscan /usr/local/bin

echo -e "${GREEN}installing aquatone${NC}"

cd $SEC

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

apt install -y ./google-chrome-stable_current_amd64.deb


wget https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip

unzip aquatone_linux_amd64_1.7.0.zip -d aquatone/

echo -e "${GREEN}installing nuclei${NC}"

go get -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei

echo -e "${GREEN}cloning SecLists${NC}"

cd $SEC

mkdir -p SecLists/Miscellaneous && cd SecLists/Miscellaneous

wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Miscellaneous/dns-resolvers.txt

cd $SEC
mkdir -p SecLists/Discovery/DNS && cd SecLists/Discovery/DNS/

wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt

echo "Cleaning up"

rm -rf google-chrome-stable_current_amd64.deb aquatone_linux_amd64_1.7.0.zip

echo -e "${GREEN}DONE!!${NC}"
