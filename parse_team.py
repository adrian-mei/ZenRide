import sys
import plistlib

try:
    with open(sys.argv[1], 'rb') as f:
        data = f.read()
        start = data.find(b'<?xml')
        end = data.find(b'</plist>') + 8
        plist_data = data[start:end]
        plist = plistlib.loads(plist_data)
        print(plist.get('TeamIdentifier', ['UNKNOWN'])[0])
except Exception as e:
    print(e)
