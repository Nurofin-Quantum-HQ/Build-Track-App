import os

path = r"c:\Users\Muneesha\Desktop\build-track\Build-Track-App\lib\models\project_model.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

payment_history_old = """    final paymentHistory = j['paymentHistory'] != null
        ? List<Map<String, dynamic>>.from(
            (j['paymentHistory'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : const <Map<String, dynamic>>[];"""

payment_history_new = """    final paymentHistory = j['paymentHistory'] != null
        ? List<Map<String, dynamic>>.from(
            (j['paymentHistory'] as List).map(
              (e) {
                final m = Map<String, dynamic>.from(e as Map);
                if (m['date'] != null) {
                   m['date'] = _parseLocal(m['date'].toString())?.toIso8601String() ?? m['date'];
                }
                return m;
              }
            ),
          )
        : const <Map<String, dynamic>>[];"""

text = text.replace(payment_history_old, payment_history_new)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done payment_history")
