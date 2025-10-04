#!/usr/bin/env python3
# Check TOR is working
import urllib.request
import json
response = urllib.request.urlopen("https://check.torproject.org/api/ip")
data = json.loads(response.read())
if data["IsTor"]:
	exit(0)
else:
	print("This connection is NOT routed through TOR!")
	exit(1)
