import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\screen\reports\csv_import_helper.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix default mode in payments loop
text = text.replace("String pMode = 'Cash';", "String pMode = 'UPI';")

# Fix fallback default mode in the payload
text = text.replace("'paymentMode': 'Cash',", "'paymentMode': 'UPI',")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
