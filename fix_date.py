import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\models\project_model.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Make a function helper to parse local
helper = """
DateTime? _parseLocal(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}
"""

text = text.replace("class EntryModel {", helper + "\nclass EntryModel {")

text = text.replace("date: DateTime.tryParse(j['date']?.toString() ?? j['createdAt']?.toString() ?? '') ?? DateTime.now(),", "date: _parseLocal(j['date']?.toString() ?? j['createdAt']?.toString()) ?? DateTime.now(),")
text = text.replace("paymentDate: j['paymentDate'] != null\n          ? DateTime.tryParse(j['paymentDate'].toString())\n          : null,", "paymentDate: _parseLocal(j['paymentDate']?.toString()),")
text = text.replace("approvedAt: j['approvedAt'] != null\n          ? DateTime.tryParse(j['approvedAt'].toString())\n          : null,", "approvedAt: _parseLocal(j['approvedAt']?.toString()),")
text = text.replace("completedAt: j['completedAt'] != null\n          ? DateTime.tryParse(j['completedAt'].toString())\n          : null,", "completedAt: _parseLocal(j['completedAt']?.toString()),")
text = text.replace("budgetLastCalculatedAt: j['budgetLastCalculatedAt'] != null\n          ? DateTime.tryParse(j['budgetLastCalculatedAt'].toString())\n          : null,", "budgetLastCalculatedAt: _parseLocal(j['budgetLastCalculatedAt']?.toString()),")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done project_model")
