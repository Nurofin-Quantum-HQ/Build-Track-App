import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/frontend/src/components/ThemePicker.jsx', 'r', encoding='utf-8') as f:
    content = f.read()

# Add useAuth and api call
if 'useAuth' not in content:
    content = content.replace("import React, { useState, useEffect } from 'react';",
                              "import React, { useState, useEffect } from 'react';\nimport { useAuth } from '../contexts/AuthContext';\nimport api from '../utils/api';")

if 'const { user, updateUser } = useAuth();' not in content:
    content = content.replace('export function ThemePicker() {',
                              'export function ThemePicker() {\n  const { user, updateUser } = useAuth();')

# Update applyTheme
old_apply = '''  const applyTheme = (color) => {
    const hover = adjustColor(color, -20); // darken
    const light = adjustColor(color, 30);  // lighten
    const rgb = hexToRgb(color);

    document.documentElement.style.setProperty('--color-primary', color);
    document.documentElement.style.setProperty('--color-primary-hover', hover);
    document.documentElement.style.setProperty('--color-primary-light', light);
    document.documentElement.style.setProperty('--color-primary-rgb', rgb);
    localStorage.setItem('bt_theme_color', color);
  };'''

new_apply = '''  const applyTheme = (color, saveToBackend = false) => {
    const hover = adjustColor(color, -20); // darken
    const light = adjustColor(color, 30);  // lighten
    const rgb = hexToRgb(color);

    document.documentElement.style.setProperty('--color-primary', color);
    document.documentElement.style.setProperty('--color-primary-hover', hover);
    document.documentElement.style.setProperty('--color-primary-light', light);
    document.documentElement.style.setProperty('--color-primary-rgb', rgb);
    localStorage.setItem('bt_theme_color', color);
    
    if (saveToBackend && user) {
      api.put('/auth/profile', { themePreference: color })
        .then(res => {
          if (updateUser) updateUser(res.data.user);
        })
        .catch(err => console.error("Failed to sync theme", err));
    }
  };'''

content = content.replace(old_apply, new_apply)

content = content.replace('applyTheme(c);', 'applyTheme(c, true);')

# Also sync when user logs in! (In App.jsx or ThemePicker useEffect)
sync_effect = '''  useEffect(() => {
    if (user?.themePreference) {
      setThemeColor(user.themePreference);
      applyTheme(user.themePreference, false);
    } else {
      const saved = localStorage.getItem('bt_theme_color');
      if (saved) {
        setThemeColor(saved);
        applyTheme(saved, false);
      }
    }
  }, [user?.themePreference]);'''

content = re.sub(r'  useEffect\(\(\) => \{\n    const saved = localStorage\.getItem\(\'bt_theme_color\'\);\n    if \(saved\) \{\n      setThemeColor\(saved\);\n      applyTheme\(saved\);\n    \}\n  \}, \[\]\);', sync_effect, content)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/frontend/src/components/ThemePicker.jsx', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated ThemePicker frontend sync")
