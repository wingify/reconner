#!/bin/bash

show_logo(){
	echo "


██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗███╗   ██╗███████╗██████╗
██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║████╗  ██║██╔════╝██╔══██╗
██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝
██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗
██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║
╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝

"
}

init(){

	export SEC=/root/sec
	export GO111MODULE=on
	export GOPATH=$(go env GOPATH)
	export GOROOT=$(go env GOROOT)
	export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

	curr_date=$(date +"%Y-%m-%d")
	mkdir -p $SEC/subdomains/$domain/$curr_date

	curr_time=$(date +%s)

	working_dir=$SEC/subdomains/$domain/$curr_date
	asset_finder_out=$working_dir/asset_finder_$domain.out
	amass_out=$working_dir/amass_$domain.out
	subfinder_out=$working_dir/subfinder_$domain.out
	massdns_out=$working_dir/massdns_$domain.out
	altdns_out=$working_dir/altdns_$domain.out
	massdns_new=$working_dir/massdns_new_$domain.out
	http_altdns=$working_dir/http_altdns.out
	ips_list=$working_dir/ips_list.out
	final=$working_dir/final.out
	pc_token=$PC_TOKEN
}
domain=
excluded=
no_alts=
while getopts ":d:e:n:" opt; do
	case ${opt} in
		d )
			domain=${OPTARG}
			init
			;;
		e )
			excluded=${OPTARG}
			;;
		n )
			no_alts=true
			;;
		* )
			show_usage
			exit 1;
			;;
	esac
done
shift $((OPTIND -1))

#to run amass
run_amass(){
	echo "Running Amass"
	if [ -z "$excluded" ]
	then
		amass enum -active -d $domain -o $amass_out -config $SEC/amass_config.ini -nf $subfinder_out -brute -w $SEC/SecLists/Discovery/DNS/subdomains-top1million-5000.txt -noalts
	else
		amass enum -active -d $domain -o $amass_out -config $SEC/amass_config.ini -nf $subfinder_out -brute -w $SEC/SecLists/Discovery/DNS/subdomains-top1million-5000.txt -bl $excluded -noalts
	fi
}

run_subfinder(){
	echo "Running Subfinder"
	subfinder -d $domain -o $subfinder_out
}

show_usage(){
	show_logo

	echo "Usage: bash reconner.sh -d example.com"
}

merge_and_sort_two_files(){
	cat $1 $2 > $working_dir/tmp_merged
	cat $working_dir/tmp_merged | sort -u > $2

	rm -rf $working_dir/tmp_merged
}

sort_n_remove_duplicates(){
	cat $1 > $working_dir/tmp_file
	cat $working_dir/tmp_file | sort -u > $1

	rm -rf $working_dir/tmp_file
}

generate_commonspeak(){
	echo "generating possibilities with common-speak wordlist"
	python3 $SEC/commonspeak2-wordlists/subdomains/commonspeak.py $domain >> $1
}

run_asset_finder(){
	echo "Running asset finder"
	assetfinder --subs-only $domain > $asset_finder_out
}

run_massdns(){
	cat $1 | $SEC/massdns/bin/massdns -r $SEC/SecLists/Miscellaneous/dns-resolvers.txt -t A --verify-ip -o S -w $working_dir/tmp_massdns.out
}

run_track(){
	amass track -d $domain
}

get_domain_ips(){
	#separate ip and domains in different files

	echo "separating ip and domains in different files"
	mapfile -t list < <(cat $1)

	for output in "${list[@]}"
	do
		tmp=$(echo $output | cut -f 2 -d " " )

                if [ "$tmp" = "A" ];then
			echo $output | cut -f 3 -d " " >> $ips_list
		fi

		echo $output | cut -f 1 -d " " | sed -r "s/(\.\s+$)|(\.$)//g" >> $2
	done

	rm -rf $working_dir/tmp_massdns.out

}

generate_alterations(){
	echo "generating alterations"

	#cat $massdns_out | dnsgen - > $altdns_out
	altdns -i $massdns_out -o $altdns_out -w $SEC/altdns/words.txt
}

get_alive_domains(){
	echo "Checking for alive domains"
	cat $1 | httprobe -c 80 -t 20000 > $working_dir/http_final.out
}

get_open_ports(){

	echo "scanning for ports"
	masscan -iL $working_dir/final_ip.out -p0-65535 --rate 10000 -oL $working_dir/masscan_out&
}


run_aquatone(){
	echo "Running aquatone"
	cat $final | $SEC/aquatone/aquatone -ports xlarge -out $working_dir/aquatone/ -http-timeout 2000 -threads 10
}

main(){
	show_logo

	run_subfinder

	run_asset_finder

	merge_and_sort_two_files $asset_finder_out $subfinder_out

	run_amass

	merge_and_sort_two_files $subfinder_out $amass_out

	generate_commonspeak $amass_out

	sort_n_remove_duplicates $amass_out

	run_massdns $amass_out

	cp $working_dir/tmp_massdns.out $working_dir/resolved_domains.out

	get_domain_ips $working_dir/tmp_massdns.out $working_dir/tmp

	cat $working_dir/tmp | sort -u >> $massdns_out

	rm -rf $working_dir/tmp

	if [ "$no_alts" = true ]; then
		echo "Skiping alterations"
	else
		generate_alterations
		run_massdns $altdns_out

        	cat $working_dir/tmp_massdns.out >> $working_dir/resolved_domains.out

        	sort_n_remove_duplicates $working_dir/resolved_domains.out

        	get_domain_ips $working_dir/tmp_massdns.out $massdns_new

        	sort_n_remove_duplicates $ips_list
	fi

	mv $ips_list $working_dir/final_ip.out

	python3 $SEC/clean_ips.py $working_dir/final_ip.out $working_dir/final_ip.out

	merge_and_sort_two_files $massdns_out $massdns_new

	mv $massdns_new $final

	get_alive_domains $final

	get_open_ports

	run_aquatone

	time_now=$(date +%s)
	time_taken=$((time_now-curr_time))
	echo "Time taken in seconds: "$time_taken
}

if [ -z "$domain" ]
then
	show_usage;
	exit 1;
else
	source ~/.bashrc
	main
fi
