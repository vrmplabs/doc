#!/bin/bash
#
# Initial data for Keystone using python-keystoneclient
#
# Tenant               User      Roles
# ------------------------------------------------------------------
# admin                admin     admin
# service              glance    admin
# service              nova      admin, [ResellerAdmin (swift only)]
# service              quantum   admin        # if enabled
# service              swift     admin        # if enabled
# demo                 admin     admin
# demo                 demo      Member, anotherrole
# invisible_to_admin   demo      Member
#
# Variables set before calling this script:
# SERVICE_TOKEN - aka admin_token in keystone.conf
# SERVICE_ENDPOINT - local Keystone admin endpoint
# SERVICE_TENANT_NAME - name of tenant containing service accounts
# ENABLED_SERVICES - stack.sh's list of services to start
# DEVSTACK_DIR - Top-level DevStack directory

# setting
. settings

#Users Password
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}  #echo $ADMIN_PASSWORD
SERVICE_PASSWORD=${SERVICE_PASSWORD:-$ADMIN_PASSWORD}  #echo $SERVICE_PASSWORD

#--token ADMIN --endpoint http://172.16.10.77:35357/v2.0
SERVICE_TOKEN=${SERVICE_TOKEN:-ADMIN} #echo $SERVICE_TOKEN
SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-http://localhost:35357/v2.0} #echo $SERVICE_ENDPOINT
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}  #echo $SERVICE_TENANT_NAME
export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT #export | grep SERVICE

function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

#token-ep=" --token $SERVICE_TOKEN --endpoint $ENDPOINT "

# Tenants: admin,service,demo,invisible_to_admin
ADMIN_TENANT_ID=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT_ID=$(get_id keystone tenant-create --name=service)
DEMO_TENANT_ID=$(get_id keystone tenant-create --name=demo)
INVIS_TENANT_ID=$(get_id keystone tenant-create --name=invisible_to_admin)

# Users: admin,demo,nova,glance
ADMIN_USER_ID=$(get_id keystone user-create --name=admin --pass="$ADMIN_PASSWORD")
DEMO_USER_ID=$(get_id keystone user-create --name=demo --pass="$ADMIN_PASSWORD") 
NOVA_USER_ID=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --tenant_id $SERVICE_TENANT_ID)
GLANCE_USER_ID=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --tenant_id $SERVICE_TENANT_ID)

# Roles: admin,KeystoneAdmin,KeystoneServiceAdmin,anotherrole,Member
ADMIN_ROLE_ID=$(get_id keystone role-create --name=admin)
KEYSTONEADMIN_ROLE_ID=$(get_id keystone role-create --name=KeystoneAdmin)
KEYSTONESERVICE_ROLE_ID=$(get_id keystone role-create --name=KeystoneServiceAdmin)
# ANOTHER_ROLE demonstrates that an arbitrary role may be created and used
# TODO(sleepsonthefloor): show how this can be used for rbac in the future!
ANOTHER_ROLE_ID=$(get_id keystone role-create --name=anotherROLE_ID)
MEMBER_ROLE_ID=$(get_id keystone role-create --name=Member)


# Add Roles to Users in Tenants
keystone user-role-add --user $ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant_id $ADMIN_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant_id $DEMO_TENANT_ID
keystone user-role-add --user $DEMO_USER_ID --role $ANOTHER_ROLE_ID --tenant_id $DEMO_TENANT_ID
# TODO(termie): these two might be dubious
keystone user-role-add --user $ADMIN_USER_ID --role $KEYSTONEADMIN_ROLE_ID --tenant_id $ADMIN_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $KEYSTONESERVICE_ROLE_ID --tenant_id $ADMIN_TENANT_ID
# The Member role is used by Horizon and Swift so we need to keep it:
keystone user-role-add --user $DEMO_USER_ID --role $MEMBER_ROLE_ID --tenant_id $DEMO_TENANT_ID
keystone user-role-add --user $DEMO_USER_ID --role $MEMBER_ROLE_ID --tenant_id $INVIS_TENANT_ID
# Configure service users/roles
keystone user-role-add --tenant_id $SERVICE_TENANT_ID --user $NOVA_USER_ID --role $ADMIN_ROLE_ID
keystone user-role-add --tenant_id $SERVICE_TENANT_ID --user $GLANCE_USER_ID --role $ADMIN_ROLE_ID


# Service and EndPoint:keystone, nova, glance, volume
SERVICE_KEYSTONE_ID=$(get_id keystone service-create --name=keystone --type=identity)
SERVICE_NOVA_ID=$(get_id keystone service-create --name=nova --type=compute)
SERVICE_GLANCE_ID=$(get_id keystone service-create --name=glance --type=image)
SERVICE_VOLUME_ID=$(get_id keystone service-create --name=volume --type=volume)


keystone endpoint-create --region RegionOne --service_id=$SERVICE_KEYSTONE_ID \
                         --publicurl=http://$KEYSTONE_IP:5000/v2.0 \
                         --internalurl=http://$KEYSTONE_IP:5000/v2.0 \
                         --adminurl=http://$KEYSTONE_IP:35357/v2.0
keystone endpoint-create --region RegionOne --service_id=$SERVICE_NOVA_ID \
                         --publicurl='http://'$CONTROLLER_IP':8774/v2/%(tenant_id)s' \
                         --internalurl='http://'$CONTROLLER_IP':8774/v2/%(tenant_id)s' \
                         --adminurl='http://'$CONTROLLER_IP':8774/v2/%(tenant_id)s'
keystone endpoint-create --region RegionOne --service_id=$SERVICE_GLANCE_ID \
                         --publicurl=http://$GLANCE_IP:9292/v1 \
                         --internalurl=http://$GLANCE_IP:9292/v1 \
                         --adminurl=http://$GLANCE_IP:9292/v1 
keystone endpoint-create --region RegionOne --service_id=$SERVICE_VOLUME_ID \
                         --publicurl='http://'$CONTROLLER_IP':8776/v1/%(tenant_id)s' \
                         --internalurl='http://'$CONTROLLER_IP':8776/v1/%(tenant_id)s' \
                         --adminurl='http://'$CONTROLLER_IP':8776/v1/%(tenant_id)s'



#if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
#    SWIFT_USER_ID=$(get_id keystone user-create --name=swift \
#                                             --pass="$SERVICE_PASSWORD" \
#                                             --tenant_id $SERVICE_TENANT_ID \
#                                             --email=swift@hastexo.com)
#    keystone user-role-add --tenant_id $SERVICE_TENANT_ID \
#                           --user $SWIFT_USER_ID \
#                           --role $ADMIN_ROLE_ID
#    # Nova needs ResellerAdmin role to download images when accessing
#    # swift through the s3 api. The admin role in swift allows a user
#    # to act as an admin for their tenant, but ResellerAdmin is needed
#    # for a user to act as any tenant. The name of this role is also
#    # configurable in swift-proxy.conf
#    RESELLER_ROLE_ID=$(get_id keystone role-create --name=ResellerAdmin)
#    keystone user-role-add --tenant_id $SERVICE_TENANT_ID \
#                           --user $NOVA_USER_ID \
#                           --role $RESELLER_ROLE_ID
#fi
#
#if [[ "$ENABLED_SERVICES" =~ "quantum" ]]; then
#    QUANTUM_USER_ID=$(get_id keystone user-create --name=quantum \
#                                               --pass="$SERVICE_PASSWORD" \
#                                               --tenant_id $SERVICE_TENANT_ID \
#                                               --email=quantum@hastexo.com)
#    keystone user-role-add --tenant_id $SERVICE_TENANT_ID \
#                           --user $QUANTUM_USER_ID \
#                           --role $ADMIN_ROLE_ID
#fi
