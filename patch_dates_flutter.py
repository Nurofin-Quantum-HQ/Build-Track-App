import os

files = [
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/manual_voice_entry/add_material.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/manual_voice_entry/add_labour.dart',
    'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/manual_voice_entry/add_equipment.dart'
]

for filepath in files:
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            c = f.read()
        
        # When picked is returned, we need to inject the current time.
        # Find: if (picked != null) {
        # And inject: 
        # final now = DateTime.now();
        # final withTime = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second);
        # _selectedDate = withTime;
        # But maybe they are already doing setState(() => _selectedDate = picked)
        
        # We can just replace: setState(() => _selectedDate = picked);
        # with:
        # final now = DateTime.now();
        # setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second));
        
        c = c.replace('setState(() => _selectedDate = picked);', '''final now = DateTime.now();
                                setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second));''')
        
        # Wait, what if it's setState(() { _selectedDate = picked; });?
        c = c.replace('setState(() {\n                                _selectedDate = picked;\n                              });', '''final now = DateTime.now();
                              setState(() {
                                _selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second);
                              });''')
                              
        c = c.replace('_selectedDate = picked;', '''_selectedDate = DateTime(picked.year, picked.month, picked.day, DateTime.now().hour, DateTime.now().minute, DateTime.now().second);''')
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(c)

print("Patched Flutter manual entry dates")
