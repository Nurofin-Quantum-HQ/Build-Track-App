import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\models\project_model.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("final parsed = DateTime.tryParse(rawStartDate);", "final parsed = _parseLocal(rawStartDate);")
text = text.replace("parsedExpectedEnd = DateTime.tryParse(rawExpected);", "parsedExpectedEnd = _parseLocal(rawExpected);")
text = text.replace("DateTime.tryParse(dates!['actualEndDate'].toString())", "_parseLocal(dates!['actualEndDate'].toString())")
text = text.replace("DateTime.tryParse(j['actualEndDate'].toString())", "_parseLocal(j['actualEndDate'].toString())")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
