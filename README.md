# Jenkins Credentials Migration

Run the script in `export.groovy` in the Script Console on the source Jenkins. It will output an encoded message containing a flattened list of all system and folder credentials. 

Then, copy the output from that script and paste it to overwrite the `encoded` variable from `import.groovy` and execute in the Script Console on the destination Jenkins. All the credentials and domains from the source Jenkins will now be imported to the system store of the destination Jenkins. 
