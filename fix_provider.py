import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\controller\project_provider.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("date: json['date'] != null\n              ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()\n              : DateTime.now(),\n          description:", "createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),\n          date: json['date'] != null\n              ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()\n              : DateTime.now(),\n          description:")

text = text.replace("date: entry.date,\n        description:", "createdAt: entry.createdAt,\n        date: entry.date,\n        description:")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done project_provider")
