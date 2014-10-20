# Copyright © 2000 Abou Jreij
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.

USERNAME=""   # your moodle username
PASSWORD=""   # your moodle password
PHONENUM=""   # your phone number with your country code (ex 111848391)
ACCOUNTSID="" # your twillio account SID
AUTHTOKEN=""  # your twillio token

CACHE_DIR=~/.moodle_cache

cURL_URL=""   # your moodle homepage (the base URL of moodle)
cURL_DATA="username=$USERNAME&password=$PASSWORD"
cURL_COOKIES=$CACHE_DIR/cookies.txt

# Create cache dir
if [ ! -d $CACHE_DIR ]
then
    mkdir $CACHE_DIR
fi

# Proceed to login and retrieve the homepage
echo "==== Running checker at $(date) ===="
echo "==== Authenticating ===="
curl --data $cURL_DATA $cURL_URL/login/index.php -c $cURL_COOKIES -s > $CACHE_DIR/moodle_session.txt
test_session=$(cat $CACHE_DIR/moodle_session.txt | grep testsession | sed "s/^.*testsession=\([0-9][0-9]*\).*$/\1/")
curl "$cURL_URL/login/index.php?testsession=$testsession" -b $cURL_COOKIES -s > /dev/null
curl $cURL_URL -b $cURL_COOKIES -s > $CACHE_DIR/moodle_homepage.html

echo "==== Getting all course ids and names ===="
# Extract all the course ids
course_ids=$(cat $CACHE_DIR/moodle_homepage.html | grep dropdown-menu | sed "s/course\/view.php?id=\([0-9][0-9]*\)\">\([A-Z]*[0-9]*\)/{{\\n\1-\2\\n}}/g" | grep "^[0-9][0-9]*")

changed_courses=""

for idname in $course_ids
do
    # Get the course id and the course name
    id=$(echo $idname | tr '-' '\n' | head -n 1)
    name=$(echo $idname | tr '-' '\n' | tail -n 1)

    echo "==== Checking if $name changed ===="

    # Cache the page if it does not exists
    if [ ! -f $CACHE_DIR/$id.$name.html ]
    then
        curl -b $cURL_COOKIES $cURL_URL/course/view.php?id=$id -s > $CACHE_DIR/$id.$name.html

    # Check for difference, add to list if some exist
    else
        LOCALDOC=$(sed '/<section/,/<\/section>/!d' $CACHE_DIR/$id.$name.html)
        # Download online copy
        curl -b $cURL_COOKIES $cURL_URL/course/view.php?id=$id -s > $CACHE_DIR/$id.$name.html
        REMOTEDOC=$(sed '/<section/,/<\/section>/!d' $CACHE_DIR/$id.$name.html)
        if [ ! "$LOCALDOC" = "$REMOTEDOC" ]
        then
            changed_courses="$changed_courses $name"
        fi
    fi
done

if [ ! "$changed_courses" = "" ]
then
    changed_courses="The following courses' moodle page have changed: $changed_courses"
    curl -X POST https://api.twilio.com/2010-04-01/Accounts/$ACCOUNTSID/Messages -u $ACCOUNTSID:$AUTHTOKEN -d "From=%2B14704287840" -d "To=%2B$PHONENUM" -d "Body=$changed_courses" -s > /dev/null
else
    echo "==== Nothing changed! ===="
fi

echo $changed_courses
