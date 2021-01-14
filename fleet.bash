cat <<-ENDOFTEXT > /tmp/trim.awk
function ltrim(s) { sub(/^ */, "", s); return s }
function rtrim(s) { sub(/ *$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)); }
ENDOFTEXT

logmsg() {
    printf "%s %s %-30s %-30s %-s\n" "$(date)" "$(whoami)" "$SCR" "$1" "$2" >> /var/log/fleet
}

listsecuritygroups() {
    L_LIST=`$AWS ec2 describe-security-groups | grep $FTAG | gawk '{print $3}'`
    for L_ITEM in $L_LIST; do
        echo $L_ITEM
    done
}
listkeys() {
    L_LIST=`$AWS ec2 describe-key-pairs | gawk -v rx="$FTAG" '($3 ~ ("^" rx)) { print $3 }'`
    for L_ITEM in $L_LIST; do
        echo $L_ITEM
    done
}
listspots() {
   FLDS="InstanceId,State.Name,InstanceType,InstanceLifecycle"
   $AWS ec2 describe-instances \
            --query 'Reservations[*].Instances[*].['$FLDS']' | grep "running" | egrep "spot$" | gawk '{print $1}' 
}
listinstances() {
    FLDS="InstanceId,ImageId,Placement.AvailabilityZone,State.Name,InstanceLifecycle,InstanceType,PublicIpAddress,LaunchTime"
    $AWS ec2 describe-instances --query 'Reservations[*].Instances[*].['$FLDS']'
}
listrunningfleet() {
    FLDS="InstanceId,ImageId,Placement.AvailabilityZone,State.Name,InstanceLifecycle,InstanceType,PublicIpAddress,LaunchTime"
    $AWS ec2 describe-instances --filters Name=tag:Name,Values=FleetAuto \
                                --query 'Reservations[*].Instances[*].['$FLDS']' | grep "running" 
}
scpdo() {
     scp -o StrictHostKeyChecking=no -i $KEYFILE $1 $UNAME@$IP:$2
}
sshdo() {
    ssh $UNAME@$IP -o StrictHostKeyChecking=no -i $KEYFILE $1
}
getdemandfleet() {
    zap $Tmp; zap $Tmp3
    FLDS="InstanceId,State.Name,InstanceType,InstanceLifecycle"
    $AWS ec2 describe-instances --filters Name=tag:Name,Values=FleetAuto \
                                --query 'Reservations[*].Instances[*].['$FLDS']' \
                                | grep "running" | gawk '{print $1}' > $Tmp
    cp $Tmp $Tmp3
}
FLEETCAT=fleetdns
getset() {

cat <<-ENDOFTEXT > /tmp/trim.awk
function ltrim(s) { sub(/^ */, "", s); return s }
function rtrim(s) { sub(/ *$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)); }
ENDOFTEXT

    ID=`cat $FLEETHOME/INST/$FLEETCAT | gawk -F, -v L=$1 '{if (NR==L) print $1}'`
    IP=`cat $FLEETHOME/INST/$FLEETCAT | gawk -F, -v L=$1 '{if (NR==L) print $2}'`
    KEY=`cat $FLEETHOME/INST/$FLEETCAT | gawk -F, -v L=$1 '{if (NR==L) print $3}'`
    UNAME=`cat ~/.spot    | gawk '@include "/tmp/trim.awk";{if (NR==9) print trim($0)}'`
}
show() {
    logmsg "$1"
    echo "$1"
}
zap() {
    rm -rf "$1"  >/dev/null 2>&1
}
remote() {
      echo $1; 
      ssh $UNAME@$IP -o StrictHostKeyChecking=no -i $FLEETHOME/PEMS/$KEY.pem $1
}
getspotfleet() {
    zap $Tmp; zap $Tmp3
    FLDS="InstanceId,State.Name,InstanceType,InstanceLifecycle"
    $AWS ec2 describe-instances \
             --query 'Reservations[*].Instances[*].['$FLDS']' \
             | grep "running" | egrep "spot$" | gawk '{print $1}' > $Tmp
    cp $Tmp $Tmp3
}
dnsinit() {
      rm -rf $FLEETHOME/INST
      mkdir -p  $FLEETHOME/INST
      getspotfleet
      KEYNAME=$(bib -n KEYNAME -g)
      KEYFILE=$(bib -n KEYFILE -g)
      SGDUMMY=$(bib -n SGDUMMY -g)
      SGNAME=$(bib -n SGNAME -g)
      cat $Tmp3 | while read line; do
                $AWS ec2 create-tags --resources $line --tags Key=Name,Value=FleetAuto
                SZ=".Reservations[0].Instances[0]"
                $AWSJ ec2 describe-instances --instance-ids $line > $Tmp
                D=`cat $Tmp | jq "$SZ.PublicIpAddress"  | sed -e 's/["]//g'`
                echo $line","$D","$KEYNAME  >> $FLEETHOME/INST/fleetdns
      done
      IID=$(cat $FLEETHOME/INST/fleetdns | gawk  -F, '{print $1}')
      IP=$(cat  $FLEETHOME/INST/fleetdns | gawk  -F, '{print $2}')
      KEY=$(cat $FLEETHOME/INST/fleetdns | gawk -F, '{print $3}')
      bib  -n IID -v $IID -p
      bib  -n IP -v $IP -p
      bib  -n KEY -v $KEY -p
      bib  -n UNAME -v ubuntu -p

      logmsg "IID" "$IID"
      logmsg "IP" "$IP"
      logmsg "KEY" "$KEY"
      UNAME="ubuntu"
}
