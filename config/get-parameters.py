#!/usr/bin/env python
import json,sys
with open(sys.argv[1]) as f:
    o = json.load(f)
for k,v in o["Parameters"].iteritems():
    print "{0}={1}".format(k,v)
