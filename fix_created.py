import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\models\project_model.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("final DateTime date;", "final DateTime date;\n  final DateTime createdAt;")
text = text.replace("required this.date,", "required this.date,\n    required this.createdAt,")
text = text.replace("date: _parseLocal(j['date']?.toString() ?? j['createdAt']?.toString()) ?? DateTime.now(),", "date: _parseLocal(j['date']?.toString() ?? j['createdAt']?.toString()) ?? DateTime.now(),\n      createdAt: _parseLocal(j['createdAt']?.toString()) ?? DateTime.now(),")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done project_model")

path2 = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\screen\dashboard\homescreen.dart"
with open(path2, "r", encoding="utf-8") as f:
    text2 = f.read()

text2 = text2.replace("final timeLabel = relativeTimeLabel(entry.date.toLocal());", "final timeLabel = relativeTimeLabel(entry.createdAt.toLocal());")

with open(path2, "w", encoding="utf-8") as f:
    f.write(text2)
print("Done homescreen")

