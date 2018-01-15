#!/bin/bash

MAILGUN_DOMAIN=""
MAILGUN_KEY=""
MAILGUN_EMAIL=""
REPORT_FILE="/var/log/monitoring_report.log"

while true ; do
    case "$1" in
        -mgd|--mailgun-domain)
            case "$2" in
                "") echo " Please provide a mail gun domain" exit 1;;
                *) MAILGUN_DOMAIN=$2 ; shift 2 ;;
            esac ;;
        -mgk|--mailgun-key)
            case "$2" in
                "") echo " Please provide a mail gun key" exit 1;;
                *) MAILGUN_KEY=$2 ; shift 2 ;;
            esac ;;
        -mge|--email-address)
            case "$2" in
                "") echo " Please provide a email address to send emails to" exit 1;;
                *) MAILGUN_EMAIL=$2 ; shift 2 ;;
            esac ;;
        *) shift ; break ;;
    esac
done

function sendToMailgun(){
    if [ ! -z "$MAILGUN_KEY" ] && [ ! -z "$MAILGUN_DOMAIN" ] &&  [ ! -z "$MAILGUN_EMAIL" ]; then
        echo "Sending Email"
        curl -s --user "api:$MAILGUN_KEY" https://api.mailgun.net/v3/$MAILGUN_DOMAIN/messages \
        -F from='RaspberryPi-Alerts <noreply@raspberrypi.com>' -F to="$MAILGUN_EMAIL" \
        -F subject="'$1" -F html="$2"
    fi
}
openvpn_result=$(ps -ef | grep /run/openvpn/default.pid | grep -v grep | wc -l)
privoxy_result=$(ps -ef | grep /usr/sbin/privoxy | grep -v grep | wc -l)

ip_addr=$(curl -s http://ipinfo.io/ip)
vpn_ip_addr=$(cat /etc/openvpn/default.conf | grep 'remote ' | sed 's/remote //' | sed 's/ .*//')
ip_result=$(echo $ip_addr | grep $vpn_ip_addr | wc -l)

SEND_ERR_REPORT=0
if [[ openvpn_result -ne 1 ]]; then
    echo "openvpn not running"
    SEND_ERR_REPORT=1
fi

if [[ privoxy_result -ne 1 ]]; then
    echo "privoxy not running"
    SEND_ERR_REPORT=1
fi

if [[ ip_result -ne 1 ]]; then
    echo "VPN($vpn_ip_addr) Disconnected - $ip_addr"
    SEND_ERR_REPORT=1
fi

REPORT="Date: $(date)<br/>OpenVPN Running: $openvpn_result<br/>Privoxy Running: $openvpn_result<br/>IP Validate: $ip_result<br/><br/>Actual IP Address:   $ip_addr<br/>VPN IP Address:      $vpn_ip_addr" 

if [ $SEND_ERR_REPORT -gt 0 ]; then
    echo "Failure Detected"
    if [ ! -f $REPORT_FILE ]; then
        echo "Writing Report File"
        echo $REPORT > $REPORT_FILE
        sendToMailgun "VPN Offline - Disconnected" "$REPORT"
    fi
    exit 1
fi

if [ -f $REPORT_FILE ]; then 
    echo "Removing report file"
    rm $REPORT_FILE
    sendToMailgun "VPN Online - Connected" "$REPORT"
fi
exit 0