import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\screen\reports\csv_import_helper.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix inner array property
text = text.replace("'paymentMode': pMode,", "'method': pMode,")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
