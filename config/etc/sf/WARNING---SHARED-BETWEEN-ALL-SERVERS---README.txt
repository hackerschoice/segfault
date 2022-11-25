@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ THIS DIRECTORY IS SHARED BETWEEN ALL SERVERS @@@
@@@ BE CAREFUL OF WHAT YOU TOUCH OR PUT HERE     @@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

You have write-access to "/everyone/this". Put your
data to share in that directory.
Everyone else has read-only access to that same data
at "/everyone/${SF_HOSTNAME}"

Try it:
echo "Hello World" >/everyone/this/hello.txt
cat "/everyone/${SF_HOSTNAME}/hello.txt"

