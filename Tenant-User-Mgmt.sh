#!/bin/bash
# Jason Grimm
 
clear
 
#####
#
# multi-tenant-user-management-script.sh
# Quick script to create / reset users, passwords and admin access for multiple users across multiple tenants
# Jason Grimm, 10.7.2015, jgrimm73@gmail.com, http://www.brothergrimm.com
#
#
# Basic useage is to loop through multiple environments, create / or reset a list of users in that environment and grant them admin access
#
# Example flow:
#
# 1. Set varialbes, arrays, etc.
# 1a. Create environment list
# 1b. Set default admin name
# 1c. Set default tenant suffix (optional, but handy to avoid multiple tenants, users, etc. with "admin" in their name)
# 1d. Create user list
# 1e. Set default new password
#
# 2. Start first loop (environments)
# 2a. Source credentials
# 2b. Check credentials, if credentials fail skip environment to avoid throwing a bunch of errors
# 2c. Get admin tenant id
# 2d. Get admin role id
#
# 3. Start second loop (users)
# 3a. Check to see if user exists
# 3b. Get user id
# 3c. Check to see if user is enabled
# 3d. Update user password
# 3e. Add user to admin tenant and to admin role
# 3f. Create new user and add to admin tenant / role
#
#####
 
# 1. Set varialbes, arrays, etc.
echo "############# 1. Set variables"
 
# 1a. Create environment list; add multiple environments with a space in between, e.g. "demo1 trial1 trial2" and so on
ENV_LIST="Admin.sh"
echo "###### 1a. Create environment list; environment list set to $(echo $ENV_LIST)"
 
# 1b. Set default admin name
# 1b. NOTE - This script assumes consistent admin user names across tenants and will fail otherwise
ADMIN_NAME="demoadmin"
echo "###### 1b. Set default admin name; default admin name set to $(echo $ADMIN_NAME)"
 
# 1c. Set default tenant suffix (optional, but handy to avoid multiple tenants, users, etc. with "admin" in their name)
# 1c. NOTE - This script assumes consistent admin tenant names across tenants and will fail otherwise
ADMIN_TENANT_NAME="Demo Admin"
echo "###### 1c. Set default tenant suffix; set to $ADMIN_TENANT_NAME"
 
# 1d. Create user list; add multiple users with a space in between, e.g. "jgrimm73 jgrimm74" and so on
# 1d. NOTE - Do not use the username that you are authenticating with in your crecential file in this list as the password will be changed
# 1d. the script will complete because you already have a session open, but remember to update your credential files with the new password
USER_LIST="demo-user1"
echo "###### 1d. Create user list; user list set to $(echo $USER_LIST)"
 
# 1e. Set default new password
NEW_PASS="P@ssw0rd"
echo "###### 1e. Set default password for new users to $NEW_PASS"
 
echo "#############"
 
# 2. Start first loop (environments)
echo ""
echo "######### 2. Start first loop (environments)"
for ENV in $ENV_LIST; do
 
    # 2a. Source credentials
    # 2a. NOTE - Make sure admin credential files are pre-created, named correctly and working properly
    echo "##### 2a. Sourcing credentials ~/$ENV"
    echo "##### 2a. Connecting to environment $ENV ..."
 
    . ~/credrc-$ENV
 
    # 2b. Check credentials, if credentials fail skip environment to avoid throwing a bunch of errors
    echo "##### 2b. Testing admin credentials"
    # echo ""
    if keystone role-get admin; then
 
        # echo ""
        echo "##### 2b. Admin credentials work fine"
        # If command successful then process the environment
        echo "##### 2b. Processing environment $ENV ..."
 
        # 2c. Get Admin tenant id
        echo "##### 2c. Getting admin tenant id for environment $ENV"
        ADMIN_TENANT_ID=`keystone tenant-list | grep "$(echo $ENV $ADMIN_TENANT_NAME)" | awk '{ print $2 }'`
        echo "##### 2c. Admin tenant id for environment $ENV is $ADMIN_TENANT_ID"
 
        # 2d. Get Admin role id
        echo "##### 2d. Getting admin role id for environment $ENV"
        ADMIN_ROLE_ID=`keystone role-get admin | awk '/ id / { print $4 }'`
        echo "##### 2d. Admin role id for environment $ENV is $ADMIN_ROLE_ID"
 
        echo "#############"
 
        # 3. Start second loop (users)
        echo ""
        echo "######### 3. Start second loop (users)"
        for USER in $USER_LIST; do
 
            # 3a. Check to see if user exists
            echo "##### 3a. Check to see if user $USER exists ..."
            if keystone user-list | grep $USER 1>/dev/null; then
 
                echo "##### 3a. User $USER exists, only get id, enable, add to admin role / tenant and reset password"
 
                # 3b. Get user id
                echo "##### 3b. Getting user id for user $USER ..."
                USER_ID=`keystone user-get $USER | awk '/ id / { print $4 }'`
                echo "##### 3b. User id for user $USER is $USER_ID"
 
                # 3c. Check to see if user is enabled
                echo "##### 3c. Checking to see if user $USER is enabled ..."
                if [[ "$(keystone user-get $USER | awk '/ enabled / { print $4 }')" == "True"  ]]; then
                    
                    # User is already enabled, do nothing
                    echo "##### 3c. User $USER is enabled, do nothing"
 
                    # Show results
                    echo "##### 3c. Check results for user $USER"
                    # echo ""
                    keystone user-get $USER
                    # echo ""
 
                else
 
                    # User is not enabled, enable now
                    echo "##### 3c. User $USER is not enabled, enabling now ..."
                    keystone user-update --enabled true $USER_ID
 
                    # Show results
                    echo "##### 3c. Check results for user $USER"
                    # echo ""
                    keystone user-get $USER
                    # echo ""
 
                fi
 
                # 3d. Update user password
                echo "##### 3d. Update user password for user $USER ..."
                keystone user-password-update --pass "$NEW_PASS" $USER
 
                # 3e. Check to see if the user is already in the admin tenant with the admin role
                echo "##### 3e. Check $USER is in admin tenant $ADMIN_TENANT_ID & set to admin role $ADMIN_ROLE_ID ..."
 
                if keystone user-role-list --user $USER --tenant $ADMIN_TENANT_ID | awk '/ admin / { print $4 }' 1>/dev/null; then
 
                    echo "##### 3e. $USER is in admin tenant $ADMIN_TENANT_ID & set to admin role $ADMIN_ROLE_ID"
 
                else
 
                    # Add user to admin tenant and to admin role
                    echo "##### 3e. $USER is not in the admin tenant $ADMIN_TENANT_ID & is not set to admin role $ADMIN_ROLE_ID, enabling now ..."
                    keystone user-role-add --user $USER --role $ADMIN_ROLE_ID --tenant $ADMIN_TENANT_ID
 
                fi
 
            else
 
                # 3f. Create new user and add to admin tenant / role
                echo "##### 3f. $USER doesn't exist, creating user, setting password & adding to admin tenant / role"
                keystone user-create --name $USER --tenant-id $ADMIN_TENANT_ID --pass $NEW_PASS --enabled true
                keystone user-role-add --user $USER --role $ADMIN_ROLE_ID --tenant $ADMIN_TENANT_ID
 
            fi
 
            echo "#############"
    
        done
 
    else
 
        echo ""
        echo "Problem with credentials or access level"
        echo "Processing next tenant / user ..."
 
    fi
 
    echo ""
    echo "Processing next tenant / user ..."
 
done
 
echo ""
echo "No more tenants or users to process, all complete."
 
exit
